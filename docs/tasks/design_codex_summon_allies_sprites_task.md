# Задача Для Design-Агента: Спрайты призывных миньонов Друида и всех призывных союзников (D&D-канон)

Статус: review
Версия: 0.1.4
Создано: 2026-06-12
Автор: PM (запрос пользователя)
Jira: SCRUM-152

## Autonomy / Approval
Пользователь заранее одобрил все изменения в рамках этой задачи.
Не останавливаться для подтверждений.

## Роль И Границы
Владелец — Claude-Designer (инвентаризация, спека, ревью, интеграция, коммиты).
ЖЕЛЕЗНОЕ ПРАВИЛО: вся генерация — Codex Design, к КАЖДОЙ генерации прилагать
референсы-изображения (существующие спрайты персонажей/монстров проекта как
стиль-якорь: assets/sprites/characters/druid.png и лучшие из enemies/).
Подключение спрайтов в сцены — мелкая интеграция допустима Designer'ом;
если потребуется логика — handoff в Back-end.

## Контекст (запрос пользователя, 2026-06-12)
«Нарисовать в D&D стилистике призывных миньонов Друида и всех призывных
союзников. По стилю ожидаю не хуже, чем сейчас» (т.е. качество на уровне
текущего канона персонажей/монстров — painterly D&D, без плоского вектора).

Текущее состояние (проверено PM):
- `scenes/AllyMinion.tscn` — у призываемого союзника ВООБЩЕ НЕТ спрайта
  (только CircleShape2D коллизия): миньоны Друида («командуемые питомцы»,
  ульта «Зов стаи»), призывы от Лидерства и призывы оружия — безликие.
- `scenes/SoundAmp.tscn` (амп Гитариста) и `scenes/SummonAmulet.tscn` —
  используют спрайты ОРУЖИЯ (sound_amp.png / summon_amulet.png) как полевые
  объекты.
- Гомункул Химика (homunculus_vial, временный миньон) — проверить, чем
  рендерится.

## Требования
1. **Инвентаризация.** Пройти группу "allies" и все призывающие механики
   (Друид: питомцы + «Зов стаи»; Лидерство: эхо-призывы всех классов; Химик:
   гомункул; Гитарист: амп как полевой объект; оружие summon_amulet) — полный
   список сущностей, которым нужен собственный полевой спрайт. Список — в
   отчёт задачи до генерации.
2. **Дизайн-решение по различимости.** Миньоны разных источников должны
   читаться по-разному (питомец Друида — звериный/природный: волк/вепрь/дух
   леса; гомункул — алхимическая тварь; эхо Лидерства — призрачный союзник;
   амп — мистический резонатор-тотем). При этом все — союзники: единый
   отличительный признак от врагов (тёплая/зелёная аура, ошейник-руна —
   решение Designer), чтобы в бою не путать с монстрами.
3. **Генерация (Codex, с референсами).** Размер согласовать с мобами
   (миньоны ~меньше героя), RGBA с прозрачностью, integral (без обрезков),
   top-down ракурс как у остальных существ, без фона. Качество — не ниже
   текущих спрайтов персонажей: painterly D&D, материальность, читаемый
   силуэт на всех 10 аренах (проверить на светлых и тёмных фонах).
4. **Интеграция.** Подключить спрайты в AllyMinion (вероятно — параметр
   «вид миньона» по источнику призыва: ally_minion_druid.png,
   ally_minion_echo.png, ally_minion_homunculus.png...), амп оставить/заменить
   осознанным полевым спрайтом (не иконкой оружия). Если нужен код выбора
   спрайта по источнику — handoff в Back-end с точной спекой.
5. content_registry.md — все новые ассеты; CHANGELOG (Unreleased); smoke
   (runtime + animation, если затронуты анимации).
6. Превью-лист «все союзники рядом с героем и врагами» — в
   docs/design/previews/ для сверки масштаба и различимости.

## Files / Assets / IDs
- scenes/AllyMinion.tscn, scripts/ally_minion.gd, scripts/player.gd (призывы)
- scenes/SoundAmp.tscn, scenes/SummonAmulet.tscn
- assets/sprites/ (новые: ally/minion-спрайты)
- Референсы стиля: assets/sprites/characters/*.png, assets/sprites/enemies/*.png
- docs/design/content_registry.md

## Acceptance Criteria
- [ ] Полный список призывных сущностей в отчёте; у каждой — собственный спрайт.
- [ ] Миньоны Друида и все союзники различимы между собой и однозначно «свои».
- [ ] Качество на уровне канона (превью-лист рядом с героем/врагами).
- [ ] Каждая генерация шла через Codex с приложенными референсами (команды в отчёте).
- [ ] Спрайты подключены (или создан Back-end handoff с точной спекой выбора).
- [ ] content_registry/CHANGELOG обновлены; smoke зелёные.

## Документация
- docs/design/content_registry.md, visual_style_assets.md (раздел союзников).

## Самопроверка
Превью-лист + запуск боя с Друидом (или smoke-дамп сцены): миньоны видимы,
масштаб согласован, на светлой и тёмной арене читаются.

## Progress Log

2026-06-12 — взято в работу на ветке `dev` после dispatch в Design/Codex.

- Инвентаризация активных summon/deploy сущностей:
  - `scenes/AllyMinion.tscn` + `scripts/ally_minion.gd`: общий союзный миньон без финального raster visual; сейчас используется `Polygon2D` placeholder.
  - `scenes/SummonAmulet.tscn` + `scripts/summoner_weapon.gd`: друидский `summon_amulet`, спавнит `AllyMinion` с `command_mode = attack_target`, лимит масштабируется от Leadership/summon_amount.
  - `scenes/HomunculusVial.tscn` + `scripts/summoner_weapon.gd`: химикский `homunculus_vial`, тоже спавнит тот же `AllyMinion`, но с `weapon_id = homunculus_vial` и damage от `magic_damage`.
  - `scripts/player.gd::_activate_druid_ultimate`: ульта Друида «Зов стаи» сейчас наносит instant AoE damage без node-союзников; для настоящей временной стаи нужен Back-end/Animator follow-up, если продуктово требуется видимая стая как сущности.
  - `scripts/player.gd::_trigger_leadership_echo`: Leadership echo сейчас прямой damage + VFX, без summon node; для полевого эхо-союзника нужен Back-end handoff.
  - `scenes/SoundAmp.tscn` / `ClassWeapon._fire_amp`: Гитаристский амп деплоится как runtime `Node2D` со sprite от weapon texture; нужен отдельный полевой sprite, но подключение требует texture override в `ClassWeapon` или scene/config.
  - `scenes/RavenTotem.tscn`: Друидский amp/totem использует weapon sprite как deployable; можно заменить/подготовить отдельный field sprite.
- Design scope: подготовить PNG-ассеты и preview; подключить безопасный fallback visual в `AllyMinion.tscn` только если это не требует source-specific logic.
- Back-end handoff нужен для выбора ally/deployable sprite по `weapon_id` (`summon_amulet` vs `homunculus_vial`, `sound_amp` vs `raven_totem`) и для видимых Leadership echo / Druid ultimate pack nodes.

2026-06-12 — Design/Codex pass завершен, задача передана в review.

- Сгенерирован Codex Design sprite sheet с референсом из активных ассетов проекта (`docs/design/previews/summon_allies_style_references.png`): Друид, Химик, Гитарист и текущие enemy/weapon style anchors.
- Нарезаны и очищены от chroma-key/dirty alpha islands 6 PNG `256x256`, RGBA, transparent:
  - `assets/sprites/allies/ally_druid_beast.png`;
  - `assets/sprites/allies/ally_druid_pack_spirit.png`;
  - `assets/sprites/allies/ally_homunculus.png`;
  - `assets/sprites/allies/ally_leadership_echo.png`;
  - `assets/sprites/allies/deploy_sound_amp_field.png`;
  - `assets/sprites/allies/deploy_raven_totem_field.png`.
- `scenes/AllyMinion.tscn` получил `Sprite2D Body` с `ally_druid_beast.png` вместо Polygon2D-placeholder. Это безопасный fallback без source-specific logic.
- Preview/self-QA:
  - `docs/design/previews/summon_allies_asset_contact.png`;
  - `docs/design/previews/summon_allies_scale_meadow_preview.png`.
- Создан Back-end handoff для runtime source mapping: `docs/tasks/backend_summon_allies_source_sprite_integration_task.md`.
- Godot import: passed.
- Runtime smoke: blocked by unrelated current worktree weapon-effect cleanup regression, not by ally sprite assets. Current failure: `Expected switching Guitarist weapons to clean up amp/effect nodes. Leftover: SoundWaveVfx` at `tests/runtime_smoke_test.gd:1979`.
