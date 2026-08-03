# Expedition crew portraits

These production WebP portraits are one coherent **soft science-fantasy
frontier** set. They were generated as a single 2-by-2 atlas and then cropped
to independent `512 x 512` assets so lighting, scale and backdrop remain
consistent across the pilot and all three starter companions.

| Asset | Stable presentation identity |
|---|---|
| `pilot_navigator.webp` | universal helmeted Navigator pilot |
| `companion_spark.webp` | `spark-v1` / Искра |
| `companion_moss.webp` | `moss-v1` / Мох |
| `companion_rune.webp` | `rune-v1` / Руна |

The images are presentation only. Pet selection, active state, bond, level and
evolution remain server-authoritative. Known starter IDs receive these assets;
unknown IDs deliberately keep the code-native fallback until their own art is
shipped. Stage and active-state signals are drawn by Flutter above the image,
so the illustration never predicts a server-owned unlock.

The atlas prompt specified four equal cells, the project palette, readable
silhouettes at `80 px`, no text, no logos, no weapons, and no cyberpunk,
fitness-dashboard, anime or chibi treatment.
