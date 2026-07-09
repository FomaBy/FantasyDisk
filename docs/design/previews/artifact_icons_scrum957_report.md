# SCRUM-957 Artifact Icon Generation / Alpha / Readability Report

Date: 2026-07-10
Owner: Designer2/Codex (`/root/audit_qa`)
Jira: SCRUM-957

## Generation Contract

- Explicit Jira OpenAI Images override.
- Generator:
  `skills/codex/fantasydisk-asset-generator/scripts/generate_asset.py`.
- Model/quality/size: `gpt-image-2`, `high`, `1024x1024`, `--no-task`.
- Exactly one independent API call per distinct icon; no shared grid.
- Chroma removal:
  `$CODEX_HOME/skills/.system/imagegen/scripts/remove_chroma_key.py` with
  `--auto-key border --soft-matte --transparent-threshold 12
  --opaque-threshold 220 --despill`.
- Runtime normalization: isolated alpha bbox fitted to a `256x256` transparent
  canvas. All four margins are within `10–18%`. `hawk_lens` receives a
  deterministic 20-degree presentation rotation before fitting so its long
  monocular silhouette preserves the same margin contract without distortion.

## Canonical IDs And Silhouettes

| Canonical ID | Display intent | Distinct silhouette | Prompt/source note |
| --- | --- | --- | --- |
| `red_whetstone` | Точильный камень | broad tapered crimson stone in iron cradle | `docs/design/references/icons/artifacts/red_whetstone/prompt.md` |
| `field_kit` | Полевой бинт | linen roll strapped to compact leather field pouch | `docs/design/references/icons/artifacts/field_kit/prompt.md` |
| `magnetic_buckle` | Магнитный талисман | open horseshoe buckle, copper coils, violet lodestone | `docs/design/references/icons/artifacts/magnetic_buckle/prompt.md` |
| `fast_boots` | Легкие сапоги | paired slim leather boots with swept heel fins | `docs/design/references/icons/artifacts/fast_boots/prompt.md` |
| `hawk_lens` | Линза охоты | diagonal brass monocular with hawk-brow shroud | `docs/design/references/icons/artifacts/hawk_lens/prompt.md` |

Visual inspection confirms no text, letters, numbers, logo, watermark, frame,
panel, badge, opaque background or unrelated props. The five silhouettes remain
distinguishable in the committed `256/64/40/32` contact sheet.

## Source Provenance SHA-256

| ID | Chroma source SHA-256 | Alpha source SHA-256 |
| --- | --- | --- |
| `red_whetstone` | `a265d7c9e33634bf96160e12fb847e67bef65b37a950736a5ab51744002c5eb7` | `cea2e530e024894310ab86a3ea483f8171f426af77da1c5fda641f3c07b0597c` |
| `field_kit` | `bec5ea9c92c2d850b627692ff9c59fe782fe30e792a60d294c065f0002be3561` | `b84ef4fb5c21d4686b6ad47d9f86fd1e5e591eab62653d75bc61c43fc1bdc50f` |
| `magnetic_buckle` | `770539c9cf3113949eb8c5a5293d27e37498148e970700250136a8829de0b056` | `eba72afd345fdf209699ed3e875c69f165f56ea776a2510028488d0d460b6881` |
| `fast_boots` | `d6a6e534a4dd722de79868f3248e020b5638d591dbc1676ad83856b25286d6ed` | `09d29cd614a59d750c0fc27f5a9b77c4e9013a3e7d4ef4932a4ccb77f0430011` |
| `hawk_lens` | `f7544ac621b085c583d88828999e9a9c9e143d049ca6e6a4017da781b5596145` | `2ab44d5e512bddd83c5979c3a6ef389991ad83761f8424ada037df0ce25470ec` |

Each source directory also contains `<id>_pre_scrum957_runtime.png` so the
committed before/after evidence does not depend on mutable Git history.

## Runtime PNG / Alpha / Padding

All files are `256x256` RGBA PNG with alpha extrema `0..255`, four fully
transparent corners, non-empty visible content, and zero visible green-dominant
chroma-fringe pixels (`alpha > 16`, `G > 120`, `G > 1.35R`, `G > 1.35B`).

Padding order is left/top/right/bottom.

| ID | Runtime SHA-256 | Alpha bbox | Padding | Transparent px | Partial-alpha px |
| --- | --- | --- | --- | ---: | ---: |
| `red_whetstone` | `71e5407889aaf33cdc8858d25d6a5218bfd5ab83e8584eef5bc27a4b96d5473f` | `(36,45)-(220,211)` | `14.06/17.58/14.06/17.58%` | 46,350 | 1,919 |
| `field_kit` | `faf835b98a155b3c0cd15ba5b502faff494d26b85b480ea62e3b041e8a26c672` | `(37,36)-(219,220)` | `14.45/14.06/14.45/14.06%` | 38,448 | 1,941 |
| `magnetic_buckle` | `c1eddb6733b11ad173d3e1d9c11310318d9d7cadb1aa925cf798c342543bf769` | `(36,39)-(220,216)` | `14.06/15.23/14.06/15.62%` | 45,042 | 3,167 |
| `fast_boots` | `f728c23d82587485b31cbae6faec2053afe2670eab903e14431ca19fcd844c48` | `(40,36)-(216,220)` | `15.62/14.06/15.62/14.06%` | 47,000 | 2,613 |
| `hawk_lens` | `efb8a7da96a31157013d1f20c6c642e99a1d437911f323985d7918c1106f91c5` | `(36,41)-(220,215)` | `14.06/16.02/14.06/16.02%` | 48,044 | 1,793 |

All five runtime SHA-256 values are unique.

## Small-Size Readability

Visible-pixel count uses resized alpha `>16`; every icon remains non-empty and
keeps a distinct silhouette at all required sizes.

| ID | 64px visible px | 40px visible px | 32px visible px |
| --- | ---: | ---: | ---: |
| `red_whetstone` | 1,219 | 494 | 327 |
| `field_kit` | 1,714 | 691 | 450 |
| `magnetic_buckle` | 1,304 | 542 | 350 |
| `fast_boots` | 1,179 | 482 | 319 |
| `hawk_lens` | 1,109 | 451 | 294 |

Evidence:

- `docs/design/previews/artifact_icons_scrum957_contact.png`
  (`SHA-256 47bdbb25cfada2e4cd90ad048a0166c521a6388608c94489e8c2269d0a1b4d14`)
- `docs/design/previews/artifact_icons_scrum957_existing_comparison.png`
  (`SHA-256 520e7b4b39a62f51cd1ffb196715b9d9606350457c479c72d8dece8f6d0198e6`)

## Import And Exclusion Guard

The existing `.import` sidecars have no Git diff. Their preserved SHA-256:

| ID | `.import` SHA-256 |
| --- | --- |
| `red_whetstone` | `848aa5414ff4bd5b787e91b7ad41609c54a7a2411030de879b2cb17cea0ff8bd` |
| `field_kit` | `c9fa4a8de2cca0cba195f6573063aa8a5783436207d61e60b9d5ac481b0a40a6` |
| `magnetic_buckle` | `f75cc809210c73dfadfad9f3b7898f30bad6f53a668553c1350e798683768d0e` |
| `fast_boots` | `feb2380078436a73f9935aa5db2019d6b9ad4006a90f7a6528c141c4ee7c920a` |
| `hawk_lens` | `330e155ec4e22e0c909d93db283c7c9889b7162d5beee0ff8ade15a03621d9ee` |

Excluded runtime data/assets are unchanged:

- `artifact_quickstring.png` SHA-256 remains
  `d74441e3ab4d66f2a9bfe90fc7bb91e90d749e1c59b20553745a107849b52917`.
- `shop_shop_weapon_cooldown.png` SHA-256 remains
  `bf14cf2fc09680d04923d5dd86814e96e0499e7deac3015e52ae7d7c524456d8`.
- `shop_shop_artifact.png` SHA-256 remains
  `c2f32f1857fb623a470f91e306c67618d6e1e871c92c5d919e88cc495b7e4f58`.
- `artifact_dusty_artifact.png` does not exist and was not invented.
- No ProgressionData, Codex/UI code or shared product documentation was edited.

The mapping decision is linked to SCRUM-956: «Масло темпа» and «Пыльный
артефакт» are shop items `shop_weapon_cooldown` and `shop_artifact`, not aliases
for `quickstring` or a new `dusty_artifact` artifact record.

