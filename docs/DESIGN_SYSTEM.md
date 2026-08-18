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

## Native application identity

The launcher and native startup boundary use one universal expedition emblem:
a dark compass, an illuminated route and a distant ENERGY signal. It belongs
to the whole expedition rather than one starter, so the application never
selects Искра, Мох or Руна before the player does.

- launcher art contains no text and keeps its essential silhouette inside the
  Android `66 × 66 dp` adaptive-icon safe zone;
- Android supplies separate foreground/background layers, a round fallback and
  a monochrome themed-icon layer; iOS exports every declared app-icon scale
  from the same source;
- the native splash uses the same emblem on application Ink `#07151D`, with no
  fake loading progress, animation delay, remote content or Flutter dependency;
- Android 12+ delegates masking and startup timing to the system splash API,
  while older Android and iOS show the static mark until Flutter's first frame;
- startup remains decorative and introduces no accessibility announcement,
  gameplay state or navigation action.

## Component rules

- `ExpeditionBackdrop` owns the quiet atmospheric layer. Its painter is static,
  ignores input and does not animate while scrolling.
- `ExpeditionPanel` is the default grouped surface. Tone communicates domain,
  not enabled/disabled state.
- `ExpeditionBadge` is used for short state or location labels.
- `ExpeditionProgressRing` is used only for one headline progress measure and
  renders a broken route orbit rather than a generic fitness gauge.
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

`CompanionPortrait` gives every starter a recognizable production illustration
that remains readable without relying on color:

- Искра is an angular lumen scout with high ears and a signal tail;
- Мох is a low, rounded terra guardian with a living sprout;
- Руна is a faceted echo navigator framed by asymmetric signal waves.

New companion production follows the canonical lineup, shared rendering rules
and naming gap recorded in [COMPANION_ART_BIBLE.md](COMPANION_ART_BIBLE.md).

The original four crew portraits are one coherent illustrated atlas: a
universal helmeted Navigator pilot plus the adult forms of Искра, Мох and Руна.
Each companion also has identity-preserving young and adolescent portraits.
All WebP assets stay readable at the `72-80 px` in-product sizes and use the
same night-ink, lumen, ENERGY and resonance palette as the Flutter theme. The
pilot portrait is shared by Home and the account dossier; companion portraits
are shared by the first journey, Home and the journal.

The companion reads the stable `petId` for its illustration and the
authoritative `evolutionStage` for both the portrait and code-native orbit
geometry. Stage zero is the small young form, stage one is the adolescent form
and stage two is the existing fully developed portrait. Player-facing copy
names those forms **Малыш**, **Юный** and **Взрослый** instead of exposing only
a technical number. A static three-node growth line may show this known visual
arc, but only the server-returned stage is marked as current. It never predicts
unlock eligibility, bond requirements, rewards or transition timing. Unknown
future IDs keep the previous code-native painter fallback instead of guessing
an illustration from a name; stages beyond the illustrated set keep their
literal form number and the last known portrait rather than receiving an
invented age label.

Selection, growth, journal and dossier portraits are static repaint boundaries,
carry a complete semantic label and pair the active marker with text elsewhere
in the card. Home carries the same companion identity into its expedition hero
and crew card only when the accepted mobile snapshot contains the server-owned
`petId`, species and `evolutionStage`.
Older cached responses that predate those additive fields keep the textual
active-companion badge and icon fallback; the client never derives identity or
form from the pet name.

The first game-native motion candidates belong only to the exact `spark-v1`,
`moss-v1` and `rune-v1` identities. Each transparent raster atlas contains nine
explicit clips and sixteen look directions behind a versioned manifest; no clip
is selected from the pet name, species or inferred gameplay state. Home may
play one idle pass for any of those accepted exact IDs, while pet choice and
growth surfaces retain the stage-specific portraits. The violet companion
keeps the current `rune-v1` / «Руна» server presentation until its separate
naming migration is reviewed. Reduced-motion settings hold the first frame,
and continuous looping requires a deliberate scene-level opt-in. These
candidates are material for the physical motion review in TASK-011, not
evidence that the three-pet visual direction or motion tolerance has already
been validated.

The universal `navigator-v1` pilot now has a separate transparent motion atlas
under the identity and movement rules in
[PILOT_ART_BIBLE.md](PILOT_ART_BIBLE.md). Home plays one non-looping idle pass
for that exact current presentation; the account dossier and journal keep their
static portrait. The shared atlas player preserves reduced-motion behavior and
frame geometry without treating pilot art as a companion species. No pilot ID,
selection, progression, API or persistence state is changed by the asset.

The Home companion signal pairs the portrait with explicit active-companion,
level, named form, bond text and the non-interactive growth line. Journal pet
cards repeat the same current marker beside a code-native bond field and the
existing evolution action. Exact `spark-v1`, `moss-v1` and `rune-v1` IDs keep
their spark, growth and echo identities; any future ID receives a neutral
constellation instead of inheriting art from its name or species. The field
uses only the literal accepted bond, evolution target, current server form and
existing `canEvolve` result. Its four trace samples are decorative rather than
invented thresholds, and an evolved companion keeps the literal bond without
showing a fake next target. The composition becomes vertical on narrow layouts,
remains a static presentation of the accepted snapshot and does not affect pet
selection, evolution availability, command execution or navigation lifecycle.

## Character cosmetics

Character art responds only to server-known cosmetic IDs. `pilot-scarf`
selects the illustrated scarf portrait for the universal Navigator, while
`spark-halo` adds an ENERGY-colored light ring above the accepted current form
of Искра. The cosmetics list shows these real character previews instead of a
generic sparkle icon. Preview portraits are decorative and excluded from
semantics; the cosmetic name and action remain the accessible source.

The base Navigator motion atlas never approximates or removes the scarf. A
motion portrait receiving the exact `navigator-v1` plus `pilot-scarf` state
uses the separately versioned scarf atlas; the cosmetic catalog may play one
non-looping idle pass from it. The account dossier and journal retain
`pilot_navigator_scarf.webp`, and unknown future pilot IDs keep the static
portrait fallback.

Portrait widgets accept a set of equipped cosmetic IDs so presentation is
driven by the additive server-owned `equippedCosmetics` mapping. The journal
renders the Navigator and active companion together, applies the returned
`PILOT` and `PET` values independently and marks every equipped catalog card;
`PROFILE` remains a separate server slot rather than replacing character art.
Exact responses committed before that field existed fall back to the legacy
`activeCosmeticId`, while an explicitly empty mapping remains authoritative.
The client never combines local selections with server state. Unknown IDs keep
the base portrait. An equipped projection is accepted only when its slot is
supported and exactly matches the referenced server-catalog item; unknown IDs
or cross-slot assignments reject the inconsistent snapshot instead of being
silently reinterpreted by presentation.

The two existing `PROFILE` cosmetics now have their own code-native route
identity. `trail-banner` places a compact three-signal expedition banner over
the journal vista, while `dawn-frame` adds an ENERGY sunrise frame around the
same accepted chapter image. Their catalog cards show matching previews rather
than the generic sparkle icon. The treatment is selected only from the exact
server-owned `equippedCosmetics.PROFILE` value; the cosmetic name never selects
art. Unknown future profile IDs keep the unmodified vista and receive a neutral
constellation preview. Neither treatment changes chapter semantics, progress,
topology, availability or any command boundary.

## First journey route signal

The journal and the guided first-journey header present the same milestones as
one quiet code-native route instead of generic progress bars. Journal node
order comes directly from `content.onboardingSteps`, while the guided flow uses
its existing bounded `FirstJourneyProgress.steps` sequence. Journal completion
comes only from `completedOnboardingSteps`; the guided header repeats the same
effective completion facts that already choose its current screen.

The six current exact step IDs select welcome, Health permission, first sync,
pet selection, first expedition and first decision marks. An unknown future ID
receives a neutral constellation even when its display copy resembles a known
step. The base trace preserves the accepted ordering; an illuminated segment
appears only between two adjacent completed steps. It never selects a current
step, predicts availability, completion timing or chapter topology.

Painting is decorative. The journal signal owns one complete route summary,
while every visible journal row states its own complete or incomplete status.
In the guided header the painting is excluded from semantics because the
existing `N/6 этапов пройдено` copy remains its one accessible summary. The
guided signal does not choose a stage; it only mirrors the already accepted
`FirstJourneyProgress.completedSteps`. Resume/continue actions, onboarding
command ownership and authoritative reload remain unchanged. At compact width
with enlarged text, the full-width signal stays above the journal milestone
list or guided stage panel without compressing their two-line actions.

## Pilot progression sigils

The journal gives server-authored pilot skills and achievements a compact
code-native sigil vocabulary instead of repeating generic hub, trophy and lock
icons. Each current catalog identity has a distinct route, signal, ENERGY,
crew or milestone silhouette. Exact stable `skillId` and `achievementId`
values select those marks; an unknown future ID receives a neutral
constellation fallback even if its display name resembles existing content.

Sigils never decide availability or completion. Skill unlock state continues
to come from `unlockedSkills`, achievement state from the accepted achievement
set, and all names, descriptions, XP requirements and ordering remain
server-authored. Locked and unlocked treatments pair contrast with explicit
text, while the decorative mark is excluded from semantics so screen readers
hear one server name and one literal state. At compact width with enlarged
text, achievement tiles become a single vertical list and skill actions retain
their existing full-width command boundary.

## Quest route signals

Journal quests use a code-native objective mark and a five-node route trace
instead of repeating one generic assignment icon and Material progress bar.
The exact server-authored `metric` selects the current vocabulary:

- `TOTAL_ACCEPTED_STEPS` uses a walking trail;
- `RESOLVED_EVENTS` uses a linked signal;
- `SQUAD_MEMBERSHIP` uses a three-member route cluster.

An unknown future metric receives a neutral constellation even when its quest
name resembles current content. The accepted `progress` and `target` illuminate
the trace proportionally; `ready` and `claimed` affect presentation only and
remain paired with the explicit **«В пути»**, **«Готово»** or **«Получено»**
badge. Quest order, reward-first experiment assignment, reward values, claim
availability and command identity remain server-owned.

Objective painting is decorative and excluded from semantics. The route trace
exposes one complete label with the current server quest name and literal
progress. Compact cards place the mark above the name and keep the existing
full-width claim action; wide cards keep the mark beside the server copy.

## Weekly route beacon

The journal gives the headline weekly route one code-native ENERGY beacon
instead of a generic route icon and progress ring. The exact server-authored
`routeId` selects the known first-signal trace; an unknown future ID receives a
neutral constellation fallback even when its season name resembles current
content.

The illuminated part of the trace is driven only by accepted
`weeklyRouteProgress / weeklyRouteRequiredEnergy`. Its five painted samples are
decorative positions along one continuous measure: they are not chapter nodes,
reward tiers or client-owned milestones. Season name, level, XP, remaining
ENERGY, available wallet balance and claim actions remain separate literal
server facts.

The painter is excluded from semantics. One complete label exposes the exact
season name and numeric ENERGY progress, while the same numbers remain visible
below the beacon. Compact layout places the beacon above the server copy; wide
layout keeps it beside that copy. Spend and reward commands, read-only state,
remote-config availability and authoritative reload remain unchanged.

## Season reward seals

The weekly route gives its existing claimable season reward a compact
code-native seal instead of returning to a generic gift icon. The persisted
first-signal ID `signal-season-1` and its bounded local/default predecessor
`season-1` select the same current identity only by exact match. Season names,
prefixes and suffixes never select art, and any future season keeps the neutral
constellation.

The partial orbit repeats only the literal reward level against the accepted
season level count. It does not discover the next reward, decide claimability,
describe reward contents or infer completion from XP. The existing weekly card
continues to decide whether the claim button is present and enabled from its
accepted state, and its complete **«Награда уровня N»** label remains the only
accessible content for the decorative seal.

The seal owns no command, callback, idempotency, cached-state or authoritative-
reload behavior. Its fixed square stays inside the existing wrapping claim
control at compact width and in both themes.

## Squad formation signal

The journal turns accepted squad membership into a quiet resonance formation
instead of presenting the group as an administrative text block. The signal is
driven only by whether `squad` exists and by the exact length of the accepted
`memberUserIds` list. It never assigns portraits, roles, online presence or a
client-side capacity to those opaque identities.

Up to six decorative member nodes remain legible in the formation. Larger
server-owned squads add an overflow broadcast mark while the adjacent text
continues to state the exact member count; the visual cap is not a membership
limit. When `squad` is absent, the same component shows an open channel beside
the existing create and join controls without implying that either command has
already succeeded.

The formation is excluded from semantics. One summary exposes the exact
server-provided squad name and member count; the full `squadId` remains a
separate selectable text value, and leave remains a separate control. Compact
layouts place the signal above that summary and make create, join and leave
actions full-width. Command keys, payloads, busy/read-only conditions and
authoritative refresh stay unchanged.

## Expedition item vocabulary

The first field-kit illustrations turn server-owned rewards and equipment into
recognizable expedition objects instead of repeating generic Material icons:

- `lumen-shard` is an asymmetric lumen crystal with a visible ENERGY core;
- `echo-thread` is a flexible braided resonance filament with an open loop;
- `resonance-compass` is the crafted circular navigation instrument that
  combines lumen, resonance and one ENERGY marker.

The same square art follows an item through event reward preview, durable
result, inventory, recipe ingredients, crafted result and equipped navigation
slot. It is selected only from the exact stable `itemId`; an unknown ID
receives the neutral code-native fallback even if its display name resembles
known content. Presentation never derives quantity, rarity, availability,
recipe state, equipment state or route access from the illustration.

Item art is decorative beside the complete server-provided name and state
copy, is excluded from semantics and does not intercept input. Highlighted
borders may reinforce a unique, crafted or equipped presentation only where
adjacent text already states that condition. The coordinated `512 x 512` WebP
sources remain legible at `56-72 px`; compact item identities place art above
copy and the existing full-width action instead of compressing text beside the
image.

## Crafting assembly signal

The workshop gives the existing `resonance-compass-v1` recipe its own code-
native assembly contour. Accepted ingredient nodes converge on a resonance
instrument core and then on one output signal. The known contour is selected
only from the exact server-owned `recipeId`; an unknown future recipe keeps a
neutral constellation core even when its display name resembles the compass.

Ingredient node illumination comes only from the literal accepted available
and required quantities already shown in the adjacent rows. The output trace is
illuminated only by the accepted `READY` or `CRAFTED` status; the client does not
derive recipe readiness from the painted inputs. A decorative cap limits a
large future ingredient list to four nodes and an overflow mark, while the full
server list and every exact quantity remain visible and accessible below it.
The signal is excluded from semantics and owns no craft action, impression,
outbox, idempotency or authoritative-reload behavior. Its fixed-height field
remains width-flexible at `320 px / 1.6×` text scale.

## Equipment mount signal

The server-owned `NAVIGATION` slot is presented as a field-instrument mount
rather than a generic administrative row. Its two route rails remain open for
the accepted `EMPTY` status and illuminate only for the accepted `EQUIPPED`
status. The installed `resonance-compass` receives its own needle identity only
from the exact item ID; an unknown item keeps a neutral constellation inside
the accepted slot, and an unknown slot uses a neutral field instead of
borrowing the navigation contour.

The mount does not infer equipment compatibility, route availability or an
action from item ownership. Slot status and item identity come literally from
the accepted equipment projection; the existing full slot name, description,
item copy and `EQUIP`/`UNEQUIP` controls remain authoritative. The signal is
excluded from semantics and input handling, and owns no command, idempotency,
impression or reload behavior. Its fixed-height field remains width-flexible in
light and dark themes at `320 px / 1.6×` text scale.

## Expedition event scenes

Four pivotal first-chapter events establish the illustrated scene vocabulary:

- `signal-source-v1` frames the outer beacon and its repeating signal;
- `echo-vault-v1` frames the unstable archive core, stabilization lattice and
  living echo thread;
- `mirror-delta-v1` frames the reflected fork and the concealed resonance
  current;
- `resonance-pocket-v1` frames forgotten routes converging inside folded
  space.

The same event scene follows an exact `eventId` through the ready choice card,
durable result handoff and guided first journey. It never selects art from a
title or summary and never derives choice availability, requirements, rewards
or route access. Unknown IDs receive a neutral code-native signal field, so
future server content remains readable without borrowing an unrelated scene.

Each scene owns one concise image semantic that begins with the current
server-authored event title; visual node names never become a parallel content
source. The visible server title, summary, choice and result copy remain
unchanged. The `960 x 540` WebP sources keep their focal silhouettes inside the
middle of the frame, render behind a repaint boundary and scale proportionally
at compact width before the height cap is applied on wider surfaces.

## Event choice signals

The open event choices on Home and in the guided first journey use compact
code-native decision marks instead of visually identical text-only controls.
The vocabulary distinguishes signal analysis, companion-led movement, core
stabilization, living echo, field survey, resonance passage, hidden-current
cartography and compass guidance.

Every current mark is selected only from the exact server-owned
`eventId / choiceId` pair. All 39 current pairs are covered; the accepted
legacy `signal-source-v1 / trust-companion` pair keeps the companion mark for
older chapter-v1 snapshots. A known choice ID inside a future event, a future
choice inside a known event or any other unknown pair receives the neutral
constellation. Titles and descriptions never select art.

The literal accepted choice availability may only mute the mark on Home. It
does not decide whether the owning button is enabled, and locked requirement
copy remains explicit. Full server-provided title, description, XP, bond and
material reward copy stays in the existing control semantics; the mark and
optional item art are decorative. At compact width the mark and reward art
move above the copy while the original callback, command key, idempotency,
telemetry and authoritative reload boundaries remain unchanged.

After a choice is accepted, the same exact-pair mark follows its server-owned
identity through the durable Home handoff, an accepted resolved event card and
the guided first-journey completion. The mark never decides that a resolution
succeeded, predicts the next node or derives an outcome or reward. Legacy
resolved snapshots without a `selectedChoiceId` keep their complete text-only
fallback; future event/choice pairs retain the neutral constellation.

## Event progression gain signals

Accepted event results give pilot XP and companion bond their own code-native
gain marks instead of returning to generic person, pet or check icons. The
durable Home handoff and guided first-journey completion share the same
vocabulary: `navigator-v1` uses the route-pointer mark, while `spark-v1`,
`moss-v1` and `rune-v1` retain distinct spark, growth and echo identities.

Dispatch requires both the exact reward channel (`pilotExperience` or
`petBond`) and the exact server-owned subject ID. A known pet ID in the pilot
channel, a known pilot ID in the companion channel or any future subject keeps
the neutral constellation even when the visible name resembles current
content. Names never select art.

The signal is decorative and does not calculate the gained amount, resulting
total, level, evolution stage or reward availability. Complete server-provided
numbers and names remain the accessible source beside the mark; material
rewards keep their exact item artwork. Compact result surfaces place the mark
above wrapping copy, while wider surfaces keep both in one row. ACK, command,
outcome and authoritative-reload boundaries remain unchanged.

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

## Current node landmarks

The Home hero pairs the complete server-provided current-node name with one
compact code-native landmark instead of repeating the same radar icon at every
stop. All nineteen nodes in the accepted `chapter-1-v2` catalog, including the
optional `resonance-pocket`, have distinct silhouettes selected only from the
exact `currentNodeId`. A future unknown ID receives a neutral constellation even
when its display name matches a known landmark.

The landmark represents one accepted current location, not chapter topology.
It does not show ordering, adjacency, hidden branches, travel availability or a
predicted next node. Progress, completion and the advance action continue to
come from the accepted expedition snapshot; completion only adds the existing
flag treatment. The painter is excluded from semantics and input, while one
container announces the complete server-authored current-node name and literal
completion state. The two-line label remains readable at compact width with
enlarged system text.

When an accepted event result explicitly contains `nextNode`, the same exact-ID
landmark appears with a next-node role in the durable Home handoff and guided
first-journey completion. An absent value remains absent, and a future ID keeps
the neutral constellation. This handoff does not infer adjacency, route order
or availability; it only repeats the server-provided ID and complete name, with
separate next-node semantics and a decorative forward marker.

## Expedition progress signals

The main Home route and the guided first expedition share one code-native
ENERGY trace instead of returning to a generic progress bar. The exact
server-owned `starter-expedition-v1` ID selects the outer-beacon contour; a
future expedition ID keeps a neutral constellation even when its name or node
copy resembles the first chapter.

The illuminated trace uses only the literal accepted
`progress / requiredEnergy` ratio already shown beside it. Its five samples are
decorative positions along one continuous measure, not chapter nodes, event
gates or client-owned milestones. Current node identity remains separate in the
accepted snapshot, and the signal never predicts adjacency, completion or route
availability.

Painting is excluded from semantics. Existing complete progress, current-node,
wallet and remaining-ENERGY copy stays accessible on both surfaces. The signal
owns no advance/sync callback, command key, idempotency, cached read-only state
or authoritative reload behavior, and its fixed-height field remains
width-flexible at compact size with enlarged text.

## Activity intake signal

The guided Health-permission step receives one static route-intake field so it
no longer falls back to a generic walking icon while every adjacent first-
journey stage carries its own expedition visual. Footfall marks enter a quiet
route gate; lumen identifies the trusted route, ENERGY recalls why walking
matters and resonance marks the privacy boundary.

The signal represents only the product contract already stated by the screen:
the app reads step count and does not read GPS. It accepts no step value,
permission state, provider, risk result or synchronization outcome, and it
never shows progress, success or a reward before the existing command returns.
The system permission sheet, activity coordinator, idempotency boundary and
authoritative refresh sequence remain unchanged.

The painter is static, has one concise image semantic and does not intercept
input. The existing body copy remains the detailed source for Health scope and
the complete action label remains reachable at compact width with enlarged
text.

## Daily route orbit

Home presents the accepted daily walking ratio as one quiet broken route orbit
instead of a generic Material activity ring. The center repeats the existing
literal percentage, while the adjacent copy remains the source for exact daily
steps, personal goal and policy explanation.

The first-journey activity reward repeats that orbit only after a successful
sync response. Its trace combines the response's literal `acceptedTotal` with
the personal `dailyGoal` from the already accepted Home snapshot, and the
adjacent copy exposes both values. It does not issue or imitate a second
reward, infer ENERGY, or alter the onboarding command and refresh sequence.

The five painted samples are decorative positions along one continuous daily
measure. They are not reward tiers, ENERGY grants, streaks or client-owned
milestones, and the highlighted trace uses only the already accepted bounded
`dailyProgress`. Goal calculation, Health synchronization, ENERGY issuance and
the expedition action remain outside the component.

The static painter owns one complete semantic summary and excludes its internal
percentage copy from duplicate announcements. It keeps the same fixed square
footprint in light and dark themes and in the existing compact Home reflow.

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
  owns the exact-ID ENERGY beacon;
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

## Cached route state

Home and the path journal identify an accepted cached snapshot as a saved
route rather than presenting it as a generic offline warning. The composition
must preserve the trust boundary between readable server-confirmed history and
actions that still require a live authoritative response.

- the complete saved-route status, snapshot time and read-only explanation are
  shown before the cached screen content;
- the transport or server reason remains separate supporting detail and never
  becomes a route fact, reward or progress value;
- the banner owns no retry or mutation callback: each screen keeps its existing
  refresh action, while cached gameplay and platform commands remain disabled;
- signal red is not used for this non-destructive degraded state, and the cloud
  icon, badge and explicit copy carry meaning without relying on color;
- the whole state is a live region with a semantic heading, and its badge and
  reason wrap without truncation at `320 px / 1.6×` text scale.

## First journey bootstrap states

The first journey uses the same route-contact composition while startup replay
and the two authoritative read models are still being prepared. This keeps the
guided entry in the accepted expedition language without pretending that a
milestone or route value has already been restored.

- loading covers both owner-scoped saved-action replay and the subsequent Home
  and journal reads, and remains indeterminate throughout;
- failure keeps diagnostic detail separate from the player-facing explanation
  and exposes the existing retry boundary;
- the explicit **«Открыть игру»** path keeps its existing continue-later
  behavior, while recovery and account actions remain available in the app bar;
- no previous first-journey screen, milestone or reward is shown before both
  authoritative snapshots have been accepted;
- compact layouts and enlarged system text stay scrollable, with the same live
  region, semantic heading and complete status label as the primary read state.

## Application boundary states

Session restoration, protected runtime shutdown, launch configuration and the
internal Validation Center bootstrap share one application-boundary
composition before any player snapshot can be shown.

- loading remains indeterminate and explains the controller-owned lifecycle
  operation without inventing route progress or adding a second retry path;
- restoration and shutdown use distinct copy, while the authentication
  controller keeps ownership of state transitions and route dismissal;
- blocked configuration and validation states remain fail-closed and expose no
  action that cannot be completed by the current lifecycle;
- raw configuration diagnostics remain development-only; release builds keep
  the existing redacted instruction;
- resonance continues to identify the internal validation domain, while signal
  red identifies a blocked launch and is paired with explicit text;
- the shared full-screen panel is a live region with a semantic heading and
  stays scrollable at compact width with enlarged system text.

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

## Trust decision dialogs

Irreversible account controls and terminal recovery cleanup use one explicit
decision composition instead of a generic Material alert.

- account deletion keeps both existing confirmation stages, the exact
  `УДАЛИТЬ` phrase and fresh identity-provider authentication; the dialog does
  not own deletion, session shutdown or idempotency;
- recovery cleanup remains limited to terminal local diagnostics and states
  plainly that authoritative server state is not changed;
- signal red is reserved for the destructive confirmation, while a complete
  badge, icon and copy carry the same meaning without color;
- cancel remains available at every local decision boundary, and disabled
  confirmation stays disabled until the caller's existing condition is met;
- the semantic heading, complete wrapping badge and a single scroll surface
  keep warnings and both actions reachable at compact width with enlarged
  system text.

## First journey field signals

Read-only recovery, controller notices and outcome-ambiguous action feedback
remain part of the guided route instead of falling back to generic Material
cards. The shared inline signal preserves the distinction between information
and state that needs an authoritative check without changing who owns it.

- saved-state copy uses a neutral signal and does not imply that a live route
  or mutation is available;
- controller notices use lumen; the shared error channel uses resonance and
  **«Состояние требует проверки»** because it can also receive a failed reload
  after a confirmed mutation;
- signal red requires an explicit caller classification that the action was
  not authoritatively confirmed and is not inferred from `errorMessage`;
- the signal owns no retry, dismissal or navigation callback, and it never
  turns diagnostic text into route progress or a reward;
- icon, explicit status label and body copy carry meaning without relying on
  color, and every dynamic signal is announced as a live region;
- the complete label and message wrap without truncation inside the existing
  first-journey scroll surface at `320 px / 1.6×` text scale.

## Compact Home composition

The full expedition Home remains the same authoritative screen when narrow
width and enlarged system text require a different composition. Responsive
layout changes hierarchy and wrapping only; it does not remove a command or
reinterpret accepted state.

- compact application chrome keeps saved-action recovery visible and groups
  refresh plus account navigation into one labelled overflow menu;
- the daily walking ring, route ENERGY status and pilot/pet cards reflow
  vertically instead of shrinking text or clipping status;
- the integrated synchronization and gameplay dock keeps both existing
  callbacks, allows two-line labels and remains outside the scroll surface;
- all Home content remains reachable through the existing single scroll view,
  while the floating journal navigation and sticky dock keep their reserves;
- the contract is verified at `320 × 640 / 1.6×` without changing cache,
  command, idempotency, impression or authoritative-refresh ownership.

## Compact journal composition

The path journal remains one continuous player-facing log at compact width;
responsive presentation does not introduce tabs, hide accepted content or
change which commands the server owns.

- compact application chrome keeps saved-action recovery visible and groups
  refresh plus account navigation into one labelled overflow menu;
- onboarding status, weekly progress, companion identity, skills, quests and
  cosmetics reflow vertically before labels or actions become truncated;
- the three-node companion growth line shares width equally between its stage
  names and keeps one complete semantic summary instead of three noisy nodes;
- dense action rows become explicit full-width controls while preserving the
  same command keys, availability conditions and callbacks;
- the single journal scroll surface reserves space below its footer for the
  floating navigation bar, so the final refresh and version context remain
  reachable;
- the contract is verified across the complete journal at
  `320 × 640 / 1.6×` without changing cache/read-only behavior, experiment
  exposure, command execution, idempotency or authoritative refresh.

## Compact first journey composition

The guided first chapter keeps one continuous authoritative route when narrow
width and enlarged system text require a different composition. Responsive
presentation changes wrapping and hierarchy only; it does not complete a
milestone, predict a reward or introduce another command path.

- compact application chrome keeps saved-action recovery visible and moves
  account navigation into one labelled overflow menu;
- route progress separates its complete label from the accepted milestone
  count instead of compressing both into one row;
- welcome, activity, reward, expedition, event and completion panels reduce
  internal chrome while keeping every action full-width and two-line capable;
- companion choices reflow vertically, keep their stable portrait identity and
  expose the same selection callback over the complete card;
- the single first-journey scroll surface keeps every stage action and the
  existing **«Продолжить позже»** boundary reachable at `320 × 640 / 1.6×`;
- the contract does not change startup replay, cached read-only behavior,
  command keys, idempotency, authoritative refresh or completion ownership.

## Compact pilot dossier composition

The account route remains a trust and data-control surface when narrow width
and enlarged system text require a different composition. Responsive layout
does not reinterpret identity, queue state or any destructive boundary.

- the pilot identity reflows below its marker while keeping the complete
  session label and existing dossier semantics;
- saved-action recovery and the optional Validation Center become explicit
  vertical link panels without changing their callbacks or visibility rules;
- export, permanent deletion and logout retain full-width two-line actions;
- both deletion confirmations keep the shared scrollable trust dialog, phrase
  requirement and fresh-authentication boundary;
- the complete route is verified at `320 × 640 / 1.6×` without changing export
  ownership, owner-scoped command state, idempotency or session lifecycle.

## Adaptive expedition navigation

The two primary player destinations keep one stable state boundary while the
navigation chrome adapts to the space assigned by its parent.

- phone and compact layouts retain the floating bottom dock, with reduced side
  reserve below `360 px` so both labelled destinations remain complete;
- layouts at `960 px` and wider move the same destinations into a persistent
  expedition rail only when at least `480 px` remain inside the vertical safe
  area; shorter landscape and split-screen surfaces retain the overflow-safe
  bottom dock;
- both compositions reuse the same selected index, `IndexedStack`, destination
  visibility and `onDestinationChanged` callback;
- one stable keyed destination slot moves inside the same shell row, preserving
  scroll position, draft input and loader state across resize or rotation;
- descendants receive the actual bottom-dock obstruction: compact Home and
  Journal retain their navigation clearance, while the wide rail removes that
  reserve and keeps only action/footer spacing;
- the shell does not add routes, content, commands or read-model assumptions;
- compact and wide compositions are verified with enlarged system text.

## Navigation destination glyphs

The two stable player destinations use code-native route marks instead of the
generic compass and book icons. **Expedition** follows a three-signal trail to
one outer beacon, while **Journal** keeps the same signal vocabulary inside an
open field log. The selected treatment changes both geometry and color: the
route gains its beacon orbit, and the journal trace becomes fully connected.

These marks represent navigation only. They do not read chapter progress,
unread state, availability, a current node or any server-owned value. The
owning `NavigationBar` or `NavigationRail` keeps the complete destination
label, selected state and callback; glyph painting is excluded from semantics
and input. Compact dock and wide rail reuse the same two widgets without
changing the stable `IndexedStack` or destination lifecycle.

## Current journey route trail

Home shows the accepted path of the current expedition journey as a quiet,
horizontally scrollable node trail. The additive Home `routeTrail` read model
owns ordering, node identity, display name and literal `VISITED`, `CURRENT` or
`COMPLETED` state. The viewport opens on the last accepted point while the
player can scroll back through the path already taken.

Resolved points may carry one additive server-owned `decision`. A compact
second label places the persisted choice before its persisted outcome with the
same directional arrow used by the journal. The completed terminal keeps that
annotation when its state changes from `VISITED` to `COMPLETED`; an unresolved
current point reserves the same geometry but shows no invented copy.

The trail never loads or reconstructs the chapter graph on-device. It does not
show future nodes, optional branches, GPS position or real-time walking. A new
`journeyNumber` therefore begins with one current node even though permanent
pilot, pet and inventory progression remains. Unknown future node IDs retain
their server name and the same state geometry; visual identity is not inferred
from names or content versions. One localized summary owns semantics and
repeats the ordered node/choice/outcome sequence, while node labels and
state-specific icon geometry keep the visual map readable without relying on
color alone. Legacy snapshots without `routeTrail` simply omit the map; route
nodes without the additive `decision` retain the original compact presentation.

## Current journey decision log

The journey places the accepted decisions directly below the journal hero.
The additive Home `decisionLog` owns server order, stable event and choice
identity, persisted event/choice/outcome copy and resolution time. The card
shows only entries from the current `journeyNumber`; a new journey therefore
returns to an explicit empty state instead of mixing earlier routes.

Each entry uses a numbered code-native signal, a decision arrow and separate
outcome typography. Compact reward chips repeat the literal pilot XP, named
companion bond and optional material quantity saved with that decision; they
do not subtract current totals or read current content. One container semantic
announces its position, event, choice, outcome and the same reward list, while
the visual children are excluded from duplicate screen-reader output.
Persisted copy is rendered literally and is never reconstructed from current
content, node topology or display-name heuristics. Cached Home data is labelled
as a saved entry; if Home is unavailable the platform journal remains usable
and omits this server-owned section. Legacy snapshots without `decisionLog` or
without additive reward fields remain readable and do not invent rewards.

## Completed journey recap

When Home marks the current expedition `COMPLETED`, the journey places one
code-native recap directly above the decision log. Its badge confirms the
completed `journeyNumber`, while compact reward chips show the server-owned
decision count, total pilot XP, combined companion bond and ordered material
totals. When additive pet bond detail is available, the combined companion
chip becomes one named chip per persisted pet in first-appearance order. The
card never sums the visible decisions on-device: every displayed value comes
from the additive Home `completionRecap` built from immutable event resolutions
for that exact journey.

When Home supplies `finalDecision`, the card places a compact finale block
between the decision count and rewards. It repeats persisted event, choice,
outcome and summary copy; it does not infer an ending from the current node,
status or content catalog.

One container semantic announces completion, decision count and the same
ordered reward list; all visual children are excluded from duplicate
screen-reader output. Persisted material identity and copy remain literal after
content republish or rollback. Cached data is labelled as a saved result.
In-progress and newly started journeys omit the card, while legacy completed
snapshots without `completionRecap` keep the decision log usable and do not
invent totals.

## Recent journey archive

When earlier completed journeys exist, the journal places a compact archive
directly below the current decision log. It shows at most five server-ordered
recaps, newest first. Each entry repeats the authoritative journey number,
decision count and persisted reward totals, including the same named companion
bond breakdown when supplied; mobile neither aggregates visible decisions nor
looks up current content copy.

An archived entry also shows its persisted `finalDecision` before rewards, so
two journeys with identical totals can remain narratively distinct. The same
finale wording is included in that entry's single semantic summary.

When additive `decisions` are available, a separate full-width accessible
control expands the complete saved history for that archived journey. The
collapsed archive remains compact; the expanded region reuses the numbered
decision entries, literal persisted copy and reward chips of the current
journey log. The control announces the journey identity, entry count and its
show/hide action, while every revealed entry keeps its own ordered semantic.
The current completion card does not render the same list again because its
existing decision log immediately follows it.

The server treats the immutable start receipt for journey N+1 as proof that
journey N finished. This keeps an old event resolution whose historical status
was `COMPLETED` from becoming a false archive entry after a chapter extension.
The current journey is always outside the archive and keeps its separate
completion card when applicable. One semantic container per archived journey
announces its decision count and ordered reward list, with visual children
excluded from duplicate output. Legacy snapshots without
`recentJourneyRecaps` omit the archive.

## Journey companion bond breakdown

Current and archived recap cards retain the compatible combined bond total,
but prefer ordered named companion chips when Home supplies
`petBondRewards`. Each visual chip uses persisted pet copy and the semantic
summary announces the same pet/name totals. Missing legacy detail falls back
to one combined companion chip; an explicit breakdown is never reconstructed
from current pet state, current content or the visible decision list.

## Completed journey finale

The current completion card and every recent archive entry may carry one
server-ordered `finalDecision`. The visual block labels the finale, shows the
persisted event title, connects choice to outcome and repeats the saved outcome
summary. Its containing recap semantic announces the same sequence before the
reward list. Legacy recaps without the additive object omit the block; mobile
never substitutes the last visible current-journey entry for missing history.

## Next visual slices

1. Extend the four pivotal event scenes across the remaining first-chapter
   event IDs only after the core illustrated loop is validated; application
   icon and native splash are already defined by the shared expedition emblem.
2. Split the journal into player-facing tabs only when closed-beta content
   density proves that the single expedition log no longer scans well.
3. Produce store screenshots and motion guidelines after the first complete
   illustrated gameplay loop is captured on physical devices.
