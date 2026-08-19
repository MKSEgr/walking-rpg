# Walking RPG — companion art bible

## Status and authority

This document records the product owner's companion canon and the shared art
rules for production assets. It is the source for new companion artwork. The
direction still requires physical-device and motion-tolerance evidence under
TASK-011; committed art is not a substitute for that validation.

The hooded figure uses the separate pilot rules in
[PILOT_ART_BIBLE.md](PILOT_ART_BIBLE.md); manufactured pilot equipment is not a
companion anatomy reference.

## Canonical starter lineup

- **Искра** — the agile turquoise ground scout; stable server ID `spark-v1`.
- **Мох** — the patient moss-backed guardian; stable server ID `moss-v1`.
- **Навигатор** — the violet floating companion shown in the third row of the
  approved starter sheet.
- The hooded figure in the bottom row is a pilot, not a fourth pet.
- Люма is a discarded draft and is not a companion, evolution form or style
  reference.

The current server catalog exposes the violet companion as `rune-v1` with the
player-facing forms «Навигатор», «Навигатор потоков» and «Навигатор
созвездий». The stable ID and `companion_rune_*` asset paths intentionally
remain unchanged for compatibility. The separate `navigator-v1` pilot keeps
its identity name in portrait and dossier contexts; paired crew copy uses the
neutral role «Пилот» so the two characters remain unambiguous.

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

## Мох identity

- Low, broad and weighty alien quadruped with a patient grounded stance.
- A layered stone-and-bark shell carries living moss and one small physically
  connected sprout; the growth never becomes a detached effect or accessory.
- Calm dark intelligent eyes, a short blunt face and thick load-bearing limbs
  keep the silhouette readable without baby-doll proportions.
- Muted olive, lichen and deep blue-charcoal materials dominate. Restrained
  amber warmth may appear only in natural seams, never as symbols or circuits.
- Four sturdy animal feet, with no hands, clothing, tools, collar, weapons,
  manufactured armor or readable shell markings.
- Primary character: patient, protective, observant and quietly reassuring.

Gaze, head angle, forefoot weight, shell posture and sprout movement communicate
emotion in that order. Locomotion is deliberate and close to the ground; jumps
compress deeply, travel only a short distance and land with visible weight. The
sprout follows the body with soft organic delay rather than acting like an
antenna or mechanical indicator.

## Навигатор identity

- Compact levitating alien companion built around one faceted violet body and
  a dark inset face with two intelligent cyan eyes.
- Crown, back and lateral crystal planes create an asymmetric readable
  silhouette; they are organic mineral anatomy, never manufactured armor.
- A curved articulated crystal tail/fan and its stabilizer facets read as one
  coherent connected orbit around the body, not ambient debris or particles.
- Deep violet, indigo and blue-black dominate. Cyan light stays local to the
  eyes and restrained anatomical seams; rare warm glints only mark discovery.
- No legs, paws, hands, wings, clothing, tools, pilot equipment, weapons,
  readable symbols, circuits or generic drone hardware.
- Primary character: precise, curious, quietly intense and highly attentive.

Gaze, face-plane angle, lateral stabilizers, crown overlap and tail/fan curvature
communicate emotion in that order. Locomotion is a controlled hover and fast
directional glide rather than walking. Vertical bursts keep the whole body
intact, while stabilizers and the tail/fan counter the change in momentum.

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

The Искра, Мох and Навигатор v1 atlases and machine-readable cell maps live in
`mobile/assets/characters/companion_{spark,moss,rune}_motion_v1.{png,json}`.
The violet companion retains the current stable `rune-v1` presentation ID
until the separate naming migration is reviewed; the atlas does not silently
change catalog or API state.

## Exclusions

- No chibi proportions, baby-doll eyes, anime/cel treatment, pixel art, heavy
  comic outlines, plastic highlights or photoreal fur.
- No cyberpunk circuits, manufactured plates, straps, readable symbols,
  weapons or generic sci-fi gadgets.
- No scenery or ambient effect baked into reusable character sprites.
- Do not reuse discarded Люма anatomy, round mouse ears, paddle tail, white
  muzzle mask, purple coat patches or detached glowing anatomy for Искра.
