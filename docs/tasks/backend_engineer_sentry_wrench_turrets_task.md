# Инженер: «Ключ Часового» — переосмысление в разворачиваемые турели

- Jira: SCRUM-888
- Статус: done
- Контур: Claude
- Owner: Claude Fable 5 (интерактивный чат пользователя)
- Thread: claude-fable5-ui-unify-20260708
- Worktree: /private/tmp/fsd_wt_turrets (ветка engineer-turrets)
- Branch: dev
- Locked paths: scripts/progression_data_weapons.gd (engineer_sentry_wrench),
  scripts/progression_data_balance.gd (его скаляры), новый scripts/sentry_turret.gd (+сцена при
  необходимости), scripts/player*.gd (атака-хук оружия), assets/sprites/weapons/engineer_turret/**,
  tests/ (новый focused-тест турелей + правки weapon-identity ассертов)

## Source Request

Прямая директива пользователя (чат, 2026-07-08): «оружие инженера — ключ часового
надо переосмыслить, пусть это будут туррели».

## Решение

Механика: вместо текущей у `engineer_sentry_wrench` — игрок периодически
разворачивает стационарную турель-часового (лимит 2–3 одновременно, старейшая
заменяется), турель автоматически стреляет по ближайшему врагу; урон/темп
скейлятся от атрибутов инженера. Дизайн и баланс — строго по доктрине
`~/.codex/skills/fantasydisk-class-balance-director/SKILL.md`: кит инженера
(3 оружия суммарно) остаётся сопоставим по solo/AoE/выживанию; ниша оружия —
зонный контроль/удержание позиции, отличная от двух других оружий класса.
Переиспользовать инфраструктуру союзных сущностей (ally minion family) для
таргетинга/жизненного цикла. Спрайт турели — PixelLab (top-down 64×64,
бронза/латунь/полуночная сталь), уже сгенерирован оркестратором.
ID и название оружия сохраняются (сейв-совместимость; «Часовой» = sentry —
тематически точно), тексты title/description/identity обновить под турели.

## Acceptance Criteria

- [ ] Турели разворачиваются, лимит соблюдается, автострельба по ближайшему,
      урон скейлится от атрибутов; фокус-ссылка старой механики удалена/заменена.
- [ ] Баланс: comfort-band оружия в progression_data_balance выдержан
      (ideal_1/5/20 пересчитаны по доктрине), кит инженера сопоставим.
- [ ] Новый focused-тест турелей зелёный (спавн/лимит/урон/очистка при смерти
      боя); runtime_smoke, weapon_select смоук (identity «Отличие:» обновлён),
      pool_dot/каркасные гейты без регрессий.
- [ ] Кодекс/выбор оружия показывают новые тексты автоматически.

## Прогресс

- 2026-07-08: спека, спрайт турели PixelLab — Claude Fable 5.
- 2026-07-08: субагент engineer-turrets влит (b9e71076+db052a77): sentry_turret.gd
  + сцена, развёртка 2.7с/лимит 2 (замена старейшей), залп 2 по разным целям
  (×0.55^i), скейл от Лидерства, чистка через player_weapon_effects; бюджет-модель
  переписана 1:1, residual-пара тюнера сохранена (±0.2% к старому оружию),
  comfort-веса 1.03 подтверждены; identity «развёртка стационарных турелей
  и удержание зоны».

## QA-Вердикт

- Статус: PASSED
- Дата: 2026-07-08, судья: Claude Fable 5 (оркестратор)
- Гейты (godot_gate, EXIT=0): НОВЫЙ engineer_turret_test (deploy/limit/nearest/
  scale/cleanup — прогнан и после влития в dev), summoner_strengthening,
  comfort_band cross-class (153 замера, 0 нарушений), global damage balance
  smoke (51 пар), content_registry_consistency, codex_data_smoke, animation
  smoke, runtime_smoke (полный). pool_dot_runaway_gate пропущен осознанно
  (чужие тяжёлые прогоны; правило одиночного запуска).
- Disk cleanup: removed /private/tmp/fsd_wt_turrets (+ .godot-кэш), ветка
  engineer-turrets удалена после влития.
