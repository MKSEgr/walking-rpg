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

## Companion identity

`CompanionPortrait` gives every starter a recognizable code-native silhouette
that remains readable without relying on color:

- Искра is an angular lumen scout with high ears and a signal tail;
- Мох is a low, rounded terra guardian with a living sprout;
- Руна is a faceted echo navigator framed by asymmetric signal waves.

The portrait reads the stable `petId` for identity and the authoritative
`evolutionStage` for additional geometry. Stage zero is the base form; later
values enrich the same silhouette rather than replacing it with an unrelated
character. The painter is prepared for stages zero through two, but the client
never predicts, unlocks or advertises a stage that the server did not return.

Portraits are static repaint boundaries, carry a complete semantic label and
pair the active marker with text elsewhere in the card. The first journey and
the journal share the same portrait. Home now carries the same identity into
its expedition hero only when the accepted mobile snapshot contains the
server-owned `petId`, species and `evolutionStage`. Older cached responses that
predate those additive fields keep the textual active-companion badge; the
client never derives identity or form from the pet name.

The Home companion signal pairs the portrait with explicit active-companion,
level, form and bond text. It becomes vertical on narrow layouts, remains a
static presentation of the accepted snapshot and does not affect compass
visibility, command execution or navigation lifecycle.

## First chapter environment

`ChapterVista` defines the code-native key art for the first chapter: layered
mist, quiet ridges, a distant signal tower and a sparse lumen trail. The scene
keeps the same calm frontier tone in light and dark themes and avoids assets
that could drift away from the application palette.

The vista is deliberately not a route map. Its waypoints are atmospheric, do
not represent the server's node topology and are never interactive. When the
first journey supplies authoritative expedition progress, only the signal
trail illumination changes; the journal uses the scene without a progress
value. The painter is static, isolated by a repaint boundary, ignores input and
exposes one concise image semantic instead of decorative child semantics.

The first journey, journal and Home expedition hero share this environment.
Home supplies only the progress from its accepted snapshot; cached state stays
visually honest, and the vista does not participate in impression visibility or
navigation lifecycle decisions.

## Entry experience

The authentication entry uses the same quiet frontier backdrop and first-
chapter vista as the accepted in-game direction. The vista is atmospheric and
receives no progress value before authentication, so it cannot imply a player
route or accepted server state.

Sign-in remains a thin presentation over the existing OIDC lifecycle. The
screen preserves controller-owned busy, reauthentication, error and notice
states; it opens the same system-browser flow and does not handle credentials.
Privacy facts shown before entry are limited to existing product boundaries:
no GPS and read-only step access. Status messages are live regions, while the
illustration exposes one concise image semantic.

## Journal composition

The path journal extends the expedition language without becoming a second
Home screen:

- the season hero identifies the authoritative chapter, state version, active
  companion, XP and currently known ENERGY balance;
- first-journey progress remains the first resumable task;
- the weekly route is the single headline progression measure and therefore
  owns the ENERGY progress ring;
- companions, pilot skills, quests, squad, cosmetics and achievements use
  domain-toned field panels while preserving their existing command keys;
- experiment assignments and remote configuration remain collapsed service
  diagnostics rather than player-facing progression.

Cached journal snapshots stay read-only and never infer ENERGY from stale
platform state. Visual badges summarize only values already present in the
accepted read models.

## Pilot dossier and account controls

The account surface is a pilot dossier, not another progression screen. It
shares the expedition backdrop, field panels and semantic accents so the route
language survives outside Home, while displaying only authenticated identity
and local runtime state that the screen actually owns.

- the dossier names the current identity and distinguishes a protected OIDC
  session from development mode without implying extra account status;
- saved-action counts and store warnings continue to come from the existing
  owner-scoped command runtime, and the Validation Center remains visible only
  when the shell supplies that internal route;
- export stays a plain, portable JSON data action and does not become a reward
  or progression mechanic;
- permanent deletion keeps signal-red styling, explicit irreversible copy and
  the existing two-step plus fresh-login confirmation;
- no pet form, chapter progress, security claim or server capability is
  inferred for decorative effect.

## Saved-action recovery

The saved-action route is a recovery trust layer, not an alternate command
console. It uses the expedition backdrop and field panels while preserving the
owner-scoped runtime as the only source of queue state.

- the summary displays only the accepted local snapshot counts for pending and
  terminal failed records;
- explicit replay remains available only when pending records exist and keeps
  the original command, payload and idempotency boundary;
- pending records cannot be removed because the server response may have been
  lost after the mutation completed;
- only terminal failed diagnostic records expose dismissal, with the existing
  confirmation that server state is not changed;
- unreadable storage remains fail-closed, exposes no raw path, payload or token
  data and never implies that the queue was cleared;
- compact layouts and enlarged system text stay scrollable, and signal red is
  paired with explicit rejected-state copy rather than used as color alone.

## Primary read states

Home and the path journal share one connection-state composition before an
authoritative snapshot is accepted. The state reads as contact with the route,
not as a generic blocking dialog or invented game progress.

- loading exposes an indeterminate signal only; it never estimates completion
  or renders values from a snapshot that has not been accepted;
- failure states keep the exact existing retry boundary and show diagnostic
  detail separately from the player-facing explanation;
- Home may still open its local demonstration snapshot explicitly, while the
  journal offers no stale interactive fallback;
- a failed refresh does not expose journal commands or optimistic state;
- the status badge keeps its complete label and may wrap under enlarged text;
- the shared panel is a live region with a semantic heading and remains
  scrollable at compact width with enlarged system text.

## Physical-device validation

The internal Validation Center carries the same trust-layer language into a
controlled device-evidence workflow. Resonance marks the non-release operator
surface, while lumen, ENERGY and resonance distinguish accepted Health facts,
server sync and the authoritative checkpoint without changing their meaning.

- the launch hero states that the route is internal and that exported JSON is
  not physical-device evidence without the dated protocol and review;
- build, authentication mode, Health source and source SHA remain literal
  metadata from the current launch rather than decorative status;
- Health read, synchronization and checkpoint capture remain three explicit
  operator actions, and the presentation does not add background work;
- observation panels and the launch journal display only the controller's
  owner-bound in-memory snapshot, with no raw payload or identity;
- schema-v1 export keeps the existing allowlist, redaction, checksum, size,
  temporary-file and active-owner checks;
- compact layouts and enlarged system text keep the complete workflow
  scrollable, including the safety note and final export action.

## Next visual slices

1. Turn the expedition chapter into a visual route map only from an
   authoritative topology/read model, without adding GPS or real-time walking
   interaction.
2. Split the journal into player-facing tabs only when closed-beta content
   density proves that the single expedition log no longer scans well.
3. Produce app icon, splash, store screenshots and motion guidelines only after
   the in-game direction is approved.
