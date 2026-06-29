# SCRUM-654 Level Up Head Badge Runtime Spec

SCRUM-654 is a backend/runtime cleanup for the accepted level-up visual language from SCRUM-519 and SCRUM-588. No new bitmap mockup is generated: the implementation reuses `LevelUpPopupBadge` and keeps all text inside that authored badge artwork.

Runtime requirements:

- One visible overhead `LevelUpEffect` node in the `level_up_effects` group at a time.
- Rapid level-ups replace older live `LevelUpEffect` group members before spawning the next one.
- Badge display size is `160x80`, within the accepted compact range `144x72..180x90`.
- `LevelUpToast` remains outside the world-effect cleanup group and stays textless: sparkle/ring feedback only, with no duplicate `Label` child.
- The badge follows the player through `LevelUpEffect.setup(player)` and keeps frame content inside the authored empty badge zone.

Acceptance evidence is covered by focused runtime tests and the UI smoke assertion for duplicate effects.
