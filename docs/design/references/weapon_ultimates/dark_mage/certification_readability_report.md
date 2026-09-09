# FAN-3938 Dark Mage ultimate readability capture

Source revision: `d192be10bbe52dd89971cab0acc66eb92ccab37f` / tree `e4a423855ffab4e8c83a2e5255fef4e65f4cf5cf`.
Renderer: Godot `4.7.stable.official.5b4e0cb0f`, macOS Metal compatibility renderer, fixed 60 FPS.

The windowed runner `tests/ultimates/presentation/dark_mage_certification_live_capture.gd` instantiates each shipped Dark Mage timeline scene and its victim-impact flipbook in a fixed HUD/player/hazard fixture.  Each viewport image has three weapon rows and four mode columns, so it records all 48 weapon × mode × viewport observations.  The deterministic matrix uses three victims in normal/reduced-motion/photosensitivity-safe modes and 39 in crowded mode.  The columns sample ordinary active, crowded active, reduced-motion held, and low-contrast photosensitivity-safe held presentation; each row retains the real timeline scene and the class-local impact frames.

## Observations

| Weapon | Release / active read | Recovery limitation |
| --- | --- | --- |
| `dark_book` | The abyss mirror remains centered and distinct from HUD and the orange hazard marker in all modes. | The frozen certification frame records the active beat; recovery motion is represented by the shipped timeline but not animated in the still. |
| `cursed_skull` | Crown silhouette and impact markers remain legible with 39 victims, while HUD and hazards stay visible. | A still cannot convey the full chain-transfer cadence; timing remains covered by `dark_mage_ultimate_timelines.gd`. |
| `dark_wand` | The vanishing-thread silhouette stays visible against each mode panel and preserves player/hazard separation. | The static image cannot demonstrate branch progression; its active pose and the existing timeline test supply complementary evidence. |

The PNG paths, native dimensions, SHA-256 values, mode definitions, exact runtime resources, and replay commands are the authoritative records in `certification_capture_manifest.json`. The focused verifier rejects a missing viewport, missing canonical key or mode, missing file, LFS pointer, invalid PNG, wrong dimensions, or hash mismatch.
