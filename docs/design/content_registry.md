# FantasyDisk Content Registry

Обновлено: 2026-06-14

Этот документ задает правило для всех будущих задач: любая игровая сущность должна иметь понятное имя, стабильный ID и место в документации. Рандом в игре может выбирать только из заранее определенных сущностей, а не создавать безымянный контент, на который потом невозможно сослаться.

## Разделы Реестра

Реестр разрезан на разделы: каждый раздел живет в одном файле
`docs/design/content/*.md`, и у файла один владеющий домен. Этот индекс
остается совместимой точкой входа: он перечисляет все разделы реестра под
прежними названиями и ведет к файлу, где раздел теперь живет.

Правила ведения реестра (формат сущности, обязательные обновления
документации, правила для новых сущностей) лежат в
[`content/registry_conventions.md`](content/registry_conventions.md).

Меняя контент, правьте только файл нужного раздела. Новый раздел живет в
файле раздела и в этом индексе одновременно; `tools/check_content_registry.py`
падает на разделе, которого нет в индексе, на битой ссылке, на дубликате
канонического ID внутри блока и на неизвестном class/actor ID.

| Раздел | Файл |
| --- | --- |
| Обязательное Правило Для Будущих Тасков | [`content/registry_conventions.md`](content/registry_conventions.md) |
| Правило Автономной Работы | [`content/registry_conventions.md`](content/registry_conventions.md) |
| Формат Любой Сущности | [`content/registry_conventions.md`](content/registry_conventions.md) |
| Правила Для Новых Сущностей | [`content/registry_conventions.md`](content/registry_conventions.md) |
| Брендинг Проекта | [`content/branding.md`](content/branding.md) |
| Персонажи | [`content/characters.md`](content/characters.md) |
| Расширенный Ростер 0.1.4 (Фундамент, 2026-06-11) | [`content/characters.md`](content/characters.md) |
| Анимации И Rig-Профили | [`content/animation.md`](content/animation.md) |
| Оружие | [`content/weapons.md`](content/weapons.md) |
| Ультимейты Классов | [`content/weapons.md`](content/weapons.md) |
| Призывные Союзники И Deployables | [`content/allies.md`](content/allies.md) |
| Стандартные Монстры | [`content/enemies.md`](content/enemies.md) |
| Элитные Монстры | [`content/enemies.md`](content/enemies.md) |
| Умения Монстров (Канонические Имена Кодекса) | [`content/enemies.md`](content/enemies.md) |
| Мини-Элитки (Свита Возвышения L7, SCRUM-155) | [`content/enemies.md`](content/enemies.md) |
| Боссы | [`content/enemies.md`](content/enemies.md) |
| SCRUM-541 Secret Boss Registry Addendum | [`content/enemies.md`](content/enemies.md) |
| Лор И Летопись (FAN-1080) | [`content/lore.md`](content/lore.md) |
| Узлы Маршрутной Карты | [`content/route_map.md`](content/route_map.md) |
| Случайные События | [`content/route_map.md`](content/route_map.md) |
| Фоны И Карты | [`content/route_map.md`](content/route_map.md) |
| Препятствия | [`content/route_map.md`](content/route_map.md) |
| Пикапы И Ресурсы | [`content/route_map.md`](content/route_map.md) |
| VFX-Ассеты Эффектов | [`content/vfx.md`](content/vfx.md) |
| Projectiles И VFX Assets | [`content/vfx.md`](content/vfx.md) |
| Sprite QA Notes | [`content/vfx.md`](content/vfx.md) |
| UI Иконки Характеристик | [`content/ui.md`](content/ui.md) |
| UI Visual Kit 2026-06-14 | [`content/ui.md`](content/ui.md) |
| UI Иконки И HUD | [`content/ui.md`](content/ui.md) |
| UI Frames / Escape Stats Visual Kit | [`content/ui.md`](content/ui.md) |
| SCRUM-478 Bright Minimalist UI Source Package | [`content/ui.md`](content/ui.md) |
| SCRUM-666 Combat HUD 2K Source Package | [`content/ui.md`](content/ui.md) |
| Иконки Артефактов, Shop UI И Курсор | [`content/ui.md`](content/ui.md) |
| SCRUM-810 Input Glyphs (Gamepad + Keyboard) — 0.2.0 | [`content/ui.md`](content/ui.md) |
| Награды За Характеристики | [`content/progression.md`](content/progression.md) |
| Базовые Улучшения За Уровень | [`content/progression.md`](content/progression.md) |
| Возвышения (Усложнения) | [`content/progression.md`](content/progression.md) |
| Магазинные Предметы | [`content/progression.md`](content/progression.md) |
| Уровни Возвышения (Метапрогрессия) | [`content/progression.md`](content/progression.md) |
| Артефакты | [`content/artifacts.md`](content/artifacts.md) |
| Тиры Артефактов | [`content/artifacts.md`](content/artifacts.md) |
| Звуковые Ассеты | [`content/audio.md`](content/audio.md) |
| SCRUM-723 Scene/Resource Reference Integrity Audit (0.2.0) | [`content/integrity_audits.md`](content/integrity_audits.md) |
