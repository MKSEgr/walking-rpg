# Walking RPG — pilot art bible

## Status and authority

This document records the approved visual identity and production rules for the
current universal pilot. It complements [COMPANION_ART_BIBLE.md](COMPANION_ART_BIBLE.md)
without applying pet anatomy exclusions to manufactured pilot equipment. The
direction still requires physical-device and motion-tolerance evidence under
TASK-011; committed art is not a substitute for that validation.

## Navigator identity

- Stable server identity: `navigator-v1`; current player-facing copy:
  «Навигатор».
- Anonymous adult human frontier pilot with a broad deep-blue hood and an
  opaque turquoise glass visor. No face, hair, age markers or gendered anatomy
  is exposed.
- Restrained pale contour lines remain inside the visor. They read as a quiet
  navigation surface, not a glowing face, text, circuit board or hologram.
- A practical charcoal and blue-black exploration suit, gloves and boots
  complete the silhouette. Worn brass edging and one small turquoise chest
  light are secondary accents.
- The base identity carries no weapon, handheld tool, backpack, cape, logo or
  readable symbol. `pilot-scarf` is a separate server-owned cosmetic state.
- Primary character: calm, capable, attentive and humane rather than militarized
  or anonymous-threat coded.

The stable `rune-v1` companion now also uses «Навигатор» as its canonical base
name. Pilot portraits, profile and dossier surfaces retain the pilot identity
name above, while paired crew copy uses the role «Пилот» to avoid
«Навигатор и Навигатор» without changing either stable ID.

The existing `pilot_navigator.webp` portrait is the identity anchor. Full-body
motion extends only the unseen lower suit with conservative matching materials;
it does not redesign the hood, visor, torso or palette.

## Rendering and movement

- Expressively stylized painterly 2D soft science-fantasy, matching the crew
  portraits and companion atlases. No photorealism, glossy 3D, chibi, anime,
  pixel-art or heavy comic treatment.
- The hood and visor lead recognition at small sizes. Body angle, shoulders,
  hands and stance carry emotion in that order.
- Running is practical and balanced. Greeting uses one open hand. Tired motion
  lowers the shoulders without collapsing the silhouette. Sensing uses one
  restrained hand-to-visor gesture; inspection keeps both hands empty.
- Local visor and chest illumination never becomes a global halo, detached
  particles, speed lines or cyberpunk neon clutter.

## Motion asset contract

- Transparent `8 x 11` raster atlas with `192 x 208` cells and one whole pilot
  per occupied cell.
- The manifest maps 73 occupied cells to idle, directional running, greeting,
  jump, tired, waiting, sensing and inspection clips plus sixteen clockwise
  look directions.
- Scale and baseline stay stable inside each clip. Jump frames retain vertical
  travel. No floor, cast shadow, scenery, text, borders, particles or motion
  blur is baked into the reusable sprite.
- Look directions keep the feet and lower torso anchored while visor angle,
  hood overlap and upper torso turn. The sprite is not rotated as a flat card.
- Reduced-motion presentation holds a representative still. Continuous loops
  remain an explicit scene-level decision.

The v1 atlas and manifest live in
`mobile/assets/characters/pilot_navigator_motion_v1.{png,json}`. Home may play
one non-looping idle pass for the exact current `navigator-v1` presentation.
The account dossier and journal retain the existing static portrait.

## Cosmetics and future pilots

The base atlas never removes or approximates a server-owned cosmetic. The exact
`navigator-v1` plus `pilot-scarf` presentation uses the separately versioned
`pilot_navigator_scarf_motion_v1.{png,json}` atlas. Its compact deep-teal wrap
follows the shoulders without becoming a cape or detached effect. The cosmetic
catalog may play one non-looping idle pass; the account dossier and journal
retain `pilot_navigator_scarf.webp`. Unknown future pilot identities keep the
static portrait fallback; new IDs, selection rules or progression remain
content/API work and must not be inferred from a display name.
