# Full-screen Home visual review

Actual Flutter widget captures for PR #580, rendered from commit
`58b3857917c21c7b5d5319854e4b4f2942de6706` with Flutter 3.44.7.
Fixtures contain synthetic steps, ENERGY and route progress, SDK Roboto/Material
fonts, and no real account data.

![Full-screen Home with the pilot and Spark](home-dark-spark-ru.png)

| Preview | Locale / theme | Logical viewport | Text scale |
| --- | --- | --- | --- |
| [Pilot + Spark](home-dark-spark-ru.png) | RU / dark | 390 × 844 | 1.0 |
| [Pilot + Moss](home-light-moss-ru.png) | RU / light | 390 × 844 | 1.0 |
| [Pilot + Navigator](home-dark-rune-en.png) | EN / dark | 390 × 844 | 1.0 |
| [Compact phone](home-narrow-large-ru.png) | RU / dark | 320 × 640 | 1.6 |
| [Enlarged text](home-large-text-en.png) | EN / light | 500 × 800 | 2.0 |
| [Safe-area insets](home-safe-insets-ru.png) | RU / dark; top 44, bottom 34 | 390 × 844 | 1.0 |
| [Reduced motion](home-reduced-motion-ru.png) | RU / dark | 390 × 844 | 1.0 |

The detailed frontier now fills the entire screen, including the toolbar and
navigation. Portrait crew compositions place the pilot and accepted companion
between a compact route HUD and a smoked-glass action panel. Brass outlines,
cream labels and an amber primary action match the environment. The compact
step counter keeps enlarged text from consuming a second row.

The layout measures both HUD groups before fitting the crew. Captures check
edge-to-edge background coverage, toolbar and navigation clearance, all actor
bounds, and the detail-scroll affordance. They also open details and verify
that their scroll viewport stays between the HUD groups. Foreground scenery
blends into the empty frontier when a short screen requires a smaller cast.

The render source passed all 696 mobile tests and seven explicit capture cases.
Final formatting and analyzer validation are recorded in the PR checks.
Coverage includes exact accepted IDs, neutral fallbacks, authoritative command
guards and impression visibility. Event images keep independent accessibility
descriptions in the clipped detail viewport.

Issue [#579](https://github.com/MKSEgr/walking-rpg/issues/579) adds a
presentation-only, finite atmospheric reveal above the static scene: low mist,
a peripheral vignette and sparse cyan motes settle after about 1.6 seconds.
The pilot, companion and the realistic scene artwork do not animate. Reduced
motion paints the settled static result immediately with no active ticker. The
decorative layer ignores pointers, excludes semantics and does not affect
gameplay state or the accessible controls. The settled ordinary and
reduced-motion captures are byte-identical; reduced motion skips the transition.

Reproduce with the command in [the design system](../../DESIGN_SYSTEM.md#home-crew-scene).
Artwork references and full prompts are in [the asset directory](../../../mobile/assets/scenes/README.md).

These are synthetic widget renders for design review, not evidence of physical
device behavior. Physical-device and owner acceptance remain under TASK-011 /
issue #156; #156 is an external gate and is not closed by this gallery.
Character animation needs a separate detailed asset pass.
