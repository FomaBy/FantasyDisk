#!/usr/bin/env python3
"""FAN-1028/FAN-1029: class-trio таблица по модели skills/codex/fantasydisk-class-balance-director.

Оси считаются roster-relative (метрика класса / медиана ростера), потому что живой слой
не имеет абсолютных таргетов: формульные цели (48/150) авто-достигаются тюнером и
непригодны как знаменатель для live-замеров.

Входы: build/character_balance_dps.csv (живой CSV, lvl20_ideal/random) и
build/ascension_params.json (per-weapon EHP формульного слоя — ось defense).
Выход: build/class_trio_fan1028.md.
"""

import json
from pathlib import Path
from statistics import mean, median

ROOT = Path(__file__).resolve().parent.parent
DEAD_SLOT_SHARE = 0.40  # оружие мертво, если хуже 40% средней своего кита по ВСЕМ осям


def main() -> None:
    import csv
    rows = list(csv.DictReader((ROOT / "build/character_balance_dps.csv").open()))
    params = json.loads((ROOT / "build/ascension_params.json").read_text())

    classes: dict = {}
    for r in rows:
        classes.setdefault(r["class"], []).append(r)

    per_class = {}
    for cid, ws in classes.items():
        ehp_map = {wid: w["ehp"] for wid, w in params["classes"][cid]["weapons"].items()}
        per_class[cid] = {
            "solo": mean(float(w["lvl20_ideal_1t"]) for w in ws),
            "aoe": mean(float(w["lvl20_ideal_5t"]) for w in ws),
            "crowd": mean(float(w["lvl20_ideal_20t"]) for w in ws),
            "solo_rnd": mean(float(w["lvl20_random_1t"]) for w in ws),
            "defense": mean(ehp_map.values()),
            "weapons": ws,
            "ehp_map": ehp_map,
        }

    med = {k: median(v[k] for v in per_class.values())
           for k in ("solo", "aoe", "crowd", "solo_rnd", "defense")}

    out = []
    w = out.append
    w("# Class-trio таблица (FAN-1028, живой слой lvl20_ideal, текущий код)")
    w("")
    w("Скоры = метрика класса / медиана ростера. Модель осей — class-balance-model.md;")
    w(f"медианы ростера: solo {med['solo']:.0f}, aoe(5t) {med['aoe']:.0f}, "
      f"crowd(20t) {med['crowd']:.0f}, EHP {med['defense']:.0f}.")
    w("Коридор kit-total: ideal ±8%, review ±12%, fail ±15% (roster-relative).")
    w("")
    w("| Класс | Solo | AoE | Crowd | Defense | **Total** | Вердикт | Мёртвые слоты |")
    w("| --- | ---: | ---: | ---: | ---: | ---: | :---: | --- |")

    scored = []
    for cid, v in per_class.items():
        s = {k: v[k] / med[k] for k in ("solo", "aoe", "crowd", "defense")}
        total = mean(s.values())
        dead = []
        kit_mean = {ax: mean(float(x[col]) for x in v["weapons"])
                    for ax, col in (("1t", "lvl20_ideal_1t"), ("5t", "lvl20_ideal_5t"), ("20t", "lvl20_ideal_20t"))}
        for x in v["weapons"]:
            if all(float(x[col]) < DEAD_SLOT_SHARE * kit_mean[ax]
                   for ax, col in (("1t", "lvl20_ideal_1t"), ("5t", "lvl20_ideal_5t"), ("20t", "lvl20_ideal_20t"))):
                dead.append(x["weapon"])
        scored.append((total, cid, s, dead))

    for total, cid, s, dead in sorted(scored, reverse=True):
        dev = abs(total - 1.0)
        verdict = "ideal" if dev <= 0.08 else ("review" if dev <= 0.12 else ("FAIL" if dev <= 0.15 else "FAIL+"))
        w(f"| {cid} | {s['solo']:.2f} | {s['aoe']:.2f} | {s['crowd']:.2f} | {s['defense']:.2f} | "
          f"**{total:.2f}** | {verdict} | {', '.join(dead) or '—'} |")

    w("")
    w("## Пер-оружейные выбросы (ideal, множитель к медиане ростера по оси)")
    w("")
    med_w = {col: median(float(r[col]) for r in rows)
             for col in ("lvl20_ideal_1t", "lvl20_ideal_5t", "lvl20_ideal_20t")}
    w("| Класс/оружие | Solo × | AoE × | Crowd × | Заметка |")
    w("| --- | ---: | ---: | ---: | --- |")
    flagged = []
    for r in rows:
        m1 = float(r["lvl20_ideal_1t"]) / med_w["lvl20_ideal_1t"]
        m5 = float(r["lvl20_ideal_5t"]) / med_w["lvl20_ideal_5t"]
        m20 = float(r["lvl20_ideal_20t"]) / med_w["lvl20_ideal_20t"]
        note = ""
        if max(m1, m5, m20) > 3.0:
            note = "runaway-ось"
        if m1 < 0.4 and m5 < 0.4 and m20 < 0.4:
            note = (note + "; " if note else "") + "слаб по всем осям"
        if float(r["lvl20_ideal_1t"]) == 0.0:
            note = "НОЛЬ live solo"
        if note:
            flagged.append((max(m1, m5, m20), f"| {r['class']}/{r['weapon']} | {m1:.2f} | {m5:.2f} | {m20:.2f} | {note} |"))
    for _, line in sorted(flagged, reverse=True):
        w(line)

    (ROOT / "build/class_trio_fan1028.md").write_text("\n".join(out) + "\n", encoding="utf-8")
    print("written: build/class_trio_fan1028.md")


if __name__ == "__main__":
    main()
