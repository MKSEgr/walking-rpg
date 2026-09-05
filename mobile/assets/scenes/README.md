# Home cinematic scene v2

Created for issue #575 after the owner rejected the simplified foreground from
PR #574 and requested the existing beautiful landscape plus realistic detail.

The environment reference is the project's existing
[`signal_source.webp`](../events/signal_source.webp). The composition preserves
its lunar sky, misty mountain layers, basalt ledge, distant beacon and lumen
trail while placing the familiar pilot and selected companion in the foreground.

| Asset | Accepted companion | Dimensions | Bytes |
| --- | --- | --- | --- |
| `home_crew_spark_v2.webp` | `spark-v1` | 1254 × 1254 | 193,778 |
| `home_crew_moss_v2.webp` | `moss-v1` | 1254 × 1254 | 168,938 |
| `home_crew_rune_v2.webp` | `rune-v1` | 1254 × 1254 | 167,084 |
| `home_pilot_v2.webp` | missing / unsupported companion | 1254 × 1254 | 167,950 |

Total: 697,750 bytes. Exactly one scene is mounted at a time. Full square framing
keeps both actors visible. These are still species illustrations; they do not
encode route topology, progress, evolution forms, cosmetics or rewards.
Unsupported pilot IDs use the original landscape; unsupported complete pet
identities retain the existing neutral portrait on the pilot-only scene.

## Provenance and production

Generated with OpenAI built-in image generation on 2026-09-05 using this
repository's existing landscape and character portraits as references. Full
prompts and reference paths are retained in [provenance.json](provenance.json).
The full-body pilot study was a design reference only; its generated background
was not suitable for a transparent sprite and it is not a production asset.

The Spark scene establishes the camera, pilot, environment and lighting.
Reference-image edits replace only the companion for Moss and Navigator, or
remove it for the pilot-only fallback. Finished 1254 × 1254 PNG outputs were
encoded to WebP with ImageMagick `convert input.png -quality 90 output.webp`,
without resizing, cropping, masking or other artistic processing.

This owner-requested visual direction is recorded in the pilot and companion
art bibles. The scenes have no independent character animation. New animation
requires its own detailed frames/layers and review. Physical-device acceptance
remains under TASK-011 / issue #156.
