# Home cinematic scene review

Actual Flutter widget captures for the cinematic Home redesign in PR #576,
rendered from commit `357f1e62fd94967965df36b6f10d129bf1ef60cd` with Flutter
3.44.7. Fixtures contain synthetic steps, ENERGY and route progress, SDK
Roboto/Material fonts, and no real account data.

![Home with the pilot and Spark](home-dark-spark-ru.png)

| Preview | Locale / theme | Logical viewport | Text scale |
| --- | --- | --- | --- |
| [Pilot + Spark](home-dark-spark-ru.png) | RU / dark | 390 × 844 | 1.0 |
| [Pilot + Moss](home-light-moss-ru.png) | RU / light | 390 × 844 | 1.0 |
| [Pilot + Navigator](home-dark-rune-en.png) | EN / dark | 390 × 844 | 1.0 |
| [Compact phone](home-narrow-large-ru.png) | RU / dark | 320 × 640 | 1.6 |
| [Enlarged text](home-large-text-en.png) | EN / light | 500 × 800 | 2.0 |
| [Reduced motion](home-reduced-motion-ru.png) | RU / dark | 390 × 844 | 1.0 |

The existing signal-source landscape anchors the new detailed, realistic crew
art. Each companion has a coordinated scene with the same pilot and environment.
The whole square remains visible; enlarged text on compact phones scales the
scene down so the primary action cannot cover the crew. Detailed activity and
crew panels remain below the first ordinary-phone viewport.

This revision uses still artwork with identical reduced-motion behavior.
Natural character animation needs a separate high-resolution production pass.
The mobile suite passed 683 tests, including accepted-identity changes,
unknown-ID and legacy fallbacks and the existing authoritative commands.
All six captures check that the scene stays above the primary action and both
actors stay within the composition. Reproduce these images with the command in
[the design system](../../DESIGN_SYSTEM.md#home-crew-scene). Artwork references
and generation prompts are in [the asset directory](../../../mobile/assets/scenes/README.md).

These are widget renders, not physical-device or product-owner acceptance.
TASK-011 / issue #156 still owns that decision.
