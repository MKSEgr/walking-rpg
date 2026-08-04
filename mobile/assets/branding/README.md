# Walking RPG native branding

`expedition_emblem.webp` is the source artwork for the launcher icon and native
launch screen. It is intentionally not listed in `pubspec.yaml`: the generated
Android and iOS resources own startup rendering before Flutter is available.

The emblem is universal rather than pet-specific. Its compass, illuminated
route and distant signal communicate expedition, walking and progression
without promising a server-owned location or choosing Искра, Мох or Руна for
the player.

Generate every native raster from the repository root with:

```shell
python3 mobile/tool/generate_branding_assets.py
```

The generator requires Pillow. Validate the committed dimensions, color modes
and Android adaptive-icon safe zone without rewriting files with:

```shell
python3 mobile/tool/generate_branding_assets.py --check
```

## Artwork provenance

- created for this repository with OpenAI image generation on 2026-08-04;
- production prompt: an original compass-and-route expedition emblem in the
  approved night-ink, lumen, ENERGY and resonance palette, with a strong
  text-free silhouette and no character, pet, fitness, GPS or crypto symbol;
- the flat chroma background was removed locally and the result was reviewed
  at launcher size before platform export;
- no third-party logo, font or stock artwork is embedded.
