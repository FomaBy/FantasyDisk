# Кит UI-рамок «Ornate Dark / Red» (референс пользователя, 2026-06-14)

Два листа панелей/рамок в тёмном орнаментальном dark fantasy стиле с красными
акцентами, прозрачный фон. Дополняют кит кнопок Red&Gold Dragon (SCRUM-273) —
вместе полный UI-рестайл.

- `frame_kit_ornate_dark_sheet_b_spec.png` — ОСНОВНОЙ спек-лист: 13 типов рамок
  под игру, у КАЖДОЙ подписаны title + texture margin + content margin
  (т.е. готовые 9-slice nine-patch margin'ы — НЕ угадывать).
- `frame_kit_ornate_dark_sheet_a.png` — дополнительный лист рамок (варианты/
  размеры), использовать как доп-источник если нужно.

13 типов из спек-листа:
1. Global Panel
2. Level Panel
3. List/Card Frame
4. Hero Portrait/Card Frame
5. Card Hover/Card Frame
6. Tooltip Frame
7. HUD Panel
8. HUD Card
9. Timer Panel
10. Pause Main Panel
11. Pause Stat Group
12. Pause Stat Chip / Basic Row
13. Pause Stat Tooltip

У каждой на листе подписаны texture margin и content margin — брать их как
nine-patch margins при настройке StyleBoxTexture. Применить ко всем панелям/
окнам/HUD/тултипам/карточкам игры.
