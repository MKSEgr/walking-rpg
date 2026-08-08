# Expedition crew portraits

These production WebP portraits are one coherent **soft science-fantasy
frontier** set. The original adult crew was generated as a single 2-by-2 atlas.
The younger companion forms and Navigator scarf were then generated from those
adult identity anchors. Every shipped asset is an independent `512 x 512`
portrait optimized for the `72-80 px` in-product presentation.

| Asset | Stable presentation identity | Visual state |
|---|---|---|
| `pilot_navigator.webp` | universal helmeted Navigator pilot | base |
| `pilot_navigator_scarf.webp` | universal helmeted Navigator pilot | `pilot-scarf` |
| `companion_spark_stage0.webp` | `spark-v1` / Искра | stage 0, young |
| `companion_spark_stage1.webp` | `spark-v1` / Искра | stage 1, adolescent |
| `companion_spark.webp` | `spark-v1` / Искра | stage 2, adult |
| `companion_moss_stage0.webp` | `moss-v1` / Мох | stage 0, young |
| `companion_moss_stage1.webp` | `moss-v1` / Мох | stage 1, adolescent |
| `companion_moss.webp` | `moss-v1` / Мох | stage 2, adult |
| `companion_rune_stage0.webp` | `rune-v1` / Руна | stage 0, young |
| `companion_rune_stage1.webp` | `rune-v1` / Руна | stage 1, adolescent |
| `companion_rune.webp` | `rune-v1` / Руна | stage 2, adult |
| `companion_spark_motion_v1.png` | `spark-v1` / Искра | transparent motion atlas |
| `companion_spark_motion_v1.json` | `spark-v1` / Искра | game clip manifest |
| `companion_moss_motion_v1.png` | `moss-v1` / Мох | transparent motion atlas |
| `companion_moss_motion_v1.json` | `moss-v1` / Мох | game clip manifest |
| `companion_rune_motion_v1.png` | `rune-v1` / Навигатор visual canon | transparent motion atlas |
| `companion_rune_motion_v1.json` | `rune-v1` / Навигатор visual canon | game clip manifest |

The images are presentation only. Pet selection, active state, bond, level and
evolution and equipped cosmetics remain server-authoritative. Known starter IDs
receive the image matching their accepted `evolutionStage`; unknown IDs keep
the code-native fallback until their own art ships. The `spark-halo` cosmetic
is a Flutter light layer so it follows every age form without duplicating the
underlying portraits. Unknown cosmetic IDs do not alter character art.

## Companion motion atlases

The motion atlases are game assets, not chat avatars. Each preserves one exact
stable identity in an `8 x 11` grid of `192 x 208` cells. Its manifest maps 73
occupied cells to nine game-facing clips (`idle`, directional running, greeting,
jump, tired, waiting, sensing and inspection) plus sixteen clockwise look
directions. The remaining cells are transparent by contract.

Искра remains low and elastic, using her ears and tail fan to lead motion. Мох
stays broad, deliberate and weighty; his gaze and head lead while the living
sprout follows with restrained organic delay. The violet Навигатор companion
hovers and glides, leading with the eyes and face plane while lateral facets and
the curved tail/fan stabilize momentum. The three atlases share rendering,
light logic and cell geometry without sharing silhouettes or locomotion.

Home uses one non-looping idle pass for exact active `spark-v1`, `moss-v1` and
`rune-v1` identities. The violet companion remains `rune-v1` / «Руна» in the
current server catalog until its naming migration is reviewed separately. Pet
selection, evolution form, bond and active state still come from the accepted
server snapshot; an atlas never chooses a pet, renames it or predicts
progression. The existing stage portraits remain the authoritative form
presentation in pet selection, growth and journal surfaces. Other pet IDs
retain their static portrait until they receive their own reviewed motion
atlas.

Motion stops on the first frame when the platform requests reduced animation.
Continuous playback is an explicit scene-level opt-in and is not used by the
Home card. Validate dimensions, the committed digest, occupied cells and
transparent unused cells from the repository root with:

```shell
python3 mobile/tool/validate_companion_motion_assets.py
```

The validator requires Pillow.

All prompts specified the project palette, readable silhouettes at `80 px`, no
text, logos or weapons, and no cyberpunk, fitness-dashboard, anime or chibi
treatment. Earlier forms preserve the adult species materials while reducing
body scale and silhouette complexity; they are not unrelated redesigns.
