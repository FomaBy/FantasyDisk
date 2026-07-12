#!/usr/bin/env python3
"""FAN-1028/FAN-1029: матрица жизнеспособности возвышений (A0/A1/A5) по 17 классам.

Совмещает три источника:
  1. build/ascension_params.json  — дамп ProgressionData (tools/ascension_params_dump.gd):
     базовые/производные статы, классовые награды возвышений, кумулятивный пресс
     сложности, формульные kit-DPS (после budget-тюнинга), stage_scale, ENEMY_BALANCE.
  2. Живой CSV tools/character_balance_csv.gd (--mode=live): build/character_balance_dps.csv
     либо лог прогона (строки вида `class/weapon [family] 1t: l1=.. id=.. rnd=..`).
  3. Сценовые базы боссов/элиток: scenes/Boss*.tscn, scenes/Elite*.tscn (max_health,
     contact_damage, projectile_damage — текстовый парс .tscn).

Модель угрозы (зеркала кода, см. docs/design/systems/balance_systems_map_fan1028.md):
  boss_hp    = scene.max_health × EB.boss.hp(1.9) × (5.40 + stage_scale×1.55) × asc.boss_hp_mult
               (combat_director.gd::_scale_boss_for_run; секретный босс ×1.18 сверху)
  elite_hp   = scene.max_health × EB.elite.hp(4.6) × (25 + stage_scale×4) × 1.08
               × подтип(armored 1.35) × asc.elite_hp_mult (combat_director.gd::_scale_elite_enemy)
  требуемый DPS = hp / 300 c (kill-or-lose таймер элиток/боссов, main.gd)
  hazard     = scene.projectile_damage × EB.boss.dmg(1.46) × (1+(stage_scale−1)×0.70)
               × (1.35 + 0.25×(фаза−1))   (boss.gd phase hazard; НЕ капится долей HP)
  slam       = scene.contact_damage × EB.boss.dmg × (1+(stage_scale−1)×0.70)
               × (1.5 + 0.22×(фаза−1))    (boss.gd _spawn_disk_slam)

Сторона игрока:
  kit_dps(A) = среднее live lvl20_ideal (и lvl20_random) по 3 оружиям
               × asc.damage_multiplier × asc.attack_speed_multiplier (награды класса)
  EHP(A)     = HP×player_max_hp_mult/(1−def)/(1−dodge) + absorb×6 + regen×30×healing_mult
               (зеркало _budget_ehp / survivability harness)
  HP-модель у боссов: floor = derived base (без внутрирановых карт), typical = floor×1.45
               (медиана HP-карт/статов к 20 уровню по LEVEL_UP_REWARDS-пулу — консервативно).

Запуск:
  python3 tools/ascension_viability_report.py [--csv build/character_balance_dps.csv]
      [--log <лог живого прогона>] [--out build/ascension_viability_report.md]
"""

import argparse
import json
import re
import sys
from pathlib import Path
from statistics import mean

ROOT = Path(__file__).resolve().parent.parent
FIGHT_TIMER = 300.0
BOSS_ROTATION_A1 = ["rift_warden", "bone_archon", "brood_mother"]
BOSS_ROTATION_A2 = ["disk_devourer", "ashen_colossus", "rift_warden", "bone_archon", "brood_mother"]
SECRET_BOSS = "secret_ascension_boss"
BOSS_SCENES = {
    "rift_warden": "BossWarden.tscn",
    "disk_devourer": "BossDiskDevourer.tscn",
    "bone_archon": "BossBoneArchon.tscn",
    "brood_mother": "BossBroodMother.tscn",
    "ashen_colossus": "BossAshenColossus.tscn",
    "secret_ascension_boss": "BossSecretAscension.tscn",
}
STAGE_BOSS_A1 = 8
STAGE_BOSS_A2 = 16
STAGE_ELITE_LATE = 12
HP_TYPICAL_GROWTH = 1.45  # консервативная оценка HP-карт/статов к lvl20
DPS_OK = 1.25
DPS_RISK = 1.0


def parse_tscn_stats(path: Path) -> dict:
    out = {}
    text = path.read_text(encoding="utf-8", errors="ignore")
    for key in ("max_health", "contact_damage", "projectile_damage"):
        m = re.search(rf"^{key} = ([0-9.]+)", text, re.M)
        if m:
            out[key] = float(m.group(1))
    return out


LOG_RE = re.compile(
    r"^(?P<cls>[a-z_]+)/(?P<weapon>[a-z_]+) \[[a-z_]+\] "
    r"1t: l1=(?P<l1_1>[0-9.]+) id=(?P<id_1>[0-9.]+) rnd=(?P<rnd_1>[0-9.]+) \| "
    r"5t: l1=[0-9.]+ id=(?P<id_5>[0-9.]+) rnd=(?P<rnd_5>[0-9.]+) \| "
    r"20t: l1=[0-9.]+ id=(?P<id_20>[0-9.]+) rnd=(?P<rnd_20>[0-9.]+)", re.M)


def load_live_from_log(path: Path) -> dict:
    """{cls: {weapon: {id_1, rnd_1, id_5, rnd_5, id_20, rnd_20}}}"""
    data: dict = {}
    for m in LOG_RE.finditer(path.read_text(encoding="utf-8", errors="ignore")):
        row = {k: float(v) for k, v in m.groupdict().items() if k not in ("cls", "weapon")}
        data.setdefault(m.group("cls"), {})[m.group("weapon")] = row
    return data


def load_live_from_csv(path: Path) -> dict:
    import csv as _csv
    data: dict = {}
    with path.open() as fh:
        for row in _csv.DictReader(fh):
            cls = row.get("class") or row.get("character") or ""
            weapon = row.get("weapon", "")
            if not cls or not weapon:
                continue
            def fv(*names):
                for n in names:
                    if n in row and row[n] not in ("", None):
                        try:
                            return float(row[n])
                        except ValueError:
                            pass
                return 0.0
            data.setdefault(cls, {})[weapon] = {
                "id_1": fv("lvl20_ideal_1t", "ideal_1"), "rnd_1": fv("lvl20_random_1t", "random_1"),
                "id_5": fv("lvl20_ideal_5t", "ideal_5"), "rnd_5": fv("lvl20_random_5t", "random_5"),
                "id_20": fv("lvl20_ideal_20t", "ideal_20"), "rnd_20": fv("lvl20_random_20t", "random_20"),
            }
    return data


def ehp(hp: float, defense: float, dodge: float, absorb: float, regen: float,
        php_mult: float, healing_mult: float) -> float:
    return (hp * php_mult) / max(1.0 - defense, 0.05) / max(1.0 - dodge, 0.05) \
        + absorb * 6.0 + regen * 30.0 * healing_mult


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--params", default=str(ROOT / "build/ascension_params.json"))
    ap.add_argument("--csv", default=str(ROOT / "build/character_balance_dps.csv"))
    ap.add_argument("--log", default="")
    ap.add_argument("--out", default=str(ROOT / "build/ascension_viability_report.md"))
    args = ap.parse_args()

    params = json.loads(Path(args.params).read_text())
    live = {}
    if args.log and Path(args.log).exists():
        live = load_live_from_log(Path(args.log))
    if not live and Path(args.csv).exists():
        live = load_live_from_csv(Path(args.csv))
    if not live:
        print("FATAL: нет живых данных (ни --log, ни --csv)", file=sys.stderr)
        return 1

    eb = params["enemy_balance"]
    stage_scale = params["stage_scale"]
    asc = {int(k): v for k, v in params["ascension_difficulty"].items()}

    boss_stats = {bid: parse_tscn_stats(ROOT / "scenes" / fn) for bid, fn in BOSS_SCENES.items()}
    elite_scenes = sorted((ROOT / "scenes").glob("Elite*.tscn"))
    elite_hp_bases = [parse_tscn_stats(p).get("max_health", 0.0) for p in elite_scenes]
    elite_hp_base_worst = max(elite_hp_bases) if elite_hp_bases else 24.0

    def boss_hp(bid: str, stage: int, level: int) -> float:
        base = boss_stats[bid].get("max_health", 300.0)
        mult = float(eb["boss"]["hp_multiplier"]) * (5.40 + stage_scale[stage] * 1.55)
        if bid == SECRET_BOSS:
            mult *= 1.18
        return base * mult * float(asc[level]["boss_hp_mult"])

    def elite_hp(stage: int, level: int) -> float:
        return elite_hp_base_worst * float(eb["elite"]["hp_multiplier"]) \
            * (25.0 + stage_scale[stage] * 4.0) * 1.08 * 1.35 * float(asc[level]["elite_hp_mult"])

    def boss_hazard(bid: str, stage: int, phase: int, kind: str) -> float:
        st = boss_stats[bid]
        dmg_scale = float(eb["boss"]["damage_multiplier"]) * (1.0 + (stage_scale[stage] - 1.0) * 0.70)
        if bid == SECRET_BOSS:
            dmg_scale *= 1.18
        if kind == "hazard":
            return st.get("projectile_damage", 3.0) * dmg_scale * (1.35 + 0.25 * (phase - 1))
        return st.get("contact_damage", 3.0) * dmg_scale * (1.5 + 0.22 * (phase - 1))

    def verdict(margin: float) -> str:
        if margin >= DPS_OK:
            return "OK"
        if margin >= DPS_RISK:
            return "RISK"
        return "FAIL"

    lines = []
    w = lines.append
    w("# Матрица жизнеспособности возвышений (A0 / A1 / A5)")
    w("")
    w("Генератор: `tools/ascension_viability_report.py` (модель — см. док-стринг и")
    w("`docs/design/systems/balance_systems_map_fan1028.md`). Живой слой: lvl20_ideal /")
    w("lvl20_random из `tools/character_balance_csv.gd --mode=live` (окно 8с, болванки).")
    w("")
    rot_a2 = {level: max(boss_hp(b, STAGE_BOSS_A2, level) for b in BOSS_ROTATION_A2) for level in (0, 1, 5)}
    rot_a1 = {level: max(boss_hp(b, STAGE_BOSS_A1, level) for b in BOSS_ROTATION_A1) for level in (0, 1, 5)}
    w("## Пороги угрозы (worst-case ротации)")
    w("")
    w("| Уровень | Босс А1 HP | треб. DPS | Босс А2 HP | треб. DPS | Элитка st12 HP | треб. DPS |")
    w("| --- | ---: | ---: | ---: | ---: | ---: | ---: |")
    for level in (0, 1, 5):
        w(f"| A{level} | {rot_a1[level]:.0f} | {rot_a1[level]/FIGHT_TIMER:.1f} | "
          f"{rot_a2[level]:.0f} | {rot_a2[level]/FIGHT_TIMER:.1f} | "
          f"{elite_hp(STAGE_ELITE_LATE, level):.0f} | {elite_hp(STAGE_ELITE_LATE, level)/FIGHT_TIMER:.1f} |")
    sec_hp = boss_hp(SECRET_BOSS, STAGE_BOSS_A2, 5)
    w(f"| A5 секрет | — | — | {sec_hp:.0f} | {sec_hp/FIGHT_TIMER:.1f} | — | — |")
    w("")

    w("## Ваншот-пороги финального босса (фаза 3; на A5 фаза 4)")
    w("")
    w("| Уровень | Худший hazard | Худший slam |")
    w("| --- | ---: | ---: |")
    for level, phase in ((0, 3), (1, 3), (5, 4)):
        rot = BOSS_ROTATION_A2 + ([SECRET_BOSS] if level == 5 else [])
        hz = max(boss_hazard(b, STAGE_BOSS_A2, phase, "hazard") for b in rot)
        sl = max(boss_hazard(b, STAGE_BOSS_A2, phase, "slam") for b in rot)
        w(f"| A{level} | {hz:.1f} | {sl:.1f} |")
    w("")

    w("## Классы")
    w("")
    w("| Класс | Билд | Kit DPS A0 | Маржа A1 | Маржа A5 (А2-босс) | HP typ A5 | EHP A5 | Hazard A5 %HP | Вердикт DPS A5 | Вердикт выживания A5 |")
    w("| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | :---: | :---: |")

    summary = {}
    for cid, centry in sorted(params["classes"].items()):
        weapons_live = live.get(cid, {})
        if not weapons_live:
            w(f"| {cid} | — | нет живых данных | | | | | | ? | ? |")
            continue
        for build_key, label in (("id_1", "ideal"), ("rnd_1", "random")):
            kit0 = mean(v[build_key] for v in weapons_live.values())
            row = {"kit0": kit0}
            for level in (0, 1, 5):
                mods = centry["ascension_mods"][str(level)]
                pmult = float(mods.get("damage_multiplier", 1.0)) * float(mods.get("attack_speed_multiplier", 1.0))
                required = rot_a2[level] / FIGHT_TIMER
                row[f"margin{level}"] = (kit0 * pmult) / required
            d5 = centry["derived_a5"]
            adiff5 = asc[5]
            hp_floor = d5["max_health"]
            hp_typ = hp_floor * HP_TYPICAL_GROWTH
            php = float(adiff5["player_max_hp_mult"])
            heal5 = float(adiff5["healing_mult"])
            ehp5 = ehp(hp_typ, d5["defense"], d5["dodge"], d5["absorb"], d5["regeneration"], php, heal5)
            rot = BOSS_ROTATION_A2 + [SECRET_BOSS]
            hz5 = max(boss_hazard(b, STAGE_BOSS_A2, 4, "hazard") for b in rot)
            hz_pct = hz5 / max(hp_typ * php, 1.0) * 100.0
            surv = "ONESHOT" if hz_pct >= 100.0 else ("RISK" if hz_pct >= 65.0 else "OK")
            if build_key == "id_1":
                summary[cid] = {"margin5": row["margin5"], "surv": surv, "hz_pct": hz_pct}
            w(f"| {cid} | {label} | {kit0:.0f} | {row['margin1']:.2f} | {row['margin5']:.2f} | "
              f"{hp_typ*php:.0f} | {ehp5:.0f} | {hz_pct:.0f}% | {verdict(row['margin5'])} | {surv} |")
    w("")

    w("## Сводка A5 (ideal-билд)")
    w("")
    fails = {c: s for c, s in summary.items() if s["margin5"] < DPS_RISK or s["surv"] == "ONESHOT"}
    risks = {c: s for c, s in summary.items()
             if c not in fails and (s["margin5"] < DPS_OK or s["surv"] == "RISK")}
    w(f"- FAIL: {', '.join(sorted(fails)) or 'нет'}")
    w(f"- RISK: {', '.join(sorted(risks)) or 'нет'}")
    w(f"- OK: {', '.join(sorted(set(summary) - set(fails) - set(risks))) or 'нет'}")
    w("")
    w("Оговорки: kit DPS — среднее 3 оружий на болванках (8с, без ульты в full-charge циклах,")
    w("без кайта); random-билд ближе к реальному первому прохождению. Ваншот-порог сравнивается")
    w("с typical HP (floor×1.45×player_max_hp_mult); уворот/i-frames/absorb смягчают hazard в бою.")

    Path(args.out).write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"written: {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
