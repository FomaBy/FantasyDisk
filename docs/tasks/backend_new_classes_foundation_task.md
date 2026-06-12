# Задача Для Back-end-Агента: Шесть Новых Классов — Логика, Баланс, Оружие (Фундамент)

Статус: done 2026-06-11. Результат: 6 новых классов data-driven (BASE_STATS/CHARACTER_CONFIGS/WEAPONS_BY_CLASS/CLASS_DAMAGE_PARAMETER/STAT_CLASS_RELEVANCE/ASCENSION_LEVELS 10x6 с тематическими именами). Сигнатурное оружие: chakrams (новый режим boomerang — коридорный урон туда-обратно), moon_crossbow (узкий beam 900/1 пробой), restore_potion (aoe_projectile + heal_percent_on_attack 2.5% max HP), blast_powder (aoe_projectile + leaves_pool: ядовитое облако с тиками dot_damage 3с), long_spear (berserk_weapon strip 90x540 x3.0 + пассив защиты), summon_amulet (summoner_weapon: звери из AllyMinion, урон 55% sound_wave_damage владельца, лимит через max_summons от Лидерства, группа player_weapon_effects для cleanup). Экран выбора — сетка 2 колонки в скролле на 9 карточек (целиком кликабельны). Кодекс: 9 классов c playstyle-описаниями автоматически. Спрайты — hue-shift placeholder копии (отмечено в registry), оружейные визуалы временные. Баланс ±20% от Берсерка расчетно (методика и числа в mechanics_extract; chakrams скорректированы 0.8->0.45, копье 1.35->3.0). Попутный фикс: колбэк AoE-снаряда обращался к освобожденному владельцу — добавлен guard. Тесты: 9 классов экипируют сигнатурки и наносят урон (друид призывает), 10 уровней вознесения у всех; smoke стабильно зеленый 3x. ДЛЯ PM: датасет классов в dev — можно запускать арт-задачу codex_design_new_classes_art_task.
Создано: 2026-06-11
Автор: PM
Блокер частично снят PM 2026-06-11 (релиз закрыт). Остается зависимость: `backend_full_attributes_wiring_audit_task.md`
(классы строятся на полном наборе атрибутов).

## Autonomy / Approval
Пользователь заранее одобрил все изменения. Балансные значения — из
`docs/design/mechanics_extract.md` (Class Sheet); пробелы заполнять разумно
и фиксировать в документации.

## Контекст
Решение пользователя: добавить все классы из документации. В Class Sheet
кроме реализованных (Берсерк, Темный маг; Гитарист — наш кастомный) заявлены:

| ID (предлагаю) | Имя | Архетип | Сигнатурное оружие (из таблицы) |
| --- | --- | --- | --- |
| `assassin` | Ассасин | Быстрый крит-мили, увороты | Чакрамы (возвращающиеся метательные клинки) |
| `ranger` | Рейнджер | Дальний точный урон | Лунный арбалет |
| `doctor` | Доктор | Выживание/хил через урон | Зелье восстановления (метательное: урон врагам + лечение себе) |
| `chemist` | Химик | AoE + DoT зоны | Взрывная пыль (облака/взрывы с ядом) |
| `knight` | Рыцарь | Танк, защита, контратака | Копье (длинный точечный удар + блок) |
| `druid` | Друид | Призыватель | Амулет призыва (звери-саммоны, скейл от Лидерства) |

## Требования
1. **Данные**: добавить 6 классов в `progression_data.gd` data-driven, как
   существующие: статы по Class Sheet (HP, attack speed, crit и т.д. из
   mechanics_extract), описание, сильные/слабые стороны, стартовые статы.
2. **Оружие**: по ОДНОМУ сигнатурному оружию на класс (вторые/третьи — следующей
   итерацией). Механики по архетипу из таблицы выше; переиспользовать
   существующие системы (melee_weapon, class_weapon, summoner_weapon, projectile).
   Каждому оружию — конфиг в данных, VFX через AttackVfx до прихода арта.
3. **Классовая релевантность**: расширить CLASS_DAMAGE_PARAMETER /
   STAT_CLASS_RELEVANCE / class_affinity артефактов на новые классы
   (какой урон «свой» у каждого — реши по архетипу, зафиксируй).
4. **Выбор персонажа**: экран выбора вмещает 9 классов (сетка/скролл,
   карточки целиком кликабельны, как сейчас).
5. **Мета-прогрессия**: уровни вознесения для новых классов (по образцу
   существующих 10x3).
6. **Визуал-заглушки**: до прихода арта от Codex/Design использовать
   перекрашенные копии ближайшего по архетипу спрайта (assassin/knight ←
   berserk, ranger/chemist/doctor ← dark_mage, druid ← guitarist) с явной
   пометкой в content_registry «placeholder». Подключение финальных спрайтов —
   отдельная интеграция после `codex_design_new_classes_art_task.md`.
7. **Кодекс/балансовая цель**: новые классы в кодексе-энциклопедии; каждый
   класс зачищает стандартную волну в пределах ±20% от Берсерка.
8. Тесты: smoke расширить запуском боя каждым из 9 классов; meta-тест на
   ascension новых классов.

## Files / Assets / IDs
- `scripts/progression_data.gd`, `scripts/player.gd`, `scripts/class_weapon.gd`,
  `scripts/melee_weapon.gd`, `scripts/summoner_weapon.gd`, `scripts/meta_progression.gd`,
  `scripts/ui_screens.gd`, `scripts/codex_data.gd`, новые сцены оружия.
- ID: `assassin`, `ranger`, `doctor`, `chemist`, `knight`, `druid` + ID оружия
  `chakrams`, `moon_crossbow`, `restore_potion`, `blast_powder`, `long_spear`, `summon_amulet`.

## Acceptance Criteria
- [ ] 9 классов выбираются и играются, у каждого свое оружие с механикой архетипа.
- [ ] Статы/релевантность/аффинити/вознесение/кодекс покрывают новые классы.
- [ ] Баланс: зачистка волны ±20% от Берсерка (зафиксировать замеры).
- [ ] Все сущности в content_registry (с пометками placeholder у арта).
- [ ] Smoke (9 классов) и meta тесты зеленые.

## Документация
- content_registry (классы, оружие, ID), mechanics_extract (статы/формулы новых классов),
  current_game_state, CHANGELOG.

## Handoffs
- Арт: `codex_design_new_classes_art_task.md` (Codex генерирует, Designer режет и интегрирует).
