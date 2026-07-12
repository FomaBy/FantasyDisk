#!/usr/bin/env python3
"""audio_master.py — мастеринг аудио-пака FantasyDisk (SCRUM-966/967).

Курируемые CC0/CC-BY источники -> канонические ogg по спеке
docs/design/systems/audio.md (§2 музыка, §5 SFX, §6 loudness, §7 форматы).

Что делает:
  * музыка: intro+loop-edit (bar-aligned, кроссфейд шва EOF->loop_offset),
    x2-удлинение авторских лупов, детект хвостового фейда, LUFS-нормализация
    (integrated -16 LUFS +-0.5), true-peak лимит <= -1.0 dBTP, LRA-отчёт,
    loop-seam QA (амплитудный скачок на стыке);
  * SFX: слоение/трим/фейды/питч (resample)/biquad LP-HP, моно-даунмикс,
    нормализация по max momentary loudness (400 мс), true-peak лимит;
  * конверсия в OGG Vorbis 44.1 kHz (libsndfile), метаданные не переносятся
    (гардрейл §1.4: чистые теги);
  * отчёт: длительности, LUFS, true peak, seam-скачок, размер файла.

Зависимости: numpy + soundfile (обязательно; libsndfile >= 1.1 читает mp3,
пишет ogg). scipy и pyloudnorm опциональны (fallback: линейный ресемплер и
K-weighted приближение соответственно).

Запуск (венв не обязателен, системный python3 с установленными numpy/soundfile
тоже подходит):
  python3 tools/audio_master.py \
      --manifest tools/audio_master_manifest.json \
      --src <dir с исходниками> --out <корень assets/audio> [--only id ...]
"""

from __future__ import annotations

import argparse
import json
import math
import os
import sys

import numpy as np

try:
    import soundfile as sf
except ImportError:  # pragma: no cover
    print("FATAL: нужен python-soundfile (pip install soundfile numpy)")
    raise

try:
    from scipy.signal import resample_poly

    HAVE_SCIPY = True
except ImportError:  # pragma: no cover
    HAVE_SCIPY = False

try:
    import pyloudnorm

    HAVE_PYLN = True
except ImportError:  # pragma: no cover
    HAVE_PYLN = False

SR = 44100


# ---------------------------------------------------------------- утилиты DSP


def db_to_lin(db: float) -> float:
    return 10.0 ** (db / 20.0)


def load_audio(path: str, target_sr: int = SR) -> np.ndarray:
    """float32 (n, ch), ресемпл к target_sr."""
    data, sr = sf.read(path, dtype="float32", always_2d=True)
    if sr != target_sr:
        if HAVE_SCIPY:
            g = math.gcd(sr, target_sr)
            data = resample_poly(data, target_sr // g, sr // g, axis=0).astype(
                np.float32
            )
        else:  # линейная интерполяция (fallback без scipy)
            n_out = int(round(len(data) * target_sr / sr))
            x_old = np.linspace(0.0, 1.0, len(data), endpoint=False)
            x_new = np.linspace(0.0, 1.0, n_out, endpoint=False)
            data = np.stack(
                [np.interp(x_new, x_old, data[:, c]) for c in range(data.shape[1])],
                axis=1,
            ).astype(np.float32)
    return data


def to_mono(x: np.ndarray) -> np.ndarray:
    return x.mean(axis=1, keepdims=True) if x.shape[1] > 1 else x


def resample_rate(x: np.ndarray, rate: float) -> np.ndarray:
    """Питч/скорость через ресемплинг (rate<1 => ниже и длиннее)."""
    if abs(rate - 1.0) < 1e-6:
        return x
    n_out = int(round(len(x) / rate))
    x_old = np.arange(len(x), dtype=np.float64)
    x_new = np.linspace(0.0, len(x) - 1.0, n_out)
    return np.stack(
        [np.interp(x_new, x_old, x[:, c]) for c in range(x.shape[1])], axis=1
    ).astype(np.float32)


def biquad(x: np.ndarray, kind: str, freq: float, q: float = 0.7071) -> np.ndarray:
    """RBJ biquad low/high-pass."""
    w0 = 2.0 * math.pi * freq / SR
    alpha = math.sin(w0) / (2.0 * q)
    cw = math.cos(w0)
    if kind == "lp":
        b0, b1, b2 = (1 - cw) / 2, 1 - cw, (1 - cw) / 2
    elif kind == "hp":
        b0, b1, b2 = (1 + cw) / 2, -(1 + cw), (1 + cw) / 2
    else:
        raise ValueError(kind)
    a0, a1, a2 = 1 + alpha, -2 * cw, 1 - alpha
    b = np.array([b0, b1, b2]) / a0
    a = np.array([a1, a2]) / a0
    y = np.zeros_like(x)
    for c in range(x.shape[1]):
        x1 = x2 = y1 = y2 = 0.0
        xc = x[:, c]
        yc = y[:, c]
        for i in range(len(xc)):
            v = b[0] * xc[i] + b[1] * x1 + b[2] * x2 - a[0] * y1 - a[1] * y2
            x2, x1 = x1, xc[i]
            y2, y1 = y1, v
            yc[i] = v
    return y


def fade(x: np.ndarray, fade_in: float = 0.0, fade_out: float = 0.0) -> np.ndarray:
    x = x.copy()
    n_in = int(fade_in * SR)
    n_out = int(fade_out * SR)
    if n_in > 0:
        x[:n_in] *= np.linspace(0.0, 1.0, n_in)[:, None] ** 1.5
    if n_out > 0:
        x[-n_out:] *= np.linspace(1.0, 0.0, n_out)[:, None] ** 1.5
    return x


# ------------------------------------------------------------------- loudness


class Loudness:
    """EBU R128 через pyloudnorm; RMS-приближение как fallback."""

    def __init__(self):
        self.meter = pyloudnorm.Meter(SR) if HAVE_PYLN else None

    def integrated(self, x: np.ndarray) -> float:
        if self.meter and len(x) >= int(0.5 * SR):
            return float(self.meter.integrated_loudness(x))
        mono = x.mean(axis=1)
        rms = np.sqrt(np.mean(mono**2)) + 1e-12
        return 20 * math.log10(rms) - 0.691  # грубое приближение

    def windowed_max(self, x: np.ndarray, win_s: float) -> float:
        """Максимум loudness по окнам (0.4 c ~ momentary, 3 c ~ short-term)."""
        n = int(win_s * SR)
        if len(x) <= n:
            pad = np.zeros((n - len(x) + 1, x.shape[1]), dtype=np.float32)
            return self.integrated(np.concatenate([x, pad]))
        hop = max(1, n // 4)
        best = -120.0
        for s in range(0, len(x) - n + 1, hop):
            best = max(best, self.integrated(x[s : s + n]))
        return best

    def lra(self, x: np.ndarray) -> float:
        """Loudness range по EBU TECH 3342 (упрощённо, окна 3 c/шаг 1 c)."""
        n = int(3.0 * SR)
        hop = SR
        vals = []
        for s in range(0, max(1, len(x) - n + 1), hop):
            v = self.integrated(x[s : s + n])
            if v > -70.0:
                vals.append(v)
        if len(vals) < 3:
            return 0.0
        vals = np.array(vals)
        gate = vals[vals > vals.mean() - 20.0]
        return float(np.percentile(gate, 95) - np.percentile(gate, 10))


def true_peak_db(x: np.ndarray) -> float:
    if HAVE_SCIPY:
        up = resample_poly(x, 4, 1, axis=0)
    else:
        up = x
    return 20 * math.log10(float(np.abs(up).max()) + 1e-12)


def limit_true_peak(x: np.ndarray, ceiling_db: float) -> np.ndarray:
    """Простой lookahead-лимитер (5 мс атака, 60 мс релиз)."""
    ceil_lin = db_to_lin(ceiling_db) * 0.995
    la = int(0.005 * SR)
    rel = int(0.060 * SR)
    amp = np.abs(x).max(axis=1)
    # скользящий максимум в окне lookahead
    if la > 1:
        from numpy.lib.stride_tricks import sliding_window_view

        padded = np.concatenate([amp, np.full(la - 1, amp[-1] if len(amp) else 0.0)])
        amp = sliding_window_view(padded, la).max(axis=1)
    need = np.minimum(1.0, ceil_lin / np.maximum(amp, 1e-9))
    gain = np.empty_like(need)
    g = 1.0
    alpha = 1.0 - math.exp(-1.0 / rel)
    for i in range(len(need)):
        tgt = need[i]
        if tgt < g:
            g = tgt  # мгновенная атака
        else:
            g += (tgt - g) * alpha
        gain[i] = g
    return (x * gain[:, None]).astype(np.float32)


def normalize(
    x: np.ndarray, meter: Loudness, mode: str, target_db: float, ceiling_db: float
) -> tuple[np.ndarray, float, float]:
    """Нормализация к target (mode: integrated|momentary_max|shortterm_max).

    Итеративно: лимитер съедает часть громкости — докручиваем гейн до
    попадания в +-0.3 LU (или пока не упрёмся в потолок), затем корректирующий
    трим по true peak (лимитер работает по сэмплам, межсэмпловые пики могут
    вылезти за потолок)."""

    def measure(v: np.ndarray) -> float:
        if mode == "integrated":
            return meter.integrated(v)
        if mode == "momentary_max":
            return meter.windowed_max(v, 0.4)
        return meter.windowed_max(v, 3.0)

    x0 = x  # каждый заход лимитируем ЧИСТЫЙ гейнированный сигнал: повторное
    # лимитирование уже лимитированного накапливает pumping-артефакты
    gain = target_db - measure(x0)
    y = x0
    got = measure(y)
    for _ in range(4):
        y = limit_true_peak((x0 * db_to_lin(gain)).astype(np.float32), ceiling_db)
        got = measure(y)
        if abs(target_db - got) <= 0.3:
            break
        step = target_db - got
        if step > 2.0 and gain > target_db - measure(x0) + 6.0:
            break  # лимитер стеной — дальше только каша
        gain += min(2.0, max(-6.0, step))
    tp = true_peak_db(y)
    if tp > ceiling_db:  # межсэмпловый overshoot — статический трим
        y = (y * db_to_lin(ceiling_db - tp)).astype(np.float32)
        got = measure(y)
        tp = true_peak_db(y)
    return y, got, tp


# -------------------------------------------------------------- анализ музыки


def rms_envelope(x: np.ndarray, hop_s: float = 0.010) -> np.ndarray:
    mono = x.mean(axis=1)
    hop = int(hop_s * SR)
    n = len(mono) // hop
    env = np.sqrt(
        np.mean(mono[: n * hop].reshape(n, hop) ** 2, axis=1) + 1e-12
    )
    return env


def onset_strength(x: np.ndarray, hop_s: float = 0.010) -> np.ndarray:
    env = rms_envelope(x, hop_s)
    log_env = np.log(env + 1e-9)
    k = 5
    sm = np.convolve(log_env, np.ones(k) / k, mode="same")
    d = np.diff(sm, prepend=sm[0])
    return np.maximum(0.0, d)


def snap_to_onset(x: np.ndarray, t: float, window: float = 0.35) -> float:
    """Ближайший сильный онсет к моменту t (сек)."""
    hop_s = 0.010
    ons = onset_strength(x, hop_s)
    i0 = max(0, int((t - window) / hop_s))
    i1 = min(len(ons) - 1, int((t + window) / hop_s))
    if i1 <= i0:
        return t
    seg = ons[i0 : i1 + 1]
    return (i0 + int(np.argmax(seg))) * hop_s


def detect_tail_fade(x: np.ndarray) -> float:
    """Начало хвостового фейда (сек); len(x)/SR если фейда нет."""
    env = rms_envelope(x, 0.050)
    if len(env) < 100:
        return len(x) / SR
    ref = np.median(env[len(env) // 4 : len(env) * 3 // 4])
    thr = ref * db_to_lin(-9.0)
    i = len(env)
    while i > 0 and env[i - 1] < thr:
        i -= 1
    return i * 0.050


def crossfade_loop_seam(
    x: np.ndarray, k: int, l: int, xfade: int
) -> np.ndarray:
    """Вырезает [0:l], вшивая в хвост материал перед k равномощным кроссфейдом,
    чтобы wrap EOF->k был непрерывен. Требует k >= xfade."""
    assert k >= xfade > 0 and l <= len(x)
    out = x[:l].copy()
    t = np.linspace(0.0, 1.0, xfade)[:, None]
    a = np.cos(t * math.pi / 2.0)  # хвост лупа затухает
    b = np.sin(t * math.pi / 2.0)  # материал перед k нарастает
    out[l - xfade : l] = out[l - xfade : l] * a + x[k - xfade : k] * b
    return out


def seam_jump(x: np.ndarray, loop_offset_samples: int) -> float:
    """Амплитудный скачок стыка EOF -> loop_offset (методика SCRUM-154)."""
    last = x[-1]
    first = x[loop_offset_samples]
    return float(np.abs(first - last).max())


# ------------------------------------------------------------------ пайплайны


def build_music(entry: dict, src_dir: str, meter: Loudness) -> tuple[np.ndarray, dict]:
    mode = entry["edit"]
    info: dict = {}
    if mode == "author_loop":
        x = load_audio(os.path.join(src_dir, entry["src"]))
        reps = int(entry.get("repeat", 1))
        core = x
        x = np.concatenate([core] * reps) if reps > 1 else core
        loop_off = (reps - 1) * len(core)
        info["loop_offset_sec"] = loop_off / SR
        info["seam"] = seam_jump(x, loop_off)
    elif mode == "cut_loop":
        x = load_audio(os.path.join(src_dir, entry["src"]))
        bpm = float(entry["bpm"])
        bar = 4.0 * 60.0 / bpm
        intro_hint = float(entry.get("intro_sec", 3.0))
        k_t = snap_to_onset(x, intro_hint)
        loop_target = float(entry["loop_sec"])
        usable_end = detect_tail_fade(x) - float(entry.get("tail_guard_sec", 1.0))
        bars = max(4, int(round(loop_target / bar)))
        while k_t + bars * bar > usable_end and bars > 4:
            bars -= 1
        l_t = snap_to_onset(x, k_t + bars * bar, window=min(0.45, bar / 4))
        xfade = int(float(entry.get("seam_xfade_sec", 0.35)) * SR)
        k = int(k_t * SR)
        l = min(int(l_t * SR), len(x))
        k = max(k, xfade)
        y = crossfade_loop_seam(x, k, l, xfade)
        x = y
        info["loop_offset_sec"] = k / SR
        info["loop_bars"] = bars
        info["seam"] = seam_jump(x, k)
    elif mode == "sting_cut":
        x = load_audio(os.path.join(src_dir, entry["src"]))
        t0 = snap_to_onset(x, float(entry["start_sec"])) - 0.02
        t0 = max(0.0, t0)
        dur = float(entry["dur_sec"])
        x = x[int(t0 * SR) : int((t0 + dur) * SR)]
        x = fade(x, fade_in=0.008, fade_out=float(entry.get("fade_out_sec", 0.35)))
        info["loop_offset_sec"] = None
    else:
        raise ValueError(mode)
    norm_mode = entry.get("norm", "integrated")
    x, got, tp = normalize(
        x, meter, norm_mode, float(entry["lufs"]), float(entry.get("ceiling", -1.0))
    )
    if info.get("loop_offset_sec") is not None:
        info["seam"] = seam_jump(x, int(info["loop_offset_sec"] * SR))
    info.update(loudness=got, true_peak=tp, dur=len(x) / SR)
    if norm_mode == "integrated":
        info["lra"] = meter.lra(x)
    return x, info


def build_sfx(entry: dict, src_dir: str, meter: Loudness) -> tuple[np.ndarray, dict]:
    total = int(float(entry["dur_sec"]) * SR)
    ch = 2 if entry.get("stereo") else 1
    canvas = np.zeros((total, ch), dtype=np.float32)
    for layer in entry["layers"]:
        x = load_audio(os.path.join(src_dir, layer["src"]))
        if s := layer.get("slice"):
            x = x[int(s[0] * SR) : int(s[1] * SR)]
        if r := layer.get("pitch"):
            x = resample_rate(x, float(r))
        if hz := layer.get("lp"):
            x = biquad(x, "lp", float(hz))
        if hz := layer.get("hp"):
            x = biquad(x, "hp", float(hz))
        x = to_mono(x) if ch == 1 else (np.repeat(x, 2, axis=1) if x.shape[1] == 1 else x)
        x = x * db_to_lin(float(layer.get("gain_db", 0.0)))
        if fi := layer.get("fade_in"):
            x = fade(x, fade_in=float(fi))
        if fo := layer.get("fade_out"):
            x = fade(x, fade_out=float(fo))
        off = int(float(layer.get("at", 0.0)) * SR)
        n = min(len(x), total - off)
        if n > 0:
            canvas[off : off + n] += x[:n]
    if entry.get("loop"):
        xf = int(float(entry.get("loop_xfade_sec", 0.25)) * SR)
        t = np.linspace(0.0, 1.0, xf)[:, None]
        head = canvas[:xf].copy()
        canvas[-xf:] = canvas[-xf:] * np.cos(t * math.pi / 2) + head * np.sin(
            t * math.pi / 2
        )
    else:
        canvas = fade(
            canvas,
            fade_in=float(entry.get("fade_in", 0.002)),
            fade_out=float(entry.get("fade_out", 0.02)),
        )
    x, got, tp = normalize(
        canvas,
        meter,
        entry.get("norm", "momentary_max"),
        float(entry["lufs"]),
        float(entry.get("ceiling", -3.0)),
    )
    info = {"dur": len(x) / SR, "loudness": got, "true_peak": tp}
    if entry.get("loop"):
        info["seam"] = seam_jump(x, 0)
    return x, info


def write_ogg(path: str, x: np.ndarray, compression_level: float) -> None:
    """Пишет OGG Vorbis чанками по 1 c: одноразовый sf.write всего буфера
    сегфолтит libsndfile 1.2.2 на длинных треках (проверено на 115 c)."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    data = x if x.shape[1] > 1 else x[:, 0]
    kwargs = {"compression_level": compression_level}
    try:
        handle = sf.SoundFile(
            path, "w", SR, x.shape[1], format="OGG", subtype="VORBIS", **kwargs
        )
    except TypeError:  # старый soundfile без compression_level
        handle = sf.SoundFile(path, "w", SR, x.shape[1], format="OGG", subtype="VORBIS")
    with handle:
        for i in range(0, len(data), SR):
            handle.write(data[i : i + SR])


# ------------------------------------------------------------------------ CLI


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--manifest", required=True)
    ap.add_argument("--src", required=True, help="каталог исходников")
    ap.add_argument("--out", required=True, help="корень assets/audio")
    ap.add_argument("--only", nargs="*", help="обработать только эти id")
    args = ap.parse_args()

    with open(args.manifest, encoding="utf-8") as fh:
        manifest = json.load(fh)
    if not HAVE_PYLN:
        print("WARN: pyloudnorm не найден — RMS-приближение LUFS")
    if not HAVE_SCIPY:
        print("WARN: scipy не найден — линейный ресемплер, true peak без oversample")

    meter = Loudness()
    rows = []
    fails = []
    for section, builder, sub in (
        ("music", build_music, "music"),
        ("sfx", build_sfx, "sfx"),
    ):
        for entry in manifest.get(section, []):
            aid = entry["id"]
            if args.only and aid not in args.only:
                continue
            try:
                x, info = builder(entry, args.src, meter)
                out_path = os.path.join(args.out, sub, aid + ".ogg")
                write_ogg(out_path, x, float(entry.get("vorbis_level", 0.5)))
                size = os.path.getsize(out_path) / 1e6
                rows.append((aid, info, size))
                seam = info.get("seam")
                seam_s = f" seam {seam:.4f}" if seam is not None else ""
                lra = info.get("lra")
                lra_s = f" LRA {lra:.1f}" if lra is not None else ""
                lo = info.get("loop_offset_sec")
                lo_s = f" loop@{lo:.2f}s" if lo else ""
                print(
                    f"OK {aid:36s} {info['dur']:7.2f}s "
                    f"{info['loudness']:6.1f} LUFS TP {info['true_peak']:5.1f}"
                    f" {size:5.2f}MB{lo_s}{seam_s}{lra_s}"
                )
            except Exception as e:  # noqa: BLE001
                fails.append((aid, repr(e)))
                print(f"FAIL {aid}: {e!r}")
    print(f"\nИтого: {len(rows)} ok, {len(fails)} fail")
    total = sum(r[2] for r in rows)
    print(f"Суммарный размер: {total:.1f} MB")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
