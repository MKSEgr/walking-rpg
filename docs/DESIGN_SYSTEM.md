# Walking RPG — visual foundation

## Product expression

The interface should read as an asynchronous expedition RPG before it reads as
an activity tracker. Walking remains the input, while route, signal, crew and
choice are the visible product language.

The first direction is **soft science-fantasy frontier**:

- deep water and night-ink surfaces create distance and calm;
- lumen teal marks the trusted route and primary action;
- amber is reserved for ENERGY, movement and crafted utility;
- violet marks resonance, unusual events and gated paths;
- route contours, radar circles and sparse nodes suggest navigation without
  turning the app into a tactical HUD.

The result must avoid both a generic fitness dashboard and high-noise neon
cyberpunk. It is designed for adults, short sessions and readable Russian copy.

## Experience hierarchy

The expedition screen follows the actual game loop:

1. current node and expedition state;
2. today's personal walking progress;
3. available ENERGY and route progress;
4. the single next authoritative action;
5. pending result or event choice;
6. pilot and active pet;
7. equipment, inventory and workshop;
8. technical version metadata.

Cached state, pending acknowledgements and locked choices keep their existing
behavior. Styling never creates optimistic progress or hides a server-owned
restriction.

## Tokens

| Role | Dark reference | Meaning |
|---|---:|---|
| Ink | `#07151D` | application depth |
| Deep water | `#0B2028` | elevated background |
| Night panel | `#102A33` | field panels |
| Lumen | `#66E6BE` | route, success, primary action |
| ENERGY | `#FFC85A` | movement currency and crafting |
| Resonance | `#AE98FF` | rare signal and optional path |
| Signal red | `#FF7C89` | actionable error only |
| Moon mist | `#DDEDE8` | primary dark-mode text |

Theme-specific values are exposed through `WalkingRpgPalette`; business
widgets should not introduce independent accent colors.

## Component rules

- `ExpeditionBackdrop` owns the quiet atmospheric layer. Its painter is static,
  ignores input and does not animate while scrolling.
- `ExpeditionPanel` is the default grouped surface. Tone communicates domain,
  not enabled/disabled state.
- `ExpeditionBadge` is used for short state or location labels.
- `ExpeditionProgressRing` is used only for one headline progress measure.
- the bottom navigation floats above content, while screens reserve enough
  bottom padding for it;
- primary controls have a minimum height of 52 logical pixels;
- labels and icons accompany color-coded state so meaning is never color-only.

## Light, dark and accessibility

The application follows the operating-system theme. Both palettes retain the
same semantic accents. Text scaling, screen-reader labels and platform reduced
motion remain part of every screen review. Decorative painting must not add
semantics or intercept gestures.

## Next visual slices

1. Define the world key art and the first chapter environment language.
2. Design final silhouettes and three evolution stages for all starter pets.
3. Turn the expedition chapter into a visual route map without adding GPS or
   real-time walking interaction.
4. Recompose the journal into player-facing tabs and move diagnostics behind a
   clearly secondary surface.
5. Produce app icon, splash, store screenshots and motion guidelines only after
   the in-game direction is approved.
