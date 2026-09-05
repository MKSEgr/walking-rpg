# Home foreground review

Actual Flutter widget captures for the Home redesign in PR #574, rendered from
commit `108840407a463229a45ef3e72b8c4e2236e1340c` with Flutter 3.44.7.
The capture job applies the repository formatter before rendering; subsequent
format-only edits do not change these pixels. Fixtures contain synthetic steps,
ENERGY and route progress, SDK Roboto/Material fonts, and no real account data.

| Preview | Locale / theme | Logical viewport | Text scale |
| --- | --- | --- | --- |
| [Pilot + Spark](home-dark-spark-ru.png) | RU / dark | 390 × 844 | 1.0 |
| [Pilot + Moss](home-light-moss-ru.png) | RU / light | 390 × 844 | 1.0 |
| [Pilot + Navigator](home-dark-rune-en.png) | EN / dark | 390 × 844 | 1.0 |
| [Compact phone](home-narrow-large-ru.png) | RU / dark | 320 × 640 | 1.6 |
| [Enlarged text](home-large-text-en.png) | EN / light | 500 × 800 | 2.0 |
| [Reduced motion](home-reduced-motion-ru.png) | RU / dark | 390 × 844 | 1.0 |

The first viewport puts the full-body crew on a common ground plane. Detailed
activity and crew panels remain below it on ordinary phones; tall/wide layouts
can show more information. The greeting control plays a finite reaction, while
reduced motion holds a still. The screen remains scrollable at enlarged text.

The mobile suite passed 681 tests, including crew reactions, offscreen and
lifecycle behavior, snapshot fallbacks and existing authoritative commands.
All six capture cases passed layout checks. Reproduce these images with the
command in [the design system](../../DESIGN_SYSTEM.md#home-crew-scene).

These are widget renders, not physical-device or product-owner acceptance.
TASK-011 / issue #156 still owns that decision.
