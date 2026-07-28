# FantasyDisk Current Game State

Обновлено: 2026-07-16 (опубликован stable release 0.2.4)

Этот документ описывает то, что уже есть в текущей версии игры. Он нужен агентам и разработчикам как быстрый фактический снимок проекта перед изменениями в геймплее, балансе, UI, персонажах, врагах, прогрессии и ассетах.

Канонические ID и игровые названия всех сущностей находятся в `docs/design/content_registry.md`. Любая новая сущность должна появляться там в той же задаче, в которой она добавляется в игру.

Domain docs для подробностей по областям:
- `docs/design/systems/combat.md`;
- `docs/design/systems/route_map.md`;
- `docs/design/systems/menus_ui.md`;
- `docs/design/systems/characters_weapons.md`;
- `docs/design/systems/enemies_bosses.md`;
- `docs/design/systems/progression_balance.md`;
- `docs/design/systems/input_controls.md`;
- `docs/design/systems/persistence.md`;
- `docs/design/systems/visual_style_assets.md`;
- `docs/design/systems/animation.md`;
- `docs/design/systems/technical_architecture.md`.

## Проект

- Движок: Godot 4.
- Жанр: 2D top-down loot-action survival roguelite с RPG-билдкрафтом.
- Текущий опубликованный stable release: `0.2.4` (2026-07-16). Главный акцент
  этого выпуска — исправление публичной доставки: private source repository остаётся
  закрытым, а updater получает manifest и installers из отдельного public
  binary-only `FomaBy/FantasyDisk-Releases`. Telegram снова доставляет игрокам
  poster, DMG, Windows Setup и SHA256SUMS; Discord публикует Telegram link.
  Игровой баланс и контент 0.2.4 не изменились относительно принятой версии 0.2.3.
- Основная рабочая платформа: macOS. Релизные платформы: macOS (DMG с ярлыком
  Applications) и Windows (x86_64 NSIS-инсталлер с embed_pck; отдельный zip/exe
  игрокам не публикуется).
- macOS-канал сборки выбирается ЯВНО через `FANTASYDISK_MACOS_CHANNEL`; тихий
  downgrade запрещён в обе стороны. Полный контракт — `docs/process/game_updates.md`
  и `docs/process/release_versioning.md`:
  - `signed` — строгий default, включается автоматически при наличии credentials:
    `MACOS_SIGN_IDENTITY` (Developer ID Application) и `MACOS_NOTARY_PROFILE`
    обязательны; codesign, notarytool, `stapler` и `spctl` выполняются отдельно
    для приложения и итогового DMG.
  - `unsigned` — текущий выбранный канал (решение владельца, FAN-1121, после
    отмены FAN-1094): DMG и .app без подписи Developer ID и нотаризации.
    После всех изменений bundle получает только локальную ad-hoc подпись, чтобы
    заменить унаследованную подпись export template и проверить целостность;
    она не удостоверяет издателя и не отменяет Gatekeeper. Notarization, stapler
    и `spctl` пропускаются; целостность дополнительно гарантируется HTTPS +
    доверенным манифестом + точным именем/размером/SHA-256, а клиент явно
    помечает сборку unsigned и даёт ручную инструкцию («Всё равно открыть» /
    Open Anyway).
- Для ОБОИХ каналов Finder DMG показывает только нативные `FantasyDisk.app` и
  `Applications` с одной тонкой стрелкой между ними; baked copy, рамки,
  `.background`, `.fseventsd` и прочие root-служебные элементы запрещены и
  проверяются при sealing вместе с exact-tag inputs, layout, secret scan,
  `SHA256SUMS.txt` и `update-manifest.json`.
- Исторически FAN-1094 требовал fail-closed signed-only поставку
  (ad-hoc/unnotarized релиз запрещён), но задача отменена и заменена
  unsigned-каналом FAN-1121, поэтому signed-only больше не является текущим
  универсальным правилом.
- Версионирование: продуктовые версии используют SemVer `X.Y.Z`; техническое
  исправление изменённых байтов без нового игрового поведения использует
  `X.Y.Z.R`. Источник истины — `project.godot::config/version`; immutable
  релизы — теги `v<version>` на `main`, разработка — в `dev` (см.
  `docs/process/release_versioning.md`). Исторический release freeze
  FAN-1128/FAN-1210 завершён публикацией `0.2.4`. Сборка:
  `tools/build_release.sh <version>`.
- Основная сцена: `scenes/Main.tscn`.
- Основной управляющий скрипт: `scripts/main.gd` — тонкий координатор (state, пауза, основной цикл, делегирующие стабы для тестов). Он владеет модулями-компонентами: `scripts/ui_screens.gd` (меню/экраны/HUD/стили), `scripts/route_map_screen.gd` (генерация маршрута и экран карты), `scripts/combat_director.gd` (бой, спавн, баланс, арена, pickups). Модули — RefCounted с ссылкой `game` на main; общее состояние живет в main.
- Иконка приложения: `icon.svg`, подключена через `project.godot` `application/config/icon` и оформлена как fantasy disk emblem с золотым ободом и фиолетовым разломом.
- Главный игрок: `scenes/Player.tscn`, логика в `scripts/player.gd`.
- Smoke tests: `tests/runtime_smoke_test.gd` остается umbrella-проверкой полного core loop. Для быстрых регрессий SCRUM-202 добавил focused suites: `tests/runtime_smoke_ui_test.gd`, `tests/runtime_smoke_combat_test.gd`, `tests/runtime_smoke_progression_economy_test.gd`, `tests/runtime_smoke_weapon_mechanics_test.gd`, `tests/runtime_smoke_boss_elite_test.gd`. Дополнительно используются `tests/animation_smoke_test.gd` и `tests/meta_progression_smoke_test.gd`.
- Playable animation snapshot SCRUM-869: all 17 playable classes still expose
  the 8-direction idle + 6-frame directional `move/walk` contract for runtime and
  Hero Select previews. The latest PixelLab refresh re-imported complete packs
  for Assassin, Biologist, Chemist, Dark Mage, Druid, Guitarist, Knight, Priest,
  Ranger, Robot and Thief; Berserk, Soldier, Elementalist, Sniper, Engineer and
  Doctor keep their current valid runtime packs until PixelLab source packages
  expose complete directional movement rows or a valid manifest download.
- SCRUM-885 (2026-07-08) performs a focused Knight refresh from PixelLab MCP
  character `c1a7d633-7353-4861-aea3-8d937b601cba` (`FantasyDisk Knight PixelLab
  SCRUM-430 no-shield 2026-06-30`). The importer refreshed only `knight`, kept the
  no-shield/no-weapon source contract, and exported 8 idle directions plus 6-frame
  directional `move/walk` rows at `2026-07-08T15:55:39.543782`.

## Основной Поток Игры

Текущий забег состоит из следующих этапов:

1. Главное меню.
2. Настройки видео и управления, если игрок их открывает.
3. Выбор персонажа.
4. Выбор оружия выбранного персонажа.
5. Генерация горизонтальной маршрутной карты текущего акта.
6. Выбор узла маршрута.
7. Бой или небоевой экран узла.
8. Получение опыта, денег, наград и артефактов.
9. Возврат на карту.
10. Boss текущего акта.
11. После boss Act 1 — после короткой задержки на проигрывание смерти босса
    показывается **экран трофея босса (SCRUM-873)**: обязательный выбор 1 из 3
    СУПЕРРЕДКИХ артефактов (верхний тир, `boss_completion_artifact_choices`, без
    дублей, с учётом класса; Escape не закрывает), затем переход к новой карте
    следующего акта с сохранением билда. При переходе в следующий акт герой
    **отхиливается на 70% max HP** (`ACT_TRANSITION_HEAL_PERCENT`, лечение с
    clamp по максимуму, применяется к `run_player_snapshot` в
    `advance_to_next_act`). После boss Act 2 — победа или разрешённый secret boss;
    третья route map не создаётся. Перед secret boss экран выбора сохраняется,
    после итоговой победы autosave очищается.
    Смерть завершает забег в любом акте.
    Финальная победа и смерть (включая ручное «Завершить забег») показывают **экран
    итогов забега (run summary, SCRUM-502)**: время забега (MM:SS), достигнутый этап,
    убийства, урон по врагам / полученный урон, собранное золото, финальный уровень,
    набранные артефакты и причину исхода (имя босса/категория). Метрики собираются в
    `game.run_metrics` по ходу боёв (`reset_run_metrics` на старте забега; НЕ персистятся
    в autosave), рендерятся через `_add_run_summary_rows` в компактной колонке
    no-scroll result-модалки поверх мета-текста, и обнуляются при возврате в меню /
    новом забеге.

Бой длится по таймеру (SCRUM-785): обычный бой `60 + 3 * route_stage` секунд (максимум 90, ×множитель Возвышения) — выжил до конца = победа. Элитка и Босс — фиксированный 5-минутный (`300с`, `ELITE_BOSS_ROUND_DURATION`, без множителя Возвышения) таймер «убей или проиграл»: победа = убить цель до истечения; таймаут с живой целью = поражение. Таймер тикает и в боссовом бою. После смерти босса SCRUM-865 даёт `2.0s` задержку перед victory/act transition и не-boss pressure cleanup, чтобы full-frame death animation не срезалась мгновенным `_clear_world()`.
SCRUM-1071 закрепляет single-owner lifecycle игрового Player: повторный старт
строящегося или подтверждённого живыми Player/generation/HUD боя идемпотентен,
но stale `combat_active` после прямой очистки картой нормализуется и не блокирует
RouteNode A/pressed. В группе `player` и у viewport остаются ровно один
`current_player` и одна включённая Camera2D. Полные Player-снапшоты
для меню имеют отдельную роль/группу `temporary_players`, отключённые gameplay
process/physics/collision/camera и удаляются централизованно до потери UI-ссылок;
`_clear_world()` синхронно выводит из дерева все принадлежащие Main Player, а не
только объект из ссылки `current_player`.
В двухактном забеге `route_stage` остаётся локальным для карты акта, а длительность,
спавн, награды, цены и boss/elite scaling читают `route_scaling_stage() =
route_stage + (current_act - 1) * 8`. Offset равен неизменным 8 activity rows:
Act 2 начинается с бюджета boss Act 1 и достигает прежнего финального stage 16,
не добавляя узлы или время боёв.

## Разрешения И Окно

Обновление 2026-06-12 (настройки v3):
- **Мониторы**: при 2+ экранах в настройках появляется дропдаун выбора монитора (номер + разрешение); окно переезжает на выбранный экран во всех режимах. При одном экране опция скрыта.
- **Оконные разрешения** применяются честно: размер клампится по `screen_get_usable_rect` выбранного монитора (учет масштаба ОС/дока/меню-бара), окно центрируется от origin usable rect (раньше центрирование игнорировало origin — на втором мониторе окно уезжало); разрешения больше монитора задизейблены в списке. Borderless занимает usable rect экрана.
- **Вкладки**: экран настроек разделен на четыре `TabContainer`-вкладки «Экран», «Звук», «Управление», «Игра». «Управление» использует внутренний `ControlsScroll`; SCRUM-1025 добавил вертикальный `SettingsGameScroll` для пяти gameplay-sandbox строк и Reset. На 1080p/2K четыре таба стоят одним рядом, на 720p — безопасной сеткой 2×2; LB/RB включает четвёртую вкладку и wrap.
- **Tab switcher art/typography**: исторические SCRUM-396/v2 three-slot strips больше не являются live geometry. SCRUM-1025 использует четыре независимые global-kit plates `SettingsTabButton_0..3`, поэтому орнамент не растягивается. SCRUM-1060 переводит все четыре таба в единый text-only contract: иконки не рендерятся ни на одном tier, а effective font совпадает с `SettingsBackButton` (`21/22/23/23 px` на `1152×648` / `1280×720` / `1920×1080` / `2560×1440`). Полные русские подписи лежат только в плоской `x=48..212` content-zone каждой 260px плиты, без clip/wrap/ellipsis/downscale; принятые SCRUM-975 PNG-иконки остаются source/runtime history и удалять их не требуется.
- **Semantic typography (SCRUM-1061)**: `scripts/ui/semantic_typography.gd`
  является единым runtime-источником ролей display/title/section/body/
  description/action/tab/field/value/tooltip/caption/HUD, их min-target-max и
  overflow policy. Readable/Settings/Codex/pause compatibility helpers,
  route-map, global tooltip/toast, threat/world feedback и raw combat HUD
  делегируют в этот API без изменения уже принятых effective values и
  content-zone geometry. Машинный inventory из
  `docs/design/mockups/scrum1061_semantic_typography/` сопоставляет каждый
  player-facing override роли либо явному allowlist с owner/reason/next issue;
  два Atlas-canvas исключения остаются у SCRUM-1068. SCRUM-1073 мигрировал все
  остальные 139 legacy cross-band sites: schema-3 inventory хранит пары
  original/replacement fingerprint и effective before/after, все replacements
  live, originals отсутствуют, routing SCRUM-1073 равен нулю. Геометрия
  адаптирована без снижения semantic floors; шестирежимная матрица теперь также
  включает 2048×1152. SCRUM-1070 меняет только геометрию Atlas reset-footer и
  не владеет inventory-site.
  Continue Run
  числится как title, но SCRUM-1062 geometry/tier не менялись.
- **Minimalist UI kit**: SCRUM-449 подключил SCRUM-448 minimal non-button frame kit (`assets/sprites/ui/frames/minimal/`) к runtime Settings shell/switcher/content panel, Codex panels/cards/tooltips, economy choice cards/price badges, reward cards, pause/result shells, generic panels/cards/tooltips и компактным HUD wrappers. Hero Select v3 frames, progression node rings and combat bar fills остаются screen-specific exceptions. QA: `build/qa/scrum448_ui_minimalist/`, runtime smoke/UI/no-overlap PASS.
- **Minimal Metal / text-button runtime kits**: SCRUM-459 wired the SCRUM-452 strict minimal-metal frame kit under `assets/sprites/ui/frames/minimal_metal/` as first-class runtime paths/constants plus a reusable StyleBoxTexture helper with metadata texture/content margins and safe rects. SCRUM-462 keeps the SCRUM-450 minimal-metal button kit available for compact/icon-like exceptions, while SCRUM-669 promotes the SCRUM-657 generated text-button kit under `assets/sprites/ui/frames/text_buttons_unique/` for normal text/action buttons such as main menu, back, quit, continue, settings, feedback, pause, event and rebind actions. SCRUM-842 uses the existing `continue_run_long_420x72` family for the continue-run dialog primary button so `Продолжить` fits inside button content margins in every state. Card/hit-area, icon-only, slot, portrait, stepper, route-node and weapon/reward-card exceptions remain card/slot styled. Red & Gold buttons are historical/backup only for this pass. QA evidence writes under `build/qa/scrum669_text_buttons/` plus the existing UI smoke outputs.
- **Звук**: слайдеры Общая/Музыка/Эффекты/Звуки интерфейса (0-100%, шаг 2) вынесены во вкладку «Звук», имеют видимый темный трек, золотую заполненную часть, числовое значение справа и keyboard focus для стрелок. Переключатели музыки/эффектов подписаны «Вкл.»/«Выкл.»; mute не сбрасывает значение слайдера. SCRUM-974 добавил persisted `ui_volume`, `mute_when_unfocused` (default off) и `low_hp_warning_enabled` (default on): UI-шина является дочерней SFX, приложение опционально глушит Master вне фокуса, а low-HP loop восстанавливается при повторном включении без нового HP-edge. `AudioScroll` скрыт на 1080p/2K и даёт focus-scroll на 720p. По умолчанию музыка и эффекты выключены явными флагами `music_enabled=false` / `sfx_enabled=false`, все четыре слайдера остаются на 100%. «Сбросить звук» возвращает все восемь audio keys к defaults.
- **Управление**: вкладка «Управление» показывает режим прицеливания (`Автонаводка на ближайшего` / `По курсору`), persisted toggles `Дебаг-режим` и `Боевой фидбек`, а также биндинги движения, паузы и `ultimate` внутри вертикального scroll-контейнера с авто-прокруткой к фокусу. Дефолты: aim mode `nearest`, debug mode `off`, combat feedback `on`, WASD + стрелки для движения, Escape для паузы, R для ультимейта. SCRUM-814 переводит боевое движение игрока на `Input.get_vector("move_left", "move_right", "move_up", "move_down", deadzone)`: клавиатура и D-pad дают полную скорость, левый стик геймпада дает пропорциональную скорость с deadzone `0.25` по умолчанию, диагонали ограничены текущей максимальной скоростью. `move_*` actions идемпотентно получают left-stick `JOY_AXIS_LEFT_X/Y` и D-pad events без удаления клавиатурных биндингов. Вибрация геймпада включена по умолчанию (`gamepad_vibration`), no-op без подключенного геймпада/headless; урон игроку дает weak `0.6` на `0.25с`, смерть strong `0.8` на `0.5с`, ultimate weak `0.4` на `0.15с`. Ребинд проверяет конфликт с другими действиями и не перезаписывает чужую клавишу молча; есть reset defaults. SCRUM-816 разбивает вкладку на секции «Устройство ввода» (OptionButton режима `input_mode` + live-статус подключения пада по hot-plug), «Клавиатура» (прежние ребинды) и «Геймпад» (ребинд joypad-кнопок/осей по каждому экшену через режим прослушивания с обработкой конфликтов, слайдер `gamepad_deadzone` `0.05..0.5`, чекбокс `gamepad_vibration`, «Сбросить геймпад»); заодно устранён баг, при котором клавиатурный ребинд/сброс стирали joypad-часть экшена (теперь трогаются только `InputEventKey`).
- **Устройства ввода (SCRUM-811, SCRUM-846)**: autoload `InputDeviceManager` (`scripts/input_device_manager.gd`) доливает joypad-бинды во все игровые и `ui_*` экшены (канон: стик+крестовина — движение/фокус, A/B — подтвердить/назад, Start — пауза, Y — ультимейт, RB — level-up, Back — фидбек), детектит активное устройство по последнему вводу с hot-plug (отключение пада мгновенно возвращает клавиатуру) и отдает `device_changed`/`active_kind()`/`binding_text()` для подсказок UI. Клавиатура и геймпад работают одновременно всегда; `input_mode` (`auto`/`keyboard`/`gamepad`) влияет только на подсказки/глифы. SCRUM-846 закрепил Back/Select→feedback, закрытие feedback через B/Start и fallback от пустых/битых saved gamepad bindings, чтобы A/confirm и левый стик не могли быть стёрты старым `settings.cfg`. Полный контракт: `docs/design/systems/input_controls.md`.
- **Dev console (SCRUM-831/SCRUM-845)**: внутриигровая консоль открывается клавишей слева от `1` (`/~`, `§`, `Ё`) как live overlay поверх игры. Она перехватывает командный ввод в `main._input`, но больше не добавляет `dev_console` в `pause_reasons` и не ставит `SceneTree.paused`, поэтому в Windows/player-сборке активный бой, враги, таймер и движение игрока продолжают тикать при открытой консоли.
- **Персистенс / Continue Run**: дисплей, звук (включая `ui_volume`, `mute_when_unfocused`, `low_hp_warning_enabled`), `aim_mode`, `debug_mode`, `combat_feedback`, `input_bindings`, а также геймпад-ключи (`input_mode`, `gamepad_bindings`, `gamepad_deadzone`, `gamepad_vibration`) сохраняются в `user://settings.cfg` (`scripts/game_settings.gd`) и применяются при старте. SCRUM-816 добавил запись этих геймпад-ключей в `main.save_game_settings()` (раньше их писало только ядро при старте, и любое сохранение настроек перезаписывало их дефолтами) + зеркалит `gamepad_deadzone`/`gamepad_vibration` в root-мету для `player.gd`. SCRUM-976 добавил пять gameplay-sandbox множителей с нейтральным `1.0`; при подтверждении оружия они копируются в неизменяемый snapshot забега и отдельно входят в autosave. Изменение/сброс настроек влияет только на следующий забег. Активный забег сохраняется отдельно через `scripts/run_autosave.gd` в `user://fantasydisk_autosave.cfg` после безопасных route checkpoints с `current_act` 1..2; legacy `current_act=3` нормализуется в финальный Act 2 checkpoint с сохранением route/build state. Главное меню предлагает «Продолжить»/«Новая игра» через widened SCRUM-842 continue-run dialog (840×380 panel, 420×72 primary continue button). SCRUM-1062 заменил отдельный Luminari PNG-wordmark заголовка на живой `ContinueRunTitle` Label с точным текстом `Продолжить забег?`, общим theme/default Font resource и fit-safe effective tier `38/40/42/42px`; glyph effects остаются внутри пустой `696×70` title-zone на 648p/720p/1080p/2K и live resize. Autosave callbacks/focus не менялись; смерть/финальная победа по-прежнему очищают autosave.

- **Gameplay sandbox (SCRUM-976)**: диапазоны — HP монстров `0.5–3.0`, урон монстров `0.5–3.0`, урон игрока `0.5–2.0`, скорость атак игрока `0.5–2.0`, скорость атак монстров `0.5–3.0`, шаг `0.1`. `scripts/gameplay_sandbox.gd` — единый контракт normalize/snapshot/metadata. HP/урон применяются один раз в общем `Enemy` (поэтому покрыты обычные враги, призывы, элитки и боссы); скорость монстров ускоряет только attack cooldown countdown, не telegraph/windup/recover. Игрок получает финальный exact-множитель после release softcaps. Любой не-нейтральный snapshot помечает `progression_eligible=false`, блокирует достижения, Codex, boss/meta/Ascension progression и не принимается как release-balance evidence; run-local XP, золото, предметы и сводка сохраняются.
- **Лор и повествование (FAN-1080, FAN-1099)**: канон мира в `docs/design/lore.md` (Диск/Разлом/Владыки/Хранители/Печать/Возвышение-витки/Исток), рантайм-проекция `scripts/lore_data.gd`. FAN-1099: интро истории из 4 слайдов больше НЕ показывается при запуске игры («Начать новую игру» и «Новая игра» ведут сразу в выбор героя) — рассказ о мире остался только в Кодексе, запись «Вступление» на вкладке «Летопись» (те же 4 слайда). Экран `LoreIntroScreen` и хелперы `_maybe_show_lore_intro`/`_show_lore_intro`, флаг `lore_intro_seen` и тест-байпас `force_skip_lore_intro` сохранены в коде для пересмотра/тестов и возможного возврата интро, но в потоке запуска сейчас не задействованы. Кодекс: 7-я вкладка «Летопись» (шаг nav-плит 104), лор-секции в досье классов («Происхождение»), боссов («Владыка Разлома») и элиток («Офицер прибоя»), лор-строка под боевым баннером босса/элитки (элитки заодно получили русские титулы из Кодекса), лорные строки победы («Печать наложена…») и поражения. Спойлер-гард Истока — по `secret_boss_defeated`. Русские `boss_display_name` добавлены Стражу Разлома и Пожирателю Диска, секретный босс — «Исток». Тест: `tests/lore_screens_test.gd`.
- **Gameplay sandbox UI (SCRUM-1025)**: вкладка «Игра» читает ranges/step/values только из SCRUM-976 API, показывает `%.1f×`, нейтральный/пользовательский статус и предупреждение о progression/evidence gate. Изменения сохраняются немедленно, но не мутируют snapshot активного забега; Reset делает один атомарный save и disabled в neutral. `SettingsBottomActions` (экранные Apply/Revert) скрыт на Game, а `SettingsGameScroll` занимает расширенный прозрачный content owner `960/1158/1544` и сохраняет отдельный 14px scrollbar lane на 720p. PixelLab compact mockup задавал `306px` видимой высоты без live Atlas frame; runtime намеренно ограничивает её до `242px` на 720p (`878×520` canvas, max scroll `278`), чтобы ни строки, ни Reset не уходили под нижний орнамент. Focused Metal/headless matrix: `tests/settings_game_scrum1025_test.gd`.
- **Settings footer frame safety (SCRUM-1053)**: on the compact tier
  `SettingsBottomActionsSafe` structurally reserves `64px` for the native
  Apply/Revert plates plus `24px` of empty bottom space. At 1280x720 the
  seamless content ends at `y=507`, the footer is `160,519,960,64`, and the
  authored Atlas inner boundary ends at `y=583`; content/footer keep a 12px gap
  and the complete plates, labels, focus and hit rects keep 24px clear of the
  bottom ornament. Compact Screen uses vertical `SettingsScreenScroll` so its
  legacy native rows cannot force this structural reserve outside the frame.
  The whole footer wrapper collapses on Game, preserving its exact `892x242`
  viewport and `878x520` canvas. Headless/Metal coverage includes the 760px
  compact threshold in `tests/settings_footer_scrum1053_test.gd`.
- **Обновления игры (FAN-1112)**: начиная с 0.2.2 экспортированный клиент один
  раз за сессию проверяет public GitHub Releases; offline-ошибка старта не мешает
  игре, а новая SemVer вызывает prompt. `SettingsUpdateButton` доступна на первых
  трёх вкладках Settings и запускает явную проверку с результатом. Финальные DMG
  и Windows Setup скачиваются в `user://updates` и открываются только после
  строгой проверки trusted URL, имени, размера и SHA-256; self-overwrite игры не
  используется. Полный runtime/release контракт: `docs/process/game_updates.md`.
- **Codex unlock tracking (SCRUM-621 / FAN-1077)**: `scripts/meta_progression.gd`
  persists discovered characters, weapons, monsters, bosses and artifacts plus an independent
  `codex_unread` map for characters, weapons, monsters, bosses and artifacts in
  `user://fantasydisk_meta.cfg`. Runtime records enemies on encounter and
  artifacts when their reward is applied. New discoveries become unread once;
  old saves migrate with no unread flood. Opening an entry clears and saves its
  marks. Main Menu, Codex tabs and unread-first rows share the generated
  exclamation badge. Hero/weapon presentation APIs are ready, while their
  future unlock rules do not yet restrict the current roster.
- **Фидбек/баг-репорт**: SCRUM-362 добавил глобальное действие `feedback` (по умолчанию `P`). FAN-1057/FAN-1059 превращает верхний `FeedbackOverlayLayer` в responsive privacy-first форму: текст, preview, default-on `FeedbackScreenshotToggle`, полный allowlist game/OS metadata, persistent pseudonymous installation UUID, edge-observed IP, оператор/retention и локальное хранение раскрыты до подтверждения; фокус идёт TextEdit → Toggle → Send → Cancel, а правый стик прокручивает disclosure из любого focus stop. Schema-v2 relay использует bounded JPEG либо явный `null`; opt-out не хранит `Image`, не кодирует JPEG и не создаёт локальный `screenshot.png`. Dev/CI raw Discord остаётся только debug-путём; player export не содержит credential. Любой network transport fail-closed, пока public `feedback/privacy_*` значения не утверждены, а `feedback/relay_session_url` остаётся пустым. При отсутствующем/неуспешном online route отчёт сохраняется в `user://feedback/<timestamp>_<uuid>/`; локальная копия хранится на устройстве до удаления игроком.

В настройках доступны:

| Разрешение | Статус |
| --- | --- |
| 2560x1440 | Оконный default, если помещается |
| 1920x1080 | Оконный fallback |

Режимы окна:
- Windowed
- Borderless Window
- Fullscreen

## Игровая Карта И Камера

- Текущий размер боевой арены: 4096x2304 (SCRUM-518 увеличил ×1.6 от прежних 2560x1440 — площадь ≈ ×2.56, соотношение 16:9 сохранено; больше простора для кайтинга и читаемости толпы).
- Центр арены считается от размера карты: `ARENA_SIZE * 0.5`, сейчас 2048x1152.
- Камера использует combat zoom 1.12 и ограничена границами арены.
- На 1600x900 и 2560x1440 камера показывает только часть карты вокруг персонажа, а не всю арену целиком (на увеличенной арене — тем более).
- При подходе к краям камера clamp-ится по 0..4096 и 0..2304 и не должна показывать пространство за картой.
- Границы карты рисуются видимой линией.
- Вокруг арены создаются физические стены.
- Зум камеры выбран так, чтобы карта ощущалась крупной, но угрозы вокруг игрока оставались читаемыми.

## Фоны Арены

В проекте есть фоновые изображения:

| Фон | Путь |
| --- | --- |
| Main Menu Epic Battle V3 | `assets/backgrounds/main_menu_epic_battle_v3.png` |
| Event / Upgrade / Meta Progression | `assets/backgrounds/ui/ui_backdrop_arcane_lab.png` |
| Shop Screen | `assets/backgrounds/ui/ui_backdrop_merchant_archive.png` |
| Campfire / System Screens | `assets/backgrounds/ui/ui_backdrop_system_cathedral.png` |
| Route Map Backdrop | `assets/backgrounds/route_map_backdrop.png` |
| Stone Garden | `assets/backgrounds/field_stone_garden.png` |
| Marsh | `assets/backgrounds/field_marsh.png` |
| Dry Road | `assets/backgrounds/field_dry_road.png` |
| Meadow | `assets/backgrounds/field_meadow.png` |
| Ruined Courtyard | `assets/backgrounds/field_ruined_courtyard.png` |
| Misty Marsh | `assets/backgrounds/field_misty_marsh.png` |
| Dusty Badlands | `assets/backgrounds/field_dusty_badlands.png` |
| Enchanted Meadow | `assets/backgrounds/field_enchanted_meadow.png` |
| Ashen Rift | `assets/backgrounds/field_ashen_rift.png` |
| Cursed Grove | `assets/backgrounds/field_cursed_grove.png` |

Фон арены выбирается случайно из доступного набора и может зависеть от типа узла карты.

Все 10 боевых фонов нарисованы в нативном 2560x1440. С SCRUM-518 арена увеличена до 4096x2304, поэтому `_spawn_arena_background` апскейлит фон под арену (scale ≈ 1.6) — фоны теперь слегка мылятся (ожидаемый компромисс ради простора; перерисовка набора под 4K вынесена в отдельную арт-задачу через `fantasydisk-asset-generator`). SCRUM-369 (2026-06-14) заменил весь набор через `fantasydisk-asset-generator`: `field_marsh`, `field_meadow`, `field_misty_marsh`, `field_ruined_courtyard`, `field_dusty_badlands`, `field_enchanted_meadow`, `field_ashen_rift`, `field_cursed_grove`, `field_dry_road`, `field_stone_garden`. Новый стиль — реалистичный D&D/dark fantasy top-down battlefield floor с богатым материалом по биомам, но приглушенной центральной зоной для читаемости героев, монстров, projectile/VFX и анимаций. `field_dry_road` и `field_stone_garden` теперь существуют как реальные PNG, поэтому live links из `ARENA_BACKGROUND_OPTIONS` больше не битые. QA previews: `docs/design/previews/arena_backgrounds_scrum369_contact.png`, `docs/design/previews/arena_backgrounds_scrum369_readability.png`.
`main_menu_epic_battle_v3.png` используется стартовым экраном как активный фон
главного меню. FAN-1097 заново собрал сцену как цельный 2560x1440 cinematic
dark-fantasy key art через встроенный OpenAI Image Generator в Codex: один
безоружный варвар стоит спиной на базальтовом утёсе над огромным фиолетовым
disk-shaped dimensional rift, а руины и грозовой горный горизонт создают глубину.
Фокус целиком вынесен в center-right/right; спокойная левая колонка под 6
runtime-кнопок и title-safe область под `MainMenuTitleLabel` остаются без ключевых
силуэтов, а lower-right utility zone локально приглушена. Фон не содержит baked
UI, text, logo, buttons, frame, cursor или watermark; runtime texture path и UI
wiring не менялись. Built-in source/targeted edit, оба prompt, backup, mockup,
responsive previews и точные safe zones задокументированы в
`docs/design/mockups/fan1097_main_menu_openai_background/spec.md` и
`docs/design/references/fan1097_main_menu_openai_background/manifest.json`.
Предыдущий FAN-1088 runtime фон сохранён в
`docs/design/backups/fan1097_main_menu_openai_background/main_menu_epic_battle_v3_pre_fan1097.png`;
FAN-1088 package остаётся историческим provenance.
SCRUM-680 release refresh (2026-07-02) заменил runtime logo на PixelLab-based
`assets/sprites/ui/menu_title/main_menu_title_fantasy_disk.png` (`960x360`,
transparent; source/provenance `docs/design/references/main_menu_logo_release_fix/`)
и опустил `MainMenuActions` ниже логотипа через viewport-aware top calculation,
чтобы 1920x1080, 2560x1440 и 1080x1920 не перекрывали title. SCRUM-418 удалил
старый `main_menu_epic_battle.png` из runtime assets как legacy-дубль; backup
лежит вне shipping scope в `build/qa/scrum418/removed_assets_backup/`. Старые
совместимые копии `screen_event_background.png`, `screen_shop_background.png` и
`screen_campfire_background.png` также удалены из `assets/sprites/ui/screens/`
как дубли canonical UI backdrop set.

SCRUM-158/170 добавили и подключили canonical UI backdrop set `assets/backgrounds/ui/`: `ui_backdrop_system_cathedral.png`, `ui_backdrop_merchant_archive.png`, `ui_backdrop_arcane_lab.png`, `ui_backdrop_reward_hall.png`, `ui_backdrop_defeat_crypt.png`. Все `2560x1440`, с низкоконтрастным спокойным центром под центральные окна и более богатым dark fantasy материалом по краям. Runtime mapping идет через `SCREEN_BACKGROUND_PATHS`: `system/settings/codex/hero_select/weapon_select/pause_stats/meta_tree/campfire` -> cathedral, `shop` -> merchant archive, `event/upgrade/level_up/meta_progression` -> arcane lab, `elite_reward/victory/artifact_reward` -> reward hall, `death/defeat/end_run_confirm` -> defeat crypt. Фоны ставятся `TextureRect` cover-scaling под читаемое затемнение, без замены route map/combat backgrounds.
`route_map_backdrop.png` используется full-screen route map hook-ом: это темный низкоконтрастный фон пустоши с туманным спокойным центром под узлы и линиями, а детали/силуэты вынесены к краям.

## Брендинг

| Ассет | Путь | Использование |
| --- | --- | --- |
| FantasyDisk App Icon | `icon.svg` | Project/application icon через `project.godot` |
| FantasyDisk Steam Library Logo | `assets/marketing/steam/fantasydisk_steam_library_logo.png` | 1280x720 transparent PNG для Steam library/logo placement; preview на темном фоне: `assets/marketing/steam/fantasydisk_steam_library_logo_preview.png` |

## UI Visual Style

SCRUM-586/SCRUM-593 make the dedicated 2K stat tooltip live for
`StatTooltipPanel` / `_make_custom_tooltip`. The runtime frame is
`assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_stat_tooltip.png`
(`430x288` RGBA, transparent edge alpha, no baked text) with texture margins
`32/32/32/32`, content margins `44/42/44/42`, and a `342 px` runtime label safe
width. Spec and previews live under `docs/design/mockups/scrum586_stat_tooltip/`
and `docs/design/previews/scrum586_stat_tooltip_*`.

Historical Hero select v3 kept the hero portrait on the left, dossier/details in the main
right-side information area, and `HeroSelectRadarPanel` as a separate floating
top-right widget. The radar is intentionally offset below the header/wax-seal
buttons to keep the 1280x720, 1600x900 and 2560x1440 no-overlap smoke stable.
The radar drawing control now lives in `scripts/ui/hero_stat_radar.gd`, while
hero-select constants, shop UI constants and dark-fantasy theme paths live in
focused `scripts/ui/*` modules and are exposed through the existing
`scripts/ui_screens.gd` facade.

SCRUM-447 made Hero Select v3 live from the accepted SCRUM-446 Design-source
package, but the 2026-06-30 black minimal redesign supersedes it for the active
runtime. The historical v3 path built a centered proportional
`1536x864` canvas from `docs/design/references/hero_select_v3/zones.json`,
`zones_normalized.json` and `frames_spec.json`, using
`assets/sprites/ui/frames/hero_select_v3/background.png`,
`frame_preview.png`, `frame_dossier.png`, square `frame_radar.png` and
`frame_carousel.png`. Runtime content stayed inside each documented content rect:
large portrait in preview, name/description/traits/weapons/ascension/select in
dossier, `HeroStatRadar` inside a square radar frame, and image-only hero
thumbnails inside the carousel. SCRUM-416 portrait routing, SCRUM-417 covered
portrait scaling, ascension controls, Select, Back/Escape and focus behavior are
preserved. QA evidence lives under `build/qa/scrum446_hero_select_v3/`, including
the `1536x864` mockup-vs-runtime screenshot comparison, rect dump and no-overlap
matrix.
SCRUM-687 supersedes that v3 runtime art/layout with the live PixelLab parts kit
under `assets/sprites/ui/frames/hero_select_pixellab/`: the screen now scales a
`2560x1440` source-space composition with separate portrait, dossier, radar,
ascension and carousel frames while preserving the same interaction contract and
directional PixelLab preview rotation.

Основной UI button pass SCRUM-273 заменил SCRUM-147 Parchment & Wax Seal на Red & Gold Dragon kit из `docs/design/references/Buttons/button_kit_red_gold_dragon_sheet.png`; SCRUM-462 затем promoted SCRUM-450 Minimal Metal, а SCRUM-669 promoted SCRUM-657 generated text buttons as the live normal text/action button kit. Live normal text-button textures now live in `assets/sprites/ui/frames/text_buttons_unique/` with exact-size families (`main_menu_380x104`, `standard_420x104`, `wide_440x104`, `back_260x104`, `quit_220x72`, `continue_240x72`, `later_260x72`, `settings_back_280x64`, `feedback_260x64`, `feedback_cancel_220x64`, `pause_280x60`, `event_back_380x54`, `rebind_420x62`, plus long-label variants) and five states (`normal/hover/focus/pressed/disabled`). Metadata/source: `docs/design/references/ui_text_buttons_unique_size_redraw/button_family_metadata.json`; SCRUM-450 Minimal Metal remains available for compact/icon-like exceptions and historical metadata validation; old Red & Gold backup for the earlier promotion pass: `build/qa/scrum450_minimal_metal_buttons/red_gold_button_backup/`; old parchment/wax button backup: `build/cleanup_backup_red_gold_buttons_2026_06_14/`.

Основной UI frame pass SCRUM-274 заменил SCRUM-229 leather+gold runtime panel direction на Ornate Dark / Red kit из `docs/design/references/UiFrame/frame_kit_ornate_dark_sheet_b_spec.png`. Live panel textures лежат в `assets/sprites/ui/frames/ornate/`: `global_panel`, `level_panel`, `card_frame`, `hero_card`, `card_hover`, `tooltip`, `hud_panel`, `hud_card`, `timer_panel`, `pause_main`, `pause_stat_group`, `pause_stat_chip`, `pause_stat_tooltip`. Contact preview: `docs/design/previews/ornate_dark_frame_kit_contact.png`; pipeline: `tools/build_ornate_ui_frame_kit.py`; old leather/gold + dark_fantasy/escape panel backup: `build/cleanup_backup_ornate_frames_2026_06_14/`.

SCRUM-373 подготовил Design-ready единый master frame kit, SCRUM-382 подключил его к generic runtime UI, а SCRUM-384 заменил те же preserved runtime paths на тонкую металлическую ревизию: `assets/sprites/ui/frames/unified/ui_frame_unified_master.png`, `ui_frame_unified_master_fill.png`, `ui_frame_unified_inner_fill.png`, `ui_frame_unified_ornament_top.png`, `ui_frame_unified_ornament_bottom.png`, `ui_frame_unified_hover_overlay.png`. Source metadata: `docs/design/references/unified_master_frame/unified_master_frame_metadata.json`; previews: `docs/design/previews/unified_master_frame_thin_revision_contact.png` и `docs/design/previews/unified_master_frame_thin_safe_zone.png`. Generic panels/cards/tooltips/HUD/timer frames use a shared tiled 9-slice builder (`72` texture margins; `88` content margins; filled surfaces use `ui_frame_unified_master_fill.png`), while documented whole-image frames like Hero Select SCRUM-356, radar/carousel and Settings tab switcher remain proportional.

SCRUM-439 исторически переключил Settings на v2 runtime package:
`assets/sprites/ui/frames/settings_v2/ui_frame_settings_v2_main_modal.png` и
`ui_frame_settings_v2_tab_switcher_3slot.png`. Тот runtime сохранял ровно три
вкладки (`SettingsTabButton_0..2`) с source-space safe rects
`Rect2(150,78,275,92)`, `Rect2(502,78,275,92)`,
`Rect2(854,78,275,92)`, а `SettingsTabs` продолжает владеть страницами
«Экран», «Звук», «Управление». Все существующие настройки/ребайнды/Debug Mode
сохранены; body-контент сидит на плоской внутренней safe-подложке внутри v2
modal, чтобы не накладываться на frame ornament и Back button на 720p. QA dumps:
`build/qa/scrum439/settings_v2_runtime_rects.md` и
`build/qa/scrum439/settings_v2_no_overlap_matrix.md`.

SCRUM-879 superseded the old v2 modal geometry with the fullscreen Atlas shell,
SCRUM-972 removed its remaining double-surface artifact, and SCRUM-1025 added
the fourth live Game page. Live
`SettingsContentPanel` and the hidden `SettingsTabs` panel now draw no fill or
border; the content owner, clipping and positive margins remain. Four
independent tab plates replace the old strip; Screen Apply/Revert is hidden on
Game because sandbox values persist immediately. Settings rows render over one
continuous sanctum background inside the hollow `SettingsFrame`, with no gray
inner rectangle at 1280x720, 1920x1080 or 2560x1440. Design evidence:
`docs/design/mockups/scrum972_settings_seamless_content/`; focused coverage:
`tests/settings_scrum972_seamless_content_test.gd`.

SCRUM-667 ограничил live Settings двумя оконными разрешениями: 2560x1440 по
умолчанию, если оно помещается на выбранном мониторе, и 1920x1080 как fallback.
SCRUM-441 HiDPI logic remains: resolution options проверяются через
`DisplayResolution.resolution_fits(...)` по физическим пикселям
(`screen_size * screen_scale`), `_apply_video_settings()` клэмпит размер окна через
`DisplayResolution.clamp_to_physical(...)`, а `project.godot` включает
`window/dpi/allow_hidpi=true`.
SCRUM-441 follow-up: при смене video settings runtime синхронизирует
`Window.content_scale_size` с фактическим выбранным оконным/полноэкранным размером,
чтобы Godot preview/Windows показывали реальный viewport выбранного разрешения,
а не только масштабировали базовый 2K canvas.
QA evidence: `build/qa/scrum441/hidpi_resolution_evidence.md`.

SCRUM-273/274/382 подключили stateful style layer к Red & Gold Dragon buttons + unified generic frames; SCRUM-462 keeps the SCRUM-450 minimal-metal button kit available, SCRUM-463 promotes the SCRUM-452 six-frame `minimal_metal` kit as the active generic non-button surface set, and SCRUM-669 switches normal text/action button routing to the SCRUM-657 exact-size `text_buttons_unique` kit. `scripts/ui/ui_theme_paths.gd` now contains `TEXT_BUTTON_UNIQUE_DIR`, `TEXT_BUTTON_UNIQUE_TEXTURES`, texture/content maps, metadata-backed minimal-metal frame/button maps, minimal-metal frame paths/margins/content/safe rects and legacy Red & Gold/minimal/ornate constants for backup/history. `scripts/ui_screens.gd` chooses text-button family by node name/size and routes generic frame roles through minimal-metal `modal`, `panel`, `card`, `tooltip`, `hud_strip` and `field`; `scripts/pause_stats_menu.gd` uses minimal-metal modal/panel/field/tooltip frames plus SCRUM-657 `pause_280x60` text buttons. SCRUM-318 no-yellow semantics are preserved with near-white hover/focus font and dedicated generated hover/focus textures; pressed/disabled use dedicated state textures. Runtime/theme tests check main buttons, pause/run buttons, SCRUM-657 text-button families, all 15 SCRUM-450 historical/exception button families and SCRUM-451 frame rollout paths; QA evidence lives in `build/qa/scrum669_text_buttons/`, `build/qa/scrum450_minimal_metal_buttons/` and `build/qa/scrum451_minimal_metal_rollout/`.
SCRUM-585 historically refreshed the glossary tooltip as a dedicated 2K element
(`GlossaryTooltipPanel`, `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_gt_panel.png`,
content margins `Vector4(66, 44, 66, 40)`). Spec/evidence:
`docs/design/mockups/scrum585_glossary_tooltip/`. SCRUM-889 removes the live
glossary section from the in-game Codex, so this tooltip is retained only as
historical/reference UI material unless a future screen explicitly reuses it.
SCRUM-840 extends the readable tooltip contract across generic `tooltip_text`
UI without new bitmap assets: `scripts/ui/global_tooltip.gd` reuses the existing
minimal-metal tooltip frame for standard controls, preserves the 2K stat
tooltip frame for its specialist path, wraps copy inside content margins,
ignores mouse input, clamps to the viewport, and keeps an 18px cursor/anchor gap
with side flip when space allows. The runtime spec mirror lives at
`docs/design/mockups/scrum840_global_tooltips/spec.md`.

SCRUM-281 добавил отдельный Hero Select frame kit из `docs/design/references/herouiframe/`: `assets/sprites/ui/frames/hero_select/ui_frame_hero_select_{portrait,dossier,radar,thumbnail_strip,thumbnail,asc_button,asc_label,asc_mods}.png`. SCRUM-320 заменил только bottom `thumbnail_strip` на Carusel reference frame из `docs/design/references/carusel/`: live PNG `ui_frame_hero_select_thumbnail_strip.png` теперь 1536x255 RGBA, старый SCRUM-281 strip лежит в `build/cleanup_backup_hero_select_carousel_2026_06_14/`, pipeline `tools/build_hero_select_carousel_frame.py`, preview `docs/design/previews/hero_select_carousel_frame_contact.png`. В runtime эта нижняя рамка не 9-slice и не растягивается по одной оси: она рисуется цельным `TextureRect` в пропорциональном контейнере (`1024x170` at 720p, `1536x255` at 1080p, `2048x340` at 1440p). SCRUM-342 увеличил читаемость миниатюр без нарушения frame-rule; SCRUM-355 затем пересобрал live dossier + thumbnail strip более тонкими/спокойными вариантами через `tools/build_hero_select_thin_frames.py`, preview `docs/design/previews/hero_select_thin_frames_content_zones.png`, QA/handoff `build/qa/scrum355/hero_select_thin_frames_qa.md`, backup `build/qa/scrum355/hero_select_pre_scrum355_frame_assets.zip`. SCRUM-354 подключил строгие Design safe margins в runtime: dossier `Vector4(126, 160, 126, 172)` и thumbnail strip `Vector4(132, 62, 132, 62)`, причём карусельные отступы масштабируются от source `1536x255`, а не от 720p display `1024x170`. Фактические QA rects теперь показывают dossier content `299x280` и thumbnail row `848x88` внутри strict safe zones на 1280x720 с 2px tolerance для дробного масштабирования и 22px gap между frame’ами; 1600x900 и 2560x1440 также проходят safe-zone/no-overlap assertions. SCRUM-321 принял live `ui_frame_hero_select_portrait.png` как production heroframe-style ассет и перевел левую рамку портрета на такой же принцип: `HeroSelectPortraitPanel` сохраняет левую треть master layout, но внутренний `HeroSelectPortraitFrame` рисуется цельным `TextureRect` и масштабируется пропорционально (`249x394` / `423x669` / `596x944` на 720p/1080p/1440p). Портрет героя лежит только в content-zone с base margins `Vector4(128, 230, 128, 330)`; нижний самоцвет, верхний гребень и боковой металл остаются свободны. SCRUM-323 пересобрал live `ui_frame_hero_select_dossier.png` из DescriptionHS reference pack как `1120x1140` RGBA, pipeline `tools/build_hero_select_dossier_frame.py`, backup в `build/cleanup_backup_hero_select_dossier_2026_06_14/`, preview `docs/design/previews/hero_select_dossier_frame_content_zone.png`. В runtime центральное досье больше не `StyleBox`: `HeroSelectDossierPanel` центрирует цельный `HeroSelectDossierFrame` (`387x394`, `581x591`, `774x788` на 720p/1080p/1440p), а текст, Возвышение и кнопка лежат в `HeroSelectDossierContent` внутри strict zones. SCRUM-322 заменил live `ui_frame_hero_select_radar.png` на windrose compass frame из `docs/design/references/windrose/`: production PNG `1024x1024` RGBA, pipeline `tools/build_hero_select_windrose_frame.py`, backup в `build/cleanup_backup_hero_select_windrose_2026_06_14/`, preview `docs/design/previews/hero_select_windrose_radar_content_zone.png`. В runtime floating `HeroSelectRadarPanel` теперь квадратный whole-image layer (`390x390`, `585x585`, `780x780` на 720p/1080p/1440p). SCRUM-347 убрал старый `HeroStatRadarTitle`, центрировал `HeroStatRadar` в compass field и увеличил radius factor полигона `0.30 -> 0.36`; подписи подтянуты ближе, чтобы оставаться внутри safe frame. Остальные Hero Select frame assets подключены только в `HeroSelectScreen` через локальные `HERO_SELECT_FRAME_*` dictionaries, потому что требуют своих safe-area margins. QA screenshots/rect dump: `build/qa/scrum281/hero_select_1280x720.png`, `hero_select_1920x1080.png`, `hero_select_2560x1440.png`, `hero_select_capture_rects.md`; SCRUM-320 копии: `build/qa/scrum320/hero_select_carousel_*.png`; SCRUM-321 rect dump: `build/qa/scrum321/hero_select_portrait_rects.md`; SCRUM-323 rect dump: `build/qa/scrum323/hero_select_dossier_rects.md`; SCRUM-355 rect dump: `build/qa/scrum355/hero_select_thin_frames_runtime_rects.md`; SCRUM-354/SCRUM-322/SCRUM-347/SCRUM-342 rect dump lives at `build/qa/hero_select_radar_rects.md`.

SCRUM-356 подключил unified Hero Select frame в runtime: `assets/sprites/ui/frames/hero_select/ui_frame_hero_select_unified_panel.png` (`1536x1024` RGBA) теперь рисуется цельным proportional `TextureRect` как `HeroSelectUnifiedFrame` и объединяет portrait + description + bottom controls без 9-slice/one-axis stretch. `HeroSelectPortraitPanel`, `HeroSelectDossierPanel`, `AscensionSelectorRow` и `HeroSelectChooseButton` размещаются только в source-space safe zones из `docs/design/references/hero_select_unified_panel/scrum356_unified_panel_metadata.json`: portrait `Rect2(130,145,420,560)`, description `Rect2(610,145,786,500)`, bottom controls `Rect2(570,705,660,178)`. `AscensionMinusButton`/`AscensionPlusButton` используют compact `ui_frame_hero_select_asc_button_small.png`; на 720p delta-строка Возвышения скрывается, чтобы controls не заходили на орнамент, а на больших окнах остается внутри bottom safe-zone. Radar остается отдельным floating top-right `HeroSelectRadarPanel`, carousel — отдельным bottom strip.

SCRUM-798 (2026-07-01) established the current no-radar Hero Select sizing. The
live `HeroSelectScreen` remains `_build_character_select_v4()`: large rotating
portrait left, fixed eight colored stat bars right, Ascension and cyclic
carousel below. SCRUM-1064 supersedes only the dossier content: optional exact
trait first, then name, all three canonical weapons, deterministic top-3
`BASE_STATS` with values, and complete primary/secondary/weak relevance lists
from `ProgressionData.hero_select_dossier`. Free description and prose
strengths/weaknesses are no longer live. All text stays in the frame-safe
`HS4DossierScroll`; 1152×648/720p use the compact 2×4 stat lane and required
scroll, 1080p/2K retain one column, and live resize rebuilds this screen without
run/route reset. Accepted PixelLab shell is reused; plan/evidence:
`docs/design/mockups/scrum1064_hero_dossier/`.

SCRUM-951 gives those eight Hero Select characteristics stable, shared stat-ID
colors from `HeroSelectConstants.HERO_STAT_COLORS`; class changes update values
and fill lengths without tinting semantic identity. Name/value text, bar length
and concise tooltip remain alongside color. The 720p stats zone is 2×4 so all
localized names and numbers remain visible; 1080p/2K stay 1×8. Strength text
uses accessible `#E05B4C` while its bar retains canonical `#D84A3A`; other
labels use their canonical accent directly. PixelLab-first mockup/spec and
Metal evidence live under `docs/design/{mockups,previews}/scrum951_hero_stat_colors/`.

Historical SCRUM-980 (superseded by SCRUM-1063 below) moved the ascension
placement. Its then-live
`HS4AscensionFrame` is now a wide right-hand band between dossier and carousel:
the `-`/value/`+` stepper occupies its left content segment, while the exact
selected-level delta is untrimmed inside vertical
`HS4AscensionDescriptionScroll` on the right. The 1280×720 layout scrolls the
long delta inside the frame; 1920×1080 and 2560×1440 show it in full.
`HS4CarouselCounter` and `HS4ChooseButton` keep separate reserved zones, so no
ascension text/control overlaps the carousel, dossier, portrait, frame border or
CTA. Coverage: `tests/hero_select_scrum980_ascension_layout_test.gd` and
transient `build/qa/scrum980/`.

Historical SCRUM-1026 (also superseded by SCRUM-1063 below) hardened that layout against the longest valid selected-level
copy. At viewport heights from 1000 px, the right ascension band reserves 132 px
and grows upward only into the already scroll-safe dossier; its bottom edge,
carousel/counter, portrait, Choose button, art and content margins do not move.
All selectable levels 0..5 now fit without vertical overflow at 1920×1080 and
2560×1440. The compact 1280×720 band is 69 px: its real 59 px utility row stays
inside 5 px top/bottom frame content margins, while the full delta remains
reachable through real mouse/keyboard/gamepad scrolling with boundary focus
transfer. The focused gate enumerates every selectable level with
viewport-bounded pointer clicks, exact cumulative tooltips and hero-switch
scroll reset; geometry spec:
`docs/design/mockups/hero_select_black_minimal/scrum1026_ascension_level3_responsive_spec.md`.

SCRUM-1063 supersedes SCRUM-979's clamped carousel edges and the visible
SCRUM-980/1026 modifier lane. Carousel Previous/Next and Ascension `−`/`+` now
share one accepted textless PixelLab horizontal plate, identical geometry and
normal/hover/pressed/focus/disabled states. Each responsive control keeps the
former arrow height and uses exactly `2 ×` its former rounded width. The only
visible stepper copy is centered `Возвышение N`; cumulative modifiers remain in
the panel/value/button tooltips. Previous at the first window selects the last
hero in the final window, while Next at the final window selects the first hero;
pointer, keyboard and gamepad use the same refresh path for selection, window,
portrait, dossier, counter and Ascension. Compact 1152×648/1280×720 tiers keep
three complete slots by uniformly scaling cards to 116/132 px. UI Director
spec/provenance/previews: `docs/design/mockups/scrum1063_hero_carousel_wide_buttons/`
and `docs/design/references/scrum1063_hero_carousel_wide_buttons/`.

Historical SCRUM-952 added the first Hero Select reading hierarchy:
`Особенность`, `Плюсы`, `Минусы`. All 17 unique traits remain implemented
data entries with a concise `short_description` for selection/tooltips and a
detailed `description` for Codex. Hero Select reads the trait through
`ProgressionData.class_trait`, while CodexData projects the same record; class
copy is not duplicated per screen. SCRUM-1064 removes visible prose plus/minus
and consumes the same traits in its structured dossier. SCRUM-1046
adds a local scroll-first input contract: keyboard/D-pad/left-stick vertical
actions and PageUp/PageDown move real compact overflow while focus stays in the
dossier, then transfer to Back/Choose only at the respective boundary; changing
the hero still resets the lane to its first line. No visual geometry changed.

SCRUM-263/264 остаются правилом размеров: стандартные action-кнопки 104px высотой через `_make_button()` и `_set_action_button_size()`, main menu использует 380x104, wide action capped до 560px, pause menu 280x60, rebind/dropdown-style controls 420x62, compact utility 54x42 и FAB 50x50. Text-heavy choices используют паттерн «инфо-рамка над + короткая стандартная кнопка под». Route nodes, shop item hit areas, hero thumbnails, reward/weapon cards остаются карточками/hit areas без heavy action button frame. SCRUM-281 добавляет локальное исключение: `HeroSelectChooseButton` использует compact `hero_confirm` 260x72, чтобы screen-specific herouiframe layout оставался внутри 1280x720. Runtime smoke пишет фактический dump размеров в `build/qa/scrum450_minimal_metal_buttons/minimal_metal_button_sizes.md`.

Contextual UI frame kits removed from runtime `assets/sprites/ui/frames/contextual/` by SCRUM-418 after no live references were found; historical backup lives under `build/qa/scrum418/removed_assets_backup/` and active UI direction remains Red & Gold Dragon + Ornate Dark canon.

Settings controls получили системные fantasy assets из `assets/sprites/ui/icons/system/`: checkbox checked/unchecked, slider track/grabber, arrows/back/settings/close icons. Иконки зарегистрированы в `scripts/ui_icon_registry.gd` как `system_*`. SCRUM-396 подключил design-ready 3-slot tab switcher frame `assets/sprites/ui/frames/settings/ui_frame_settings_tab_switcher_3slot.png` к экрану настроек как proportional strip с runtime hit areas внутри recorded safe rects и без obsolete fourth slot.

SCRUM-332 prepared a Design-ready economy node UI kit for shop, attribute shop,
rest/campfire, upgrade and event screens. SCRUM-406 wires it into runtime:
attribute shop, rest, upgrade and event choices use the economy panel plus
choice-card frame variants inside the authored safe zones, while shop keeps
compact square wall item slots and uses only the economy price badge so the
merchant wall layout remains readable. Mockup/spec:
`docs/design/mockups/scrum332_shop_economy/`; runtime-ready frame assets:
`assets/sprites/ui/frames/economy/`; preview:
`docs/design/previews/scrum332_shop_economy_frame_kit_contact.png`; runtime QA
dump: `build/qa/scrum332/economy_ui_no_overlap_matrix.md`. The irregular dragon
panel still must not use its full bounding box as content space.

SCRUM-437 makes the 0.1.6 wide economy choice-card runtime live for rest,
upgrade, event and Attribute Shop choices. The old narrow option-card paths are
replaced by `ui_frame_economy_choice_card_wide.png` and
`ui_frame_economy_choice_card_wide_hover.png` (`960x640`, RGBA transparent),
with source size `Vector2(960,640)`, content margins
`Vector4(132,118,132,128)` and safe rect `Rect2(132,118,696,394)` carried as
runtime metadata. Choice rows use 360/420/480px responsive targets at
1280/1920/2560 widths, with a compact 1152px matrix fallback; Attribute Shop
cards get extra vertical room for icon/title/interpretation/price copy. QA dumps
live under `build/qa/scrum437/`. Spec:
`docs/design/mockups/scrum437_wide_economy_choice_card/spec.md`.

## Combat VFX

Активные атаки оружия используют raster/fantasy VFX из `assets/sprites/effects/` через `scripts/attack_vfx.gd`, `scripts/class_weapon.gd` и melee-пути `scripts/berserk_weapon.gd`. Persistent pools больше не выглядят как программные круги: `poison_pool.png`, `spark_pool.png` и `briar_pool.png` подключены к Химику/Друиду как Sprite2D с мягкой пульсацией и fade-out, при этом урон, радиус и интервалы тиков остаются в data-driven weapon config.

SCRUM-455 изменил runtime placement экипированного оружия игрока: `VisualRoot/WeaponSocket` теперь стоит на орбите 104px по направлению активной атаки/aim, а не в центре тела/старом hand mount. Сокет и `WeaponVisual` рендерятся за телом героя, поэтому held-оружие визуально облетает персонажа и не закрывает playable sprite; урон, cooldown, hit shapes, VFX spawn и targeting не менялись. QA evidence: `build/qa/scrum455/weapon_orbit_runtime_dump.md`; focused gate: `tests/weapon_orbit_smoke_test.gd`.

SCRUM-457 приглушил attack-VFX на общем runtime уровне: `AttackVfx._calmed_color()` снижает saturation/brightness/additive alpha, beam visuals уже, trails реже, dust/music-note clutter меньше. Зоны урона остаются читаемыми и совпадают с прежними gameplay радиусами/коридорами: hit queries, cooldowns, timing и targeting не менялись. QA evidence: `build/qa/scrum457/attack_vfx_calmness_dump.md`; smoke gate: `tests/attack_vfx_smoke_test.gd`.

SCRUM-261 обновил enemy/boss skill VFX под runtime mechanics SCRUM-259. `HazardVfx` теперь выбирает отдельные D&D/painterly PNG по node name (`BossGravityWell`, `BossVampiricBite`, `BossRiftZone`, `BroodWebZone`, `AshEmberZone`, `BossMoltenArmorPulse`) и даёт отдельные helpers для shield block, summon portal, reflect-thorns aura и command aura. Это визуальная маршрутизация: gameplay timing, damage, node names и balance не менялись. Preview-лист: `docs/design/previews/scrum261_elite_boss_vfx_contact.png`.

SCRUM-258 добавил per-weapon visual signature layer для всех 51 оружий ростера 0.1.5: `assets/sprites/effects/vfx_weapon_<weapon_id>.png`. `ClassWeapon` перед исполнением текущего attack mode вызывает `AttackVfx.weapon_signature()` и размещает короткую полупрозрачную D&D/painterly пластину по `weapon_id` в зоне атаки/цели/ауры. SCRUM-335 расширил это покрытие на `BerserkWeapon`, поэтому `sword`, `axe`, `hammer`, `long_spear`, `tower_shield` и `holy_flail` тоже показывают dedicated `vfx_weapon_*` signature поверх своих slash/slam/strip VFX. Это только визуальный слой: урон, радиусы, формулы, targeting, cooldowns, delay и status mechanics остаются из Back-end SCRUM-256/251/254/245. Preview-листы: `docs/design/previews/scrum258_unique_weapon_vfx_contact.png`, `docs/design/previews/scrum258_unique_weapon_vfx_readability.png`.

SCRUM-924 дополняет статичную signature-пластину `holy_flail` отдельным
PixelLab-first runtime VFX расширяющейся спирали. Семь кадровых шагов следуют
live-окнам SCRUM-923 (`0.085с`, radius `22%→100%`, полный `235px`), поэтому
цепь/кистень читаются как постепенный center-out «vroom-vroom» оборот, а не как
мгновенный полный круг. Animator-bridge изолирован в Holy Flail scene/script;
shared damage, targeting, radius, dedup и balance не менялись. Evidence/contact:
`docs/design/references/scrum924_holy_flail_spiral_vfx/` и
`docs/design/previews/scrum924_holy_flail_spiral_vfx_contact.png`; actual Godot
inner/mid/outer capture: `docs/design/previews/scrum924_holy_flail_spiral_vfx_runtime.png`.

SCRUM-730 перерисовал `vfx_weapon_biologist_sample_injector.png` для Инъектора Образцов через OpenAI Images override: эффект теперь читается как точная sample-dart injection line с двумя biochemical analysis echoes у ткани цели и полупрозрачным ghost-силуэтом самого инъектора. Runtime path/API не менялись; mechanics, damage, cooldowns, targeting и attack shapes остаются прежними. Evidence: `docs/design/references/weapon_attack_animations/biologist_sample_injector/manifest.json`, preview `docs/design/previews/weapon_attack_animations/biologist_sample_injector_contact.png`.

SCRUM-741 перерисовал `vfx_weapon_elementalist_meteor_core.png` для Ядра Метеора через PixelLab MCP override: эффект теперь читается как круг отложенного meteor impact с вторичными shard-burst маркерами рядом и полупрозрачным ghost-силуэтом самого meteor core поверх VFX. Runtime path/API не менялись; mechanics, damage, cooldowns, targeting, задержка удара и secondary shard behavior остаются прежними. Evidence: `docs/design/references/weapon_attack_animations/elementalist_meteor_core/manifest.json`, preview `docs/design/previews/weapon_attack_animations/elementalist_meteor_core_contact.png`.

SCRUM-335 добавил runtime feedback в `scripts/enemy_projectile.gd`: обычный magic projectile врагов/боссов сохраняет свой canonical sprite, но получает textured `beam_strip.png` trail во время полета и `impact_flash.png` + `impact_ring.png` при попадании по игроку. Это не меняет lifetime, collision mask, one-hit guard, damage или speed.

SCRUM-337 заменил весь активный raster art pack для attack VFX без изменения runtime API: 83 `assets/sprites/effects/*.png` и 2 `assets/sprites/projectiles/*.png` пересобраны через `fantasydisk-asset-generator` source sheets, очищены под alpha и экспортированы с теми же именами/размерами. В бою это выглядит как более объёмные D&D/dark-fantasy магические вспышки, слэши, зоны, порталы, лужи и weapon signature plates; mechanics, damage, delays, targeting и balance не менялись. Preview-листы: `docs/design/previews/scrum337_attack_vfx_core_contact.png`, `docs/design/previews/scrum337_attack_vfx_weapon_contact.png`.

SCRUM-277 добавил weapon integrity gate для всего ростера: `tests/weapon_integrity_test.gd` проходит 17 классов x 3 оружия, проверяет `weapon_ids`, `scene_path`, scene `weapon_id`, attack-mode/shape marker, отсутствие коллизий с пассивками/магазином/level-up rewards и фактический `WeaponVisual` после `Player.configure_character()`. Оставшиеся proxy-текстуры новых классов заменены на canonical weapon PNG, включая `priest_chime -> priest_chime.png` вместо `sound_amp.png`.

## Препятствия

Ямы и колонны отключены в текущей версии: они не генерируются, не создают collision blockers и не участвуют в pathing. На арене активны только физические границы карты. Препятствия могут вернуться позже после отдельного визуального и gameplay-редизайна.

## Маршрутная Карта

Маршрутная карта горизонтальная: SCRUM-1057/1079 разворачивает step-колонки
слева направо, со start слева и boss справа; ветки одного step разнесены по Y
без пересечения hitbox-ов. Акт состоит из 8 рядов активностей и финального ряда
босса (`ROUTE_STEPS_TO_BOSS = 8`). Первые два selectable ряда всегда состоят только из `battle`
узлов; дальнейшие пулы типов по-прежнему зависят от фазы акта.

SCRUM-1089 делает горизонтальную карту full-fit: все 9 колонок акта сразу
помещаются в видимую область на 1152×648, 1280×720, 1600×900, 1920×1080 и
2560×1440. Горизонтальный scrollbar и pan больше не нужны и отключены вместе с
vertical scroll; legacy `RouteMapScroll`/`VerticalRouteMap` сохранены для input,
focus и tooling compatibility. Шапка поднята в реальную пустую центральную зону
gold shell, title/progress остаётся полным, а menu-run HUD HP/XP/ULT/gold имеет
ровно 2× прежний видимый размер. На компактных tiers title и HUD стоят друг над
другом, на 1920/2560 — рядом. Узлы используют большую часть доступной высоты и
ширины, но остаются внутри documented ornament reserve. Source/spec/runtime
evidence: `docs/design/{mockups,references,previews}/scrum1089_route_map_full_fit_hud2x/`.

Карта открывается отдельным full-screen экраном. Legacy-имя canvas
`VerticalRouteMap` сохранено для tooling compatibility, но metadata публикует
`route_orientation=horizontal`. Canvas по высоте равен authored node viewport, а по
ширине теперь равен authored node viewport и распределяет фиксированные девять
колонок без overflow. `RouteMapScroll` отключает обе оси; оба scrollbar скрыты,
`scroll_horizontal=0`, `scroll_vertical=0`.
SCRUM-1086 удерживает status второй строки шапки в той же safe-zone:
на 1152/1280 показана компактная, но полная форма без ellipsis; на 1600+
текст остаётся прежним.

При open/return/live resize UI сохраняет все колонки в видимой области и
удерживает scroll offsets на нуле. Drag и wheel/trackpad больше не двигают
canvas; при этом движение мыши выше drag threshold по-прежнему подавляет клик
по узлу, поэтому encounter не стартует случайно.

Линии маршрута тонкие и декоративные. Они игнорируют мышь, как и иконки внутри узлов, поэтому hover tooltip и клики по узлам работают после скролла/pan. На route screen компактный HP/XP/money HUD находится в том же UI-слое, чтобы отдельный fullscreen HUD CanvasLayer не перекрывал карту и не перехватывал клики.

Debug-режим карты: клавиша `F12` переключает `route_debug_free_pick`. При включении любой узел любого ряда становится доступным для клика в любой момент; выбор узла из другого ряда перематывает `route_stage` к этому ряду. В шапке карты показывается красный индикатор «DEBUG: свободный выбор». Режим выключен по умолчанию и не сохраняется между запусками.

Типы узлов:

| Тип | Назначение |
| --- | --- |
| `battle` | Обычный бой |
| `elite_battle` | Бой с элитным врагом (победа открывает окно награды: выбор 1 из 3 артефактов крупными карточками по центру экрана, иконка 112px + тир цветом + эффект + классовая интерпретация, выбор обязателен, навигация мышью/клавиатурой/геймпадом; панель центрируется через full-rect `CenterContainer` и проверяется фактическим `global_rect` на 1280x720/1469x908/2560x1440; показывается до экрана докачки) |
| `shop` | Магазин |
| `event` | Случайное событие |
| `rest` | Костер / отдых |
| `boss` | Финальный босс |

### Случайные События

Event-node открывает один data-driven сценарий из `scripts/event_data.gd`. В пуле 28 сценариев: `sudden_fork`, `wandering_bard`, `cursed_altar`, `road_ambush`, `old_well`, `wounded_mercenary`, `goblin_lottery`, `hot_spring`, `mirror_phantom`, `stone_guardian`, `heroes_graveyard`, `fallen_star`, `training_dummies`, `warden_gate_trial`, `abandoned_forge`, `merchant_caravan`, `whispering_grove`, `collapsing_mineshaft`, `crystal_geode_vault`, `starlit_observatory`, `sunken_caravan`, `war_drums_camp`, `twin_offering_shrine`, `oracle_crossroads`, `runed_menhir`, `gilded_gambler`, `tidewater_grotto`, `wandering_emberwisp`.

Правила:
- один и тот же event ID не повторяется в рамках акта, пока пул не исчерпан;
- каждый сценарий имеет историю и 2-3 выбора;
- честные сделки заранее показывают цену HP/золота/стата;
- часть сценариев класс-реактивны: исход ветвится по «архетипному» атрибуту героя через литеральные stat-checks (endurance=танк, intelligence=маг, leadership=призыватель). «Свой» класс проходит профильную проверку легче и/или получает усиленный профильный бонус, мискласс — рискует. Сейчас класс-реактивны `warden_gate_trial` (3 архетипные створки), `abandoned_forge` (профильная заготовка танка/мага), `oracle_crossroads` (3 тропы: тело/разум/воля), `runed_menhir` (сила берсерка vs знание учёного);
- hidden-risk варианты помечены как риск и могут дать артефакт, хлам или бой;
- attribute checks используют текущие базовые характеристики игрока (`strength`, `agility`, `intelligence`, `perception`, `knowledge`, `endurance`, `leadership`);
- платные варианты (`cost_money`) показывают stage-scaled цену в золоте, отключаются при недостатке денег с tooltip-пояснением и дополнительно блокируются в Back-end применении, чтобы прямой вызов не мог бесплатно продвинуть маршрут;
- боевые исходы стартуют обычный или элитный бой с временным `pending_event_combat` payload: enemy health multiplier, reward multiplier и optional post-combat reward очищаются после боя;
- небоевые исходы применяются к run snapshot через `stats`, `mods`, `money`, `heal_percent`, `health_percent_cost`, `random_artifact`.

Узлы имеют:
- название;
- цвет;
- рамку;
- PNG-иконку;
- tooltip при наведении;
- связи с узлами следующего ряда.

Иконки карты:

| Узел | Ассет |
| --- | --- |
| Обычный бой | `assets/sprites/map_icons/map_battle_skull.png` |
| Элитный бой | `assets/sprites/map_icons/map_elite_skull_bones.png` |
| Магазин | `assets/sprites/map_icons/map_shop_tent.png` |
| Событие | `assets/sprites/map_icons/map_event_question.png` |
| Сундук / артефакт | `assets/sprites/map_icons/map_chest_artifact.png` |
| Костер | `assets/sprites/map_icons/map_rest_campfire.png` |
| Rift Warden | `assets/sprites/map_icons/map_boss_rift_warden.png` |
| Disk Devourer | `assets/sprites/map_icons/map_boss_disk_devourer.png` |

SCRUM-537 добавляет runtime `chest` route node: на каждой карте акта ровно один
сундук размещается в lower-middle non-boss row (при 10 activity rows это row
index `4`, пятый selectable ряд), не заменяет два гарантированных shop nodes и
не попадает в первые два battle-only ряда. Открытие сундука использует
существующий выбор 1 из 3 артефактов с depth-weighting
`ProgressionData.elite_artifact_choices(route_scaling_stage(), 3, selected_character_id)`;
после выбора артефакт применяется к run snapshot, route node помечается
completed, `route_stage` продвигается и autosave сохраняет checkpoint карты.

## Игрок

Игрок реализован как `CharacterBody2D`.

Ключевые свойства:
- движение по WASD / стрелкам;
- ручное управление перемещением;
- автоматические атаки оружия;
- сбор опыта и денег;
- уровень и награды;
- урон, уворот, защита, invulnerability window;
- визуальная анимация движения;
- socket для оружия;
- возможность проходить сквозь монстров.

Коллизия игрока не должна физически цепляться за enemy layers. Монстры наносят контактный урон отдельной атакой с задержкой. SCRUM-886 закрывает боевую мертвую зону для overlap/contact случаев: если монстр уже стоит в позиции игрока, melee shapes Берсерка и class weapon line/corridor/wave helpers все равно считают его валидной целью в малой 40px rescue-зоне. Это не меняет speed/collision/pathfinding врагов и не трогает численные weapon budgets.

### Выживаемость и сценарные проверки

Текущая выживаемость проверяется двумя headless harness-слоями:
- `tools/survivability_harness.gd` + `tests/survivability_scenario_test.gd` моделируют синтетические fragile/steady/sturdy/tank профили, проверяют рост TTD по стойкости, вклад absorb/defense/dodge/regen и якорят формулу к реальному `Player.take_damage`.
- `tools/survivability_scenarios.gd` строит roster projection по текущим классам и first-weapon конфигам, пишет `build/survivability_scenarios_report.md`.

Исторический замер SCRUM-190 дал 6 ok, 62 low, 0 high по contact swarm, shooter crossfire, elite burst и boss phase hazard. После него SCRUM-255 изменил формулы выживаемости: регенерация/вампиризм стали поддержкой с cap, а defense/dodge/absorb получили diminishing returns. Актуальное состояние проверяется `tests/global_survivability_balance_smoke_test.gd`, `tools/survivability_harness.gd` и `tests/survivability_scenario_test.gd`; старый SCRUM-190 результат больше не считается текущим балансом.

### Target queries

Горячие weapon/player target scans используют `scripts/combat_target_query.gd`. Helper кеширует список `enemies` на один frame и дает единые методы `nearest`, `nearest_many`, `in_radius`, `has_in_radius`, `in_corridor` и `in_segment`; line helpers поддерживают optional `back_allowance` для weapon starts, смещенных вперед от игрока. Group membership `enemies` сохранен как compatibility contract для спавна, cleanup и старых систем. Текущая интеграция покрывает `ClassWeapon`, `BerserkWeapon`, player ultimates/secondary effects, `AllyMinion` и `SummonerWeapon`; тесты `tests/combat_target_query_cache_test.gd` и `tests/contact_stuck_attack_deadzone_test.gd` проверяют геометрию helper-ов, отсутствие rebuild в том же frame и contact-stuck hit regression.

## Персонажи

Первые три игровых персонажа используют polished stylized cartoon fantasy full hero sprites без квадратных placeholder-форм и без вида минимальных технических болванок. Расширенный ростер 0.1.4 доведен до 17 классов; новые классы прошли Design art-review как polished cartoon dark fantasy full-art. SCRUM-168 добавил Back-end-класс `soldier`; Design pass 2026-06-13 подготовил финальные `soldier.png`, `soldier_rifle.png`, `soldier_grenade.png` и `soldier_bayonet.png`, а Animator pass 2026-06-13 добавил Soldier cutout rig, manifest/profile и weapon pose hooks. В бою `scripts/cutout_rig_2d.gd` собирает видимую фигуру из нарезанных кусков того же polished-арта (torso, arm_l/arm_r, leg_l/leg_r): в покое сборка пиксельно совпадает с исходным PNG, в движении конечности реально двигаются. Нарезка генерируется инструментом `tools/slice_rig_cutouts.py` в `assets/sprites/characters/cutout/`, метаданные частей — в сгенерированном `scripts/sliced_rig_manifest.gd`. Source PNG в `assets/sprites/characters/` используются меню и выбором персонажа и являются исходником нарезки. Берсерк остается без оружия в базовом спрайте, а оружие крепится отдельно через `WeaponSocket`.

SCRUM-899/SCRUM-1006 (0.2.1): Гитарист — магический кастер с деплой-геймплеем.
Электрогитара = `riff_strip` (узкая передняя полоса постоянной ширины, частые
низко-средние магические хиты, без pierce-капа), бас = большое кольцо частых слабых
магических тиков с сильным knockback под кайт, усилитель = ядро саммонер-петли
(амп-турели; Лидерство = число и uptime ампов, summon_amount = темп пульса,
attack_speed = каденция установки, урон пульса — magic_damage владельца). Класс-trait
«Разогрев»: +2 п.п./сек магического урона без полученных ударов, кап +20%, сброс при
квалифицированном ударе. Подробности: `docs/design/systems/characters_weapons.md`,
`docs/design/class_traits_registry.md`; гейт — `tests/guitarist_kit_test.gd`.

SCRUM-298 добавил Design standard для следующей волны playable full-frame sheets:
`docs/design/references/character_animation_style_sheet_0_1_5.md`. Будущие
redraw-задачи используют unarmed `assets/sprites/characters/<class_id>_sheet.png`,
cell `384x384`, минимум 5 `walk` + 5 `attack_primary` кадров, preferred
`1920x1152` sheet с дополнительной строкой `idle`. Back-end runtime уже
подготовлен: `Player._character_sheet_sprite_frames()` проверяет этот путь,
строит `idle`/`walk`/`attack_primary` и alias `attack`, а при отсутствии листа
сохраняет старый cutout/static fallback без краша. Motion quality и финальные
листы остаются за Animator/Design задачами.

SCRUM-411 исправил runtime-слой playable full-frame анимаций: если для класса
есть `assets/sprites/characters/<class_id>_spriteframes.tres` или
`<class_id>_sheet.png`, в бою видимым слоем становится
`Player/VisualRoot/Body` (`AnimatedSprite2D`) с full-frame `idle`/`walk`/
`attack`, а `RigRoot` скрыт и больше не перекрывает новый redraw. Старый cutout
rig сохраняется только как невидимый compatibility/socket/action-event anchor;
для классов без full-frame кадров fallback остаётся прежним: `Body` скрыт,
cutout `RigRoot` видим.
SCRUM-417 увеличил playable combat visual scale до `Vector2(0.36, 0.36)` для
full-frame `Body` и cutout fallback rig (+28.6% от исходного `0.28`), не меняя
player collision radius, gameplay ranges, pivot, flip или weapon socket.
QA dump: `build/qa/scrum417/combat_character_size_runtime_dump.md`.
SCRUM-518 (увеличение арены) ужал персонажа на −15%: рантайм-визуал
`PLAYER_COMBAT_VISUAL_SCALE` `0.5 → 0.425` (тянет `Body` и скелет/cutout риги
через `BASE_SPRITE_SCALE`) и согласованно коллизию `CircleShape2D radius`
`10.5 → 8.9` — sprite и collision уменьшены на один процент, без рассинхрона.
SCRUM-823 снова увеличил только боевую визуальную читаемость playable characters:
`PLAYER_COMBAT_VISUAL_SCALE` теперь `0.64` (примерно x1.5 от `0.425`) для
`Body`, skeletal и cutout fallback paths. `CircleShape2D radius` остаётся `8.9`,
поэтому hurtbox, контактное поведение, дальности, pivot, flip и `WeaponSocket`
не менялись.

FAN-1071 исправляет регрессию feet-origin после перехода ростера на разные
PixelLab full-frame packs. Live `Player/VisualRoot/Body` больше не использует
`foot_y` старого static/cutout-арта как источник позиции для full-frame кадра:
нижняя видимая alpha-граница каждой active idle/move/walk texture кэшируется и
при `animation_changed`/`frame_changed` сажается на локальный gameplay origin,
где уже находится `GroundCircle` и область получения урона. Поэтому Инженер,
Гитарист и остальные 15 героев стоят на площадке без вертикального дрейфа между
кадрами. Это visual-only transform: world position, collision radius `8.9`,
damage/targeting ranges, y-sort и damage geometry не изменены. Canonical idle
lift остаётся стабильным ориентиром камеры, weapon orbit и feedback.

SCRUM-412 очистил полный playable full-frame runtime set от белой/checkerboard
подложки: все `255` PNG в
`assets/sprites/characters/full_frame/<class>/` для 17 классов теперь имеют
настоящую прозрачную альфу внутри `384x384` canvas, без изменения путей,
`<class_id>_spriteframes.tres`, state names или timings. QA на тёмном фоне и
пиксельная проверка: `build/qa/scrum412_character_alpha/`. Будущие сборки
листов должны проходить через `tools/build_character_sheet.py`, где включён
edge-connected alpha-clean/de-halo из
`tools/alpha_clean_full_frame_characters.py`.

SCRUM-422 задаёт опорный Design source-anchor для новой волны 0.1.6 character
redraw v2: яркий/эпичный, class-readable стиль, прозрачный RGBA, `512x512`
cells, bottom-center pivot `(256, 470)`, только `idle` + `move/walk` строки
без attack-анимации, целевая высота тела `360-380 px` в ячейке и runtime scale
`0.39-0.40`, чтобы герой читался примерно в 2 раза выше среднего обычного
монстра на экране. Принятый exemplar: Berserk source under
`docs/design/references/characters_v2/bright_epic_anchor/`, asset-side source
copy `assets/sprites/characters/v2/berserk/berserk_v2_idle_source.png`. Это
пока не заменяет runtime SpriteFrames; Animator подключает idle/move после
принятия per-class source.

SCRUM-420 подготовил отдельный per-class Berserk v2 Design-source handoff:
`docs/design/references/characters_v2/berserk/berserk_v2_source_clean.png`,
`berserk_v2_idle_cell_512.png`, `berserk_v2_sheet_source_handoff.png`,
`berserk_v2_design_handoff.md` и QA report
`build/qa/scrum420_berserk_v2/scrum420_berserk_v2_alpha_size_report.json`.
Персонаж яркий/эпичный, без оружия в руках, с battle paint/fur/rage aura,
прозрачный RGBA, visible height `376 px` в `512x512` cell и pivot `[256,470]`.
Animator pass подключил live `assets/sprites/characters/berserk_spriteframes.tres`
к v2 `idle` / `walk` / `move` 5-frame loops, derived from the accepted source,
with runtime frames under `assets/sprites/characters/full_frame/berserk/` and a
48px-gutter source sheet at
`assets/sprites/characters/v2/berserk/berserk_v2_anim_sheet.png`. Previous live
frames are backed up under `docs/design/backups/scrum420_berserk_v2_pre_anim/`.
Attack animation is intentionally absent for this v2 row; animation and runtime
smoke pass.

SCRUM-461 (2026-06-17) replaced the live Berserk full-frame runtime resource
with the accepted SCRUM-456 cartoon/anime anchor. `assets/sprites/characters/berserk_spriteframes.tres`
still exposes only `idle`, `walk`, and `move`, but now uses 5-frame `512x512`
transparent runtime PNGs sliced from
`docs/design/references/chars_cartoon/berserk_cartoon_anchor_sheet_source_handoff.png`
with pivot `[256,470]`, idle at 7fps and walk/move at 9fps. Previous live frames
are backed up under `docs/design/backups/scrum461_berserk_cartoon_pre_anim/`.
Attack animation remains intentionally absent for this cartoon/anime anchor.

2026-07-01 SCRUM-703 PixelLab Berserk redraw replaces the previous tiny
PixelLab live pack with a new unarmed v3 character
`8486ce45-f749-4c63-9a6d-f0477d619c2d`. PixelLab `252x252` source rotations,
movement frames, `manifest.json`, `pixellab_metadata.json`, and
`alpha_bbox_report.json` are stored under
`assets/sprites/characters/pixellab/berserk/`; normalized runtime frames are
transparent `512x512` PNGs under
`assets/sprites/characters/full_frame/berserk_pixellab/`. The runtime alpha-bbox
height is fixed at `245 px` for all 8 idle poses and all 48 movement frames
(primary south idle bbox `217x245`), satisfying the `240..250 px` contract with
no frame below `230 px` or above `260 px`. `assets/sprites/characters/berserk_spriteframes.tres`
continues to expose `idle_<direction>` plus 6-frame looping `move_<direction>` /
`walk_<direction>` for south/east/north/west and diagonals; Hero Select v4 keeps
cycling the same directional rows clockwise in the portrait safe zone. The
north-west move direction uses a PixelLab v3 custom replacement after the first
template pass produced hammer-like props; the final accepted pack is
empty-handed. Previous live frames are backed up under
`docs/design/backups/scrum703_berserk_pixellab_pre_redraw_2026-06-30/`. Body
attack animation remains disabled/absent by current weapon-owned combat visual
scope.

2026-07-01 SCRUM-705 supersedes the SCRUM-425 Doctor art pack with a fresh
PixelLab plague-doctor full redraw at the 240-250 px runtime scale. PixelLab
character `3e0a2b30-308e-48a8-a5a6-bb28a5038ca9` (v3, `252x252` source canvas)
source idle/move frames and `manifest.json` are stored under
`assets/sprites/characters/pixellab/doctor/`, then normalized into transparent
`512x512` runtime frames under
`assets/sprites/characters/full_frame/doctor_pixellab/`. All 8 idle directions
and 6-frame looping `move_<direction>` / `walk_<direction>` rows keep a 244 px
visible alpha height, verified by
`docs/design/previews/scrum705_doctor_pixellab_240_bbox_report.md`; the contact
sheet is `docs/design/previews/scrum705_doctor_pixellab_240_contact.png`. The
base body has empty hands with no baked potion, syringe, saw or held prop, so
those stay weapon-owned visuals. `scripts/progression_data_characters.gd` doctor
`sprite_path` still points at `full_frame/doctor_pixellab/doctor_idle_south.png`;
the generic `scripts/player.gd` directional resolver and `scripts/ui_screens.gd`
Hero Select clockwise rotation pick up the directional rows automatically.
Legacy SCRUM-425 and older full-frame assets remain only as backup/history under
`docs/design/backups/scrum705_doctor_pixellab_240_pre_redraw/`,
`assets/sprites/characters/full_frame/doctor/`, and `doctor.png`.

2026-07-01 SCRUM-428 promotes Engineer to the live PixelLab directional runtime
contract using existing source character `c5bd9766-e7de-4316-ace6-e687c951e621`
(`248x248`, low top-down). Source idle rotations, movement frames and
`manifest.json` are stored under `assets/sprites/characters/pixellab/engineer/`,
then normalized into transparent `512x512` runtime frames under
`assets/sprites/characters/full_frame/engineer_pixellab/`. The rebuilt
`assets/sprites/characters/engineer_spriteframes.tres` exposes 8 static
`idle_<direction>` rows and 6-frame `move_<direction>` / `walk_<direction>` rows;
the generic fallbacks use the south row, `sprite_path` points at
`engineer_idle_south.png`, and Hero Select rotates the same directional frames.
Legacy `assets/sprites/characters/full_frame/engineer/`, `engineer.png` and
cutout pieces remain fallback/history; pre-runtime SpriteFrames/full-frame files
are backed up under `docs/design/backups/scrum428_engineer_pixellab_pre_runtime/`.

2026-07-01 SCRUM-433 promotes Sniper to the live PixelLab directional runtime
contract using existing source character `74c4f7db-ed7f-4b6a-b9b3-bc18e417563c`
(`248x248`, low top-down). Source idle rotations, movement frames and
`manifest.json` are stored under `assets/sprites/characters/pixellab/sniper/`,
then normalized into transparent `512x512` runtime frames under
`assets/sprites/characters/full_frame/sniper_pixellab/`. The rebuilt
`assets/sprites/characters/sniper_spriteframes.tres` exposes 8 static
`idle_<direction>` rows and 6-frame `move_<direction>` / `walk_<direction>` rows;
the generic fallbacks use the south row, `sprite_path` points at
`sniper_idle_south.png`, and Hero Select rotates the same directional frames.
Legacy `assets/sprites/characters/full_frame/sniper/`, `sniper.png`,
`sniper_sheet.png` and cutout pieces remain fallback/history.

2026-07-01 SCRUM-434/SCRUM-800/SCRUM-801/SCRUM-802 promote Soldier, Thief,
Elementalist and Robot to the same live PixelLab directional runtime contract.
Accepted PixelLab character IDs are Soldier
`72b487d3-feea-4012-b39f-b59ba24f7f11`, Thief
`02e507dc-b1fa-4ef5-b6eb-e5ac97fffe9f`, Elementalist
`7a334fc4-fe8e-4dcd-b05a-3f6f6d3fdc6f`, and Robot
`37c6ccf2-ab40-4c89-83a3-db8365f85257`. Source idle rotations, movement frames
and `manifest.json` live under
`assets/sprites/characters/pixellab/{soldier,thief,elementalist,robot}/`;
normalized transparent `512x512` runtime frames live under
`assets/sprites/characters/full_frame/{soldier,thief,elementalist,robot}_pixellab/`.
The rebuilt `*_spriteframes.tres` resources expose generic `idle`/`move`/`walk`
fallbacks plus all 8 directional `idle_*`, 6-frame `move_*`, and 6-frame
`walk_*` rows. `scripts/progression_data_characters.gd` now points each class
`sprite_path` at its PixelLab `*_idle_south.png`, so Hero Select, carousel,
Codex, level-up portraits and runtime movement use the same live directional
pack. Legacy full-frame/cutout/v2 assets remain fallback/history only.

2026-07-01 SCRUM-803 promotes Assassin to the live PixelLab directional runtime
contract using accepted empty-open-hands source character
`ec73da27-b704-4336-9275-74c8e3e578df` (`252x252`, low top-down). Source idle
rotations, movement frames and `manifest.json` are stored under
`assets/sprites/characters/pixellab/assassin/`, then normalized into transparent
`512x512` runtime frames under
`assets/sprites/characters/full_frame/assassin_pixellab/`. The rebuilt
`assets/sprites/characters/assassin_spriteframes.tres` exposes 8 static
`idle_<direction>` rows and 6-frame `move_<direction>` / `walk_<direction>` rows;
the generic fallbacks use the south row, `sprite_path` points at
`assassin_idle_south.png`, and Hero Select rotates the same directional frames.
Chakrams, shadow daggers and venom wire remain weapon-owned visuals. PixelLab
candidate `cdee7e9a-1d04-430e-8fc9-60fafc2cd4a8` was rejected/deleted before
import because it baked a held blade. Legacy
`assets/sprites/characters/full_frame/assassin/`, `assassin.png`,
`assassin_sheet.png` and cutout pieces remain fallback/history.

2026-07-01 SCRUM-804 promotes Ranger to the live PixelLab directional runtime
contract using new empty-handed source character
`1646d83c-f570-4bdd-9065-cb1b46bf13f7` (`240x240`, low top-down). Source idle
rotations, movement frames, `manifest.json`, and `pixellab_metadata.json` are
stored under `assets/sprites/characters/pixellab/ranger/`, then normalized into
transparent `512x512` runtime frames under
`assets/sprites/characters/full_frame/ranger_pixellab/`. The rebuilt
`assets/sprites/characters/ranger_spriteframes.tres` exposes 8 static
`idle_<direction>` rows and 6-frame `move_<direction>` / `walk_<direction>` rows;
the generic fallbacks use the south row, `sprite_path` points at
`ranger_idle_south.png`, and Hero Select rotates the same directional frames.
The base body has no baked bow, crossbow, quiver, trap, projectile or UI frame,
so those remain weapon-owned visuals. Legacy `assets/sprites/characters/full_frame/ranger/`,
`ranger.png`, `ranger_sheet.png` and cutout pieces remain fallback/history.

2026-06-30 SCRUM-431 PixelLab Priest integration replaces the legacy Priest
full-frame art with an 8-direction PixelLab holy support-caster pack (white-gold
robes, halo, empty hands, no baked weapon/tool). PixelLab character
`ed7db59e-0845-4218-b178-a56f948254b5` (v3, `252x252` source with transparent
padding) source frames and `manifest.json` are stored under
`assets/sprites/characters/pixellab/priest/`, normalized transparent `512x512`
runtime frames under `assets/sprites/characters/full_frame/priest_pixellab/`,
and `assets/sprites/characters/priest_spriteframes.tres` now exposes
`idle_<direction>` plus 6-frame looping `move_<direction>` / `walk_<direction>`
for all 8 directions (`walking-6-frames` template). Normalization trims only
transparent padding, scales nearest-neighbor x2, centers X and bottom-aligns
with 32px padding. `scripts/progression_data_characters.gd` priest `sprite_path`
points at `full_frame/priest_pixellab/priest_idle_south.png`; the generic
directional resolver and Hero Select clockwise rotation pick up the directional
rows automatically. Legacy `assets/sprites/characters/full_frame/priest/`,
`priest.png` and cutout pieces remain history/fallback.

2026-06-30 SCRUM-704 PixelLab Dark Mage full redraw replaces the previous static
PixelLab rotation pass with a new readable-scale void caster body pack. PixelLab
character `9bb0eca8-5afe-49d4-8e56-7115a45efdcc` (v3, `248x248` source) keeps
empty hands with no baked book/skull/wand/staff/orb/held prop. Source idle
rotations and `walking-6-frames` movement frames live under
`assets/sprites/characters/pixellab/dark_mage/`, normalized transparent
`512x512` runtime frames live under
`assets/sprites/characters/full_frame/dark_mage_pixellab/`, and
`assets/sprites/characters/dark_mage_spriteframes.tres` exposes
`idle_<direction>` plus 6-frame looping `move_<direction>` /
`walk_<direction>` rows for all 8 directions. `scripts/player.gd` now routes
Dark Mage through the full-frame PixelLab SpriteFrames path instead of the
historical skeleton rig priority; the skeleton source package remains
documentation/regression history.

2026-06-30 SCRUM-423 PixelLab Chemist integration replaces the legacy Chemist
static portrait/runtime source with an 8-direction PixelLab pack. PixelLab
character `c7fe44d3-1f15-45a1-b762-b2862833b151` (v3, `252x252` source) source
frames and `manifest.json` are stored under
`assets/sprites/characters/pixellab/chemist/`, normalized transparent `512x512`
runtime frames under `assets/sprites/characters/full_frame/chemist_pixellab/`,
and `assets/sprites/characters/chemist_spriteframes.tres` now exposes
`idle_<direction>` plus 6-frame looping `move_<direction>` / `walk_<direction>`
for all 8 directions (`walking-6-frames` template).
`scripts/progression_data_characters.gd` Chemist `sprite_path` points at
`full_frame/chemist_pixellab/chemist_idle_south.png`; the generic player
directional resolver and Hero Select clockwise rotation pick up the directional
rows automatically. Legacy `assets/sprites/characters/chemist.png` remains
history/fallback.

SCRUM-426 promotes Druid to the same PixelLab directional runtime path. PixelLab
character `4078113b-fece-4087-a035-9ed3714a6514` provides 8 static idle
rotations plus `walking-6-frames` movement rows for all directions under
`assets/sprites/characters/pixellab/druid/`; normalized runtime frames live under
`assets/sprites/characters/full_frame/druid_pixellab/` on a transparent
`512x512` canvas. `assets/sprites/characters/druid_spriteframes.tres` exposes
`idle_<direction>`, 6-frame `move_<direction>` / `walk_<direction>`, and generic
south-facing fallbacks, while `sprite_path` now points to
`druid_idle_south.png` for Hero Select, Codex, carousel and level-up portraits.
Attack/body weapon rows remain absent by scope.

SCRUM-442 подготовил узкий Berserk v3 single-sprite candidate после отмены
широкого character v2 подхода: новый чуть более мультяшный unarmed barbarian
source в `docs/design/references/characters_v3/berserk/`, normalized game
candidate `assets/sprites/characters/berserk_v3_sprite.png`, backup старого
`berserk_unarmed.png` под
`docs/design/backups/scrum442_berserk_v3_pre_sprite/`, contact/dark-bg previews
и strict alpha/pose QA report
`build/qa/scrum442_berserk_v3/scrum442_berserk_v3_alpha_pose_report.json`.
После review исправлен ambiguous source artifact: `berserk_v3_source_raw.png`
теперь тоже transparent RGBA `1024x1024`, как `berserk_v3_source.png` и
`berserk_v3_source_clean.png`, без opaque checker/RGB фона.
Это Design-only sprite candidate: анимации, SpriteFrames и runtime wiring не
входили в scope.

SCRUM-424 подготовил per-class Dark Mage v2 Design-source handoff:
`docs/design/references/characters_v2/dark_mage/dark_mage_v2_source_clean.png`,
`dark_mage_v2_idle_cell_512.png`, `dark_mage_v2_sheet_source_handoff.png`,
`dark_mage_v2_design_handoff.md` и QA report
`build/qa/scrum424_dark_mage_v2/scrum424_dark_mage_v2_alpha_size_report.json`.
Персонаж яркий/эпичный фиолетовый void-caster, без staff/wand/book/orb/weapon в
руках, прозрачный RGBA, visible height `376 px` в `512x512` cell и pivot
`[256,470]`. Animator pass подключил live
`assets/sprites/characters/dark_mage_spriteframes.tres` к v2 `idle` / `walk` /
`move` 5-frame loops, derived from the accepted source, with runtime frames
under `assets/sprites/characters/full_frame/dark_mage/` and a 48px-gutter
source sheet at `assets/sprites/characters/v2/dark_mage/dark_mage_v2_anim_sheet.png`.
Previous live frames are backed up under
`docs/design/backups/scrum424_dark_mage_v2_pre_anim/`. Attack animation is
intentionally absent for this v2 row; animation smoke passes. Full runtime smoke
is currently blocked before gameplay startup by an unrelated
`scripts/ui_screens.gd` parse failure from the active UI/settings lane.

SCRUM-473 replaces the temporary cartoon-trial legacy rig for Dark Mage and
Knight with real cartoon2 full-frame SpriteFrames. Runtime resources
`assets/sprites/characters/dark_mage_spriteframes.tres` and
`assets/sprites/characters/knight_spriteframes.tres` now expose only `idle`,
`walk`, and `move` (5 looping frames each, no body attack rows). Frame PNGs live
under `assets/sprites/characters/full_frame/dark_mage/` and
`assets/sprites/characters/full_frame/knight/`; safe-gutter cartoon2 sheets live
under `assets/sprites/characters/cartoon2/{dark_mage,knight}/`. `Player`
leaves `CARTOON_TRIAL_CLASSES` empty, so both classes render through the
full-frame `AnimatedSprite2D` path at the normal combat scale while weapon
visuals continue to own attacks (`USE_ATTACK_ANIMATION=false`). Animation smoke
passes; full runtime smoke is currently blocked by an unrelated Hero Select v3
back-button UI assertion.

SCRUM-430 updates Knight's live SpriteFrames/portrait source to a PixelLab
no-shield directional pack. Source frames live under
`assets/sprites/characters/pixellab/knight/`, runtime frames under
`assets/sprites/characters/full_frame/knight_pixellab/`, and
`knight_spriteframes.tres` exposes 8-direction idle poses plus 6-frame
directional `walk`/`move` rows. The accepted source keeps weapons and shield
separate from the base hero. SCRUM-885 refreshed this same PixelLab character on
2026-07-08, regenerating 56 source PNGs, 56 normalized transparent `512x512`
runtime PNGs and the manifest/alpha report without changing gameplay or weapon
visual ownership.

SCRUM-419 подготовил per-class Assassin v2 Design-source handoff:
`docs/design/references/characters_v2/assassin/assassin_v2_source_clean.png`,
`assassin_v2_idle_cell_512.png`, `assassin_v2_sheet_source_handoff.png`,
`assassin_v2_design_handoff.md` и QA report
`build/qa/scrum419_assassin_v2/scrum419_assassin_v2_alpha_size_report.json`.
Персонаж яркий/эпичный hooded rogue в dark teal/cyan contrast, sharp silhouette,
без dagger/blade/chakram/weapon в руках, прозрачный RGBA, visible height
`376 px` в `512x512` cell и pivot `[256,470]`. Animator integration now promotes
this source into live `assets/sprites/characters/assassin_spriteframes.tres`
with v2 `idle` / `walk` / `move` loops, 5 frames each, no attack by scope.
Runtime frames live under `assets/sprites/characters/full_frame/assassin/`,
derived safe sheet
`assets/sprites/characters/v2/assassin/assassin_v2_anim_sheet.png`, old live
assets backup `docs/design/backups/scrum419_assassin_v2_pre_anim/`, QA artifacts
`build/qa/scrum419_assassin_v2_anim/`; animation/runtime smoke PASS.

SCRUM-286 добавил Dark Mage sheet на этом пути:
`assets/sprites/characters/dark_mage_sheet.png` (`1920x1152`, 5 `idle`, 5
`walk`, 5 `attack_primary`, transparent RGBA). Тёмный маг остаётся без
встроенного оружия в руках; weapon/socket visuals и gameplay timing не менялись.
Animator pass подключил runtime `assets/sprites/characters/dark_mage_spriteframes.tres`
и отдельные кадры `assets/sprites/characters/full_frame/dark_mage/`: `idle` 5f
loop, `walk` 5f loop, `attack_primary`/runtime `attack` 5f one-shot. QA
артефакты: `docs/design/previews/scrum286_dark_mage_sheet_contact.png`,
`build/qa/scrum286_dark_mage/`; animation/runtime smoke PASS.

SCRUM-291 добавил Guitarist sheet на этом пути:
`assets/sprites/characters/guitarist_sheet.png` (`1920x1152`, 5 `idle`, 5
`walk`, 5 `attack_primary`, transparent RGBA). Гитарист остаётся без встроенной
гитары/баса/ампа или другого инструмента в руках; weapon/socket visuals,
deployable amp visuals и gameplay timing не менялись. Animator pass подключил
runtime `assets/sprites/characters/guitarist_spriteframes.tres` и отдельные
кадры `assets/sprites/characters/full_frame/guitarist/`: `idle` 5f loop,
`walk` 5f loop, `attack_primary`/runtime `attack` 5f one-shot. QA артефакты:
`docs/design/previews/scrum291_guitarist_sheet_contact.png`,
`build/qa/scrum291_guitarist/` and `build/qa/scrum291/`; manifest validation,
Godot import, animation smoke and runtime smoke PASS after SCRUM-409.

SCRUM-429 подготовил per-class Guitarist v2 Design-source handoff:
`docs/design/references/characters_v2/guitarist/guitarist_v2_source_clean.png`,
`guitarist_v2_idle_cell_512.png`, `guitarist_v2_sheet_source_handoff.png`,
`guitarist_v2_design_handoff.md` и QA report
`build/qa/scrum429_guitarist_v2/scrum429_guitarist_v2_alpha_size_report.json`.
Персонаж яркий/эпичный magenta/gold stage-warlock performer, без guitar,
instrument, microphone, weapon или held object в руках, прозрачный RGBA,
visible height `374 px` в `512x512` cell и pivot `[256,470]`. После
user-feedback cleanup revision белые/нейтральные matte pixels в source/cell
равны `0`. Animator integration now promotes this source into live
`assets/sprites/characters/guitarist_spriteframes.tres` with v2 `idle` /
`walk` / `move` loops, 5 frames each, no attack by scope. Runtime frames live
under `assets/sprites/characters/full_frame/guitarist/`, derived safe sheet
`assets/sprites/characters/v2/guitarist/guitarist_v2_anim_sheet.png`, old live
assets backup `docs/design/backups/scrum429_guitarist_v2_pre_anim/`, QA
artifacts `build/qa/scrum429_guitarist_v2_anim/`; animation/runtime smoke PASS.

SCRUM-435 подготовил historical per-class Thief v2 Design-source handoff и
Animator integration, now superseded for live runtime by SCRUM-800 PixelLab:
accepted source
`docs/design/references/characters_v2/thief/thief_v2_idle_cell_512.png`
was previously promoted to `assets/sprites/characters/thief_spriteframes.tres`
with v2 `idle` / `walk` / `move` loops, 5 frames each, no attack by scope. Runtime
frames live under `assets/sprites/characters/full_frame/thief/`, derived safe
sheet `assets/sprites/characters/v2/thief/thief_v2_anim_sheet.png`, old live
assets backup `docs/design/backups/scrum435_thief_v2_pre_anim/`, QA artifacts
`build/qa/scrum435_thief_v2_anim/`; animation/runtime smoke PASS. Персонаж
остаётся яркий/эпичный amber rogue, без dagger/knife/weapon/tool/coin pouch/
bomb или held object в руках, прозрачный RGBA, visible height `374 px` в
`512x512` cell и pivot `[256,470]`. These v2 assets remain fallback/history;
live runtime uses `assets/sprites/characters/full_frame/thief_pixellab/`.

SCRUM-427 подготовил historical per-class Elementalist v2 Design-source handoff
и Animator integration, now superseded for live runtime by SCRUM-801 PixelLab:
accepted source
`docs/design/references/characters_v2/elementalist/elementalist_v2_idle_cell_512.png`
was previously promoted to `assets/sprites/characters/elementalist_spriteframes.tres`
with v2 `idle` / `walk` / `move` loops, 5 frames each, no attack by scope. Runtime
frames live under `assets/sprites/characters/full_frame/elementalist/`, derived
safe sheet
`assets/sprites/characters/v2/elementalist/elementalist_v2_anim_sheet.png`, old
live assets backup `docs/design/backups/scrum427_elementalist_v2_pre_anim/`, QA
artifacts `build/qa/scrum427_elementalist_v2_anim/`; animation/runtime smoke
PASS. Персонаж остаётся яркий/эпичный multi-element caster с fire/ice/lightning/
stone streams, без staff/orb/focus/weapon или held object в руках, прозрачный
RGBA, visible height `374 px` в `512x512` cell и pivot `[256,470]`. These v2
assets remain fallback/history; live runtime uses
`assets/sprites/characters/full_frame/elementalist_pixellab/`.

Historical Sniper v2 Design-source handoff: SCRUM-433 originally prepared
`docs/design/references/characters_v2/sniper/sniper_v2_source_clean.png`,
`sniper_v2_idle_cell_512.png`, `sniper_v2_sheet_source_handoff.png`,
`sniper_v2_design_handoff.md` и QA report
`build/qa/scrum433_sniper_v2/scrum433_sniper_v2_alpha_size_report.json`.
Персонаж яркий/эпичный cold blue-steel marksman с optical targeting light, без
rifle/gun/bow/crossbow/scope/weapon/tool или held object в руках, прозрачный
RGBA, visible height `374 px` в `512x512` cell и pivot `[256,470]`.
White/neutral matte pixels и edge-visible pixels в source/cell/sheet равны
`0`. Эти source-handoff assets теперь исторические; live runtime uses the
PixelLab directional pack under `assets/sprites/characters/full_frame/sniper_pixellab/`.

SCRUM-431 подготовил per-class Priest v2 Design-source handoff:
`docs/design/references/characters_v2/priest/priest_v2_source_clean.png`,
`priest_v2_idle_cell_512.png`, `priest_v2_sheet_source_handoff.png`,
`priest_v2_design_handoff.md` и QA report
`build/qa/scrum431_priest_v2/scrum431_priest_v2_alpha_size_report.json`.
Персонаж яркий/эпичный white-gold holy healer с halo и open-hands posture, без
staff/mace/reliquary/censer/chime/book/weapon/tool или held object в руках,
прозрачный RGBA, visible height `376 px` в `512x512` cell и pivot `[256,470]`.
White/neutral matte pixels и edge-visible pixels в source/cell/sheet равны
`0`. SCRUM-431 later replaced the live Priest runtime with a PixelLab
8-direction idle + 6-frame walk pack under `assets/sprites/characters/pixellab/priest/`
and `assets/sprites/characters/full_frame/priest_pixellab/`; the older v2
handoff remains source history.

SCRUM-421 подготовил per-class Biologist v2 Design-source handoff:
`docs/design/references/characters_v2/biologist/biologist_v2_source_clean.png`,
`biologist_v2_idle_cell_512.png`, `biologist_v2_sheet_source_handoff.png`,
`biologist_v2_design_handoff.md` и QA report
`build/qa/scrum421_biologist_v2/scrum421_biologist_v2_alpha_size_report.json`.
Персонаж яркий/эпичный emerald bioluminescent scientist-naturalist в protective
field suit, без syringe/vial/flask/sample jar/tool/orb/staff/weapon или held
object в руках, прозрачный RGBA, visible height `380 px` в `512x512` cell и
pivot `[256,470]`. White/neutral matte pixels и edge-visible pixels в
source/cell/sheet равны `0`. Этот v2 package теперь исторический source
handoff: SCRUM-421 завершил live PixelLab runtime rescue from source
`cb13813a-f0a8-4d18-b019-4bd7fb1eb3f4`, with source frames under
`assets/sprites/characters/pixellab/biologist/`, normalized runtime frames under
`assets/sprites/characters/full_frame/biologist_pixellab/`, and
`assets/sprites/characters/biologist_spriteframes.tres` exposing 8-direction
`idle`, `move`, and `walk` rows.

SCRUM-432 подготовил per-class Robot v2 Design-source handoff:
`docs/design/references/characters_v2/robot/robot_v2_source_clean.png`,
`robot_v2_idle_cell_512.png`, `robot_v2_sheet_source_handoff.png`,
`robot_v2_design_handoff.md` и QA report
`build/qa/scrum432_robot_v2/scrum432_robot_v2_alpha_size_report.json`.
Персонаж яркий/эпичный polished mechanical guardian с cyan/blue sensors, core
glow and rune seams, без weapon/tool/gun/cannon/shield/orb/focus или held
object в руках, прозрачный RGBA, visible height `376 px` в `512x512` cell и
pivot `[256,470]`. Edge-visible pixels и floodable neutral/checker pixels после
cleanup равны `0`. Это не live runtime replacement; current Robot runtime
assets остаются активными до Animator/Back-end integration.

SCRUM-289 Design pass добавил Elementalist source sheet на этом пути:
`assets/sprites/characters/elementalist_sheet.png` (`1920x1152`, 5 `idle`, 5
`walk`, 5 `attack_primary`, transparent RGBA). Элементалист остаётся без
посоха, wand, orb, focus или любого held object; в руках только близкая
стихийная энергия огня/льда/молнии. Source refs:
`docs/design/references/characters/elementalist/`; preview:
`docs/design/previews/scrum289_elementalist_sheet_contact.png`; Design QA:
`build/qa/scrum289_elementalist/`. Animator pass подключил runtime
`assets/sprites/characters/elementalist_spriteframes.tres` и отдельные кадры
`assets/sprites/characters/full_frame/elementalist/`: `idle` 5f loop, `walk`
5f loop, `attack_primary`/runtime `attack` 5f one-shot. Animator QA artifacts:
`build/qa/scrum289/`; manifest validation, Godot import, animation smoke and
runtime smoke PASS.

SCRUM-282 / SCRUM-294 added accepted unarmed Assassin and Ranger runtime
SpriteFrames on the same 5 idle / 5 walk / 5 attack_primary contract:
`assets/sprites/characters/assassin_spriteframes.tres` with per-frame PNGs in
`assets/sprites/characters/full_frame/assassin/`, and
`assets/sprites/characters/ranger_spriteframes.tres` with per-frame PNGs in
`assets/sprites/characters/full_frame/ranger/`. Both keep weapon visuals
separate from the base character sheets and pass manifest validation, animation
smoke and full runtime smoke. SCRUM-419 supersedes the live Assassin runtime
SpriteFrames with the v2 idle/walk/move-only contract; attack remains absent by
that v2 task scope while weapon/socket gameplay visuals stay unchanged.

SCRUM-283 Design pass 2026-06-14 подготовил принятый source sheet Берсерка:
`assets/sprites/characters/berserk_sheet.png` (`1920x768`, `384x384` cells,
5 `walk` + 5 `attack_primary`, RGBA transparent, unarmed). QA-манифест
`build/qa/scrum283/berserk_sheet_validation.json` принят для Design handoff:
нет magenta halo, edge-touch/crop failures или оружия в руках. Animator pass
подключил `assets/sprites/characters/berserk_spriteframes.tres` и per-frame
runtime PNGs `assets/sprites/characters/full_frame/berserk/`: `walk` 5f loop,
`attack_primary`/runtime `attack` 5f one-shot, `idle` fallback 1f. Manifest,
contact sheet and GIF previews live in `build/qa/scrum283/`; animation and
runtime smoke PASS.

SCRUM-193 cleanup 2026-06-13: старые `*_placeholder.png` для Assassin/Chemist/Doctor/Druid/Knight/Ranger отсутствуют в активной папке персонажей; backup сохранен в `build/cleanup_backup_2026_06_13/`. Канонические source sprites персонажей — только `assets/sprites/characters/<class_id>.png`, а runtime cutout-части — `assets/sprites/characters/cutout/`.

SCRUM-269 cleanup audit 2026-06-14: read-only asset/image аудит завершен в `docs/design/reviews/cleanup_assets_audit_2026_06.md`. Игровой арт защищен от удаления: weapon signature VFX и weapon select sprites грузятся динамически по `weapon_id`, новые boss/mini-elite source sprites остаются pending-live art, UI/cutout/icon families остаются dynamic assets. Единственная cleanup-находка — orphan ` 2.png.import` sidecars после duplicate cleanup — вынесена в SCRUM-271.

Текущие character sprites сделаны в стиле референса пользователя: Берсерк имеет бороду, плетеные волосы, массивное тело, мех, ремни, металлические браслеты, плечо со шипами, красную боевую разметку и skull-belt без встроенного оружия; Темный маг имеет капюшон, маску, мантию, черепа, кристаллы и фиолетовые spell-orbs; Гитарист теперь использует SCRUM-706 PixelLab-образ звукового мага/сценического контроллера с капюшоном, янтарно-золотыми и магента sonic accents, шарфом/плащом и открытыми пустыми руками без встроенной гитары, баса, усилителя или микрофона.

Стандартные монстры, элитки и боссы также используют polished cartoon fantasy full-art sprites в стиле последнего референса пользователя: темное фэнтези, выразительные силуэты, сильные черные контуры, объемная покраска и читаемые archetype-shapes. В бою их видимая фигура тоже собирается `scripts/cutout_rig_2d.gd` из нарезанных кусков того же арта (`assets/sprites/enemies|elites|bosses/cutout/`): конечности, оружие (арбалет), щиты, крылья, хвост и вихрь босса — отдельные анимируемые части. Старые placeholder rig-parts удалены. Нельзя возвращать монстров к generic placeholder-спрайтам или видимым квадратным заглушкам частей тела.

SCRUM-156 Design pass 2026-06-13 подготовил финальные painterly D&D source sprites для новых сущностей SCRUM-155:
`assets/sprites/bosses/boss_bone_archon.png`,
`assets/sprites/bosses/boss_brood_mother.png`,
`assets/sprites/bosses/boss_ashen_colossus.png`,
`assets/sprites/elites/mini_scavenger_reaper.png`,
`assets/sprites/elites/mini_plague_bellringer.png`,
`assets/sprites/elites/mini_bone_warden.png`,
`assets/sprites/elites/mini_spark_wight.png`,
`assets/sprites/elites/mini_rot_hound.png`,
`assets/sprites/elites/mini_shadow_devourer.png`.
Все 9 PNG — `512x512`, RGBA, transparent, с preview-листами
`docs/design/previews/new_bosses_mini_elites_contact.png` и
`docs/design/previews/new_bosses_mini_elites_scale_preview.png`. Runtime scene/codex wiring и cutout rig slicing остаются Back-end/Animator scope; Design handoff записан в соответствующие task-файлы.

### Берсерк

- ID: `berserk`
- Роль: ближний бой, физический урон, выживаемость.
- Базовое здоровье: 88.
- Базовая скорость: 235.
- Спрайты: `assets/sprites/characters/berserk_unarmed.png`, historical 0.1.5 source sheet `assets/sprites/characters/berserk_sheet.png`, legacy fallback `assets/sprites/characters/berserk_walk_sheet_v2.png`, cutout-части `assets/sprites/characters/cutout/berserk_*.png`. Live 0.1.6 v2 runtime uses `assets/sprites/characters/berserk_spriteframes.tres` with 5-frame `idle` / `walk` / `move` loops from `assets/sprites/characters/full_frame/berserk/`; source/handoff assets live under `assets/sprites/characters/v2/berserk/`.
- Особенность: оружие отделено от персонажа и крепится к `WeaponSocket`.

Базовые характеристики:

| Характеристика | Значение |
| --- | --- |
| Сила | 10 |
| Ловкость | 5 |
| Интеллект | 2 |
| Восприятие | 5 |
| Энергия | 4 |
| Знание | 4 |
| Выносливость | 7 |
| Лидерство | 3 |

### Солдат

- ID: `soldier`
- Роль: тактический физический класс, удерживает линию огня через залпы, гранаты и штык.
- Базовое здоровье: около 78 от `Endurance=6`.
- Базовая скорость: средняя.
- Спрайты: live `assets/sprites/characters/soldier_spriteframes.tres` now uses
  SCRUM-434 PixelLab source under `assets/sprites/characters/pixellab/soldier/`
  and normalized runtime frames under
  `assets/sprites/characters/full_frame/soldier_pixellab/`; legacy
  `assets/sprites/characters/soldier.png` and cutout-части
  `assets/sprites/characters/cutout/soldier_*.png` remain fallback/history.
- Особенность: оружие отделено от персонажа и крепится через `WeaponSocket`; все 3 оружия используют новые режимы `ClassWeapon`.

Базовые характеристики:

| Характеристика | Значение |
| --- | --- |
| Сила | 7 |
| Ловкость | 6 |
| Интеллект | 2 |
| Восприятие | 8 |
| Энергия | 4 |
| Знание | 5 |
| Выносливость | 6 |
| Лидерство | 5 |

### Темный Маг

- ID: `dark_mage`
- Роль: магический урон, AoE, лучи, DoT.
- Базовое здоровье: 42.
- Базовая скорость: 250.
- Спрайт: live `assets/sprites/characters/dark_mage_spriteframes.tres` now uses
  SCRUM-704 PixelLab source under
  `assets/sprites/characters/pixellab/dark_mage/` and normalized runtime frames
  under `assets/sprites/characters/full_frame/dark_mage_pixellab/`. It exposes
  8-direction idle plus 6-frame directional `move_*` / `walk_*` rows for runtime
  movement and Hero Select clockwise preview. Legacy `assets/sprites/characters/dark_mage.png`,
  historical 0.1.5 source sheet `assets/sprites/characters/dark_mage_sheet.png`,
  cartoon2 runtime `assets/sprites/characters/full_frame/dark_mage/`, safe-gutter
  sheet `assets/sprites/characters/cartoon2/dark_mage/dark_mage_cartoon2_anim_sheet.png`,
  and cutout-части `assets/sprites/characters/cutout/dark_mage_*.png` remain
  history/fallback.

Базовые характеристики:

| Характеристика | Значение |
| --- | --- |
| Сила | 2 |
| Ловкость | 3 |
| Интеллект | 10 |
| Восприятие | 5 |
| Энергия | 7 |
| Знание | 6 |
| Выносливость | 2 |
| Лидерство | 5 |

### Гитарист

- ID: `guitarist`
- Роль: звуковые волны, импульсы, ауры, отталкивание.
- Базовое здоровье: 60.
- Базовая скорость: 268.
- Спрайт: live `assets/sprites/characters/guitarist_spriteframes.tres` now uses
  SCRUM-797 PixelLab source `d278e753-9885-4550-82ff-81ee3bef297d` under
  `assets/sprites/characters/pixellab/guitarist/` and normalized runtime frames
  under `assets/sprites/characters/full_frame/guitarist_pixellab/`. By direct
  user override this live body keeps a held guitar because it reads as a stronger
  Guitarist silhouette than the SCRUM-706 empty-hands pack. The pack has 8 idle
  directions and 6-frame directional `move_*` / `walk_*` loops; every runtime
  frame remains `512x512` transparent and normalizes the visible alpha bbox to
  `245 px` height. BBox/contact evidence is recorded in
  `docs/design/previews/scrum797_guitarist_instrument_pack_bbox_report.json`.
  Legacy `assets/sprites/characters/guitarist.png`, runtime sheet
  `assets/sprites/characters/guitarist_sheet.png`,
  `assets/sprites/characters/full_frame/guitarist/`, and cutout-части
  `assets/sprites/characters/cutout/guitarist_*.png` remain history/fallback;
  the previous SCRUM-706 live pack is backed up under
  `docs/design/backups/scrum797_guitarist_instrument_pack_pre_swap/`.

Базовые характеристики:

| Характеристика | Значение |
| --- | --- |
| Сила | 4 |
| Ловкость | 6 |
| Интеллект | 4 |
| Восприятие | 7 |
| Энергия | 6 |
| Знание | 5 |
| Выносливость | 4 |
| Лидерство | 7 |

### Расширенный Ростер 0.1.4

Foundation новых классов уже включен в выбор персонажа, выбор оружия, кодекс, формулы характеристик, ascension и smoke tests. Design visual set для первых 9 персонажей и полного набора оружия 9 классов готов: новые герои art-approved, все 27 weapon PNG существуют по каноническим путям; gameplay/backend-сцены подключают matching weapon PNG без documented visual fallback. SCRUM-168 добавил 10-й Back-end-класс `soldier` и довел набор до 30 weapon variants; canonical Soldier character/weapon PNG и cutout rig/motion подключены. SCRUM-169 добавил 11-й Back-end-класс `thief` и довел набор до 33 weapon variants; canonical Thief character/weapon PNG и cutout rig/motion подключены. SCRUM-163 добавил 12-й Back-end-класс `elementalist` и довел набор до 36 weapon variants; canonical Elementalist character/weapon PNG и cutout rig/motion подключены. SCRUM-167 добавил 13-й Back-end-класс `sniper` и довел набор до 39 weapon variants; canonical Sniper character/weapon PNG и cutout rig/motion подключены. SCRUM-165 добавил 14-й Back-end-класс `priest` и довел набор до 42 weapon variants; canonical Priest character/weapon PNG и cutout rig/motion подключены. SCRUM-162 добавил 15-й Back-end-класс `biologist` и довел набор до 45 weapon variants; canonical Biologist character/weapon PNG и cutout rig/motion подключены. SCRUM-166 добавил 16-й Back-end-класс `robot` и довел набор до 48 weapon variants; canonical Robot character/weapon PNG и cutout rig/motion подключены. SCRUM-164 добавил финальный 17-й Back-end-класс `engineer` и довел набор до 51 weapon variant; canonical Engineer character/weapon PNG и cutout rig/motion подключены. Weapon art v2 pass 2026-06-12 дополнительно перерисовал оружие Рыцаря, заменил базовый `knight.png` на unarmed sprite без встроенного копья/щита, пересобрал `knight_*` cutouts и уменьшил `WeaponVisual.scale` у крупных оружий.

SCRUM-416 перевел runtime `sprite_path` большинства классов с legacy static PNG на принятые SCRUM-412-cleaned full-frame idle кадры `assets/sprites/characters/full_frame/<class>/<class>_idle_00.png`. PixelLab-направленные классы (`assassin`, `berserk`, `dark_mage`, `guitarist`, `doctor`, `chemist`, `druid`, `elementalist`, `engineer`, `knight`, `priest`, `ranger`, `robot`, `sniper`, `soldier`, `thief`) use `<class>_pixellab/<class>_idle_south.png` as their canonical portrait source. Hero Select large portrait, carousel thumbnails, Codex character portrait and level-up portrait now share this canonical source instead of old `assets/sprites/characters/<class>.png` art; focused registry/runtime smokes assert the actual texture paths and write QA dumps under `build/qa/scrum416/`.

SCRUM-297 добавил принятый unarmed animation source sheet для `thief`: `assets/sprites/characters/thief_sheet.png` (`384x384`, 5 idle / 5 walk / 5 attack_primary) с alpha-clean и 32px-gutter references под `docs/design/references/characters/thief/`, contact preview `docs/design/previews/scrum297_thief_sheet_contact.png` и Design QA artifacts under `build/qa/scrum297_thief/`. Параллельный Animator pass уже подключил `assets/sprites/characters/thief_spriteframes.tres` и per-frame PNGs under `assets/sprites/characters/full_frame/thief/`; Designer 2 не менял SpriteFrames/runtime wiring.

SCRUM-284 добавил unarmed animation source sheet для `biologist`:
`assets/sprites/characters/biologist_sheet.png` (`384x384`, 5 idle / 5 walk /
5 attack_primary) с alpha-clean и 32px-gutter references под
`docs/design/references/characters/biologist/`, contact preview
`docs/design/previews/scrum284_biologist_sheet_contact.png` и Design QA
artifacts under `build/qa/scrum284_biologist/`. Animator pass подключил runtime
`assets/sprites/characters/biologist_spriteframes.tres` и отдельные кадры
`assets/sprites/characters/full_frame/biologist/`: `idle` 5f loop, `walk` 5f
loop, `attack_primary`/runtime `attack` 5f one-shot. Animator QA artifacts:
`build/qa/scrum284/`; manifest validation, Godot import, animation smoke and
runtime smoke PASS. SCRUM-421 later superseded the live body runtime with a
PixelLab-only 8-direction idle + 6-frame move/walk pack:
`assets/sprites/characters/pixellab/biologist/`,
`assets/sprites/characters/full_frame/biologist_pixellab/`, and
`assets/sprites/characters/biologist_spriteframes.tres`. The legacy SCRUM-284
frames remain history/fallback; the base body still has no attack row because
weapon visuals own attacks.

SCRUM-256 добавил framework уникальных классовых идентичностей: `ProgressionData.CLASS_MECHANIC_IDENTITIES` и фасадные API `class_mechanic_identity`, `class_main_attribute`, `weapon_mechanic_identity`. Для всех 17 классов зафиксированы главный атрибут, identity title, mechanic tags и 3 weapon identity. Это data contract для патча 0.1.5: последующие задачи melee/summoner/aura/VFX используют таблицу как источник направления, а сам framework не меняет текущий баланс.

SCRUM-243 добавил универсальную матрицу синергий `ProgressionData.ATTRIBUTE_WEAPON_SYNERGY_MAP`: каждый базовый атрибут имеет понятный эффект для melee, projectile, beam, AoE, summon и aura архетипов. `derived_parameters` получил мягкий cross-scaling для damage/magic/sound, attack speed, range/AoE, projectile speed, DoT, aura, summon и ultimate, поэтому прокачка любого атрибута меняет фактический параметр у representative оружия каждого архетипа. Стартовый DPS удерживается budget tuning; global damage/survivability smoke остаются зелеными.

SCRUM-254/357 усилили summon/support персонажей через data-driven `summon_role`
поля. SCRUM-859 добавил `deploy_role`, `max_summons_cap` и sentry splash knobs для
ClassWeapon-deploys. `SummonerWeapon` передает `AllyMinion` профиль урона, HP,
скорости, интервала атаки, lifetime, control knockback, support heal, splash и
leash radius. Урон призыва масштабируется от Leadership и
`summon_amount`/Knowledge/Intelligence/Energy, живучесть и темп — от
Leadership/`summon_amount`; growth capped, поэтому уровень 0 остается базовым.
Друидский `summon_amulet` использует `pack_damage`, Химик `homunculus_vial` —
`tank_control`, Друид `raven_totem` — `support_totem`, Инженер
`engineer_sentry_wrench` — `engineer_sentry`, `engineer_repair_drone` после
SCRUM-906/FAN-1075 — `orbit_drone`. Deploy roles: `stage_pulse`, `support_totem`,
`turret_dps`, `orbit_drone` и `mine_grid`. Мобильные союзники распределяют цели
группой вокруг владельца с учетом overkill pressure. Engineer sentries remember
targets per firing cycle and add small capped splash. `ProgressionData.weapon_archetype()`
считает оружие с `summon_role` summon-архетипом; balance harness не добавляет
чистым summon-оружиям невидимый direct hit.

FAN-1076 усилил постоянную пару Химика без изменения её базового damage budget. Танк теперь крупнее героя, имеет глобальный приоритет в `_combat_target()` всех базовых врагов и получает 50% эффективного регена и каждого срабатывания вампиризма Химика. Кастер также увеличен, вынесен дальше от танка для читаемости, а радиус его damage-wave поднят с 150 до 240 px. При смерти танка враги сразу возвращаются к штатному taunt/игроку, кастер держится у плеча владельца, а танк по-прежнему возвращается через 4с.

SCRUM-245 добавил reusable status layer `scripts/status_effects.gd`. Статусы живут в meta цели (`status_effects`), поддерживают duration, refresh/add/extend stack policy, DoT ticks, speed multiplier, damage multiplier, damage-taken multiplier и marker metadata. `Enemy` учитывает status slow и vulnerability в движении/получении урона; SCRUM-835 hardening также заставляет врагов читать marker-status `bastion_taunt` и временно выбирать живого `taunt_owner` как combat target для движения/стрельбы/контакта/elite-паттернов с fallback к `_player()` после expiry или invalid owner. `AllyMinion` учитывает command-aura damage/speed buff; `Player` тикает собственные статусы, раздает on-hit debuffs и классовые ауры. Тематические назначения: Dark Mage/Elementalist — `arcane_vulnerability`, Chemist/Doctor/Assassin/Biologist — `toxic_debuff`, Soldier/Knight/Robot — `staggered`, Guitarist/Druid/Engineer — `command_pressure` вокруг героя, Priest — мягкая self-support aura.

SCRUM-251 усилил ближние классы через data-driven melee identity hooks в `ClassWeapon` и `BerserkWeapon`: close-hit bonus, wounded execute, stagger knockback, cleave follow-up и small sustain. Эффекты назначены не одинаково, а по роли оружия: меч/копье добивают раненых, топор/кистень дают cleave, молот/щит/штык/робот дают stagger, кинжалы получают close execute, костяная пила — sustain. Эти эффекты не двигают тело игрока автоматически и учитываются в `ProgressionData._budget_melee_unique_bonus()` при DPS tuning.

SCRUM-860 добавил capped kill-growth как отдельную Assassin identity, а не как общий sustain: `shadow_daggers` и `venom_wire` используют `shadow_momentum`, где обычные non-boss/non-elite kills add/refresh up to 6 stacks for 6 seconds. Caps: +12% attack speed and +9% crit damage через `kill_momentum_*` run modifiers; эффект не лечит, не считает boss/elite kills, очищается по expiry/weapon swap и покрыт `tests/kill_scaling_identity_test.gd`.

| ID | Имя | Роль | Базовые характеристики |
| --- | --- | --- | --- |
| `soldier` | Солдат | Тактический физический контроль | Str 7, Agi 5, Int 3, Per 8, Energy 4, Know 3, End 7, Lead 5 |
| `thief` | Вор | Экономико-уклонительный трикстер (SCRUM-897): trait «Воровская хватка» (стартовый радиус подбора ×1.85), рикошеты с мгновенным золотом, паралич-кинжал, дым-облако | Str 5, Agi 9, Int 3, Per 8, Energy 5, Know 4, End 4, Lead 5 |
| `elementalist` | Элементалист | Стихийные орбиты, призматические разломы и метеорные осколки | Str 2, Agi 4, Int 9, Per 7, Energy 8, Know 6, End 3, Lead 5 |
| `sniper` | Снайпер | Дальний lockshot, kill-zone и осколочные выстрелы | Str 6, Agi 8, Int 2, Per 10, Energy 3, Know 3, End 7, Lead 1 |
| `priest` | Священник | Священный sustain через освящение, ward-пульсы и молитвенную цепь | Str 2, Agi 4, Int 8, Per 6, Energy 7, Know 9, End 5, Lead 6 |
| `biologist` | Биолог | Биореакции (SCRUM-896): локальные споровые кольца+замедление, пирсинг-луч анализа, темпоральное семя; trait «Разбор образцов» — +20% прямого урона по своим заражённым (SCRUM-1005) | Str 2, Agi 5, Int 8, Per 7, Energy 6, Know 10, End 4, Lead 4 |
| `robot` | Робот | Тяжелый контроль: магнитный якорь, гидравлический пресс и реакторные выбросы | Str 8, Agi 3, Int 5, Per 5, Energy 7, Know 4, End 10, Lead 4 |
| `engineer` | Инженер | Мастерская устройств: sentry link, repair drone и pressure mines | Str 4, Agi 5, Int 7, Per 6, Energy 6, Know 6, End 5, Lead 10 |
| `assassin` | Ассасин | Быстрый крит-мили/линии | Str 6, Agi 10, Int 2, Per 6, Energy 3, Know 4, End 5, Lead 4 |
| `ranger` | Рейнджер | Сторожевой лук (SCRUM-909..913): лучные хиты отбрасывают от героя; сплит-болт 1→4, пирс-конус, перманентные капканы с параличом и кровотечением | Str 7, Agi 7, Int 2, Per 9, Energy 4, Know 4, End 4, Lead 3 |
| `doctor` | Доктор | Sustain только через собственный drain-урон и яд | Str 2, Agi 4, Int 8, Per 5, Energy 6, Know 8, End 5, Lead 2 |
| `chemist` | Химик | AoE/DoT зоны и алхимический summon | Str 2, Agi 4, Int 9, Per 6, Energy 7, Know 7, End 3, Lead 2 |
| `knight` | Рыцарь | Танк и тяжелый melee-control | Str 8, Agi 3, Int 2, Per 4, Energy 3, Know 4, End 10, Lead 6 |
| `druid` | Друид | Призыв, тернии, тотемы | Str 3, Agi 4, Int 4, Per 7, Energy 6, Know 5, End 5, Lead 9 |

SCRUM-430 makes Knight's live portrait/SpriteFrames PixelLab-based:
`assets/sprites/characters/knight_spriteframes.tres`,
`assets/sprites/characters/pixellab/knight/` and
`assets/sprites/characters/full_frame/knight_pixellab/`. The body animation
contract remains `idle` / `walk` / `move` only; weapon visuals own Knight
attacks, and the base hero source has no baked weapon or shield. SCRUM-885
re-imported the pack from PixelLab MCP on 2026-07-08 and kept the same combat/UI
paths with refreshed directional frames.

## Оружие Берсерка

Берсерк использует отдельный скрипт `scripts/berserk_weapon.gd`. Урон наносится только в активное окно удара, синхронизированное с анимацией. Оружие показывает область поражения и не бьет одну цель несколько раз за один swing.

SCRUM-241 добавил переключатель прицеливания: `nearest` сохраняет автонаводку на ближайшего врага, `cursor` заставляет melee-дуги, лучи, снаряды и зоны использовать `Player.attack_aim_direction()` / `Player.attack_aim_position()` от курсора. Значение хранится в `user://settings.cfg` как `aim_mode` и применяется живьем через root meta.

| Оружие | ID | Форма | Основной стиль | Сцена |
| --- | --- | --- | --- | --- |
| Двуручный меч | `sword` | Сектор (`sweep`) | Узкий дальний сектор 100 градусов радиуса 350; секторные бонусы расширяют угол, Radius расширяет дальность | `scenes/TwoHandedSword.tscn` |
| Двуручный топор | `axe` | Сектор (`sweep`) | Широкий сектор 180 градусов радиуса 250 по ближайшему монстру | `scenes/TwoHandedAxe.tscn` |
| Двуручный молот | `hammer` | Круг | Круговой slam радиуса 150; Radius увеличивает круг, секторные бонусы не влияют, плотные паки получают target diminishing | `scenes/TwoHandedHammer.tscn` |

Параметры (идентичность оружия, 2026-06-11):

| Оружие | Зона | Темп / Урон | Модификаторы |
| --- | --- | --- | --- |
| Меч | Сектор 100 градусов, радиус 350 | interval 0.58, damage x1.15 | +10% урон (пассив); `sector_multiplier` расширяет угол, Radius расширяет дальность |
| Топор | Сектор 180 градусов, радиус 250 | interval 1.06, damage x0.85 | -10% урон (пассив); `sector_multiplier` расширяет угол, Radius расширяет дальность |
| Молот | Круг радиуса 150 | interval 1.25, damage x0.55 | Radius scaling без fixed cap; `circle_full_targets=4`, `circle_target_diminish=0.62`; `upgrade_aoe_exponent=1.08`, `upgrade_damage_exponent=1.05` |

Для большинства melee/debug VFX художественный слой `AttackVfx` может дополняться полупрозрачным оверлеем точной геометрии зоны (`_show_exact_zone_overlay`). SCRUM-854/864 сделал `sweep`-геометрию Берсерка outward wedge-зоной для урона, а SCRUM-875 убрал видимый секторный overlay с меча/топора во время атаки: игрок видит weapon signature и перевернутый на 180 градусов crescent slash, при этом фактический сектор урона, targeting, cooldowns и баланс не меняются.

## Оружие Темного Мага

Темный маг использует универсальный скрипт `scripts/class_weapon.gd`.

| Оружие | ID | Режим | Механика |
| --- | --- | --- | --- |
| Темная книга | `dark_book` | `aoe_projectile` | Два снаряда летят в две ближайшие цели и взрываются по области (`projectile_count: 2`) |
| Проклятый череп | `cursed_skull` | `homing_curse` | Самонаводящееся проклятие, прямой урон, 5 DoT-тиков и decayed splash по области цели |
| Темный жезл | `dark_wand` | `beam` | Два pierce-луча веером (`beam_count: 2`, шаг 14 градусов), каждый пробивает несколько целей с убывающей темной энергией |

## Оружие Гитариста

Гитарист также использует `scripts/class_weapon.gd`.

| Оружие | ID | Режим | Механика |
| --- | --- | --- | --- |
| Электрогитара | `electric_guitar` | `sound_wave` | Широкая звуковая волна с отталкиванием; пассив +15% attack speed |
| Бас-гитара | `bass_guitar` | `pulse` | Частый слабый контроль-пульс: damage x0.30, interval 0.85, сильный knockback, пассив +10% attack speed |
| Усилитель | `sound_amp` | `amp` | `stage_pulse`: усилитель стоит на земле ~7с и пульсирует сам (тик 1.1с); одновременно 1 + floor(Лидерство/4) ампов, но не больше 3; старший исчезает при превышении; группа `deployed_sound_amps`, чистится со сменой оружия/персонажа/забега |

## Оружие Расширенного Ростера 0.1.4

Все 17 игровых классов теперь имеют ровно 3 selectable weapon variants в `ProgressionData.WEAPONS_BY_CLASS`; smoke test проверяет загрузку и экипировку всех 51 вариантов.

ClassWeapon-режимы с полем `attack_mode` диспетчеризуются через
`ClassWeapon.ATTACK_MODE_EXECUTORS`, а не через длинный inline `match`.
Focused weapon smoke и umbrella runtime smoke проверяют, что каждый
data-driven `attack_mode` из `ProgressionData.WEAPONS_BY_CLASS` имеет
зарегистрированный executor. Legacy/Berserk-геометрия (`attack_shape`,
`summon`, `strip`, `sweep`, `circle`) остается в собственных runtime-скриптах и
не входит в этот ClassWeapon registry contract.

| Класс | Оружие | ID | Режим | Механика |
| --- | --- | --- | --- | --- |
| Солдат | Аркебуза строя | `soldier_rifle` | `suppression_burst` | 3 коротких выстрела по линии; основная цель полный урон, соседние цели reduced suppression damage |
| Солдат | Граната с фитилем | `soldier_grenade` | `grenade_cook` | Бросок/посадка без урона, затем fuse-телеграф и взрыв с falloff урона |
| Солдат | Штык-стойка | `soldier_bayonet` | `bayonet_brace` | Короткая defensive corridor-стойка: один укол на врага за brace window + knockback |
| Вор | Кошель Рикошета | `thief_coin_pouch` | `coin_ricochet` | SCRUM-897: цепь 6 прыжков (кап 8), монотонный спад до 50% ролла на последнем; золото мгновенно в кошель с первых 3 целей (без пикапа) |
| Вор | Отравленный Кинжал | `thief_shadow_cloak` | `shadow_backstab` | SCRUM-897: фантомный кинжал без движения героя; паралич-яд 0.85с (кап 1.8с, боссы/элиты ×0.25), удар в спину ×1.35, splash 0.35 ролла |
| Вор | Дымовая Бомба | `thief_smoke_bomb` | `smoke_bomb` | SCRUM-897: бросок с фитилём 0.5с, одно AoE-событие урона, затем недамажащее облако 2.6с; dodge +0.35 только внутри, кап в дыму 0.90 |
| Элементалист | Кольцо Четырёх Стихий | `elementalist_orb_ring` | `elemental_orbit` | SCRUM-948: квадратная AoE в точке каста — три канала урона (магия+физика+ожог) и отброс от центра |
| Элементалист | Призматический Фокус | `elementalist_prism_focus` | `prism_rift` | SCRUM-949: полнокартный X-разлом через точку фокуса с центр-AoE и телеграфом |
| Элементалист | Ядро Метеора | `elementalist_meteor_core` | `meteor_shards` | SCRUM-950: самое медленное оружие игрока — долгий телеграф+падение, тяжёлый удар и догорающая DoT-зона |
| Снайпер | Винтовка Мертвого Глаза | `sniper_deadeye_rifle` | `sniper_lockshot` | Короткий прицел/телеграф, затем точный дальний beam по locked target и falloff по линии |
| Снайпер | Прицел Наводчика | `sniper_spotter_scope` | `sniper_kill_zone` | Маркированная kill-zone у ближайшей цели вызывает несколько точных sky-beam попаданий |
| Снайпер | Осколочные Патроны | `sniper_shatter_rounds` | `sniper_split_round` | Основной дальний выстрел раскалывается веером по траекториям; осколки pierce до 2 целей |
| Священник | Светлый Реликварий | `priest_reliquary` | `priest_sanctify` | Освящает ближайшую цель, затем знак взрывается по области и лечит часть нанесенного урона |
| Священник | Кадило Обета | `priest_censer` | `priest_ward` | Несколько тяжёлых ward-пульсов вокруг героя наносят урон; финал поглощает 18% одного удара за cast и отвечает retaliation без скрытого лечения |
| Священник | Колокол Молитвы | `priest_chime` | `priest_prayer_chain` | Молитвенная цепь выбирает sustain-дугу между врагами ближе к владельцу и возвращает heal |
| Биолог | Споровая Линза | `biologist_spore_lens` | `bio_spore_bloom` | Три расширяющихся споровых кольца выращиваются на цели и наносят убывающий урон |
| Биолог | Инъектор Образцов | `biologist_sample_injector` | `bio_sample_dart` | Инъектор берет образец у цели, затем delayed analysis pulses бьют цель и ближайшие ткани |
| Биолог | Семя Симбионта | `biologist_symbiote_seed` | `bio_symbiote_web` | Первичная цель связывается с соседними врагами симбиотической сетью и делит биоурон |
| Робот | Магнитный Якорь | `robot_magnetic_anchor` | `robot_magnetic_anchor` | Тяжёлый отложенный AoE-якорь в точке цели: полный урон с falloff от центра, стягивает рядовых к центру 0.85/каст (импульс cap 1500), элитки/боссы не смещаются, но урон полный |
| Робот | Гидравлический Пресс | `robot_hydraulic_press` | `robot_compression_line` | Широкий коридор: урон по ВСЕЙ ширине (300), прижимает рядовых к оси 0.80/каст, элитки/боссы — полный урон и резист смещения ×0.25 |
| Робот | Реакторное Ядро | `robot_reactor_core` | `robot_reactor_vent` | Ровно 4 вентиля 90° от мировой фазы (без самонаведения), паттерн +6°/каст — веер обходит круг за 15 атак; урон вентиля = ролл ×0.42 |
| Инженер | Ключ Часового | `engineer_sentry_wrench` | `engineer_sentry_link` | `turret_dps` (SCRUM-888): персистентные стационарные турели (жёсткий кап 2, старейшая заменяется с мини-VFX) автострельбой бьют залпом по разным ближайшим целям с малым capped splash; урон/темп — от Лидерства |
| Инженер | Орбитальный Дрон | `engineer_repair_drone` | `engineer_orbit_drone` | SCRUM-906/FAN-1075: 2 увеличенных контактных дрона по умолчанию, строго напротив на кольце 121 px; спираль с третьего, кап 6 |
| Инженер | Минная Сетка | `engineer_pressure_mines` | `engineer_pressure_mines` | `mine_grid`: три мины веером лежат свой duration и тикают урон по врагам внутри, а не исчезают после первого касания |
| Ассасин | Чакрамы | `chakrams` | `boomerang` | Коридор до цели и обратно; критовые попадания запускают теневой всплеск у цели без смещения героя |
| Ассасин | Теневые кинжалы | `shadow_daggers` | `stab_flurry` | Быстрые short-range multi-stabs с критовым теневым burst; normal kills build capped `shadow_momentum` |
| Ассасин | Ядовитая струна | `venom_wire` | `dot_beam` | Тонкая poison-линия с DoT; normal kills refresh capped `shadow_momentum` |
| Рейнджер | Лунный арбалет | `moon_crossbow` | `beam` | Заряжаемый piercing shot: неподвижная стойка повышает урон |
| Рейнджер | Грозовой длинный лук | `storm_longbow` | `beam` | Заряжаемый веер дальних лучей |
| Рейнджер | Охотничий капкан | `hunter_trap` | `trap` | Deploy trap: burst + knockback; стойка усиливает подготовку |
| Доктор | Зелье восстановления | `restore_potion` | `drain_link` | Drain-связь к ближайшей цели, часть нанесенного урона лечит Доктора |
| Доктор | Чумной шприц | `plague_syringe` | `drain_link` | Тонкая чумная связь с DoT и weapon-only drain |
| Доктор | Костяная пила | `bone_saw` | `stab_flurry` | Ближний saw/flurry, DoT и weapon-only sustain от нанесенного урона |
| Химик | Взрывная пыль | `blast_powder` | `aoe_projectile` | Spark cloud + взрыв; облака разных элементов дают combo explosion |
| Химик | Кислотная колба | `acid_flask` | `aoe_projectile` | Poison/acid pool; пересечение с другим элементом взрывает комбо |
| Химик | Склянка гомункула | `homunculus_vial` | `summon` | Постоянная крупная пара: смертный танк `tank_control` (4x HP, глобальное аггро, 50% регена/вампиризма) + неуязвимый кастер с damage-wave r240 |
| Рыцарь | Копье | `long_spear` | `strip` | Длинный точечный strip; легкий frontal block/counter на малом target cap |
| Рыцарь | Башенный щит | `tower_shield` | `sweep` | Frontal bash/control; strongest incoming-based block/counter по contact pack |
| Рыцарь | Освященный кистень | `holy_flail` | `circle` | Medium circular heavy swing; broad circular holy-control counter |
| Друид | Амулет призыва | `summon_amulet` | `summon` | Beast pack `pack_damage`: Leadership scaling, умное распределение целей вокруг владельца и малый splash |
| Друид | Посох терний | `briar_staff` | `aoe_projectile` | Thorn zone, AoE DoT |
| Друид | Вороний тотем | `raven_totem` | `amp` | `support_totem` pulses, Leadership-scaled deploy limit, малый support sustain |

SCRUM-917 делает visual layer Гидравлического Пресса покадровым: отдельный
PixelLab 8-frame `compress` эффект показывает две боковые губки/pressure-waves,
которые сходятся к оси по полной live-ширине `300` (или `390` с Калибратором),
а peak crush frame совпадает с hit delay `0.20s`. Runtime использует
`scenes/vfx/RobotHydraulicPressCompressionVfx.tscn`; gameplay-геометрия и числа
SCRUM-916 не менялись.

Новые backend modes/hooks: Soldier `suppression_burst`/`grenade_cook`/`bayonet_brace`, Thief `coin_ricochet`/`shadow_backstab`/`smoke_bomb`, Elementalist `elemental_orbit`/`prism_rift`/`meteor_shards`, Sniper `sniper_lockshot`/`sniper_kill_zone`/`sniper_split_round`, Priest `priest_sanctify`/`priest_ward`/`priest_prayer_chain`, Biologist `bio_spore_bloom`/`bio_sample_dart`/`bio_symbiote_web`, `stab_flurry`, `dot_beam`, `trap`, `drain_link`, ranger stance charge (`charge_seconds`/`charge_max_multiplier`), assassin crit shadow burst (`crit_shadow_burst_radius`), Assassin kill-growth `shadow_momentum`, chemist cloud combos (`pool_element`/`combo_clouds`), knight block/counter (`block_reduction`, `counter_damage_multiplier`, `counter_incoming_multiplier`, `counter_radius`, `counter_arc_degrees`, `counter_target_cap`) и druid pet commands (`command_mode`, `command_target`). SCRUM-857 уточнил projectile/chain/pierce identities: grenade наносит damage только после fuse, meteor имеет более долгий impact+shards payoff, sniper split использует fan trajectories with pierce, priest chain выбирает sustain-arc target, а dark wand/curse применяют decay. SCRUM-858 уточнил Knight block/counter: spear получает узкую легкую ответку, tower shield — strongest frontal incoming-based counter, holy flail — broad circular soft counter. SCRUM-859 уточнил deploy identities: Guitarist amp `stage_pulse`, Druid raven `support_totem`, Engineer sentry `turret_dps`, repair drone `repair_chain`, mines `mine_grid`, with ClassWeapon deploy caps after Leadership scaling. SCRUM-860 split growth/sustain: Assassin gains capped tempo/crit from normal kills only, while Doctor drain, Priest prayer/ward, and Knight block/counter remain separate sustain identities. Deploy/trap/totem/cloud visuals используют `WeaponVisual` или `AttackVfx`, регистрируются в `player_weapon_effects` для cleanup; химические облака дополнительно временно входят в `chemist_clouds`. SCRUM-854 поднял active pool cap до 6 per weapon owner, поэтому новые acid/briar/cloud зоны не стирают предыдущую сразу и живут по собственному `pool_duration`.

SCRUM-152/157/254/357/854/859/FAN-1076: `AllyMinion.tscn` больше не использует Polygon2D-placeholder, а показывает `assets/sprites/allies/ally_druid_beast.png` как безопасный fallback. Source-specific runtime mapping подключен: `summon_amulet` выбирает `ally_druid_beast.png` или `ally_druid_pack_spirit.png`, `homunculus_vial` использует направленную PixelLab-пару `homunculus_tank_*` / `homunculus_caster_*` с отдельными крупными масштабами, будущий `leadership_echo` зарезервирован под `ally_leadership_echo.png`. Deployable mapping вынесен в weapon config: `sound_amp` ставит `deploy_sound_amp_field.png`, `raven_totem` ставит `deploy_raven_totem_field.png`. `AllyMinion` имеет runtime `max_health/health`, `heal()`, `take_damage()` и `set_combat_profile()`, чтобы призывы могли получать роль, выживаемость, sustain, темп, leash и splash от владельца. Mobile summons tag owner+weapon, стартуют с половиной текущего лимита и добирают остаток штатным summon interval. ClassWeapon deploys apply `max_summons_cap` after Leadership scaling where configured: amp/totem cap at 3 and sentry cap at 5. Cleanup groups (`allies`, `player_weapon_effects`, `deployed_sound_amps`) не менялись.

SCRUM-279/280 оживили базового волка Друида: `druid_beast` в `AllyMinion` включает `AnimatedSprite2D` с `assets/sprites/allies/ally_druid_wolf_spriteframes.tres`, `move` (8 frames, 12fps, loop) при перемещении/ожидании, `attack` (6 frames, 14fps, one-shot) в момент фактического удара и `flip_h` вправо по направлению движения/атаки. SCRUM-351 централизовал это через `scripts/full_frame_animation_registry.gd`: `druid_beast`, `druid_pack_spirit`, `homunculus` и `leadership_echo` подключают full-frame SpriteFrames по source-specific ally ID, а PNG `ally_*.png` остаются безопасным fallback при отсутствии или поломке SpriteFrames. SCRUM-353 validated the four mobile summons through `fantasydisk-animation-director`, maps runtime `attack` to manifest `attack_primary`, and padded wolf frames to safe `256x256` canvas with registry placement compensation. SCRUM-370 added 6-frame, 10fps, non-loop `death` rows to all four ally SpriteFrames paths. SCRUM-399 repainted the four mobile summon static/fallback PNGs and existing move/attack/death frame PNGs into a blue/cyan ethereal allied-spirit style while preserving runtime IDs, SpriteFrames resources, timings, scale and positions.

SCRUM-1016 добавил Animator-owned PixelLab visual packs для будущих Summon
Amulet ID `druid_ghost_wolf`, `druid_ghost_bear`, `druid_ghost_panther`,
`druid_ghost_stag` и `druid_ghost_lion` из принятых SCRUM-1015 UUID. У каждого
есть только explicit horizontal rows: `move_left/right` 6f loop и
`attack_left/right` 6f one-shot; `AllyMinion` выбирает соответствующий ряд через
`FullFrameAnimationRegistry` без `flip_h`. Source/runtime разнесены, runtime PNG
нормализованы в прозрачные `256x256` клетки с едиными center/baseline/gutter
правилами. Это только визуальная готовность: `summoner_weapon.gd`, roster/spawn
weighting, damage, aura и balance не менялись и остаются за SCRUM-902.
SCRUM-1020 заменил только дефектный `druid_ghost_bear/move_right` на
same-UUID PixelLab job `1585ff64-f3e8-4db7-aa8b-fd7631a40bae`: все шесть
кадров сохраняют одну тяжёлую медвежью форму без прежнего
canine-to-bear скачка, а alpha-area ratio снижен с `2.089121x` до
`1.083628x`. Runtime/gameplay hooks не менялись; результат ждёт
независимого re-QA.

## Боевые Эффекты (Attack VFX)

Все зоны атак и снаряды игрока рисуются текстурными спрайтами через общий модуль `scripts/attack_vfx.gd` (класс `AttackVfx`); плоские полупрозрачные Polygon2D-зоны убраны из активного боевого визуала. Текстуры эффектов лежат в `assets/sprites/effects/`. Новые художественные ассеты с 2026-06-14 генерируются только skill-ом `fantasydisk-asset-generator`; старые локальные generator scripts остаются историческими pipeline notes для уже существующих PNG.

| Эффект | Текстуры | Где используется |
| --- | --- | --- |
| Дуга-слэш | `slash_arc.png` (+ непрозрачный подслой для контраста) | Меч/топор берсерка (`sweep`); секторный overlay скрыт, crescent-дуга повернута на 180 градусов и проигрывается вдоль направления удара за ~0.18с |
| Удар молота | `impact_flash.png`, `impact_ring.png`, `dust_puff_0..2.png` | Молот: оружие замахивается вверх и с ускорением падает в землю (`_animate_hammer_slam`), затем вспышка, расходящееся кольцо и 8 клубов пыли разлетаются по радиусу AoE |
| Вой-орб | `void_orb.png` + трейл из затухающих копий | `dark_book` (aoe_projectile): пульсирующий снаряд, на взрыве — `orb_burst` (кольцо+вспышка+вой-дымки) |
| Проклятый череп | `weapons/cursed_skull.png` + glow и трейл | `cursed_skull`: череп летит к цели ~0.2с, урон и splash наносятся в момент попадания |
| Луч | `beam_strip.png` + вспышки на концах | `dark_wand` (beam) |
| Звуковая волна | `sound_wave.png` + `music_note.png` | `electric_guitar` (sound_wave): волна `)))` расширяется по направлению, вылетают ноты |
| Кольцевой импульс | `impact_ring.png` + ноты (для гитариста) | `bass_guitar` (pulse), `sound_amp` (amp) |

Правила: эффекты самоочищаются tween-ами, классовое оружие дополнительно регистрирует их в `player_weapon_effects` (мертвые ссылки фильтруются в `_register_effect`/`cleanup_effects`). Runtime smoke проверяет экипировку всех 51 weapon variants; VFX smoke остается профильным тестом основных хелперов. Скриншоты для ручной проверки: `tools/capture_vfx_preview.gd` (windowed) -> `build/vfx_preview/`.

SCRUM-854: `AttackVfx.weapon_signature()` теперь рисует главный силуэт оружия отдельным non-additive `WeaponSignatureBody` с alpha 0.60; shadow/rim остаются ниже по читаемости. Это делает оружие видимым при каждом ударе, не меняя зоны урона и не поднимая additive-alpha cap для остальных VFX. SCRUM-880 добавил optional `WeaponSignatureActualWeapon` overlay для runtime weapon texture; сейчас он используется у Берсерка `axe`, чтобы при атаке был виден actual `two_handed_axe.png`, а не только slash/crescent plate.

SCRUM-337 production art refresh: все перечисленные texture paths плюс 51 `vfx_weapon_<weapon_id>.png`, elite/boss helper VFX и `assets/sprites/projectiles/*.png` пересобраны из generated source sheets `docs/design/references/attack_vfx_realistic_dark_fantasy/`. Deterministic cut/alpha pipeline: `tools/build_scrum337_attack_vfx_from_sources.py`; QA/readability artifacts: `build/qa/scrum337/`.

SCRUM-728 (2026-07-01) заменил только `assets/sprites/effects/vfx_weapon_axe.png`: weapon signature топора теперь читается как широкая 140-градусная cleave-дуга с полупрозрачным ghost-силуэтом двуручного топора. OpenAI Images override зафиксирован в `docs/design/references/weapon_attack_animations/axe/`, preview/readability sheet: `docs/design/previews/weapon_attack_animations/axe_contact.png`. Runtime API, damage, cooldowns, targeting, радиус/угол удара и shared gameplay hooks не менялись.

SCRUM-880 (2026-07-08) усилил runtime-readability атаки `axe` без новых исходных ассетов: `BerserkWeapon` передает текущую текстуру `WeaponVisual` в `AttackVfx.weapon_signature()` как actual weapon overlay, а `AttackVfx.slash()` для `axe` получает broad lateral scale и metadata `visual_sweep_degrees=180`. Фактическая outward wedge geometry, `attack_range=250`, `sweep_degrees=180`, cooldown, targeting, damage window и balance data не менялись.

SCRUM-895 Animator pass заменяет зависимость от одной signature-пластины
изолированными PixelLab motion VFX для Berserk Axe/Hammer. Axe получает
8-frame actual weapon ghost, который проходит live `180° / 250px` cleave;
Hammer на impact показывает authored overhead-slam frame 5, ground crack и
shock ring текущего `150px` close-AoE. `TwoHandedSword.tscn`, shared
`berserk_weapon.gd`, `attack_vfx.gd`, progression/balance data и damage windows
в Animator-коммите не менялись. Backend-исправление lower-side Hammer zone
ведётся отдельно в SCRUM-1043; Hammer visual bridge принимает его точный
center/scale hook. Source/contact/runtime capture:
`docs/design/references/scrum895_berserk_axe_hammer_vfx/`,
`docs/design/previews/scrum895_berserk_axe_hammer_pixellab_contact.png`,
`docs/design/previews/scrum895_berserk_axe_hammer_runtime.png`.

SCRUM-756 (2026-07-01) заменил только `assets/sprites/effects/vfx_weapon_priest_reliquary.png`: weapon signature Светлого Реликвария теперь читается как золотой sanctify-seal с полупрозрачным ghost-силуэтом референсного реликвария внутри зоны. PixelLab MCP evidence: `docs/design/references/weapon_attack_animations/priest_reliquary/manifest.json`; preview/readability sheet: `docs/design/previews/weapon_attack_animations/priest_reliquary_contact.png`. Runtime API, damage, cooldowns, targeting, радиус sanctify-взрыва, лечение и shared gameplay hooks не менялись.

## Характеристики

Базовые характеристики:
- `strength` / Сила
- `agility` / Ловкость
- `intelligence` / Интеллект
- `perception` / Восприятие
- `energy` / Энергия
- `knowledge` / Знание
- `endurance` / Выносливость
- `leadership` / Лидерство

Производные параметры:
- `damage`
- `magic_damage`
- `attack_speed`
- `crit_chance`
- `crit_damage_multiplier`
- `move_speed`
- `dodge`
- `defense`
- `absorb`
- `health_point`
- `knockback_distance`
- `summon_amount`
- `attack_range`
- `range_multiplier`
- `regeneration`
- `vampiric_amount`
- `vampiric_chance`
- `aoe_radius`
- `pickup_radius`
- `dot_damage`
- `dot_speed`
- `projectile_speed`
- `aura_radius`
- `buff_power`
- `knockback_power`
- `ultimate_multiplier`

Формулы и описания для UI характеристик находятся в `scripts/stat_formulas.gd`.
`scripts/progression_data.gd` остается compatibility facade для старых runtime
ссылок, а данные разделены по domain owners: `progression_data_characters.gd`,
`progression_data_weapons.gd`, `progression_data_content.gd`,
`progression_data_shop.gd`, `progression_data_ascension.gd`,
`progression_data_balance.gd` и `progression_data_enemies.gd`.

Актуальная философия прокачки: все базовые и производные атрибуты полезны каждому классу. Старая фильтрация «нерелевантных» статов отключена; `STAT_CLASS_RELEVANCE` оставлен пустым для совместимости. Исключение SCRUM-854/SCRUM-862: Доктор не получает внешние regeneration/vampirism/lifesteal rewards из level-up, artifact pool, shop, elite reward, boss completion reward и start boon rolls; его sustain идет только через собственные weapon mechanics. Для остальных тематически чужих эффектов UI показывает классовую интерпретацию: магический урон становится зачарованием оружия, Лидерство — эхо-оружием/фантомом/соколом/фамильяром, DoT — малым bleed/burn/poison, Energy — ускорением уникальной механики. SCRUM-898 удалил отдельный звуковой урон и прежний универсальный battle-shout hook: все три оружия Гитариста и природная магия Друида используют `magic_damage`, а звуковая тема остаётся геометрией/VFX, не отдельной осью урона.

Runtime hooks уже подключены в `scripts/player.gd` и `scripts/class_weapon.gd`: оружейные попадания могут запускать magic enchant splash, малый DoT и leadership echo-hit; Energy ускоряет теневой burst Ассасина, counter Рыцаря и charge Рейнджера. Крит/уворот игрока не двигают тело персонажа автоматически: позиция героя остается под контролем ввода, а критовые классовые эффекты Ассасина происходят как вспышка/удар у цели.

Status hooks SCRUM-245: weapon hit дополнительно может наложить `arcane_vulnerability`, `toxic_debuff` или `staggered` по классу. Leadership/support классы обновляют ауру примерно раз в 0.55с: союзники внутри радиуса получают `command_aura`, враги — `command_pressure`. Визуально используется существующий мягкий `AttackVfx.ring_pulse` плюс marker metadata; новый Design asset не требуется.

Криты после SCRUM-247 используют сглаженные формулы: `crit_chance = effective_crit_chance(0.04 + Agility*0.0075 + flat*0.75)`, cap 55%; `crit_damage_multiplier = clamp(1.30 + Agility*0.055 + flat*0.75, 1.0, 2.75)`. Это сохраняет crit-builds полезными, но не дает flat-стаку шанса/силы крита доминировать над стабильным уроном; средний DPS удерживается через `ProgressionData.weapon()` budget tuning.

## Награды И Артефакты

В игре есть:
- награды за уровень;
- награды базовых характеристик;
- артефакты;
- магазинные предметы;
- классовые артефакты;
- риск-награда артефакты.

Магазин показывает четыре случайных предложения inline поверх canonical shop backdrop `ui_backdrop_merchant_archive.png` и позволяет купить несколько предметов за один визит, если хватает денег. SCRUM-993 помещает экран в live SCRUM-981 gold shell: complete merchant art масштабируется contain без crop внутри frame-safe rect, hollow `frame_border.png` рисуется последним, а HUD/header, четыре товара, фиксированная tooltip-полоса и Back используют authored responsive zones 1280×720 / 1920×1080 / 2560×1440. Четыре товара образуют scroll-free горизонтальный focus ring; Left/Right циклят товары, Down ведёт на Back, Up возвращает к первому доступному товару. Название — однострочный ellipsis на scaled 9-slice plate, цена поддерживает четыре цифры; недоступный товар остаётся видимым и фокусируемым (desaturated icon + red price), купленный заменяется disabled `снято` hook. Hover/focus заполняет один фиксированный tooltip вне орнамента; SCRUM-1073 расширил compact band до `700×148` с внутренней зоной `650×114`, поэтому semantic tooltip copy полностью помещается на 720p и заканчивается до Back. Уход фокуса скрывает подсказку. `UpgradeFabButton` на Shop отсутствует согласно SCRUM-982/987 разделению.

SCRUM-982/987/988 закрепляют отдельный контракт платной докачки атрибутов. Ручной вход в Attribute Shop удалён с Route Map, Rest, Shop, Event и Escape/pause menu: золото нельзя конвертировать в характеристики между обязательными наградными шагами. После обычной победы Attribute Shop по-прежнему обязателен перед картой, а после элитной победы открывается после выбора артефакта; существующие buy/reroll/skip, цена и сохранение текущего набора не меняются. Экран использует общий полый золотой shell `meta40/frame_border.png`, рисуемый поверх контента, без второй центральной рамки. Внутри пустой зоны находятся 2 предложения по умолчанию или 3 при Atlas-бонусе `attr_extra_options`; все карточки стоят в одном горизонтальном ряду. Каждая карточка прямо показывает классовую интерпретацию, влияние характеристики и derived before/after preview. На compact tier SCRUM-1073 сокращает только видимые lanes до двух строк, а tooltip сохраняет точные полные `full_text` influence/preview строки. Reroll и Skip образуют горизонтальный нижний ряд. Authored раскладка и live relayout покрывают 1280×720, 1920×1080 и 2560×1440, включая переход между ними без реконструкции экрана. Накопленные level-up выборы не теряют отдельный `LevelUpPlusButton`: он остаётся доступен на боевых и небоевых экранах при `pending_level_ups > 0` и открывает сохранённый набор наград.

SCRUM-990/991 унифицируют elite/chest и boss artifact reward. Оба пути
используют красивый `ui_backdrop_reward_hall.png`, единственную полую внешнюю
раму `meta40/frame_border.png`, рисуемую последним слоем, и три Atlas-chip
карточки в одном горизонтальном ряду; прежних видимых
`Elite/BossArtifactRewardPanel` и второй центральной окантовки нет. Точный
gold-shell inner rect и все дочерние hitbox/text/icon зоны пересчитываются на
1280×720, 1920×1080, 2560×1440 и при live resize. Выбор по-прежнему обязателен:
Left/Right циклят три карточки, Escape не закрывает экран, нажатие применяет ровно
один артефакт, очищает modal и один раз продолжает прежний callback маршрута.

Вместо расплывчатой строки «Интерпретация» карточка показывает конкретный эффект
для текущего класса: presenter делает dry-run текущих stats/run-modifiers через
канонические derived formulas, сохраняет явные условия/штрафы артефакта и
показывает наиболее существенные дельты. Рекомендации сравнивают только текущие
три оффера. `Лучший урон` и `Лучшая выживаемость` выдаются лишь уникальному
положительному победителю безопасно моделируемой оси; один hybrid может получить
обе метки, а tie/unknown/no-op остаются без метки. Для Доктора preview фильтрует
те же запрещённые generic sustain keys, что и фактическое применение награды.

Сток генерируется один раз на конкретный `shop`-узел маршрута и сохраняет purchased-состояние при повторном открытии того же экрана через меню/досье; новый `shop`-узел получает свежий набор. SCRUM-339 расширяет это на flow карты: выход из магазина возвращает на route map без продвижения `route_stage`, этот же shop-узел остается доступен для повторного входа, а узлы следующего ряда уже кликабельны. FAN-1078 делает записанную ветку магазина authoritative: соседние узлы рядом с магазином остаются locked, а вперёд открываются только связанные с выбранной веткой узлы; посещённый магазин — единственное исключение для возврата после случайного выхода/Escape. Выбор следующего route node считается точкой невозврата: только тогда старый shop stock/purchased state очищается и начинается следующий этап. Focused SCRUM-993 test детерминированно проверяет exact geometry, full tooltip fit, long caption, 9999g, foreign affinity, unaffordable/purchased states и live resize; общие runtime/UI/no-overlap/gamepad gates сохраняют re-entry и event-shop semantics. Renderer evidence: `docs/design/previews/scrum993_shop_gold_shell/runtime/`.

Экономика 0.1.4 + SCRUM-853 pacing: магазин, докачка атрибутов, reroll и платные event-исходы проходят через `ProgressionData.stage_scaled_cost()`, где поверх stage scale применяется глобальный `ECONOMY_PRICE_MULTIPLIER = 1.10`. Дроп назначается по классам целей (`DROP_CLASS_MULTIPLIERS`): обычные враги остаются базой, сложные ranged/summoner дают x1.3 XP / x1.6 золота, bruiser/shield около x1.75 XP и x2.2 золота, мини-элитки x3.6/x3.8, элитки x8/x8.5, босс получает fixed reward `money 43.0`, умноженный на `stage_scale`. SCRUM-853 не режет per-monster drops: прогресс героя замедлен через XP-кривую `ceil(req*1.09+0.8)`. SCRUM-1058 обновляет `tests/monster_xp_pressure_pacing_test.gd` под 13-боевой двухактовый финал stage 16: Berserk/hammer — 473.1 kills, Act 1 lvl 15, финал Act 2 lvl 29; Dark Mage/dark_book — 504.1 kills, Act 1 lvl 15, финал Act 2 lvl 30. Старая кривая на том же сокращённом сценарии дала бы lvl 38-39.

Design visual kit/spec для всех артефактов, shop-only предметов и курсора описан в `docs/design/artifact_shop_cursor_visual_kit.md`:
- 71 unique artifact icons: `assets/sprites/ui/icons/artifacts/artifact_<artifact_id>.png` (`256x256`, transparent realistic epic D&D/tabletop fantasy raster magic items; SCRUM-340 regenerated the base set through `fantasydisk-asset-generator` / `gpt-image-2`; SCRUM-606/609 integrated 10 dedicated icons for `field_kit`, `vital_siphon`, `powder_charge`, `bulwark_echo`, `duelist_spur`, `sacrifice_seal`, `hungry_amulet`, `berserk_totem`, `focus_lens`, `stone_hide`, and SCRUM-619/623 tracks `rift_key`);
- 7 shop-only icons: `assets/sprites/ui/icons/shop/shop_<shop_item_id>.png`;
- полный mapping: `docs/design/artifact_shop_cursor_visual_kit.md`;
- artifact icon source references/manifest: `docs/design/references/icons/artifacts/artifact_<id>_source.png` and `docs/design/references/icons/artifacts/artifact_icons_scrum340_manifest.json`; previous raster extraction scripts are superseded for active icons.
- shop/cursor generator: `tools/generate_artifact_shop_cursor_assets.py`;
- active QA preview: `assets/sprites/ui/icons/artifact_realistic_dnd_preview.png` (large and 40px checks for every active artifact).

После пользовательского фидбэка artifact icons закреплены как красивые растровые предметы, а не пентаграммы/плоские символы: один законченный D&D-style magic item на файл, bbox с запасом от краев, без пьедесталов, фоновых тайлов, осколков, частиц и текста. SCRUM-340 (2026-06-14) пересоздал базовый набор через `fantasydisk-asset-generator`, SCRUM-606/609 (2026-06-28) довели новые expected artifact IDs до runtime-ready PNG/import/source refs, а `rift_key` теперь documented как runtime artifact для secret encounter flow. Runtime paths остаются стабильными `artifact_<id>.png`, transparent alpha и читаемость 40px. Образ каждого предмета привязан к названию и эффекту из `ProgressionData.ARTIFACTS`; предыдущие generated/vector-like, glossy, concept-sheet tile и per-item pictogram направления заменены. Shop assets остаются в FantasyDisk fantasy-medallion style; cursor assets заменены в SCRUM-223 на dragon/claw/fire pointer.

Back-end integration complete: `scripts/ui_screens.gd` сначала ищет финальные PNG по mapping из visual kit, а если их нет, временно использует осмысленный fallback через `scripts/ui_icon_registry.gd` по эффекту предмета. На 2026-06-11 фактические artifact/shop/cursor PNG готовы и импортированы, поэтому fallback остается только fail-safe.

SCRUM-338 reward-screen Design kit готов к runtime-подключению: отдельные
карточки наград боя и артефактной награды элитки лежат в
`assets/sprites/ui/frames/rewards/` как `ui_frame_reward_card*.png` и
`ui_frame_reward_elite_artifact_card*.png` (`768x1024`, transparent RGBA). Это
Design-only результат; runtime подключение `_show_reward_screen` и
`_show_elite_artifact_reward` передано Back-end в
`docs/tasks/backend_reward_screens_per_reward_frames_integration_task.md`, чтобы
логика наград не менялась в Design-чате. Safe-zone metadata:
`docs/design/references/rewards/reward_frames_scrum338_metadata.json`.

SCRUM-330 подготовил Design-ready kit для pause/result кластера: OpenAI/skill
mockup `docs/design/references/ui_overhaul_pause_end/pause_end_cluster_mockup.png`,
spec `docs/design/mockups/ui_overhaul_pause_end/scrum330_pause_end_mockup_spec.md`,
runtime frame candidate
`assets/sprites/ui/frames/pause_end/ui_frame_pause_end_modal.png` (`1280x1024`,
RGBA transparent) и previews `docs/design/previews/ui_overhaul_pause_end_contact.png`
/ `ui_overhaul_pause_end_safe_zones.png`. Source safe rect modal frame:
`Rect2(170,180,940,670)`; content margins `Vector4(170,180,170,174)`.
Result crests `ui_crest_victory.png` / `ui_crest_defeat.png` остаются
декоративными header assets. SCRUM-407 подключил этот kit в runtime: меню паузы,
pause dossier/stats, victory и death screens используют
`ui_frame_pause_end_modal.png` как масштабируемый modal `StyleBoxTexture` с
Design safe/content margins; длинное pause dossier/stats содержимое живет внутри
scroll safe-zone. SCRUM-841 переводит victory/death на no-scroll result layout:
`ResultContent_*` лежит напрямую в panel safe-zone, `ResultBody_*` делит середину
на decorative crest slot и компактную `RunSummaryColumn_*`, а action button всегда
остаётся видимой в нижнем safe-слоте на 1152x648/1280x720/1080p/2K/4K. QA dump:
`build/qa/scrum330/pause_end_ui_no_overlap_matrix.md`.
SCRUM-986 отдельно исправляет предшествующий короткий victory banner: его
`960x224` atlas chip теперь центрируется по обеим осям viewport через anchors
`0.5`, поэтому полностью видим и не выходит из gold-shell safe-area на 720p,
1080p и 1440p, включая live resize.

Level-up показывает 3 фиксированных варианта на каждый полученный уровень: обычные улучшения оружия/параметров и очень редкие основные характеристики (`strength`, `agility`, `intelligence`, `perception`, `energy`, `knowledge`, `endurance`, `leadership`) с визуальной rare-пометкой. Вес обычных наград (SCRUM-695) считается напрямую от матрицы релевантности `CharacterData.ATTRIBUTE_RELEVANCE` (24 каноничных атрибута × 17 классов, инвариант 2 primary / 8 secondary / 7 optional на атрибут): primary выпадает чаще secondary, secondary чаще optional, но у каждого варианта есть floor (optional держится выше 0.3, чтобы атрибут не выпадал из пула). Набор из 3 вариантов подчиняется правилу релевантности — не более 1 `optional`-атрибута и всегда минимум 1 primary/secondary (никогда только необязательные); редкий main-stat слот и capstone «Озарение» считаются не-optional. Каждый атрибут описан человекочитаемыми единицами, согласованными с глоссарием. `ATTRIBUTE_PRIORITIES` (8 базовых характеристик) остаётся источником веса только для редкого main-stat слота и pause-stats tooltips. Один уровень дает ровно один выбор; если накопилось несколько уровней, окна открываются последовательно. Окно можно закрыть через «Позже» без потери выбора: тот же набор остается в `level_up_offer`, а нижняя SCRUM-390 plus-кнопка с pending-бейджем возвращает игрока к сохраненному пику. SCRUM-683 подключил live runtime для SCRUM-682 Level Up package: крупная `1720x1040` панель, три `470x560` reward cards, увеличенный портрет/иконки, dedicated `Позже` button art и framed visible effect-preview внутри каждой карточки. Effect-preview показывает before/after deltas из текущих статов, активных модификаторов, `ProgressionData.derived_parameters()` и выбранных героя/оружия; tooltip остается только overflow/backstop, а не единственным объяснением выбора. Runtime сохраняет SCRUM-465 viewport-aware поведение на 720p и держит весь контент внутри safe zones; SCRUM-683 focused evidence пишется в `build/qa/scrum683/level_up_no_overlap_matrix.md`. Level-up и докачка атрибутов показывают иконки через `UIIconRegistry` и добавляют текст «Интерпретация» для выбранного героя. Артефакты с `class_affinity` больше не считаются нерабочими для чужого класса: affinity теперь описывает тематику, а `affinity_mods` применяются через интерпретацию текущего героя.

SCRUM-985 supersedes прежнюю визуальную оболочку Level Up: runtime больше не
создаёт `LevelUpFrame`, а `LevelUpPanel` остаётся только responsive layout-хостом
с alpha `0.20`, прозрачным бордюром и нулевой толщиной рамки. Arcane-lab
backdrop осветлён, его shade снижен до `0.12`, intro dim — до `0.24` вместо
SCRUM-892 baseline `0.82`; плотными остаются только три локальные карточки.
Level Up отключает дополнительное readability-увеличение `UIIconRegistry`,
поэтому reward/artifact icon точно совпадает с внутренней safe-zone сокета и не
заходит на орнамент. Проверенные runtime-снимки 720p/1080p/2K лежат в
`docs/design/previews/scrum985_level_up_cleanup/`.

## Ультимейты

У каждого из 17 игровых классов есть ultimate ability, описанная в `ProgressionData.ULTIMATE_CONFIGS` и показанная в Кодексе. Заряд копится от нанесенного и полученного урона до 100, масштабируется от Energy и активируется InputMap action `ultimate` (default R, ребиндится в настройках). После активации заряд сбрасывается. SCRUM-872/FAN-1064: накопленная шкала ПЕРСИСТИТ между любым количеством раундов/узлов, отдельных боёв и актов — заряд переносится через `run_player_snapshot` (`ultimate_charge` в `_store_player_snapshot`/`_restore_player_snapshot`, clamp по `ultimate_max_charge`); обнуление происходит только при активации ульты и при старте нового забега/смене персонажа. `tests/ultimate_charge_persist_test.gd` закрепляет в том числе перенос 100% из первого боя во второй и затем в третий. Активная ульта (timed overlay) между узлами не переносится.

Боевой HUD содержит clean essential-only набор SCRUM-671/SCRUM-666: HP, XP,
money, ULT, таймер, бейдж Возвышения и bottom-right level-up plus/count control.
SCRUM-874: в боссовом и элитном бою добавляется **HUD-боссбар** по центру верха
(`BossHudNameLabel` + `BossHudTrack/BossHudBar`, зоны `HUD_V2_BOSS_NAME_2K`/
`HUD_V2_BOSS_BAR_2K` ниже кластера и таймера): имя цели + крупная полоса HP,
ведётся `_update_boss_hud_bar()` по `game.boss_hud_target` (ставит
`combat_director` в `_spawn_boss`/`_spawn_elite_enemy`, снимает `_end_combat`).
У акт-босса и элитки узла (профили `boss`/`elite`) плавающая полоса над спрайтом
НЕ создаётся (`enemy._uses_hud_boss_bar`); мини-элитки волн и обычные мобы
остаются с плавающей полосой. На смерти цели полоса доводится в ноль на время
death-анимации, затем панель гаснет; вне босс/элит боя панель скрыта.
Старые `ArtifactHudRow` и `CharacterStatsHud` в боевом overlay больше не
создаются. Tooltip ULT показывает текущую клавишу и состояние готовности.
`ultimate_multiplier` больше не зарезервирован: он усиливает урон, радиус,
длительность или число целей ульты. По боссам действует per-hit cap от max HP
босса. Верхний HUD обязан проходить no-overlap проверку фактических
`global_rect`: ресурсная панель, таймер/бейдж Возвышения и plus/count control
адаптивно размещаются без пересечений на 1152x648, 1280x720 и 2560x1440.
Runtime использует существующие generated HUD/theme assets, но размещает
контент по accepted safe zones из
`docs/design/mockups/scrum666_combat_hud_2k/ui_plan.json` /
`layout.json`; тесты падают, если контент выходит на рамки/орнамент или если
старые HUD-полосы возвращаются.

UI no-overlap coverage 0.1.4: `tests/ui_no_overlap_matrix_test.gd` проверяет peer-controls main menu, settings, Codex, patch notes, hero select, Level Up, victory и death на 1152x648, 1280x720, 1600x900 и 2560x1440, а `runtime_smoke_test.gd` дополнительно держит специализированные проверки HUD, shop wall, hero radar, route/level-up/elite reward flows. Matrix dump пишется в `build/qa/ui_no_overlap_matrix.md`; Level Up focused SCRUM-683 dump пишется в `build/qa/scrum683/level_up_no_overlap_matrix.md`.

Runtime smoke split 0.1.4: focused suites наследуют helper/assertion слой umbrella smoke и запускают тематические подмножества без изменения gameplay behavior. Это дает быстрые проверки для UI/menu, combat, progression/economy, weapon mechanics и boss/elite перед крупными refactor-задачами, но обязательная полная команда `runtime_smoke_test.gd` остается доступной и должна проходить.

Реализованные ульты: Берсерк — Неистовство; Солдат — Огневой приказ; Вор — Черная метка; Элементалист — Стихийная Сверхнова; Снайпер — Последний Выстрел; Священник — Хор Искупления; Биолог — Пробуждение Колонии; Темный маг — Темная буря; Гитарист — Соло; Ассасин — Танец клинков; Рейнджер — Лунный залп; Доктор — Переливание; Химик — Цепная реакция; Рыцарь — Бастион; Друид — Зов стаи.

## Звук

Звуковая система реализована через autoload `AudioManager` (`scripts/audio_manager.gd`, регистрация в `project.godot`):

- SFX (15 ogg-id, SCRUM-967/968): `hit`/`hit_magic`/`hit_dot` (типизированные попадания по `feedback.damage_type` в `enemy.take_damage`), `player_hit`, `dodge`, `pickup_xp`, `pickup_money`, `level_up`, `boss_phase` (смена фазы босса), `low_hp_pulse` (луп-канал `set_sfx_loop`, гистерезис HP ВКЛ<30%/ВЫКЛ≥34% — зеркалит виньетку). `purchase`/`ui_error` работают для покупок/отказов в магазине узла, докачке, Атласе и платных вариантах события; общий `_connect_ui_sfx` добавляет `ui_click`/`ui_back` к кнопкам перехода/возврата; `artifact_reveal` озвучивает баннер победы и elite/boss-экраны награды.
- Музыка (SCRUM-966/968, бардовский пак, `MUSIC_META` + loop_offset): меню `music_menu_tavern_warm`, карта/атлас `music_route_map_bard_journey`, safe-узлы `music_shop_campfire_inn`; обычный бой — shuffle-bag ротация 4 тем (без повтора подряд, session-only, мягкий динамический приоритет акта); элитка `music_elite_duel_300`, boss Act 1 `music_boss_battle_300`, финальный boss Act 2/secret boss `music_final_boss_crescendo_300`; прежний приоритет удалённого третьего акта не активируется; 3 стингера результата.
- Round-timed playback (SCRUM-968): бой стартует `play_combat_music(kind, реальная длительность раунда)`; за 6 c (8 c элитка/боссы) до конца таймера — идемпотентный `begin_music_outro` (затухание к нулю таймера, по игровому тику — пауза не рассинхронизирует); ранний конец — fast-outro 1.2 c; поверх тишины стингер победы/эпик-победы/поражения.
- Источники/лицензии: `docs/design/audio.md` + `docs/design/references/audio_sources/SOURCES.md`; CC BY-атрибуции (Kevin MacLeod ×6) — `docs/CREDITS.md`. Из главного меню `MainMenuCreditsButton` открывает player-facing `CreditsScreen` с CC BY/CC0-блоками; `CreditsBackButton` и Escape возвращают в меню.
- Пул из 8 SFX-плееров и троттлинг 0.05с на звук (пер-id overrides: `hit_dot` 0.12, пикапы 0.06, `ui_error` 0.08) защищают от спама при уроне по толпе.
- В headless-режиме (smoke tests) аудио полностью отключено, чтобы не оставлять висячие AudioStreamPlayback при выходе.
- Громкость: музыка -8 dB, SFX -4 dB, bus chain `UI -> SFX -> Master`. `ui_click`/`ui_back`/`ui_error` используют UI, остальные 12 cues остаются на SFX. Новые профили стартуют без звука: `music_enabled=false` и `sfx_enabled=false`, при этом `master_volume`/`music_volume`/`sfx_volume`/`ui_volume` остаются 100%. Нулевой `master_volume` задает очень тихую громкость, но не hard-mute'ит Master bus; отдельный `mute_when_unfocused` hard-mute'ит его только вне фокуса. `low_hp_warning_enabled` гейтит existing pulse, сохраняя requested loop state. Старые `user://settings.cfg` с `master_volume <= 0` и без `master_zero_intent` мигрируют к дефолтным 100%, чтобы случайно «залипшая» тишина не переживала перезапуск. Кроссфейд музыки при прерывании твина сбрасывает fade-player и восстанавливает целевую громкость текущего трека.

## Флоу Победы И Докачка (обновлено 2026-07-10)

- После обычного победного боя: затемнение + крупная золотая надпись «ПОБЕДА» (клик или 1.3с) -> окно докачки атрибутов -> карта.
- После элитного победного боя: «ПОБЕДА» -> экран выбора 1 из 3 артефактов -> окно докачки атрибутов -> карта.
- Босс ведет на отдельный экран победы, как раньше; дополнительно игрок получает гарантированный tier-3 артефакт и крупное золото.
- FAN-1077: успешный итог добавляет прокручиваемый журнал всех новых артефактов/героев/оружия в порядке получения. При непустом журнале сводка сжимается до времени, убийств, золота и финального уровня, не обрезая список открытий.
- Окно докачки: выбор 1 из 2 случайных характеристик (+1) за `ProgressionData.stage_scaled_cost(18 + 6 * route_stage, route_stage)` золота; «Обновить» пары за `stage_scaled_cost(6 + 2 * route_stage, route_stage)` (2 раза за окно); «Пропустить»; Escape = пропуск.
- Кнопка возврата к level-up появляется при непотраченных выборах в бою и на небоевых экранах; она открывает тот же зафиксированный набор из 3 карт и показывает pending-бейдж. В бою это SCRUM-390 квадратная `LevelUpPlusButton` с символом `+`, закрепленная в правом нижнем углу, полностью непрозрачная и использующая dedicated combat HUD plus textures с нейтральным hover/focus без желтого свечения. SCRUM-982 удаляет прежний `UpgradeFabButton` для ручной платной докачки и при наличии, и при отсутствии pending-уровней на Route Map/Rest/Shop/Event/Escape; это не затрагивает `LevelUpPlusButton`, который остаётся единственной точкой возврата к сохранённому level-up набору при `pending_level_ups > 0`. Кнопка «Позже» на самом level-up окне использует SCRUM-682 dedicated later-button textures and responsive safe-zone placement, чтобы текст, орнамент и весь контрол оставались внутри viewport/content-зоны даже на 1280x720. При самом событии получения уровня HUD-toast использует SCRUM-588 generated @2K frame `assets/sprites/ui/frames/overhaul_2k/ui_frame_2k_lut_toast.png` (`480x300`, content margins `70/112/70/112`), центрируется на `190px` выше экранной позиции героя, поднимается только до `0.70` opacity и показывает единственный текст `Level Up` внутри пустой зоны этой рамки; world-space `LevelUpEffect` рядом с героем оставлен только как flash/ring/spark burst без отдельной текстовой плашки. Быстрые несколько level-up создают self-cleaning эффекты/toasts и не меняют XP/reward/pause flow.

SCRUM-654/SCRUM-663 cleanup now resolves to a single visible level-up plaque: `LevelUpToastLabel` is the only runtime `Level Up` text and it stays inside `LevelUpToastFrame` safe margins. `LevelUpEffect` replaces older live `LevelUpEffect` nodes in the `level_up_effects` group on rapid level-up bursts, follows the player, and must not create `LevelUpPopupBadge` or any `Label` with level-up text. `LevelUpToast` joins `level_up_effects` for cleanup so screen/world cleanup cannot leave orphan toast effects behind.

## Навигация И UX

- Escape = назад на меню/предзабеговых экранах через единый стек: главное меню -> игровой диалог подтверждения выхода, настройки/кодекс/выбор персонажа -> меню; выбор оружия -> выбор персонажа. Кнопка «Выйти из игры» в главном меню открывает тот же `QuitConfirmationDialog`; реальный quit вызывается только по «Выйти», а «Отмена» в фокусе по умолчанию. В активном бою Escape сразу открывает досье/доску персонажа с левыми run-controls (Продолжить, Настройки, Завершить забег, Главное меню), ставит gameplay на паузу и не показывает старое standalone pause menu поверх или вместо доски. Повторный Escape или «Продолжить» закрывают overlay и возвращают в тот же run state без изменения таймера, позиции, предметов и прогресса. На route map, в магазине, level-up, докачке атрибутов, событии и награде элитки сохраняется существующая pause-overlay семантика поверх текущего экрана без reroll/сброса; событие по-прежнему требует выбора действия, если skip не разрешен.
- `P` открывает фидбек/bug-report overlay поверх текущего экрана через отдельный top-level `FeedbackOverlayLayer`, не очищая текущий UI и не сбрасывая состояние магазина/карты/level-up. Escape/B закрывает только форму, ввод остаётся в `FeedbackTextEdit`; Tab/D-pad ведёт к `FeedbackScreenshotToggle`, затем к Send/Cancel. На 720p прокручивается только middle body, а title/status/actions остаются закреплены.
- Экран выбора героя — fullscreen `HeroSelectScreen`: активный runtime
  (SCRUM-798 поверх редизайна пользователя 2026-06-30) убирает все декоративные
  UI-рамки, PixelLab backdrop, title frame и compass/radar. Экран строится на
  `HS4BlackBackground`: слева крупный responsive `HS4Portrait` с направленной
  preview-rotation для PixelLab-классов и static `sprite_path` fallback для
  остальных; `HS4ChooseButton` расположен под превью, а широкий правый
  `HS4AscensionFrame` между досье и каруселью содержит унифицированные широкие
  `−`/`+` и строго центрированный текст `Возвышение N`, а полные модификаторы
  доступны только в tooltip; справа
  находится scroll-safe `HS4DossierFrame` с описанием, сильными/слабыми
  сторонами, оружием, class identity, восемью характеристиками как hoverable
  Line Bars и data-driven секциями `Основные атрибуты`,
  `Второстепенные атрибуты`, `Дополнительные атрибуты`; снизу `HS4Carousel` с
  увеличенными responsive слотами. SCRUM-1063 возвращает бесконечный цикл
  first↔last поверх сдвига окна по одному герою и синхронизирует окно/выбор/
  досье/портрет/счётчик для pointer, keyboard и gamepad. Стрелки и Ascension
  используют одну принятую PixelLab 9-slice плиту с authored content margins. Select,
  Back/Escape, ascension stepper, default focus and carousel interaction behavior
  are preserved. Focused coverage: `tests/hero_select_pixellab_layout_test.gd`,
  `tests/hero_select_scrum798_capture_test.gd`,
  `tests/hero_select_scrum980_ascension_layout_test.gd`, existing Berserk/Dark Mage/Guitarist Hero Select preview
  smokes, `runtime_smoke_ui_test.gd`, and `ui_no_overlap_matrix_test.gd`.
- Размеры изображений: кодекс — персонажи 216px with covered scaling (SCRUM-417), монстры 150px, артефакты 96px; HUD-артефакты 48px; пауза-артефакты 56px; иконки магазина 112px внутри frameless hit area 164x186.
- Фон маршрутной карты: если существует `assets/backgrounds/route_map_backdrop.png`, он подключается с cover-растяжением и затемнением 0.62 для читаемости узлов; иначе — прежний однотонный фон (graceful fallback до выхода арта).

## Кодекс (Энциклопедия)

FAN-1098 replaces the already-wired Codex background at
`assets/sprites/ui/atlas_style/codex/bg_codex_sanctum.png` with a cohesive
2560x1440 RGB draconic archive created exclusively through the built-in OpenAI
Image Generator in Codex. PixelLab and the OpenAI Images API were not used.
Runtime layout, controls, text, focus, and data are unchanged. Actual Godot
captures at 1280x720, 1920x1080, and 2560x1440, the prompt, hashes, safe-zone
report, previous-asset backup, and implementation spec live under
`docs/design/{references,mockups,previews,backups}/fan1098_codex_openai_background/`.

Кнопка «Кодекс» в главном меню открывает внутриигровую энциклопедию (`_show_codex_screen` в `scripts/ui_screens.gd`). Данные — data-driven из `scripts/codex_data.gd`: персонажи/оружие/артефакты/характеристики собираются из `progression_data.gd` и `stat_formulas.gd`, описания монстров и канонические имена умений живут в `CODEX_DATA.MONSTERS` и зарегистрированы в `docs/design/content_registry.md` (раздел «Умения Монстров»). SCRUM-438 rebuild сделал live Codex v2: единый main frame, вертикальные вкладки слева, центральный scrollable список записей и правый detail panel с портретом/чипами/текстом. SCRUM-725 заменил старую геометрию на accepted `docs/design/mockups/codex_redesign_2026_06/layout_map.md` с `codex_pl_backdrop`, textless 9-slice `codex_pl` frame set and safe cream/gold text. SCRUM-849 prepared the object-first source package (`docs/design/mockups/codex_object_first_redesign/spec.md`, `layout_zones.json`, preview/contact PNGs), and SCRUM-850 made that package live in runtime: base 1920x1080 rects are `CodexMainPanel` 72,54,1776,972; `CodexNavPanel` 96,210,300,700; `CodexContent` 438,210,490,700; `CodexDetailPanel` 960,210,840,700. SCRUM-884 then simplified the center column to the list-only flow (no object preview stage), and SCRUM-889 removes the live `Глоссарий` category entirely. The right detail overlay has a larger contained portrait/icon stage, chip row and `CodexDetailParchmentInset` body text. Character portraits still use the SCRUM-416 full-frame idle `sprite_path` source as Hero Select, while artifacts use canonical artifact/shop icons. QA path/rect dumps: `build/qa/scrum416/codex_character_portrait_runtime_paths.md`, `build/qa/scrum417/codex_character_portrait_runtime_dump.md`, `build/qa/scrum438/codex_v2_runtime_dump.md`, `build/qa/scrum438/codex_v2_no_overlap_matrix.md`; SCRUM-725 source/evidence: `docs/design/references/codex_redesign_2026_06/`, `docs/design/previews/codex_redesign_2026_06_runtime_contact.png`, `build/qa/design_review/codex_1280x720.png`, `build/qa/design_review/codex_1920x1080.png`, `build/qa/design_review/codex_2560x1440.png`; SCRUM-850 screenshot evidence: `build/qa/codex_object_first/`.

SCRUM-621 adds backend unlock state for future Codex filtering; FAN-1077 extends
the persistent meta set to `discovered_characters`, `discovered_weapons`,
`discovered_monsters`, `discovered_bosses` and `discovered_artifacts`.
The live Codex data projection still exposes the full canonical roster, while
runtime gameplay hooks populate the discovery lists as the player sees enemies
and receives artifacts.

FAN-1077 adds persistent unread presentation without changing that availability
contract. A generated red/gold exclamation badge marks the Main Menu Codex
action, affected category tabs and unread-first rows. Weapons remain nested in
character dossiers, so an unread weapon raises and marks its owner row; an
explicit row open clears every aggregated mark and saves immediately. Run-local
`new_unlocks` records power the complete scrollable victory journal. Character
and weapon unlock conditions remain intentionally undefined, and the existing
roster stays accessible until that progression design lands.

SCRUM-955 реализует принятый PixelLab/content-zone пакет SCRUM-1013 и строго
разделяет справочник параметров. Live-навигация теперь содержит шесть русских
вкладок: `Персонажи`, `Монстры`, `Артефакты`, `Характеристики`, `Атрибуты`,
`Возвышение`. `Характеристики` показывает ровно 8 записей в порядке
`StatFormulas.BASE_STAT_ORDER`, `Атрибуты` — 26 записей текущего
`DERIVED_STAT_ORDER`; смешанная вкладка `stats` и множественное
`Возвышения` удалены. В правом досье иконка/портрет и отдельный прокручиваемый
список связанных параметров занимают левую безопасную зону, а заголовок, чипы
и текст — правую. SCRUM-1021 заменяет ошибочный поиск связей по локализованному
тексту на `StatFormulas.DERIVED_BASE_DEPENDENCIES`: полную 26-строчную
машиночитаемую матрицу, сверенную с `ProgressionData.derived_parameters`.
Производные показывают базовые зависимости в `BASE_STAT_ORDER`, базовые —
точную обратную проекцию в `DERIVED_STAT_ORDER`; `Сила ульты` включает все
восемь характеристик, а лексические совпадения больше не создают ложные связи.
Player-facing названия, описания и влияния характеристик
русскоязычны; raw ids убраны из строк и чипов персонажей, монстров и параметров.

FAN-1047 сохраняет эту трёхколоночную геометрию, но убирает жёлтое исключение
`minimal/codex_tab`: шесть `CodexTab_*` используют точную
`text/main_menu_380x104` production-семью с равномерным масштабированием в
`260×72`. Компактные подписи `Параметры` и `Возвыш.` остаются внутри label lane,
а все пять состояний сохраняют одинаковые bounds и content margins.

Остальные разделы: Персонажи (17 игровых классов, стиль игры, сильные/слабые
стороны, оружие), Монстры (31 запись: 11 обычных + 4 элитки + 10 мини-элиток +
6 боссов, поведение и названные умения), Артефакты (все из `ARTIFACTS` +
`SHOP_ITEMS` с иконками), Возвышение (5 уровней). Раздел `Глоссарий` больше не
показывается в live Codex; `scripts/glossary.gd` остаётся справочным
data/helper источником для внутренних пояснений. Разделы строятся лениво при
первом открытии вкладки и кэшируются — меню не фризит.

SCRUM-345/SCRUM-403 подключили отдельный Codex texture kit в стиле D&D/Dark
Fantasy Dragon: `assets/sprites/ui/frames/codex/ui_frame_codex_*.png`,
reference `docs/design/references/codex/codex_ui_texture_kit_reference.png`,
safe-zone metadata
`docs/design/references/codex/codex_ui_texture_kit_metadata.json` и превью
`docs/design/previews/codex_ui_texture_kit_contact.png`. В runtime
`scripts/ui_screens.gd` использует эти texture frames только для `CodexScreen`,
`CodexTabs`, `CodexContent`, entry cards и portrait/icon slots; остальной UI
остается на своих глобальных рамках. `GlossaryTooltipPanel` больше не создаётся
в live Codex. Smoke
проверяет фактические texture paths, а QA dump пишется в
`build/qa/scrum345/codex_texture_runtime_dump.md`.

SCRUM-438 подключил Codex v2 rebuild в runtime по OpenAI-generated package:
mockup `docs/design/mockups/scrum438_codex_v2/codex_v2_mockup_1920x1080.png`,
safe-zone overlay
`docs/design/mockups/scrum438_codex_v2/codex_v2_safe_zones_annotated_1920x1080.png`,
spec `docs/design/mockups/scrum438_codex_v2/spec.md` and machine-readable
layout metadata
`docs/design/mockups/scrum438_codex_v2/codex_v2_layout_metadata.json`. Runtime
uses real Controls and the accepted Codex frame kit paths, not the full mockup
PNG as a baked atlas; old texture paths remain because the v2 pass reuses them
as component frames instead of replacing art.

SCRUM-331 prepared a Design-ready progression/skill-tree frame kit and mockup
while preserving the existing Codex kit. Mockup/spec:
`docs/design/mockups/scrum331_progression_codex/`; runtime-ready assets:
`assets/sprites/ui/frames/progression/`; preview:
`docs/design/previews/scrum331_progression_frame_kit_contact.png`. The kit
defines main skill-tree panel, branch panel, circular node states, class
progression panel, points badge and tooltip safe zones. SCRUM-408 integrates
those frames into the live skill-tree screen: `SkillTreeMainPanel`,
`SkillTreeClassPanel`, `SkillTreePointsBadge`, `SkillTreeBranchPanel_*` and
`SkillNode_*` use the progression kit, long node title/description text is kept
outside circular rings in adjacent labels/tooltips, and Codex remains on the
accepted SCRUM-345/SCRUM-403 frame kit. QA dumps: `build/qa/scrum331/`.

## Пауза

Система паузы реализована через причины паузы. Основные причины:
- `escape_menu`;
- `level_up`.

При активной паузе:
- `get_tree().paused = true`;
- UI продолжает работать;
- состояние gameplay объектов замораживается;
- скорость игрока, врагов, боссов, снарядов и pickups обнуляется;
- таймер не идет;
- камера не двигается.

Пауза используется при:
- Escape menu;
- выборе награды за уровень.

## UI

Реализованные UI-состояния:

| Экран | Описание |
| --- | --- |
| Главное меню | SCRUM-1059: принятые battle-art фон, логотип и полая `meta40/frame_border.png` рама сохранены; шесть действий размещены одной адаптивной вертикальной колонкой слева внутри authored inner-zone (320×54 @1152×648 → 380×96 @2K), без scrollbar; SCRUM-1080/1093/1095 держит компактный utility-блок справа снизу: неизменный PixelLab Gratitude PNG рисуется через alpha-aware runtime `AtlasTexture`, icon-only благодарности стоят сразу слева от динамической версии, чей прямоугольник равен ширине live-строки + 6px и заканчивается за 8px до frame-safe границы; glow-to-label gap = 2px, реальные alpha-to-glyph gaps = 15/17/17/19px на 1280/1920/2048/2560, длинный будущий semver не клампится; Up/Down образует кольцо колонки, Right ведёт к благодарностям |
| Настройки | Четыре вкладки «Экран» / «Звук» / «Управление» / «Игра»: Atlas Settings shell, монитор, режим окна, HiDPI-aware разрешения 2560x1440/1920x1080, audio, rebinding, gameplay sandbox и FAN-1112 ручная проверка GitHub-обновления кнопкой «Обновить игру» на первых трёх вкладках |
| Выбор персонажа | Live HS4/Atlas layout: слева крупное responsive rotating selected hero preview и старт, справа scroll-safe structured dossier SCRUM-1064 (trait → имя → 3 оружия → top-3 BASE_STATS → primary/secondary/weak без прозы/тримминга) + фиксированные 8 stat Line Bars; SCRUM-1063 `HS4AscensionFrame` показывает unified wide `−` / `Возвышение N` / `+` с tooltip-only модификаторами; нижняя carousel циклично синхронизирует first↔last для pointer/keyboard/gamepad и сохраняет ≥3 слота |
| Выбор оружия | SCRUM-870 native redraw: no `WeaponSelectPixelLabRuntimeLayer`; dark opaque `MenuPanel_weapon_select`, three large `1674x260` live `WeaponOption_*` cards with `204x204` icon wells, `176x176` weapon sprites, readable title/`Отличие:`/concise mechanic/role text, right stat panel for range/radius/cooldown/context, normal fantasy Back button, and preserved mouse/keyboard/gamepad flow |
| Карта маршрута | SCRUM-1057/1079: horizontal left-to-right карта внутри общей полой gold shell; header/title, боевой resource HUD, node viewport, bottom horizontal lane и pending-level FAB находятся в точных five-target safe-зонах; vertical scroll отключён |
| Боевой HUD | SCRUM-390 ресурсная панель: HP, XP, деньги, ULT, таймер/бейдж Возвышения и ряд артефактов с no-overlap layout |
| Level-up | Экран выбора 1 из 3 наград с частицами, advisor-акцентом и отложенным выбором через нижнюю кнопку; SCRUM-985 убирает крупную внешнюю раму, оставляет яркий arcane-lab фон и локальные карточки/сокеты, а reward icon строго удерживает внутри socket safe-zone; visible formula-driven effect-preview и полноразмерная кликабельная карточка сохранены |
| Награда за бой / элитку | Обычная Battle Reward страница получила SCRUM-981 outer gold shell и compact 720–900p card tier; три локальные карточки остаются полностью кликабельными внутри body safe-zone. Elite/boss reward variants сохраняют собственные child-task contracts |
| Магазин | Frameless wall-предметы поверх canonical shop backdrop `ui_backdrop_merchant_archive.png`: иконка, тень, компактная цена, описание только hover tooltip, unavailable dim/price и empty-hook после покупки |
| Событие | Выбор одного из вариантов события поверх canonical event backdrop `ui_backdrop_arcane_lab.png`; длинный текст исхода находится внутри SCRUM-437 wide economy choice-card safe-zone, риск маркируется один раз без дубля `Риск: Риск:` |
| Отдых | SCRUM-981 outer gold shell поверх canonical system/campfire backdrop; общий resource HUD и FAB занимают отдельную верхнюю safe-полосу, лечение/защитный бонус/Back остаются внутри scroll-safe локальной панели с compact tier |
| Pause menu / stats | В активном бою Escape сразу открывает SCRUM-983/1056/FAN-1047 hero dossier внутри общей полой `meta40/frame_border.png` shell. Экран использует всю frame-safe область без scrollbars: hero/derived-колонки остаются слева, оружие/ульта/артефакты сохраняются в видимой build-summary строке с полным tooltip. Четыре действия используют точную `main_menu_380x104` family без обрезки: на 648p/720p/900p это правая вертикальная action-колонка, на 1080p/2K — горизонтальный footer. Все texture/content margins масштабируются одинаково во всех пяти состояниях. Контент, hitboxes и focus outlines остаются внутри inner rect на 1152×648, 1280×720, 1600×900, 1920×1080 и 2560×1440; B/Escape и Continue сохраняют прежний pause-stack/run state. |
| Смерть | SCRUM-981 outer gold shell вокруг локального Defeat result modal; summary и responsive action plate остаются внутри frame safe-zone |
| Победа | SCRUM-981 outer gold shell вокруг локального Victory result modal; русский итог, crest, summary и responsive action plate остаются внутри frame safe-zone. SCRUM-986 центрирует и короткий transient `VictoryBannerFrame` на любом viewport без 720p clipping |

SCRUM-981 применяет один runtime asset
`assets/sprites/ui/meta40/frame_border.png` как полую outer shell (`1536×1024`,
160 px rails, `draw_center=false`) к Main Menu, Route Map, Rest, Upgrade,
Battle Reward, Victory и Defeat. Точные safe-зоны: `[133,113,1014,494]` @720p,
`[200,169,1520,742]` @1080p, `[267,225,2026,990]` @1440p. Codex,
Level Up, Combat/HUD, transient overlays и specialist child-task screens остаются
явными исключениями. Source/evidence:
`docs/design/mockups/scrum981_gold_menu_shell/`, `build/qa/scrum981/`.

HP, XP и деньги должны оставаться видимыми на карте, в событиях и в магазине.

Обновление 2026-06-12 (артефакты, таймер и no-overlap HUD):
- Игрок хранит артефакты как `{id, title}` (`scripts/player.gd`); id используется для иконок, формат совместим со старыми title-записями.
- Боевой HUD показывает ряд иконок подобранных артефактов 40px в правом верхнем углу (`ArtifactHudRow`, HFlowContainer с переносом) с tooltip «название + эффект»; ряд перестраивается только при изменении количества артефактов. Если на узком окне верхняя полоса занята ресурсами/таймером/бейджем, ряд артефактов переносится ниже, чтобы HUD-плашки не пересекались.
- Меню паузы содержит блок «Артефакты» под базовыми характеристиками (`ArtifactsList` в `scripts/pause_stats_menu.gd`): иконки с tooltip, либо подпись «Пока не найдено».
- Таймер боя — стилизованная верхняя панель (`CombatTimerPanel`, формат M:SS); при остатке <=5 секунд цифры и рамка краснеют с легкой пульсацией. На широких окнах таймер остается по центру; на узких он смещается вправо от ресурсной панели. Таймер-панель (`CombatTimerPanel`/`timer_label`) создаётся только в обычных/элитных боях; на босс-файтах панель не создаётся, вместо неё может показываться `AscensionHudBadge`. Примечание (SCRUM-785): внутренне у босса теперь действует жёсткий 5-минутный лимит «убей или проиграл», но визуальная таймер-панель по-прежнему опускается (`_test_boss_hud_omits_timer`) — отображение боссового лимита в HUD остаётся открытым UX-вопросом (вне scope backend-таймера).
- Магазин: товары больше не лежат в карточной 2x2 сетке. `ShopParchmentWall` держит свободно расставленные wall hit areas на «пустой стене» фона правее торговца (анкеры ~50-82% ширины и 10-72% высоты экрана), чтобы предметы выглядели подвешенными на стене лавки. Runtime smoke пишет `build/qa/shop_wall_frameless_rects.md` и проверяет, что hit areas/иконки/ценники не пересекаются между собой и верхним HUD на 1280x720 и 2560x1440. Боевой экран не показывает полный список характеристик, оружие, артефакты, stage/debug text или derived-stat dump; подробности живут в Escape stats menu и reward UI.

Shop visual kit asset-ready (слот/hover frame больше не используется активным wall layout, но оставлен как совместимый asset):
- `assets/sprites/ui/shop/ui_shop_artifact_slot_frame.png`;
- `assets/sprites/ui/shop/ui_shop_artifact_slot_hover.png`;
- `assets/sprites/ui/shop/ui_shop_price_badge.png`;
- `assets/sprites/ui/shop/ui_shop_purchased_overlay.png`;
- `assets/sprites/ui/shop/ui_shop_tooltip_frame.png`.

Game cursor asset-ready:
- default: `assets/sprites/ui/cursor/game_cursor.png`;
- hover: `assets/sprites/ui/cursor/game_cursor_hover.png`;
- attack: `assets/sprites/ui/cursor/game_cursor_attack.png`;
- hotspot: `(2, 2)`.
- style: dark steel dragon/clawed pointer with a sharp upper-left tip, orange fire glow and red gem/eye; hover/attack reuse the same silhouette with stronger warm glow.

Централизованный mapping UI-иконок находится в `scripts/ui_icon_registry.gd`. Он покрывает 8 базовых характеристик, все активные производные параметры из Escape stats menu и HUD-ресурсы `hp`, `xp`, `money`, `ultimate_multiplier`. Финальные polished stylized fantasy cartoon PNG лежат в `assets/sprites/ui/icons/stats/`, `assets/sprites/ui/icons/derived/` и `assets/sprites/ui/hud/`; registry автоматически подхватывает реальные текстуры для боевого HUD, level-up reward cards, Escape stats menu, Кодекса и stat/reward/tooltips. Для производных параметров, у которых пока нет отдельного Design PNG (`absorb`, `regeneration`, `vampiric_*`, `range_multiplier`, `knockback_distance`, `ultimate_multiplier`), registry использует ближайшую существующую derived-иконку как backend fallback, без emoji/default placeholders. Shop item icons дополнительно разрешаются через реальные `artifact_<artifact_id>.png` / `shop_<shop_item_id>.png`; fallback в этот registry остается только fail-safe, если asset временно отсутствует.

Локализация и глоссарий (SCRUM-210/SCRUM-889): пользовательские строки ключевых экранов ведутся на русском; магазин, level-up rewards, HUD-ресурсы, кодексные описания и артефактные тиры больше не используют видимые `damage/HP/Tier/DoT/AoE` формулировки. Data-driven глоссарий живет в `scripts/glossary.gd` и покрывает базовые характеристики, производные параметры и основные механики (`Возвышение`, `Артефакт`, `Телеграф`, `Периодический урон`, `Ультимейт`, `Призыв` и т.д.), но больше не отображается отдельной вкладкой в live Codex. Старые term-button/tooltip UI пути удалены из `scripts/ui_screens.gd`.

Escape stats menu layout (SCRUM-1056 supersedes the SCRUM-983 overflow rules):
- The production shell remains `assets/sprites/ui/meta40/frame_border.png`: 160px source rails, `draw_center=false`, visual-only final layer. Inner reserves stay 24px (compact/1080p) or 32px (2K+); content never enters ornament.
- `HeroCardScroll` and `DerivedStatsScroll` remain clip owners but both horizontal and vertical scroll modes are disabled. Their content minimum height is asserted `<= viewport height`; hiding overflow is not accepted.
- `BaseStatsGrid` is always two columns. At compact heights it uses meaningful tight Russian labels while preserving 44px base rows/icons and 17/18px name/value text. Derived groups remain 2×2; the 648p tier hides only redundant group headings and uses tighter aliases while the visible colored/stat semantics and full tooltips remain.
- The former long Arsenal/Equipment prose is represented by always-visible `RunBuildSummaryPanel` (`Оружие`, `Ульта`, artifact count); its tooltip contains the complete weapon/ultimate descriptions and artifact names. The detailed portrait block appears at 2K, while the header keeps hero/weapon identity at smaller sizes.
- `PauseControlButtons` is a responsive `GridContainer`. Continue, Settings, End Run and Main Menu all use the exact `main_menu_380x104` normal/hover/focus/pressed/disabled textures with white tint and one uniform texture/content-margin scale. Compact targets use a right vertical rail (`219×60` at 648p; `263×72` at 720p/900p); 1080p/2K use a horizontal footer (`320×88` / `380×104`).
- The End Run confirmation uses two equal 240x72 `continue_240x72` buttons; the wider content band keeps both `Завершить` (including its final `ь`) and `Отмена` fully visible without changing the modal frame or safe Cancel focus.
- Verified rect/content-fit evidence covers 1152×648, 1280×720, 1600×900, 1920×1080 and 2560×1440 in `build/qa/scrum983/escape_dossier_visual_matrix.md`; focused/live-resize coverage is `tests/scrum983_escape_dossier_test.gd` and the repository matrix is `tests/ui_no_overlap_matrix_test.gd`.

Все стандартные UI-кнопки используют единый FantasyDisk style: темный fantasy-metal фон, золотая bevel-рамка, readable hover/pressed/disabled/focus состояния и тень. Level-up reward cards используют локальные Atlas/card surfaces с source-safe геометрией и частицами поверх яркого arcane-lab backdrop; SCRUM-985 не рисует вокруг всего экрана ещё одну декоративную раму. Full reward text remains available through tooltip when compact card text is line-limited.

Escape stats visual kit assets:
- `ui_escape_panel_frame.png` - outer menu frame;
- `ui_escape_button_frame.png` - run control buttons;
- `ui_stat_basic_row_frame.png` - compact base stat rows;
- `ui_stat_group_frame.png` - grouped derived stat sections;
- `ui_stat_chip_frame.png` - derived stat chips;
- `ui_stat_tooltip_frame.png` - custom tooltip frame;
- `ui_stat_section_divider.png` - optional group divider;
- `ui_stat_value_state_swatches.png` and `escape_stats_visual_kit_preview.png` - design references.

Sprite quality audit 2026-06-11: повторный полный аудит (`tools/sprite_quality_audit.py` — отчет/фикс грязных пикселей, островков, halo) + автопостобработка нарезки `fix_detached_fragments` в `tools/slice_rig_cutouts.py`, которая убирает обрезки соседних частей тела из подвижных конечностей (главная причина «лишних кусочков» на краях спрайтов в движении). UI-иконки с легитимными отдельными искрами island-фиксом не трогаются.

Sprite quality audit 2026-06-10: активные UI/gameplay элементы не должны использовать видимый Polygon2D-placeholder. Pickups отображаются Sprite2D через HUD PNG (`hud_xp.png` / `hud_money.png`), canonical player projectiles используют weapon-specific SCRUM-1066 profiles, а у `enemy_suicide_runner.png` удален лишний правый фрагмент текстуры.

## Враги

Базовый скрипт врагов: `scripts/enemy.gd`.

Общие возможности:
- полоса HP над каждым врагом (моб/элитка/босс/призванный полноценный враг): дешевый `_draw`-нод `scripts/enemy_health_bar.gd`, ширина пропорциональна видимому размеру спрайта, значение всегда синхронизируется как `health / max_health` через `refresh_health_bar()` после runtime-скейлинга и после получения урона; у элиток/боссов overhead-bar дополнительно клампится в видимый viewport, если крупный спрайт поднимает его за верхний край экрана, обычные враги остаются на прежней world-space привязке;
- contact_range автоматически подгоняется под фактический видимый размер спрайта (`_fit_contact_range_to_sprite`): радиус врага + радиус игрока, экспортное значение сцены остается минимумом;
- движение к игроку;
- ranged behavior с удержанием дистанции;
- contact damage через windup и cooldown;
- снаряды;
- призыв маленьких врагов;
- ground/flying collision profile;
- выпадение опыта и денег.

Стандартные враги:

| Архетип | Сцена | Спрайт | Роль |
| --- | --- | --- | --- |
| Ближний бой | `scenes/Enemy.tscn` | `enemy_melee.png` | Базовое давление толпой |
| Дальний бой | `scenes/EnemyShooter.tscn` | `enemy_ranged.png` | Редкие читаемые снаряды |
| Быстрый | `scenes/EnemyRunner.tscn` | `enemy_suicide_runner.png` | Быстро догоняет игрока |
| Жирный | `scenes/EnemyBruiser.tscn` | `enemy_bruiser_slow.png` | Медленный, высокий HP |
| Суммонер | `scenes/EnemySummoner.tscn` | `enemy_summoner.png` | Призывает мелких мобов |
| Маг | `scenes/EnemyMage.tscn` | `enemy_void_mage.png` | Магический ranged-вариант |
| Плевательщик | `scenes/EnemySpitter.tscn` | `enemy_venom_spitter.png` | Ranged pressure |
| Щитовик | `scenes/EnemyShield.tscn` | `enemy_rift_shieldbearer.png` | Защитный вариант |
| Кусачий | `scenes/EnemyBiter.tscn` | `enemy_small_biter.png` | Маленький быстрый враг |
| Костяной шаман | `scenes/EnemyBoneShaman.tscn` | `enemy_bone_shaman.png` | Вариант призывателя |
| Летающий | `scenes/EnemyFlyingRunner.tscn` | `enemy_winged_spark.png` | Летающее движение; pit layer отключен вместе с ямами |

## Снаряды Врагов

Сцена: `scenes/EnemyProjectile.tscn`.

Скрипт: `scripts/enemy_projectile.gd`.

Спрайт: `assets/sprites/projectiles/enemy_projectile_magic_64.png`.

Снаряд:
- летит по направлению к цели;
- наносит урон игроку;
- исчезает после попадания;
- удаляется по lifetime;
- удаляется за пределами арены.

## Снаряды Игрока И Pickups

Базовый снаряд игрока: `scenes/Projectile.tscn`, `scripts/projectile.gd`.

Активный визуал: data-driven SCRUM-1066 profile из
`docs/design/references/SCRUM-1065_player_projectiles/manifest.json`; legacy
scene defaults to `soldier_arquebus_round` and no longer embeds the generic
player spark.

Pickups: `scenes/Pickup.tscn`, `scripts/pickup.gd`.

Активные visual textures:
- XP pickup: `assets/sprites/ui/hud/hud_xp.png`;
- money pickup: `assets/sprites/ui/hud/hud_money.png`.

Старые Polygon2D diamond/triangle visuals больше не являются активным визуальным состоянием.

## Элитные Враги

Элитки выбираются случайно. Они должны быть примерно на порядок опаснее обычных врагов за счет HP, урона и паттернов. Обновление 2026-06-12: элитки используют `ProgressionData.stage_scale(route_stage)`, получают большой HP-бюджет под ~45-90с активного боя в budget estimate, имеют meta-флаг второй фазы на 50% HP и после победы открывают выбор 1 из 3 артефактов.

Обновление SCRUM-260 от 2026-06-13 + SCRUM-829 от 2026-07-02: размеры enemy-rank data-driven через `ProgressionData.ENEMY_SIZE_PROFILES`: ordinary 1.25, mini_elite 1.31, route elite 1.68, boss 1.90. Mini-элитки свиты Возвышения получают meta `epic_scale_profile=mini_elite` до `_ready()` и визуально читаются как усиленные мобы, карточные элитки стали крупнее и немного опаснее (HP x1.08, damage x1.06 в `_scale_elite_enemy`), боссы остаются крупнейшими. Один node scale тянет rig/body, `CollisionShape2D`, auto-fit contact_range и HP-bar.

Обновление SCRUM-259 от 2026-06-13: у элиток и боссов есть общий data-driven каталог `ProgressionData.ENEMY_MECHANIC_CATALOG`, боевые конфиги элиток `ELITE_ATTACK_CONFIGS` и unique-pattern registry `UNIQUE_ENCOUNTER_PATTERNS`. При `_ready()` сущность получает meta `unique_pattern_id`, `unique_pattern_title`, `unique_mechanics`; smoke проверяет каталог, неповторяемые signatures, telegraph/state phases и фактический spawn boss-specific mechanics. У каждой элитки есть уникальная телеграфированная активная атака со state machine `windup -> strike -> recover -> idle` (сигнал `elite_attack_phase_changed` для Animator). Во время атаки элитка стоит на месте; урон атаки ограничен 25% максимального HP игрока; от всех атак можно увернуться движением.

Обновление SCRUM-135 от 2026-06-12: активные source sprites всех 4 элиток заменены на native `512x512` и перенарезаны в `assets/sprites/elites/cutout/` с manifest `size = Vector2(512, 512)`. Поза/силуэт сохранены 1:1, поэтому хитбоксы, contact_range и epic scale остались прежними, а QHD/Retina-рендер больше не тянет 256px-арт выше native.

| Элитка | Сцена | Спрайт | Уникальное поведение |
| --- | --- | --- | --- |
| Железный Оплот | `scenes/EliteArmored.tscn` | `assets/sprites/elites/iron_bastion.png` | Щит; шипованный панцирь во время щита; Slam-волна: замах 0.6с, кольцо 260 с уроном и отбрасыванием |
| Ночной Сталкер | `scenes/EliteStalker.tscn` | `assets/sprites/elites/night_stalker.png` | Рывки; Теневой удар: уход в тень 0.5с, телепорт за спину игрока; во второй фазе зеркальный второй заход |
| Чумной Пророк | `scenes/ElitePoisoned.tscn` | `assets/sprites/elites/plague_prophet.png` | Ядовитые зоны; Ядовитый залп: lob-снаряды, лужи на 3с с тиками, чумная тематика healing inversion hook |
| Маршал Осколков | `scenes/EliteCommander.tscn` | `assets/sprites/elites/shard_marshal.png` | Аура усиления; Залп осколков: веер из 5 кристальных снарядов; фаза 2 добавляет кольцо осколков |

## Боссы

Босс выбирается случайно на финальном узле маршрута из QA-gated live rotation; `bloodthorn_lion` runtime-ready, но пока вне случайной route-ротации до отдельного QA-gated follow-up.

| Босс | ID | Сцена | Спрайт | Паттерны |
| --- | --- | --- | --- | --- |
| Rift Warden | `rift_warden` | `scenes/BossWarden.tscn` | `boss_rift_warden.png`; SCRUM-865 PixelLab full-frame rows | Залпы, зоны разлома, призыв, щит, увороты, gravity well |
| Disk Devourer | `disk_devourer` | `scenes/BossDiskDevourer.tscn` | `boss_disk_devourer.png`; SCRUM-865 PixelLab full-frame rows | Рывок, slam AoE, radial burst, vampiric bite, enrage |
| Bone Archon | `bone_archon` | `scenes/BossBoneArchon.tscn` | `boss_bone_archon.png`; SCRUM-865 PixelLab full-frame rows | Скелеты, веер черепов, bone prison/wall с проходом |
| Brood Mother | `brood_mother` | `scenes/BossBroodMother.tscn` | `boss_brood_mother.png`; SCRUM-865 PixelLab full-frame rows | Выводок, web slow zones, дополнительный web pressure, phase-3 lunge |
| Ashen Colossus | `ashen_colossus` | `scenes/BossAshenColossus.tscn` | `boss_ashen_colossus.png`; SCRUM-865 PixelLab full-frame rows | Slam-волны, ember fields, molten armor pulse, enrage |
| Кровавый Шипастый Лев | `bloodthorn_lion` | `scenes/BossBloodthornLion.tscn` | `boss_bloodthorn_lion.png`; SCRUM-865 PixelLab full-frame rows | Dash-pounce, radial thorn burst, bloodthorn spike ring, bleed-style rift zones, enrage; runtime implemented, not route-rotation yet |
| Костяной Дракон | `skeletal_dragon` | TBD | Design-source candidate `assets/sprites/bosses/pixellab_candidates/skeletal_dragon/skeletal_dragon_pixellab_alpha.png` | Planned flying skeletal boss; gameplay, scene and balance not implemented |

Боссы используют `scripts/boss.gd`, который расширяет логику обычного врага. Обновление 2026-06-12: каждый босс имеет 3 HP-фазы (`100-66%`, `66-33%`, `33-0%`), фазовые метки в meta/HP-bar, ускорение атак на фазах и danger-zone при переходе. Обновление SCRUM-259: boss-specific mechanics создают telegraph nodes (`BossGravityWell`, `BossVampiricBite`, `BossRiftZone`/bone prison, `BroodWebZone`, `BossMoltenArmorPulse`) и закреплены в `ProgressionData.UNIQUE_ENCOUNTER_PATTERNS`. HP/урон боссов масштабируются через ту же `stage_scale`, что и экономика.

Обновление SCRUM-135 от 2026-06-12: `boss_rift_warden.png` и `boss_disk_devourer.png` теперь native `512x512`, их boss cutout parts и `scripts/sliced_rig_manifest.gd` обновлены под 512px. `rift_warden` сохраняет отдельный `vortex` part; `disk_devourer` остается single-torso rig по текущему cutout CONFIG.

SCRUM-779 (2026-07-01) подготовил PixelLab-first Design-source package для
перерисовки текущих боссов и двух новых concepts. OpenAI image generation
создал concept references для `skeletal_dragon` и `bloodthorn_lion`, а PixelLab
MCP создал sprite candidates для current roster, `secret_ascension_boss` и двух
новых IDs. Пакет лежит в
`docs/design/references/bosses/pixellab_roster_redraw_2026_06/`, candidate
PNGs — в `assets/sprites/bosses/pixellab_candidates/`, previews — в
`docs/design/previews/boss_pixellab_roster_redraw_2026_06_*`. SCRUM-793
(2026-07-02) promoted only the accepted current-boss candidates:
`disk_devourer` PixelLab source `81b491db-7240-4513-bad5-263b7f81539d` and
`brood_mother` source `99d1c48c-ab86-4025-80b0-5a0ccb3d2edf` now populate the
existing live full-frame runtime rows while preserving SpriteFrames state names,
frame counts and boss gameplay callbacks. `secret_ascension_boss`,
`rift_warden`, `bone_archon`, `ashen_colossus`, `skeletal_dragon` and 8-dir
`bloodthorn_lion` remain source-only or revise-needed follow-up material. The
single-view `bloodthorn_lion` static sprite is live through SCRUM-794.
SCRUM-865 (2026-07-04) then completed the full PixelLab boss redraw runtime
pass: six supported `170x170` PixelLab 8-direction source objects produced
west-facing runtime rows for all six live bosses under
`assets/sprites/bosses/full_frame/`, preserving existing gameplay callbacks and
state names. `bloodthorn_lion` is now registered in `FullFrameAnimationRegistry`
with `skill_spike_ring` and `skill_rift_zone` visual hooks, but random route
promotion remains a separate QA-gated follow-up. QA evidence:
`build/qa/scrum793_boss_pixellab_promotion/` and
`docs/design/previews/boss_pixellab_full_redraw_2026_07_runtime_contact.png`.

## Спавн И Волны

Ключевые правила:
- монстры появляются волнами;
- активное количество врагов ограничено;
- враги могут появляться с одной или двух сторон волны;
- ранние волны избегают ситуации, где враги сразу давят со всех противоположных сторон;
- HP/урон/скорость/active cap и темп спавна растут плавно от `ProgressionData.stage_scale(route_stage) = pow(1.18, route_stage) + 0.075 * route_stage`;
- магазин, докачка атрибутов и reroll используют тот же множитель через `stage_scaled_cost`, чтобы сложность и экономика дорожали синхронно;
- маленькие враги могут появляться пачками по 3-4;
- дальнобойные враги появляются реже обычных;
- с каждым этапом и волной растут HP, урон и количество врагов.

Текущая базовая настройка:
- base spawn count: 5;
- normal active cap: 22 с ростом до global cap 48;
- elite active cap: 12;
- boss active cap: 12;
- spawn edge padding: 72 пикселя от физической границы арены;
- spawn safe radius around player/start: 420 пикселей;
- normal spawn limit: 10;
- глобальный потолок активных врагов: 48 (`max_active_cap`), включая поэтапный рост обычных и элитных боев;
- normal spawn pause: 0.7-1.2 секунды;
- boss spawn pause: 2.0-3.2 секунды.

SCRUM-853 усиливает pressure curve поверх этих базовых чисел: обычные волны
стартуют плотнее, затем получают multipliers от `route_scaling_stage`, номера
волны и elapsed time в бою; HP, контактная опасность/урон и cooldown спавна тоже
растут по этим осям. В Act 2 чаще выбираются ranged/summoner/heavy архетипы,
а обычные волны могут подмешивать mini-elites с шансом `0.015..0.12`.

Спавн использует реальные границы 4096x2304: правый и нижний edge-spawn больше не ограничены старой областью 2560x1440. Снаряды игрока и врагов удаляются только за пределами новой арены с cleanup margin 180 пикселей.

## Баланс Врагов

Обновление 2026-06-11 (10-этапный акт): базовые множители `ENEMY_BALANCE` подняты примерно на +10% HP и +8% урона у всех архетипов (например, default 3.1 HP / 1.25 damage, elite 4.6 HP / 2.10 damage, boss 1.9 HP / 1.46 damage). Поэтапный рост остался линейным, но акт теперь длиннее, поэтому добавлен жесткий потолок активных врагов 30.

Текущие модификаторы направлены на то, чтобы враги были жирнее, немного медленнее и появлялись меньшей плотностью, чем ранний прототип.

Основная идея:
- обычные враги имеют повышенный HP;
- элитки имеют сильно повышенный HP, урон и устойчивость;
- боссы сложнее за счет паттернов, HP, щитов, уворотов и ярости;
- скорость врагов снижена, чтобы игрок мог водить их и собирать группы.

## Анимации

Каноническая архитектура анимации движения находится в `scripts/cutout_rig_2d.gd`.

Архитектура нарезанного cutout-рига (2026-06-10):
- Источник данных — сгенерированный `scripts/sliced_rig_manifest.gd` (создается `tools/slice_rig_cutouts.py` вместе с PNG-частями в `assets/sprites/<group>/cutout/`).
- Иерархия: `RigRoot/Pelvis/Figure/Torso` + части `ArmL`, `ArmR`, `Weapon`, `Shield`, `WingL/R`, `Tail`, `Vortex` (дети `Torso`) и `LegL`, `LegR` (дети `Figure`). У каждой части пивот в суставе и спрайт-кусок исходного арта.
- В покое сборка пиксельно идентична исходному full-art PNG; зоны конечностей стерты из торса только за пределами силуэта тела (внутренние дырки заполнены инпейнтом), поэтому при взмахах нет дыр.
- Разворот в сторону движения — зеркалирование `Pelvis.scale.x`; вертикальное движение сохраняет горизонтальный facing. Манифест хранит `base_facing` (куда смотрит исходный арт): герои нарисованы вправо (+1), все мобы/элитки/боссы — влево (-1), поэтому моб, идущий вправо, зеркалится и не двигается спиной вперед. Итоговый знак: `facing_sign * base_facing`.
- Per-style профили движения: humanoid, heavy/guard, beast/stalker, robed, robed_walker, floating_robed, flyer, blob, colossus.
- Player polish 2026-06-11/13: `walk_blend_rate` и `direction_blend_rate` задаются профилем движения. `berserk`, `soldier`, `dark_mage`, `guitarist`, `assassin`, `ranger`, `doctor`, `chemist`, `knight`, `druid` имеют отдельные motion profiles, чтобы старт/остановка, разворот, weight shift и шаг не выглядели одинаково. Soldier profile — дисциплинированный средневесовый строевой шаг с умеренным bob и сдержанным arm swing.

Игрок:
- `scenes/Player.tscn` сохраняет `VisualRoot/Body` как скрытый `AnimatedSprite2D` fallback и источник кадров.
- Видимое движение строится через `VisualRoot/RigRoot` (нарезанный риг из манифеста).
- `WeaponSocket` остается в `VisualRoot` для совместимости с оружием, но после SCRUM-455 его позиция и вращение вычисляются как 104px orbit anchor по активному aim/attack direction; root оружия и `WeaponVisual` нормализуются за слой тела, чтобы не перекрывать full-frame героя.
- Берсерк, Темный маг и Гитарист переведены на общий нарезанный rig.
- Берсерк по-прежнему имеет `berserk_walk_sheet_v2.png` как fallback/resource animation sheet.
- Движение: сглаженный `walk_blend`, противофазные ноги с подъемом стопы, маховые руки, body bob, наклон в сторону движения, idle breathing. У Темного мага отдельный более спокойный walk profile с меньшим bob/lean и читаемым переносом веса после rework ног.

Канонические состояния игрока:
- `idle`
- `walk`
- `attack`
- `shoot`
- `cast`
- `hit`
- `death`

- Full-frame registry SCRUM-351: враги, элитки и боссы могут опционально использовать `FullFrameBody` с `SpriteFrames` из `scripts/full_frame_animation_registry.gd`; при отсутствии ресурса runtime автоматически оставляет старый `RigRoot`/static fallback. Elite/boss skill phases можно передавать как state variants (`<elite_behavior>:<attack_id>:<phase>`) без изменения mechanics/timing. SCRUM-352 подготовил 26 accepted transparent full-frame source sheets для всех стандартных врагов, route elites, mini-elites и боссов; SCRUM-394 обновил эти source sheets до `1704x1144` RGBA с `256x256` cells, `24px` discard-only gutters и `24px` outer padding, чтобы будущая нарезка не ловила соседние кадры. Манифест: `docs/design/references/scrum352_full_frame_sheets/scrum352_sheet_manifest.json`. SCRUM-363 подключил первый enemy pilot: `rift_cutter` использует `assets/sprites/enemies/full_frame/rift_cutter_spriteframes.tres` (`move` 6f loop, `attack_primary`/`attack`/`hit`/`death` 6f one-shot) через registry-only override без gameplay/balance changes. SCRUM-364 добавил тот же full-frame SpriteFrames contract для `ash_marksman`, `spark_runner`, `stone_bruiser`, `bone_caller` и `void_mage`; SCRUM-365 добавил `venom_spitter` и `rift_shieldbearer`; SCRUM-366 добавил `small_biter`; SCRUM-367 добавил `bone_shaman` и `winged_spark` (`hover_flap` loop + `hit` alias); SCRUM-368 добавил route elites `iron_bastion`, `night_stalker`, `plague_prophet` с `move`, `attack`/`attack_primary`, двумя `skill_*` rows и `attack_*` aliases per elite; SCRUM-371 добавил тот же contract для `shard_marshal` (`skill_shard_fan`, `skill_command_pulse`); SCRUM-372 добавил mini-elite visual ID hook: meta `mini_elite_kind` выбирает registered elite SpriteFrames entry, иначе fallback остается на base `elite_behavior`; SCRUM-376 подключил все 6 mini-elites как registered SpriteFrames entries; SCRUM-377 подключил 5 boss SpriteFrames entries (`rift_warden`, `disk_devourer`, `bone_archon`, `brood_mother`, `ashen_colossus`); SCRUM-378 подключил visual-only boss callbacks к matching `skill_*` rows без изменения boss mechanics/timing; SCRUM-379 добавил death lifecycle: стандартные full-frame враги с явным `death` row проигрывают его перед удалением, но сразу выходят из combat groups и отключают collision/HP bar после выдачи rewards. SCRUM-370 добавил `death` rows для 4 allies, 4 route elites, всех 6 mini-elites и всех 5 bosses; SCRUM-865 replaced all six live boss runtime rows from PixelLab and registered `bloodthorn_lion`; SCRUM-394 also rebuilt 19 Design death-row references to `1704x304` RGBA with the same safe-gutter contract.

Враги:
- стандартные враги, элитки и боссы по умолчанию используют общий `RigRoot` поверх существующего `Body` / `Sprite2D`, если для их canonical ID не задан full-frame SpriteFrames;
- исходный спрайт врага скрыт и остается источником текстуры и масштаба; видимая фигура собирается из cutout-частей того же арта;
- части тела берутся из `assets/sprites/enemies/cutout`, `assets/sprites/elites/cutout`, `assets/sprites/bosses/cutout`;
- `winged_spark` машет отдельными `wing_l`/`wing_r` (нарезанные крылья) и болтает лапами в полете;
- `ash_marksman` несет арбалет отдельной частью `weapon` (отдача при выстреле), `rift_shieldbearer` и `iron_bastion` — щит частью `shield`, `spark_runner` — хвост `tail`, `rift_warden` — вихрь `vortex` с постоянным покачиванием и пульсом;
- наземные враги шагают противофазными ногами с подъемом стопы и weight shift;
- shooter/mage/spitter имеют малую амплитуду, runner/biter/stalker — частую низкую походку, bruiser/shield/armored — тяжелый медленный sway, robed-касты — ritual sway без ног;
- элитки усиливают амплитуду rig-профиля;
- боссы используют colossus/blob профили с медленной heavy-анимацией.

Специальные движения атак (видимые жесты конечностей):
- `attack`: замах руки атаки назад (anticipation) и широкий удар вперед с выпадом корпуса и squash; у существ без конечностей (Disk Devourer, Venom Spitter) — лансж со squash-snap;
- `attack` Берсерка получает animation variant из текущего `weapon_id`: `sword` читается как короткий линейный thrust вперед, `axe` как широкая горизонтальная arc-поза, `hammer` как overhead lift + downward slam. Это визуальный слой rig-а; damage shapes, fire interval и active windows остаются в weapon/backend конфигурации.
- `shoot`: отдача корпуса и оружия/руки назад-вверх;
- `shoot` Солдата получает animation variant из текущего `weapon_id`: `soldier_rifle` — короткая отдача строевого залпа, `soldier_grenade` — cook/overhand throw, `soldier_bayonet` — forward defensive brace. Это только motion layer; `suppression_burst`, `grenade_cook`, `bayonet_brace` damage/timing остаются в `ClassWeapon`.
- `cast`: подъем обеих рук/посоха/черепа с подъемом корпуса и удержанием позы;
- Уникальные атаки элиток получают animation variant из backend-фазы `<elite_behavior>:<elite_attack_id>:<phase>` и используют длительность `windup/strike/recover` из `ProgressionData.ELITE_ATTACK_CONFIGS`: Iron Bastion поднимается в slam windup и резко проседает на strike; Night Stalker сжимается в crouch и делает forward lunge; Plague Prophet делает ritual arm raise/throw; Shard Marshal разводит руки и затем жестом выбрасывает shard fan.
- `hit`: красная вспышка и короткая тряска;
- `death`: full-frame враги с явным `FullFrameBody.death` проигрывают drawn death row перед delayed cleanup; враги без такого row оставляют `DeathGhostRig` (копию рига), которая падает, сминается и растворяется (`spawn_death_ghost` в `scripts/cutout_rig_2d.gd`).

Канонические файлы:
- rig controller: `scripts/cutout_rig_2d.gd`;
- player integration: `scripts/player.gd`;
- enemy integration: `scripts/enemy.gd`;
- boss action triggers: `scripts/boss.gd`;
- regression test: `tests/animation_smoke_test.gd`.

Тайминги атак, windup/recovery и damage windows не менялись; изменен только визуальный слой.

## Ассеты

Ключевые папки:
- `assets/sprites/characters`
- `assets/sprites/characters/cutout`
- `assets/sprites/weapons`
- `assets/sprites/enemies`
- `assets/sprites/enemies/cutout`
- `assets/sprites/elites`
- `assets/sprites/elites/cutout`
- `assets/sprites/bosses`
- `assets/sprites/bosses/cutout`
- `assets/sprites/projectiles`
- `assets/sprites/effects`
- `assets/sprites/backgrounds`
- `assets/sprites/map_icons`
- `assets/sprites/ui/icons/stats`
- `assets/sprites/ui/icons/derived`
- `assets/sprites/ui/hud`

При добавлении или замене ассетов нужно обновлять соответствующие `.tscn`, тесты и документацию.

Новый визуальный набор после movement overhaul сгенерирован через `tools/generate_visual_redesign_assets.py` (исторический helper). Актуальная нарезка cutout-частей из polished full-art выполняется `tools/slice_rig_cutouts.py`: он генерирует PNG в `assets/sprites/*/cutout/`, манифест `scripts/sliced_rig_manifest.gd` и debug-листы в `build/rig_debug/`. Скрипты не используются в runtime.

## Возвышения И Мета-Цикл

Возвышение — режим усложнения (5 кумулятивных уровней, как heat в Hades). SCRUM-516 сжал прежние 10 тонких шагов в 5 более плотных: кумулятивно L5 даёт `enemy_hp_mult = 1.80` и `enemy_damage_mult = 1.66`. Уровень выбирается на старте забега в hero select (0..открытый максимум персонажа); при открытии экрана и при смене класса selector по умолчанию ставится на максимальный доступный уровень этого персонажа (`ascension_selectable_max(character_id)`), после чего игрок может вручную понизить его кнопкой `-`. Выбранный уровень показан римской цифрой в боевом HUD и отдельным разделом в кодексе. Усложнения данными в `ProgressionData.ASCENSION_MODIFIERS`, применяются через `game.ascension_difficulty()` в combat_director/boss и `run_modifiers` игрока. У кнопки старта hero select показывает только изменение выбранного уровня через `ascension_level_change_line(level)`, а кумулятивный список `ascension_modifier_lines(level)` остается для tooltip/кодекса. Победа над финальным боссом на уровне N открывает N+1 для этого персонажа (`meta_progression.gd`) до cap 5. Per-class asc-баффы — наградный трек меты по 5 уровней (применяются на старте за пройденные уровни); экран «Древо умений» в главном меню показывает аккаунтное графовое дерево и классовый прогресс выбранного героя.

## Метапрогрессия

Метапрогрессия персистентна между сессиями:

- Метаочки начисляются за первый clear каждого уровня возвышения 0..5 каждым классом по формуле **1/1/2/3/4/5**, без фарма повторов; общий cap заработанных метаочков = `META_POINTS_CAP=100`. Выбранный персонаж открывает следующий selectable уровень возвышения до cap 5.
- За каждую победу выбранный персонаж также получает +1 `class_boss_wins`. Общие пороги классовой прогрессии 1/2/4/6/9 побед дают бонусы только этому классу: class damage, class max HP и class attack speed. Эти `class_*` модификаторы применяются на старте забега только к `selected_character_id`, поэтому прогресс Берсерка не усиливает Солдата и наоборот.
- Бонусы уровней кумулятивны: уровень N включает все бонусы уровней 1..N. Таблицы уровней доступны через `ProgressionData.ASCENSION_LEVELS` и хранятся в `scripts/progression_data_ascension.gd`; канонические ID в `docs/design/content_registry.md`.
- Главное меню открывает «Атлас героев» (Мета 4.0): вкладка созвездия выбранного класса показывает 22 сокета целиком без пан/зума, вкладка гильдии использует звёздную пыль для QoL-узлов. SCRUM-971 показывает локализованное имя выбранного класса отдельной лёгкой строкой над центральным холстом в обеих вкладках; источник совпадает с title медальона, а обновление происходит сразу при выборе класса. Собственный ряд `AtlasCenterColumn` исключает наложение имени на сокеты, header, досье, footer и орнамент рамы без новой тяжёлой панели. SCRUM-838 фиксирует input-контракт: клик по любой ячейке Атласа — доступной, недоступной, скрытой или keystone — только показывает предпросмотр в правой панели с описанием, ценой, требованиями и состоянием action-кнопки; покупка/вложение и активация keystone выполняются только отдельными кнопками панели. SCRUM-970 устраняет focus race: сокет выбирается на pointer-down, deferred layout больше не захватывает initial focus повторно, action-кнопки не расширяют responsive досье фиксированной шириной, а смена вкладки условно переносит gamepad focus на живой узел нового графа. SCRUM-1024 закрывает найденный независимым QA физический overflow 1280×720: при safe-width <1420 currency chips показывают icon + точное число с полной фразой в tooltip, variable dossier progress/hint перенесены в `AtlasNodeScroll`, а нижняя строка 17-геройской сетки следует за фокусом. SCRUM-1070 закрепляет reset-footer на exact `text/standard_420x104`: 420 px visible/hit width и 72/88/104 px responsive height, полные подписи `Сброс умений` / `Сброс умений Атласа` без wrap/clip/ellipsis, при этом кнопка и легенда остаются раздельно внутри пустой content-зоны рамы на 1152×648…2560×1440. Tooltip, focus, confirm/cancel и полный возврат только валюты текущей вкладки сохранены. `AtlasSafeArea` остаётся ровно viewport, а Back/dossier/Buy/все hitbox-ы — внутри authored frame content rect. Реальные bounded viewport mouse motion/down/up проходят class/Guild preview и явную покупку на 1280×720, 1920×1080, 2048×1152 и 2560×1440; focused test отказывается работать с default `user://` и требует уникальный scratch user-data root. Runtime layout масштабирует сокеты компактнее на 720p/1080p, разводит плотные вертикальные лучи и финально проверяет ближайшие свободные позиции, чтобы круги улучшений не наслаивались. Legacy `SKILL_TREE` schema 3 остаётся compatibility/data layer для старых API и smoke-покрытия; канон нового UX: `docs/design/systems/meta_constellations.md`.
- Сохранение через `scripts/meta_progression.gd` в `user://fantasydisk_meta.cfg` (ConfigFile).
- Бонусы применяются к игроку при старте первого боя забега (`apply_ascension_bonuses` в `scripts/main.gd`).
- Hero Select показывает только `Возвышение N` без `/ max`; экран победы отдельно показывает прогресс возвышения выбранного героя.
- Smoke tests: `tests/meta_progression_smoke_test.gd`, `tests/meta_points_per_ascension_test.gd`, `tests/meta_skill_tree_smoke_test.gd`, `tests/skill_tree_per_hero_test.gd`.

## SCRUM-896/1005 Biologist Kit Redesign (2026-07-10)

Кит Биолога пересобран под identity «хрупкий био-реактивный гибрид»:
Споровая Линза — локальный AoE у персонажа (attack_range 560→235, кольца 210
сохранены), каждый задетый замедлен на 5→20% (нормированная прогрессия
оружия, кап держится, refresh без стака) и заражён; Инъектор Образцов —
длинный пирсинг-луч (640): полный маг.ролл + физ.доля (0.50 канала damage)
всем на линии и малый бурст анализа на конце (радиус 96), пробу-инфекцию
получает ближайший; Семя Симбионта — самое дальнобойное (700) темпоральное
оружие: прорастание через 0.55с, стартовый маг.хит ×0.85, главный пейофф — 6
тиков инфекции ×1.6 (DoT строго больше стартового хита). Биоинфекция —
status `bio_infection` с `source_id` владельца; trait «Разбор образцов»
(SCRUM-1005): прямые хиты Биолога по целям под его DoT ×1.20 (тики не
усиливаются, чужие/истёкшие статусы не считаются). Бюджет-зеркала:
sustained-модель dot-оси и infected-фактор; тюнеры кита 0.85/1.62/1.62 в
коридоре (семя ушло с клампа 2.80). Оси и аудит: `docs/design/systems/characters_weapons.md`.
Тест: `tests/biologist_kit_test.gd`.

## SCRUM-909..913 Ranger Kit Redesign (2026-07-10)

Кит Рейнджера пересобран под identity «сторожевой лук» — контроль дистанции,
которую герой сам назначает. Trait «Сторожевой лук» (SCRUM-909,
`CLASS_TRAITS.ranger`): каждый прямой хит лучного оружия (конфиг-флаг
`bow_knockback_trait` у арбалета/лука; капкан не входит) отбрасывает жертву
строго ОТ ИГРОКА — вектор игрок→монстр на момент хита, сплит/пирс/удар в
спину всё равно толкают прочь; сила = derived `knockback_power`
(конфиг 175/150 + endurance×4 + leadership×3, ×«Ударная тетива»), уроном не
скейлится, боссы/элиты ×0.25. Лунный арбалет (SCRUM-910) — с заряжаемого
пирс-луча на `moon_split_shot`: физический болт в цель, после попадания
расщепление в 4 РАЗНЫХ соседей (радиус 260) с ТЕМ ЖЕ уроном, без рекурсии;
«Лунный расщепитель» теперь +2 цели сплита. Грозовой длинный лук (SCRUM-911)
— с 3-лучевого веера на `storm_pierce_cone`: конус 5 пробивающих стрел по
34° на 980 дальности, пирс 4/стрела без спада, дедуп урона на залп (вершина
— ровно один хит), поражённое тело тратит пирс-бюджет проходящей стрелы.
Охотничий капкан (SCRUM-913) — ПЕРМАНЕНТНЫЙ (без `pool_duration`; кап 6
живых, «Корневой капкан» +2 — кап, не таймер), игрока не триггерит; захлоп:
физический AoE (ролл × снапшот заряда стойки) + жёсткий паралич 2.2с
(статус `hunter_trap_paralysis`, `movement_locked` — новый generic-ключ,
`Enemy._physics_process` останавливает жертву полностью; боссы ×0.25) +
зелёное кровотечение `hunter_trap_bleed` по dot-оси (тик = dot_damage ←
Знание; 10×0.5с = 5с — переживает паралич), отброса на триггере нет.
Бюджет-зеркала: hit-модели `moon_split_shot`/`storm_pierce_cone`, тюнеры
кита 1.416/1.48/0.743 в коридоре клампа. Кит целиком физический
(`damage_parameter: "damage"`). Тест: `tests/ranger_kit_test.gd`.

## Боевые Правила После Bugfix-Пакета 2026-06-10

- Уворот игрока работает: `dodge` из `derived_parameters` проверяется в `Player.take_damage`, при успехе показывается всплывающий текст «Промах!» и звук уворота; урон и invulnerability window не применяются. С 0.1.5 defense/dodge/absorb используют SCRUM-255 diminishing returns: defense cap 62%, dodge cap 55%, absorb пропускает минимум 35% каждого удара.
- Регенерация и вампиризм после SCRUM-255 стали поддержкой, а не основным sustain: `regeneration = (0.22 + flat*0.45) * (0.45 + Knowledge/12)`, vampiric chance cap 22%, vampiric heal = `vampiric_amount*0.55 + 3.5% dealt damage`, cap 1.4/с с hard cap 2.6/с. Synthetic tank contact swarm в `tools/survivability_harness.gd` теперь 38.5с TTD вместо 321.0с.
- SCRUM-854/SCRUM-862 дополнительно срезал runaway Доктора: общие regen/vampirism/lifesteal rolls запрещены для `doctor`, включая boss completion tier-3 artifact reward, поэтому `restore_potion`, `plague_syringe` и `bone_saw` остаются единственным источником sustain и по-прежнему проходят `doctor_drain_softcap_test.gd`.
- SCRUM-860 split kill-growth from sustain: Assassin `shadow_momentum` on `shadow_daggers`/`venom_wire` is tempo-only (+attack speed/+crit damage caps from normal kills, no healing), while Doctor drain, Priest prayer/ward sustain, and Knight block/counter stay on separate class lanes.
- Формулы атрибутов после SCRUM-243 используют универсальный cross-scaling: Strength/Intelligence/Knowledge/Leadership больше не являются «мертвыми» на чужих archetype-оружиях, а Perception/Energy/Endurance дают не только профильные, но и малые темп/стабилизационные эффекты. Тест `runtime_smoke_test.gd::_test_attribute_weapon_synergy_matrix` проверяет все 8 атрибутов против 6 weapon archetypes.
- После SCRUM-469 рост статов выше базового значения класса проходит через class/stat-specific `CLASS_LEVEL_STAT_GROWTH_SCALARS` перед расчётом derived-параметров. Это нормализует lvl20 optimum relative score для 17 классов без изменения Base lvl1 и без замены уникальной тройки оружия класса.
- Скорость атаки оружия считается как `base_fire_interval / attack_speed` (минимум 0.18с): базовый `fire_interval` каждого оружия из `progression_data.gd` снова значим, оружия одного класса различаются темпом.
- Ребаланс 2026-06-10: базовые `fire_interval` первых 9 оружий увеличены в 1.6 раза, чтобы итоговый темп после фикса формулы остался близким к прежнему ощущению, но с различиями между оружиями; оружие расширенного ростера 0.1.4 балансируется в своих конфигах.
- Pulse-режим бас-гитары и усилителя использует `_rolled_damage` (учитывает `damage_parameter` и криты), как остальные режимы классового оружия.
- Все отложенные боевые эффекты (ядовитые зоны элиток, rift zone, disk slam, DoT-тики, окна урона свинга берсерка, очистка визуалов) используют tween-таймлайны, привязанные к нодам, а не `SceneTreeTimer`. Они замораживаются вместе с паузой и не наносят урон в level-up/Escape паузе.
- Status effects (`scripts/status_effects.gd`) тикают из `_physics_process()` владельца, а не через отдельные таймеры, поэтому пауза замораживает duration/DoT вместе с gameplay.
- Аура Маршала Осколков усиливает каждого обычного врага не более одного раза (meta `commander_aura_buffed`), без бесконечного мультипликативного стака.
- Статусные перекраски врагов/боссов (щит, windup, аура, ярость, dodge-flash) применяются к видимым cutout-частям через `CutoutRig2D.set_status_tint`, а не только на скрытый source-спрайт.
- Отталкивание классового оружия идет через `Enemy.apply_knockback` (импульс в velocity с затуханием), а не телепорт `global_position`; враги без метода сохраняют старый fallback.
- Враги кэшируют ссылку на игрока (`_player()`), а не ищут группу каждый физический кадр.
- Прицеливание оружия игрока (фикс 2026-06-11): все оружия целятся в ближайшего живого врага. Приоритет: ближайший в attack_range -> ближайший на арене -> последнее направление атаки. Направление движения персонажа влияет только на walk-анимацию; анимация атаки и VFX используют то же направление, что и расчет урона.
- Ближние identity-эффекты SCRUM-251 работают только на прямых weapon hits: DoT-тики не повторяют close/execute/stagger/cleave, поэтому эффекты не каскадят через яды и кровотечение. Focused coverage: `tests/melee_unique_mechanics_test.gd`.
- SCRUM-497: попадания по врагам показывают короткие floating damage numbers, красный hit-outline/flash и отдельный `!` marker на critical hits; лечение игрока и vampirism/drain показывают зелёное `+N` над игроком. Это visual-only layer с persisted toggle `combat_feedback` и global caps для плотных AoE; урон, тайминги и targeting не менялись.
- При любом уроне по игроку боевой HUD показывает легкое покраснение экрана (`DamageFlashOverlay`): фиксированный пик alpha 0.20 без стакания, затухание ~0.32с, эффект замирает на паузе (PROCESS_MODE_PAUSABLE). Сигнал: `Player.damaged`.
- SCRUM-521: при HP игрока ниже 30% боевой HUD показывает мягкую красную виньетку по краям (`LowHpVignetteOverlay`) с прозрачным центром, чтобы не закрывать бой и HUD. Виньетка гаснет после восстановления до 34%+ HP, уважает persisted toggle `combat_feedback`, не перехватывает ввод и рисуется за HUD-карточками.
- SCRUM-852/FAN-1210: стартовый молот Берсерка — `aoe_radius=150`, `attack_range=150`, `max_aoe_radius=0`; Radius scaling увеличивает круг, а плотные паки ограничены `circle_full_targets=4` / `circle_target_diminish=0.62`. `upgrade_aoe_exponent=1.08` и `upgrade_damage_exponent=1.05` сохранены. Live-гейт `tests/berserk_dps_runaway_gate.gd` симулирует ровно 8 секунд игрового времени (не номинальные 480 кадров) и держит `lvl20_ideal_20t <= 10000`, `lvl20_ideal_1t <= 1300`; пять повторов после исправления дали 20t 7337..8545 и 1t 789..1038. FAN-1712: гейт дополнительно фиксирует глобальный RNG-поток, иначе тиры артефактов роллились заново в каждом процессе и один и тот же SHA судился по разным билдам (ложный красный 20t≈14.8k при нормальном 1t); после фиксации 20 подряд прогонов — 20t 7555..8621, 1t 930..967, потолки не менялись. FAN-1729: в гейте теперь две помеченные проверки — `[ceiling]` (те же потолки 10000/1300, геометрический runaway) и `[soft-cap]` (прямая проверка diminishing returns забеговых множителей через `ProgressionData.derived_parameters`), потому что откат soft-cap'а даёт лишь +14% к 20t и потолком не ловился; потолки и балансовые константы не менялись.
- SCRUM-1043 (2026-07-11) / FAN-1100 (2026-07-15): hammer-only ground membership
  следует footline full-frame Берсерка — `_circle_attack_center(owner_node)`
  смещает центр на `16px` вниз. FAN-1100 сделал AoE круглым вместо овального:
  `_circle_attack_visual_scale()` теперь возвращает `Vector2.ONE` (прежний
  вертикальный растяг `Vector2(1.0, 1.12)` убран) и одинаково применяется
  damage-query и slam VFX. При базовом `150px` reach равномерный ~`150px` от
  смещённого центра во все стороны (верх ~`134px`, низ ~`166px` от origin);
  горизонталь без изменений. Damage, cooldown, Radius growth, dense-pack
  diminishing, sword/axe и Knight `holy_flail` не изменены; dedicated-регрессия —
  `tests/scrum1043_hammer_lower_hit_zone_test.gd`.
- SCRUM-858 (2026-07-04): Knight counter pass перенес часть tank identity в incoming-based retaliation. `tower_shield` снижает контактный удар и отвечает по фронтальной стае с radius/arc/target caps (5 incoming damage дает около 25 retaliation до cap), `long_spear` оставлен reach/pierce с легкой узкой ответкой, `holy_flail` держит широкий circular holy-control counter. Cooldown сбрасывается при `configure_character`, чтобы смена оружия/старт забега не наследовали старое окно.
- SCRUM-860 (2026-07-04): Assassin kill-growth closes the growth/sustain slice of the full rebalance. `shadow_momentum` stacks only from normal non-boss/non-elite kills, caps at 6 refreshed 6s stacks, clears on expiry/weapon swap, and is validated by `tests/kill_scaling_identity_test.gd`.

## Runtime И Performance Hygiene

Дополнение после полного code review 2026-06-11:

- Враги кэшируют ссылки на свой Body-спрайт, RigRoot и AudioManager (`_body_sprite()`, `_cutout_rig()`, `_cached_audio`) — без `get_node_or_null` в каждом физическом кадре/попадании; игрок кэширует AudioManager аналогично.
- Ежекадровый HUD-снапшот использует дешевый `_player_artifact_count()`; нормализация списка артефактов выполняется только при фактической перестройке ряда иконок.
- Удален мертвый код: `scenes/MeleeWeapon.tscn` + `scripts/melee_weapon.gd` и `scenes/Weapon.tscn` + `scripts/weapon.gd` (нигде не инстанцировались; перенесены в `build/unused_assets_backup/`), неиспользуемые константы `ROUTE_MAP_CANVAS_SIZE`, `ACTIVE_ENEMY_CAP_*`, `SHOP_INLINE_AREA_SIZE`.
- `scenes/SummonerWeapon.tscn` / `AllyMinion.tscn` и их скрипты теперь используются для source-specific summon/deploy runtime: mobile summon weapons инстанцируют `AllyMinion`, а `ClassWeapon`-deploys держат отдельные role/cap правила для amp/totem/sentry/drone/mines.
- Консоль чистая: headless-запуск игры и все три smoke-теста проходят без ошибок, warnings и debug-print.

Основные runtime-правила после performance/code quality review:

- FAN-1040: известные ресурсы Engineer kit (`SentryTurret`, orbit drone, mine)
  preload'ятся вместе с `ClassWeapon`, поэтому первый деплой не выполняет
  синхронный `load()` во время боя.
- FAN-1040: separation и threat indicators используют один per-frame
  `CombatTargetQuery` snapshot. Threat model фильтруется с частотой 10 Hz без
  тройного group scan/дубликатов boss+elite, но позиции маркеров по-прежнему
  рисуются каждый кадр.
- FAN-1040: taunt status читается scalar API без deep snapshot на каждый enemy
  physics tick; reflection для DoT выполняется только при наступившем damage
  tick. Wave spawn поддерживает локальный remaining-cap вместо повторного group
  scan после каждого enemy.
- FAN-1040: run autosave заменяет checkpoint транзакционно через `.tmp`/`.bak` с
  rollback, а основные configurable Node2D spawner boundaries валидируются
  общим `SceneContracts` перед использованием instance.
- `scripts/main.gd` кэширует Texture2D для меню, портретов, route map и фоновых экранов через локальный texture cache, чтобы не дергать `load()` повторно при перестроении UI.
- `scripts/ui_icon_registry.gd` кэширует иконки характеристик/HUD, поэтому level-up, stats menu и HUD могут безопасно переиспользовать registry без повторной загрузки PNG.
- Inline shop item icons, shop slot frames and cursor variants используют тот же texture cache; отсутствующие Design PNG кэшируются как `null` и не вызывают повторный `load()` при перестроении магазина.
- Компактный HUD обновляет HP/XP/деньги только когда значения реально изменились; при создании нового HUD snapshot сбрасывается.
- Временные визуальные эффекты классового оружия должны регистрироваться в группе `player_weapon_effects`. `ClassWeapon.cleanup_effects()`, `Player._clear_equipped_weapon()`, `_freeze_gameplay_state()` и `_clear_world()` учитывают эту группу.
- Event/shop/campfire экраны используют canonical `assets/backgrounds/ui/` mapping через `SCREEN_BACKGROUND_PATHS`; если PNG отсутствует, fallback-слой не блокирует клики.
- World cleanup чистит врагов, боссов, projectiles, enemy hazards, pickups, player weapons, weapon effects, level-up effects, arena boundaries/backgrounds.

## Известные Ограничения

- Исходный GDD упоминает автоскролл уровня вниз, но текущая реализация использует статичную арену с маршрутной картой.
- Баланс классов и оружия теперь имеет измерительный слой: `tools/balance_harness.gd` генерирует `build/balance_report.md` для 51 пары класс+оружие (solo DPS, 5-target DPS, crowd-clear 5/10/20, EHP) и финальный отчет `build/balance_final_audit_0_1_5.md`. `tests/global_damage_balance_smoke_test.gd` проверяет combined DPS +/-25%, solo DPS +/-20% и 5/10/20 crowd-clear time +/-30%; текущий SCRUM-857 recheck PASS, худшее CCT +22.0% у `doctor/restore_potion` на 20 целях. SCRUM-856 добавляет class-trio identity audit в `docs/design/reports/full_class_rebalance_identity_audit.md`: волна SCRUM-857..860 должна чинить playfeel механикой оружий/китов, а не только числовыми множителями. SCRUM-857 добавил focused gate `tests/projectile_chain_pierce_identity_test.gd` для delayed grenade, long-cast meteor, ricochet vs fan split, prayer sustain arc и dark pierce/curse decay. SCRUM-858 закрыл first tank/melee slice для Knight counter identity, SCRUM-859 закрыл deploy/summon identity slice, SCRUM-860 добавил capped Assassin kill-growth without a new vampirism loop. Playtest все еще нужен для ощущения темпа, но базовая численная сетка больше не держится только на ручной оценке.
- Таблица механик остается долгосрочным источником формул, но код сейчас использует адаптированный слой формул.
- Data-driven scene loading оружия в `scripts/player.gd` пока остается через `load()` на момент экипировки; это не hot path, но при большом расширении оружия можно вынести в общий PackedScene cache.
- DOCX-документ может отставать от Markdown-документации, если его специально не регенерировали.

## Документация Будущих Изменений

## SCRUM-692 UI Readability State

Runtime player-facing UI now has a readability scale pass: common font overrides
grow by roughly 40-50% where frame content zones allow it, with tighter caps on
small safe-zone controls. Common runtime icons from `UIIconRegistry` also scale
up for small/medium requests, while reward cards and compact HUD areas use
fit-sized requests so content remains inside decorative frames. Verified target
sizes include `1536x864`, `1920x1080`, and `2560x1440` via the UI no-overlap
matrix; screenshot evidence is under `build/qa/design_review/`.

Начиная с 2026-06-10, все будущие задачи должны обновлять документацию вместе с изменениями:

- новая механика, экран, маршрут, пауза или UX: обновить этот файл и `docs/design/fantasydisk_design_brief.md`;
- новый персонаж, враг, элитка, босс, артефакт, событие, оружие, фон или узел карты: обновить `docs/design/content_registry.md`;
- новые формулы, параметры, награды, экономика или баланс: обновить `docs/design/mechanics_extract.md`;
- изменение исходного дизайн-направления: добавить актуальное дополнение в `docs/design/gdd_source.md`.

Случайный выбор в игре должен работать только по определенным сущностям из реестра. Например, "случайный босс" означает случайный выбор из `Страж Разлома` и `Пожиратель Диска`, а не создание безымянного босса.

После завершения крупных пачек изменений нужно выполнить `docs/tasks/documentation_post_changes_domain_split_task.md`: обновить текущие документы и разнести подробности по доменным файлам в `docs/design/systems/`, минимум отдельно для боя, карты и меню/UI.

## Автономность Агентов

Пользователь заранее одобряет изменения в рамках задач. Будущие агенты должны:

- не спрашивать подтверждение на очевидные in-scope изменения;
- самостоятельно принимать разумные технические и продуктовые решения;
- доводить задачу до реализации, проверки и документации;
- описывать допущения в финальном ответе или документации.

Спрашивать нужно только при реальном блокере, обязательной эскалации среды, потенциально разрушительном действии или решении, которое выходит за scope задачи.

## Проверка Перед Сдачей Геймплейных Изменений

```bash
python3 tools/quality_gate.py --profile changed --changed-ref origin/dev
python3 tools/quality_gate.py --profile full
```

`tools/quality_gate.py` одинаково работает на macOS/Linux/Windows, обнаруживает
direct и inherited GDScript suites, изолирует `user://` и вызывает Godot только
через semaphore `tools/godot_gate.py`. Windows profile должен выполняться
нативно на Windows: `python tools/quality_gate.py --profile windows`.

Документационные правки не требуют Godot-тестов, если не меняют код, сцены или ассеты; static gate остаётся обязательным для process/tool changes.

## SCRUM-541 Current Secret Boss State

After SCRUM-1058, final Act 2 has two possible endings:

- below max Ascension: defeating the normal Act 2 boss ends the run with the
  normal victory flow;
- at max Ascension L5: defeating the normal Act 2 boss immediately starts the
  secret follow-up boss `secret_ascension_boss`.

The secret boss is backend-ready in `scenes/BossSecretAscension.tscn` and
`scripts/boss.gd` with separate canonical id, sector/ring AoE pressure, delayed
rift eruptions and phase-2 pressure/adds at 50% HP. SCRUM-539 delivered the
Design source pack and static/VFX runtime candidates under
`docs/design/references/bosses/secret_ascension_boss/`,
`assets/sprites/bosses/secret_ascension_boss.png`, and
`assets/sprites/effects/secret_ascension_boss_*_telegraph.png`; final animation
and runtime wiring remain Animator/Back-end scope. Historical balance benchmark
at final L5 stage 18: about `47.6k` HP; the two-act route finale reaches stage 16
without changing boss formulas. L20 optimum estimated TTK `121.5s..231.8s`, L20
random-average estimated TTK `347.3s..559.6s`.

## SCRUM-958 Codex Image State

Codex now routes all actual character, monster and artifact/shop images through
a cached alpha-fit layer instead of shrinking their complete transparent source
canvases. The accepted SCRUM-954 three-column layout is unchanged. Characters
are bottom-centered, monsters are centered without visible-alpha cropping, and
artifact/shop icons use padded contain. The runtime projection covers 17
characters, 31 monster entries and 161 artifact/shop entries with exact Russian
names and canonical paths at 1280×720, 1920×1080 and 2560×1440.

## SCRUM-894 Assassin Crit-Cap Kit State

Assassin — единственный класс со снятым крит-потолком: trait «Хладнокровие»
(`ProgressionData.CLASS_TRAITS.assassin`) даёт кап шанса крита 100% (у остальных
глобальные 55%), убирает diminishing крит-вложений и переливает избыток raw-шанса
сверх капа в крит-урон (кап `CRIT_DAMAGE_CAP` сохраняется). Кит: Чакрамы летят
прямым коридором и возвращаются левой дугой (double-pass за позиционирование,
жёсткий гейт 1+1 хит на цель за каст); Теневые кинжалы кроют сектор и врагов
вплотную вокруг героя, серия по врагам даёт «Рывок темпа» (короткий бафф
скорости+уворота с кулдауном; заменил Shadow Momentum kill-стаки); Ядовитая
струна стартует от самого героя, душит целей в упор в `close_contact_radius`
и усиливает DoT-тики крит-снапшотом. Защита класса — «Теневая завеса»:
самоцентричная аура уворота, работающая только под ближним прессингом
(масштаб от `aura_radius`/`buff_power`, суммарный уворот ≤ 55% — бессмертия
нет). Hero Select описание заявляет 100%-кап; копирайт-пасс — SCRUM-952.
Гейты: `tests/assassin_kit_test.gd`, `tests/kill_scaling_identity_test.gd`,
tuning 51/51, weapon integrity, global damage/survivability smokes — зелёные.
## SCRUM-900 Doctor Weapon-Only Sustain State

Доктор — сустейн-класс «чумного доктора» с data-driven trait'ом «Клятва чумного
доктора» (`CLASS_TRAITS.doctor.generic_sustain_blocked`): generic-сустейн
(регенерация, вампиризм, kill-heal, room-clear heal, low-HP regen, прямые
heal-награды и мета-звёзды регена/вампиризма) на Доктора не действует. Отсечка
работает в четырёх точках: пул наград (`is_reward_relevant`, пометка
`doctor_friendly: true` пропускает предмет), применение наград/меты
(`Player._apply_reward_mods` / `apply_meta_skill_modifiers`), базовый пассивный
реген в формуле (`derived_parameters`), lowhp-страховка `_apply_regeneration`.
Route/rest/shop-лечение (аптечки-пикапы) сознательно не блокируется.

Кит лечится ТОЛЬКО от фактически нанесённого своим оружием урона через
drain-бюджет SCRUM-517 (7 hp/s default, 11 hard cap — бессмертие от полного
заражения карты недостижимо):

- `restore_potion` (aoe_projectile): бросок зелья, магический взрыв 150r,
  хил 16% нанесённого урона; промах не лечит;
- `plague_syringe` (plague_dart): чумной дротик — зараза 24с с медленным
  ramp'ом тиков (0.45→1.0 за 5 тиков), спред 22%/тик на соседа в радиусе 200,
  кап 10 одновременных зараз, хил 12% чумного урона;
- `bone_saw` (saw_sector): melee-сектор 135° дальностью 215, мультихит с
  диминишем сверх 4 целей, сильнейший хил кита 34% — лечит только фронт:
  окружение с флангов/спины не бьётся и не лечит (позиционный риск).

Бюджет-тюнинг кита в коридоре (1.081-1.507, без клампов); crowd-clear
отклонения 20t: −55%→+10.8% хуже всего у чумы (dot-давление), зелье +6.6%,
пила +13.1% — все PASS. Гейты: tests/doctor_kit_test.gd,
weapon_tuning_application_test, weapon_integrity_test,
damage_type_isolation_test, global_survivability_balance_smoke_test,
runtime_smoke_test.

## SCRUM-905..908 Engineer Device-Commander Kit State

Инженер — «командир устройств»: все три оружия — физические устройства
(damage_parameter `damage`), объединённые data-driven trait'ом «Сеть мастерской»
(`CLASS_TRAITS.engineer.workshop_network`, SCRUM-908): живые устройства дают
стеки сети (турель/дрон 1.0, персистентная мина 0.5 — мета `network_weight` на
узле), кап `3 + floor(Лидерство/6)`, каждый стек +6% к урону ТОЛЬКО устройств
(потребитель `ClassWeapon._workshop_network_factor` в `_rolled_damage`;
generic-урон игрока не трогает, классам без trait'а фактор ровно 1.0). Смена
целого числа стеков подсвечивается ринг-пульсом вокруг героя.

- `engineer_sentry_wrench` («Часовая турель», SCRUM-904/905, id сохранён):
  турель с боезапасом `sentry_shot_magazine` 15 — расстреляла магазин →
  свернулась; таймера жизни/замены старейшей НЕТ; залп по разным ближайшим
  целям, каждый снаряд тратит заряд; пульс = amp_pulse_interval / tempo-lift /
  attack_speed (скорость атаки буквально осушает магазин быстрее); предел парка
  `2 + floor(summon_amount/4)`, рельс 6, при полном парке деплой пропускается.
- `engineer_repair_drone` («Орбитальный Дрон», SCRUM-906/FAN-1075, id сохранён,
  ремонт удалён): постоянный парк боевых дронов; базовая пара увеличена с
  visual scale 0.16 до 0.24 (+50%), находится строго напротив друг друга на
  общем кольце радиусом 121 px вместо 78 px (+55%). С третьего дрона включается
  спираль слотов (+14% радиуса за слот). Физический контакт использует per-enemy
  кулдаун 0.85с; число `2 + floor(max(summon_amount − 12, 0)/4)` (база РОВНО 2,
  рельс 6, sa=28 → 6); attack_speed раскручивает обороты (RPM),
  гироскоп-артефакт +20%.
- `engineer_pressure_mines` («Минная Сетка», SCRUM-907): 2 персистентные мины
  за деплой в случайном кольце 110..260 вокруг героя; таймера жизни НЕТ; враг
  подрывает мину сразу (включая первые 3с), сам игрок — только после 3с; кап
  живых 6 (skip, не retire); урон пары поднят против старой веерной тройки
  (скаляр 0.96 → 3.60).

Generic-скейл Лидерства `max_summons` в `player._apply_weapon_scaling` для
устройств Инженера ВЫКЛЮЧЕН (двойной счёт с summon_amount-формулами кита);
кап-рост отдан киту и артефактам SCRUM-961 (магазин +6 выстрелов, гироскоп,
сумка +2 капа мин, «Полевой чертеж» +1 предел турелей/мин за 6 LDR — поверх
рельса). Бюджет-зеркала: `_budget_sentry_ammo_model` (min(спрос парка,
magazine/деплой)), `_budget_orbit_drone_dps` (контакт × min(обороты,
1/hit_cd)), `_budget_network_factor` (ожидаемые стеки, кламп капом сети).
Тюнеры кита в коридоре без клампов; актуальные значения и cct-отклонения
фиксирует `build/balance_report.md`. Гейты: tests/engineer_kit_test.gd
(data+live: магазин/деспаун/парк, базовая антиподальная пара дронов,
радиус/scale/контакт/спираль, пара мин/триггеры/кап, стеки сети/кап от
Лидерства/без утечки), engineer_turret_test, persistent_hazard_contract_test,
class_artifacts_test, summoner_strengthening_test, weapon_tuning_application,
weapon_integrity, damage_type_isolation, animation_smoke, runtime_smoke.

## SCRUM-1037 Storm Longbow Live Release VFX

`ClassWeapon._fire_storm_pierce_cone` теперь создаёт ровно один
`StormLongbowVolleyVfx` на каждый залп и конфигурирует его живыми origin,
direction и `attack_range`. Сцена остаётся чисто визуальной: пять существующих
`AttackVfx.beam` коридоров, hit queries, общий dedup залпа, pierce budget,
damage/crit/knockback, charge и cooldown не менялись. One-shot освобождается
после 8 кадров / 16 FPS (0.5с) и зарегистрирован в стандартном
`player_weapon_effects` lifecycle для очистки вместе с оружием/миром. Контракт:
`tests/scrum912_storm_longbow_vfx_runtime_hook_test.gd`.

## SCRUM-925/926/1088 Priest Battle Prayer Runtime State

Священник начинает каждый бой с обязательного выбора ровно одной молитвы:
`prayer_wrath` (+20% всего урона Священника), `prayer_mending` (+2 HP/с) или
`prayer_aegis` (−20% входящего урона). Пул берётся из
`ProgressionData.class_battle_prayers`; `Player.select_battle_prayer` остаётся
единственной точкой применения и запрещает повторный выбор в текущем бою.
Скрытый автовыбор удалён.

`CombatDirector` создаёт игрока и HUD, затем до выбора приостанавливает дерево
причиной `battle_prayer`. `Player.on_battle_start`, opening-эффекты артефактов и
spawn элитки/босса выполняются только после валидного выбора и ровно один раз.
Пока обязательный экран открыт, ранний guard в `Main._input` поглощает physical
Escape, keyboard `ui_cancel` и gamepad B до общей ветки паузы/оверлеев: pause
dossier не может открыться поверх молитвы, а фокус первой карточки сохраняется.
Классы с пустым prayer-пулом идут по прежнему синхронному пути без экрана и
паузы.

SCRUM-1088 убрал отдельный prayer-specific интерфейс из runtime-пути. Стартовый
выбор Священника теперь создаётся теми же `_create_level_up_menu_box`,
`_level_up_layout_metrics`, `_level_up_card_plan`,
`_make_level_up_reward_button`, `_wire_run_ui_focus` и
`_start_level_up_intro`, что обычный экран повышения уровня. Живые узлы —
`LevelUpOverlay`, `LevelUpPanel`, `LevelUpRewardsRow` и
`LevelUpRewardButton0..2`; меняются только заголовок, данные молитв и callback.
Обязательный выбор не показывает `Позже`. Старый `BattlePrayerModal` /
`BattlePrayerFrameArt` и фиксированные 688×384 card rects больше не рендерятся.
Responsive/card content-zone контракт полностью совпадает с Level Up на
1280×720, 1920×1080 и 2560×1440. Спецификация и PixelLab reference-only слой:
`docs/design/mockups/scrum1088_priest_prayer_attribute_picker/`.

## SCRUM-1069 Guild Atlas Balance Runtime

Атлас гильдии усилен без смены ID, topology, schema 5, цены `59` и cap пыли
`50`. Ветки дают: Казна `+20% gold/+100 start`, Лавка `−20%` обеих цен,
Знание `+15% XP/+1 option/100% ult`, Дорога `+60 pickup/+20% healing` и
одно спасение с `30% max HP`. `Player.take_damage` сохраняет once-per-run флаг
и clamp восстановления `25..30%`; UI-панель получает точные числа из тех же
effect dictionaries, поэтому отдельного изменения `ui_screens.gd` не было.
Полный 59-cost upper bound остаётся `1.174` account power и `+17.4%` одинаковой
weighted class power, а A5 сохраняет повышенный monster/healing/reward pressure.

## SCRUM-1068 Constellation Schema 6 Runtime

Классовая часть Атласа теперь строится из production manifest schema 6: 17
бесплатных ядер, 51 линейная оружейная ветвь по `5 boon + final` и 34 hidden
side node. Это 357 классовых узлов; замороженные 25 Guild-узлов дают 382 total.
На класс тратится ровно 20 sigils: три финала разрешены одновременно, hidden
сначала раскрывается фактом челленджа, затем покупается за 1. Награды A0..A5 —
`[2,2,3,4,4,5]`; челленджи больше не дают валюту или class-wide combat bonus.

Все классовые эффекты передаются как canonical typed profiles точного оружия.
Player повторно строит amounts/multipliers/mechanics по manifest node IDs, так
что forged/foreign profile и неизвестный mechanic fail closed. Live consumers
покрывают обычные boons/hidden для ClassWeapon, Berserk/Holy Flail и summons;
51 финал привязан к явному боевому событию, caps и lifecycle. В частности,
repair drone получил bounded tether `2 HP/s`, excess-only shield final сохраняет
cap/expiry; summon death, block/absorb, return и deploy callbacks имеют точную
owner/weapon attribution. Regression gates: schema migration, 51 positive + 102
foreign negatives, 11 special-consumer behaviors, 51 weapon scenes и full
runtime smoke.

SCRUM-1091 заменил generic class-node copy на data-driven русские dossiers без
изменения manifest/runtime balance. `ConstellationDescriptionFormatter`
fail-closed строит 357/357 описаний: exact owning scope, axis/value,
`before → after` и path progress. Все 51 финал имеют уникальную локализованную
trigger/mechanic строку, manifest-driven caps, boss behavior и видимый
`>=+20%` floor. В Atlas long copy и `УНИКАЛЬНЫЙ ФИНАЛ` остаются внутри scroll;
price/Buy pinned, activation toggle финалам не выдаётся, 30px dossier reserve
проверен на 1280×720, 1920×1080, 2560×1440 и live resize.
Пятый узел каждого пути также раскрывает один из 51 точных русских боевых
приёмов; ключом локализации служит authoritative `params.identity`, поэтому
изменение source identity без новой локализации блокирует dossier и покупку.
SCRUM-1094 закрепляет precedence этого fail-closed состояния: для available и
locked malformed schema-6 узлов `AtlasNodeCondition` сохраняет точное сообщение
об ошибке, Buy остаётся visible+disabled, а currency/adjacency/purchased hints
не могут заменить ошибку правдоподобным generic fallback.

Независимый post-review 2026-07-11 отклонил ранний resolver-only green и привёл
к runtime hardening: grenade/prism/meteor/shatter создают реальные delayed
волны; backstab/deadeye/anchor/crossbow используют setup→consume marks; smoke и
censer получают фактические dodge/absorb callbacks; skull/reliquary/symbiote —
authoritative death/expiry lifecycle; plague/wire/wound синхронизируют локальные
таймеры и stacks. Repair/pack/chime/overheal shields теперь идут через единый
Player-owned timed-absorb API с немедленным derived recompute и безопасным
refresh/expiry. `constellation_schema6_live_runtime_test.gd` проверяет живой
урон, тайминги, overlapping-volley/per-cast caps, Censer ward, Reactor
knockback и Acid reset/rearm, а `constellation_schema6_lifecycle_runtime_test.gd` —
death/expiry и stack timeout/reset, а не только строки registry/resolver.

## SCRUM-1065 Player Projectile Art Handoff

Design source/production pack готов для backend-интеграции SCRUM-1066. PixelLab
permanent-object pipeline создал 19 новых уникальных sprites; принятый
SCRUM-934 Sniper shatter projectile переиспользован осмысленно, итого 20
профилей. Inventory охватывает все 17 классов и 51 оружие; 31 melee/beam/zone/
trap/summon path явно отмечен как non-projectile. Все 40 source/runtime PNG
проверены на RGBA, прозрачные углы, crop и padding (`min 6px`), а source и
real-game-scale dark/light contact sheets сохранены в
`docs/design/previews/SCRUM-1065_player_projectiles/`. Gameplay/runtime код и
боевые параметры этой Design-задачей не менялись.

## SCRUM-1066 Player Projectile Runtime

Accepted projectile art is live through a single data-driven registry rather
than weapon-ID switch statements. `ProjectileVisualRegistry` consumes the
export-safe normalized SCRUM-1065 contract in
`assets/data/projectile_visual_profiles.json` and exposes 20 canonical profiles across the 17/51 weapon
inventory. `ClassWeapon`, sentry projectiles and the legacy `Projectile.tscn`
path use profile texture, intended size, direction/rotation, trail and impact
palette; projectile-like Ranger/Biologist traces retain their immediate damage
contract and add only the short travelling sprite. The other 31 weapons stay
explicitly non-projectile. Generic void-orb/player-spark art is no longer a
canonical player-weapon fallback. Mechanics, balance, damage, targeting, speed,
count, timing, collision, hitbox and cleanup ownership are unchanged.

SCRUM-1085 makes the legacy scene setup order-independent: changing
`visual_weapon_id` after the projectile enters the tree immediately reapplies
texture, scale, rotation, metadata and trail palette. Empty IDs keep the active
profile; invalid IDs fail closed and cannot retain stale canonical visual state.
