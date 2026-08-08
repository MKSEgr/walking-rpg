import 'package:flutter/material.dart';
import 'package:walking_rpg_mobile/l10n/generated/app_localizations.dart';
import 'package:walking_rpg_mobile/l10n/generated/app_localizations_ru.dart';

extension AppLocalizationsBuildContext on BuildContext {
  /// Production always installs the generated delegates. The Russian fallback
  /// keeps presentation-only widget tests and isolated previews deterministic.
  AppLocalizations get l10n =>
      AppLocalizations.of(this) ?? AppLocalizationsRu();
}
