# Anatomy artwork — attribution

`body_front.svg` and `body_back.svg` are adapted from the male muscle
anatomy illustrations by **Ryan Graves**, published on Figma Community:
https://www.figma.com/community/file/1320468164820924031

- **License:** Creative Commons Attribution 4.0 International (CC BY 4.0) —
  https://creativecommons.org/licenses/by/4.0/
- **Obtained from:** the `advanced` style of the MIT-licensed `muscle_mapper`
  Flutter package (https://github.com/suryamolly/muscle_mapper,
  `lib/src/assets/advanced/`), whose `CREDITS.md` states the author and
  license above. The package itself is not a dependency of this app.
- **Changes made (CC BY requires indicating them):** path geometry is
  unchanged. Paths were regrouped by body-map region, the original paint
  order is recorded as `data-z`, and fills/strokes were restyled (white line
  art on a dark body). Unlabelled and non-muscle shapes are kept as outline
  detail. Regenerate with `mobile/tool/anatomy/build_anatomy_assets.py`.

In-app credit: the muscle-map screen shows
"Anatomy illustration © Ryan Graves, CC BY 4.0", and the notice is
registered with Flutter's `LicenseRegistry` (visible on the licenses page).

Before a public release, open the Figma link above and confirm the file's
license is still CC BY 4.0.
