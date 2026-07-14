# SCRUM-1050 — live screen/button family inventory

Audit basis: `docs/design/systems/menus_ui.md`, `docs/design/systems/visual_style_assets.md`, live `assets/sprites/ui/frames/`, and the current SCRUM-954 Codex contract. This inventory is a unification map, not a request to give every screen the same shell.

| Screen family | Live visual contract | Keep distinct | Unification rule |
| --- | --- | --- | --- |
| Main Menu | SCRUM-981 hollow gold shell; 2x3 action grid | heroic logo/crest zone | global action state language; gratitude icon button in the empty top-right safe zone |
| Route / Rest / Upgrade / ordinary Reward / Victory / Defeat | SCRUM-981 hollow shell where explicitly adopted; local chips/cards | map readability, rest/economy accents, result focus | shared materials, readable inner reserve, same text-button resolver |
| Hero Select | authored Hero Select frame family | portrait, radar, dossier, carousel | preserve authored geometry; normalize focus/hover brightness and button typography |
| Weapon Select | native opaque dark surfaces and large weapon cards | weapon imagery and stat chips | cards remain cards; only Back/confirm use global action family |
| Settings | fullscreen Atlas-family shell, four tabs, seamless transparent content | mechanical tabs and fields | shared action/back states; no second inner modal; stable state geometry |
| Codex | SCRUM-954 frameless 1920x1080 three-column stage | quiet book/library edge language | FAN-1047: exact `text/main_menu_380x104` tab material with uniform scaling and neutral focus; no large gold shell |
| Combat HUD | dedicated compact HUD v2 cluster | ultra-low ornament, fast scanning | no large shell/action textures; share graphite/brass/crimson palette and icon stroke weight |
| Shop / Attribute Shop / Event / economy | merchant/event backdrops, Atlas chips/cards, screen-owned layout | treasure/rune/merchant accents | action labels use global resolver; product/choice cards stay cards and never become heavy buttons |
| Level Up | frameless three-card composition | socket/card/ribbon hierarchy | preserve cards and recommendation rows; only `Позже` uses global action state family |
| Artifact Reward | reward hall + hollow shell + three cards | gem/socket reward accent | cards remain whole focus targets; action content stays inside card safe zones |
| Pause dossier / Victory / Defeat | dossier/result-specific body inside accepted shell/modal | danger action and result crest | FAN-1047 dossier preserves the exact Main Menu plate ratio in a compact right rail or wide footer; result screens keep their own accepted semantics |
| Atlas / Patch Notes / dialogs / Feedback | screen-specific Atlas/dossier/dialog structures | information density and modal hierarchy | use common text-button and compact utility families; no default Godot gray controls |

## Button taxonomy

| Control type | Canon | Required states | Geometry rule |
| --- | --- | --- | --- |
| Text/action | `assets/sprites/ui/frames/text_buttons_unique/` | normal, hover, pressed, focus, disabled | fixed decorative end caps; stretch center only; no state resize |
| Compact/icon-only | Minimal Metal utility/FAB family or screen-owned compact plate | normal, hover, pressed, focus, disabled | minimum 44px hit target; icon stays inside internal safe zone |
| Back | text-button back family, except accepted compact Codex control | normal, hover, pressed, focus, disabled | arrow/cap is ornament; label never crosses it |
| Card/slot/route node | screen-owned card/hit-area frame | normal, hover/focus, selected, disabled/locked where applicable | do not route through heavy action-button art |
| Dangerous action | same family with restrained crimson interior/accent | normal, hover, pressed, focus, disabled | danger color is semantic; geometry remains identical |

Global state language: hover/focus = neutral brighter metal without yellow glow; pressed = darker interior without movement; disabled = desaturated/dim; selected is persistent and must not be confused with hover. Runtime text and icons remain inside each asset's measured content rect.
