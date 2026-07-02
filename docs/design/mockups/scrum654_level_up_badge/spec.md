# SCRUM-654 Level Up Head Badge Runtime Spec

SCRUM-654 was a backend/runtime cleanup for the accepted level-up visual language from SCRUM-519 and SCRUM-588. The current user bugfix disables the separate `LevelUpPopupBadge` plaque so the only `Level Up` text is centered inside `LevelUpToastFrame`.

Runtime requirements:

- One visible overhead `LevelUpEffect` node in the `level_up_effects` group at a time.
- Rapid level-ups replace older live `LevelUpEffect` group members before spawning the next one.
- `LevelUpEffect` follows the player through `LevelUpEffect.setup(player)` and renders only flash/ring/spark burst content, with no `LevelUpPopupBadge` and no `Label`.
- `LevelUpToast` joins the cleanup group and owns the single visible `Level Up` label inside its strict `70/112/70/112` frame content margins.

Acceptance evidence is covered by focused runtime tests and the UI smoke assertion for duplicate effects.
