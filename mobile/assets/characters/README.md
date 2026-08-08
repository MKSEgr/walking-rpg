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

The images are presentation only. Pet selection, active state, bond, level and
evolution and equipped cosmetics remain server-authoritative. Known starter IDs
receive the image matching their accepted `evolutionStage`; unknown IDs keep
the code-native fallback until their own art ships. The `spark-halo` cosmetic
is a Flutter light layer so it follows every age form without duplicating the
underlying portraits. Unknown cosmetic IDs do not alter character art.

## Искра motion atlas

The motion atlas is a game asset, not a chat avatar. It preserves the exact
`spark-v1` identity in an `8 x 11` grid of `192 x 208` cells. The manifest maps
73 occupied cells to nine game-facing clips (`idle`, directional running,
greeting, jump, tired, waiting, sensing and inspection) plus sixteen clockwise
look directions. The remaining cells are transparent by contract.

Home uses one non-looping idle pass for the exact active Искра identity. Pet
selection, evolution form, bond and active state still come from the accepted
server snapshot; the atlas never chooses a pet or predicts progression. The
existing stage portraits remain the authoritative form presentation in pet
selection, growth and journal surfaces. Other pet IDs retain their static
portrait until they receive their own reviewed motion atlas.

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
