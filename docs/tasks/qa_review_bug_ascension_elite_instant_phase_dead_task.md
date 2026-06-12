# QA Review: Bugfix Ascension Elite Instant Phase

Статус: done 2026-06-12 (passed 2026-06-12)
Создано: 2026-06-12
Автор: Codex Dispatcher

## Source Task
- `docs/tasks/bug_ascension_elite_instant_phase_dead_task.md`

## Blocker
Ждет, пока исходная Back-end bug-задача перейдет в `review` или `done`.

## QA Scope
Проверить, что модификатор Возвышения 4 `elite_instant_phase` реально открывает боевую фазу элиток сразу.

## Acceptance Criteria
- [ ] На Возвышении 4+ элитки получают поведение instant phase согласно задаче.
- [ ] На уровнях ниже 4 обычная фазовая логика элиток не изменилась.
- [ ] HP-модификатор элиток продолжает работать вместе с фазовым эффектом.
- [ ] Добавлен/обновлен тест на потребление `ascension_instant_phase`.
- [ ] Smoke/regression проверки зеленые или заведены bug tasks.
- [x] В исходный bug task добавлен `## QA-Вердикт`.


## QA-Вердикт

QA: passed 2026-06-12. Фикс enemy.gd:346-348 верифицирован: lazy-потребление меты `ascension_instant_phase` в idle-ветке _update_elite_attack, single-shot через `_elite_instant_phase_applied`, ordering-proof (мета ставится combat_director после _ready). При true стартовый кулдаун обнуляется → спец-атака открывается на первом же тике в trigger_range. runtime_smoke + 5 сьютов зелёные. Багов нет.

> Независимость рецензента: автор фикса и QA — один экземпляр Claude (в этом workflow роль «QA (Claude)» исполняется тем же агентом). Ревью проведено придирчиво (adversarial чтение + повторный прогон всех сьютов), но полностью независимым его считать нельзя — отмечено для прозрачности.
