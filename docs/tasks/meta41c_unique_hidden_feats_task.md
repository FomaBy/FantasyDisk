# Мета 4.1c (SCRUM-836): 17/17 уникальных подвигов скрытых звёзд + лор + uniqueness-тест

Статус: hold (снять после сдачи SCRUM-834/834a — делит tree_data/smoke; метку hold снять и в Jira)
Приоритет: medium
Роль: Back-end (Claude)
Версия: 0.2.0
Создано: 2026-07-02
Jira: SCRUM-836
Контур: Claude
Owner: —
Thread/Worker: —
Locked paths: `scripts/meta_progression_tree_data.gd`, `scripts/meta_progression.gd` (hidden-метрики), `tests/skill_tree_per_hero_test.gd`, `docs/design/systems/meta_constellations.md`

## Контекст

QA-фейл SCRUM-834, блокеры 2–3: berserk остался на generic-паре
(weapon_diversity≥2 / best_ascension≥2), тест принимает любые непустые условия
и пин-ит старые berserk-значения. Дизайн §5: каждый класс — СВОЙ подвиг
(«Победи босса Акта 3 берсерком, ни разу не упав ниже 30% HP») + лор-строка,
церемония открытия.

## Scope

1. Berserk: перевести на уникальную пару подвигов (доделать 16/17 → 17/17).
2. Аудит уникальности всех 34 hidden-условий: metric+threshold сочетание не
   повторяется между классами; условия читаемы («condition_text» человеческим
   языком) и достижимы; лор-строка классу (1 предложение, тон FantasyDisk).
3. При необходимости — новые метрики в class_challenge_progress
   (например flawless_boss, no_damage_streak, lowhp_survive) с разводкой в
   meta_progression.hidden_star_unlocked/hidden_star_progress.
4. Тест-защита: строгий uniqueness-ассерт (нет дублей metric+threshold пар
   между классами), ассерт наличия лор-строки, снятие пина старых berserk
   условий в skill_tree_per_hero_test.

## Acceptance

1. 17/17 классов с уникальными парами подвигов + лор; uniqueness-тест зелёный.
2. Гейты зелёные (godot_gate, grep SCRIPT ERROR); CHANGELOG; приложение к §5
   дока при отклонениях; сдача `Статус: done` + Jira → «Контроль качества».
