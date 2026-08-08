# Walking RPG — companion art bible

## Status and authority

This document records the product owner's companion canon and the shared art
rules for production assets. It is the source for new companion artwork. The
direction still requires physical-device and motion-tolerance evidence under
TASK-011; committed art is not a substitute for that validation.

## Canonical starter lineup

- **Искра** — the agile turquoise ground scout; stable server ID `spark-v1`.
- **Мох** — the patient moss-backed guardian; stable server ID `moss-v1`.
- **Навигатор** — the violet floating companion shown in the third row of the
  approved starter sheet.
- The hooded figure in the bottom row is a pilot, not a fourth pet.
- Люма is a discarded draft and is not a companion, evolution form or style
  reference.

The current server catalog still exposes the violet companion as `rune-v1` /
«Руна» and uses «Навигатор» as pilot copy. That naming mismatch is an explicit
migration gap. Art changes must not silently rename a server-owned ID or
player-facing catalog entry; the content/API migration needs its own reviewed
change while the visual canon above remains unambiguous.

## Shared visual language

- Expressively stylized painterly 2D soft science-fantasy.
- Compact, readable silhouettes with grounded anatomy and one dominant
  species-defining feature.
- Controlled soft brush texture with selective crisp edges around faces and
  silhouettes; no photorealism, toy, clay, plush or glossy 3D rendering.
- Deep blue-black, teal, muted moss and violet form the atmospheric base.
  Amber or gold is reserved for rare safe/discovery accents.
- Bioluminescence is local and anatomical. It never becomes electronic LEDs,
  detached particles or a global halo.
- Familiar animal recognition is only an entry point; every pet must remain a
  distinct alien species rather than a direct cat, fox, dog, turtle, bat or
  insect copy.
- Emotion reads first through silhouette, pose, gaze and large appendage
  movement, then through small facial detail.
- Every pet shares rendering, edge treatment, value range, light logic and
  emotional clarity while keeping a unique silhouette, material, palette
  family, locomotion and idle rhythm.

## Искра identity

- Small, lean and agile alien quadruped with a low athletic stance.
- Large upright tapered sensory ears with restrained amber-gold inner light.
- Angular face, short dark muzzle and bright turquoise-green intelligent eyes.
- Deep blue-charcoal organic fur/plate planes; never manufactured armor.
- A turquoise brow crest and compact chest light are the primary cool accents.
- Four animal paws, with no hands, clothing, tools, collar, weapons or
  detachable accessories.
- A long flexible dark tail ends in two or three physically connected luminous
  turquoise leaf/crystal lobes.
- Primary character: alert, brave, quick and eager to investigate.

Ears, gaze, head angle, tail fan and posture communicate emotion in that order.
Locomotion stays low and elastic. The tail counterbalances running, jumping and
landing; the ears trail lightly and recover without mechanical snapping.

## Motion asset contract

- Transparent raster source with one whole-body pet per `192 x 208` cell.
- Shared scale and baseline inside a clip; jumps retain real vertical travel.
- No floor, cast shadow, scenery, text, borders, frame numbers, particles,
  speed lines, motion blur or props that are not part of the creature.
- Game-facing clips use semantic names: idle, directional run, greet, jump,
  tired, waiting, sensing and inspect.
- Sixteen clockwise look directions keep feet and lower torso anchored. Eyes
  lead; muzzle/head planes, ear overlap and upper-body turn follow. Never rotate
  or warp the whole sprite and never move only the pupils.
- Reduced-motion presentation holds a representative still. Continuous loops
  are a scene-level decision, not the default consequence of owning an atlas.
- Motion is presentation feedback only. It never selects a pet, advances an
  evolution, grants bond or replaces an authoritative server reload.

The Искра v1 atlas and machine-readable cell map live in
`mobile/assets/characters/companion_spark_motion_v1.{png,json}`. Future Мох and
Навигатор atlases must follow this contract and the shared style without
copying Искра's silhouette or movement.

## Exclusions

- No chibi proportions, baby-doll eyes, anime/cel treatment, pixel art, heavy
  comic outlines, plastic highlights or photoreal fur.
- No cyberpunk circuits, manufactured plates, straps, readable symbols,
  weapons or generic sci-fi gadgets.
- No scenery or ambient effect baked into reusable character sprites.
- Do not reuse discarded Люма anatomy, round mouse ears, paddle tail, white
  muzzle mask, purple coat patches or detached glowing anatomy for Искра.
