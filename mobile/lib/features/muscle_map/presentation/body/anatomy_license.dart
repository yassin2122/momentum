import 'package:flutter/foundation.dart';

/// Adds the anatomy artwork's CC BY 4.0 notice to Flutter's licenses page
/// (`showLicensePage`). Call once at startup. See
/// `assets/anatomy/ATTRIBUTION.md`.
void registerAnatomyLicense() {
  LicenseRegistry.addLicense(() => Stream.value(
        const LicenseEntryWithLineBreaks(
          ['Anatomy illustration (muscle map)'],
          'Muscle anatomy illustrations by Ryan Graves (Figma Community), '
          'licensed under Creative Commons Attribution 4.0 International '
          '(CC BY 4.0): https://creativecommons.org/licenses/by/4.0/\n\n'
          'Source: https://www.figma.com/community/file/1320468164820924031, '
          'via the muscle_mapper package (MIT). Changes: paths regrouped by '
          'muscle region and restyled; geometry unchanged.',
        ),
      ));
}
