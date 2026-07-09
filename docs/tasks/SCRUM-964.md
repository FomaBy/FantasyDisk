# Artifact System: QA и баланс-валидация редизайна артефакт-пулов

Статус: done
Приоритет: p1
Роль: QA
Версия: 0.2.1
Создано: 2026-07-09
Jira: SCRUM-964
Контур: Claude
Owner: claude-fable-orchestrator
Thread/Worker: claude-qa-scrum964-artifact-validation-20260709
Locked paths: `docs/tasks/SCRUM-959..964.md` (вердикты), `scripts/class_weapon.gd`
(QA-фикс mine_satchel), `tests/runtime_smoke_progression_economy_test.gd` (EV-порог).
Branch/worktree: `dev` (основной чекаут)

## Context / Problem

Финальная приёмка эпика редизайна артефактов (SCRUM-959 матрица, 960 универсальный
пул, 961 классовые Возвышения-5, 962 иконки, 963 UI/локализация) по чеклисту
`artifact_system_matrix.md` §7.6 и баланс-коридорам §8.

## Статика (без Godot) — PASSED

- 17 удалённых id (16 легаси + `swift_ink`): 0 вхождений в `scripts/` и `assets/`;
  в `tests/class_artifacts_test.gd:21-23` — сам гейт-список REMOVED_IDS (ожидаемо),
  в `tools/*.py` — исторические одноразовые генераторы иконок (не рантайм).
- `ARTIFACTS` = **154** записи = 32 `rarity_scaling` + 37 сохранённых + 85 классовых
  (17 классов × ровно 5, все `requires_ascension: 5`); дублей id нет.
- Иконки: **154** `artifact_*.png` + **154** `.png.import` на диске и в git-tree
  origin/dev, пары сходятся, легаси-PNG отсутствуют.
- Латиница в `title`: ARTIFACTS (154) и SHOP_ITEMS (7) — ноль.
- `python3 tools/validate_artifact_icons.py` — exit 0; detached-components на 6
  иконках (chain_spark/soul_harvest/second_wind — легаси SCRUM-690;
  magnetic_purse/tower_slam/arquebus_shrapnel) — **accepted-minor**, без follow-up.

## Тестовая батарея (godot_gate, последовательно) — 23/23 PASSED

| Тест | Результат | Попыток |
| --- | --- | --- |
| rewards_data_integrity (154+7+8+24) · content_rewards_integrity | PASS | 1 |
| progression_data_api_surface · weapon_integrity (17/51) | PASS | 1 |
| attribute_relevance · ascension_curve_balance | PASS | 1 |
| content_registry_consistency · asset_reference_integrity | PASS | 1 |
| no_duplicate_artifact_files · ui_icon_registry_smoke · start_boons | PASS | 1 |
| codex_data_smoke (161, гейт иконок 154/154 + запрет латиницы) | PASS | 1 |
| artifact_ascension_gate (17 классов, 154) · class_artifacts (85/17) | PASS | 1 |
| artifact_family_roll (32 семьи) · route_chest_artifact | PASS | 1 |
| event_random_artifact_empty_pool · null_artifacts_snapshot | PASS | 1 |
| codex_unlock_tracking · runtime_smoke_triggered_artifacts | PASS | 1 |
| ui_no_overlap_matrix (40с) | PASS | 1 |
| runtime_smoke полный (131с) — и повторно после QA-фикса | PASS | 2/2 |
| runtime_smoke_progression_economy | PASS после фикса порога¹ | 2 |
| runtime_smoke_triggered_artifacts (после фикса class_weapon) | PASS | 2 (1 флак²) |
| pool_dot_runaway_gate (один, chemist 33k/36k ≤ 70k) | PASS | 1 |

¹ Красный не из эпика: SCRUM-995 (закрыт ранее) сжал пул событий 29→12, риск/сейф-пар
стало 4, а голден-порог теста остался `>=10` от старого пула. Фикс порога 10→4 по
канону `progression_balance.md` §Random Events EV (там ровно 4 пары, 0 нарушений);
EV-инвариант на всех 4 держится. Коммит `2c2d30de`.
² Интермиттентный red on_low_hp-гарда под нагрузкой живой сессии пользователя —
известный паттерн, PASS со 2-го прогона.

## Гейтинг по классам (главный evidence) — PASSED ×2 прогона

Одноразовый QA-скрипт (scratchpad, вне репо): 17 классов × {asc 0, asc 4-spot,
asc 5} × 4 сэмплера (`reward_pool` / `shop_items` / `elite_artifact_choices` /
`boss_completion_artifact_choices`), исчерпывающие пулы (count=200, без
замещения) + реалистичные дровы (elite 200×3, boss 100×3 на класс):

- **asc 0**: ни один классовый ни в одном сэмплере ни у одного класса (включая
  стадии 0 и 8 элиток); **asc 4**: заперто (spot berserk/chemist).
- **asc 5**: у каждого из 17 классов все 5 своих в reward_pool (5/5), shop (5/5),
  elite-пуле (5/5); boss-пул — свои t3 2/2 (chemist 3/3), семьи фиксированно т3;
  **чужих классовых — ноль** во всех источниках (600+300 дровов на класс).
- **Cross-class**: thief asc5 + `cross_class_ids=[crimson_grip, chain_wand]` —
  проходят ровно эти два чужих (все 4 сэмплера, t3-часть и в boss-пуле), других
  чужих ноль; berserk asc0 + чужой id — cross проходит при запертых своих.
- **Доля тир-3 семей** в reward_pool: **7.7%** на 2705 роллах (коридор §8.5
  5-12%; t1/t2 = 64.4/27.9% ≈ номинал 0.64/0.29/0.08).

## Баланс §8.1 (live-замер, болванки, окно 8с канона харнесса)

Кит = базовый набор vs +5 классовых артефактов через `apply_reward`; blended =
(solo+5-target) агрегат по 3 оружиям. Триггерные on_take_hit/on_low_hp в арене
не стреляют — замер является нижней оценкой.

| Класс | Кит-прирост blended | EHP-прокси | Вердикт |
| --- | --- | --- | --- |
| berserk | **+35.6%** (по прогонам +35.6/+43.0/+44.2) | 0% | в коридоре 15-45% |
| engineer (wrench+drone) | **+31.5%** | 0% | в коридоре |
| dark_mage | **+66.5%** (+58.8/+66.5/+73.3) | −15% (black_bargain, в норме) | ⚠ warning³ |

³ Зафиксированное отклонение слайса замера, не блокер: данные реализуют матрицу
§4.15 дословно; декомпозиция — гео-трио (chain_wand + mirror_page при кластере
болванок с одной стороны, где зеркальный взрыв перекрывает ту же толпу вопреки
интенту «покрытие тыла»; void_hunger на бессмертных болванках мёртв) даёт +53.1%,
карточная флэт-DoT пара (curse_font+black_bargain = ровно level-up-карточная
экономика §8.2: +3/+0.35 и +4/+0.25) добавляет ~13-20пп на базе 1-го уровня.
Пост-тюнинг кандидат по §8.3-паттерну («отклонения фиксирует харнесс-отчёт 964»):
первым смотреть перекрытие зеркала mirror_page по уже поражённым целям.

**Найден и исправлен баг** (единственный код-дефект эпика):
`mine_satchel` — retire-oldest при капе 5 под живым автоогнём (fire_interval
~0.79с × залп 3) вытеснял персистентные мины в ~1.3с — раньше армирования 2.5с;
ни proximity-подрыв, ни автоподрыв 6с не наступали → оружие с артефактом давало
**0 урона** в непрерывном бою (репро: контрольный зонд — базовая мина 260.8 урона,
персистентная 0.0). Фикс: при полном поле новые мины не ставятся до освобождения
слота (skip-при-капе), семантика «до 5 живых» и кап-тест сохранены. Верификация
×2: автоогонь 9с wall — 888.9/898.0 урона, пик живых 5, тайм-аут освобождает слот;
мины с китом на движущихся целях 83.5 DPS (было 0.0). Коммит `2c2d30de`,
runtime_smoke/weapon_integrity/class_artifacts/triggered после фикса — PASSED.

## Честность данных — PASSED

14 записей сверены с матрицей дословно: 4 семьи потирово (warrior_charm +2/+4/+7,
splinter_gloves ×1.10/1.18/1.30, sturdy_amulet +15/+25/+40, fast_boots + поглощение
swift_ink), 10 классовых (§4.8 engineer, §4.15 dark_mage — mod-ключи/значения/
`requires_ascension`/cost по COST_BY_TIER). Тултипы соответствуют механикам
(потировые description семей; «автоподрыв через 6с» mine_satchel после фикса
соответствует поведению). Сейв-совместимость `{id,title}` без тира — PASSED
(null_artifacts_snapshot + ролл-тест legacy-записи).

## Визуальная приёмка

Оконный капчер — **deferred: live user session** (2 оконных Godot пользователя,
стенд-даун по протоколу). Вместо него: headless `ui_no_overlap_matrix_test`
PASSED (HUD-ряд артефактов, карточки) + контакт-щиты SCRUM-962 отсмотрены глазами
(`docs/design/previews/artifact_icons_scrum962_{universal,class}_contact.png`):
100/100 без текста/рамок/запечённого фона, силуэты и 40px-ряд читаемы, классовая
идентичность видна. Оконный добор — следующим свободным окном.

## Итог по эпику

959/960/961/962/963 — PASSED (вердикты в зеркалах); warning-лист: dark_mage
кит-прирост выше коридора на слайсе замера (пост-тюнинг кандидат), detached-minor
на 6 иконках (accepted). QA-фиксы: `2c2d30de` (mine_satchel + EV-порог).

## QA-Вердикт

Статус: PASSED
Дата: 2026-07-09
Проверил: claude-fable-orchestrator (claude-qa-scrum964-artifact-validation-20260709).
Статика + батарея 23/23 + гейт-свип 17×3×4 (×2) + cross-class + баланс 3 классов +
честность данных + headless-визуал — PASSED; 1 найденный баг исправлен и
верифицирован (mine_satchel, 2c2d30de); отклонение dark_mage и 6 detached-minor
зафиксированы как warning/accepted без блокировки эпика.
