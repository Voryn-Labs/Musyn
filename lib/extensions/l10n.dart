import 'package:flutter/widgets.dart';
import 'package:musyn/localization/app_localizations.dart';
import 'package:musyn/localization/app_localizations_en.dart';

extension ContextX on BuildContext {
  AppLocalizations get l10n =>
      AppLocalizations.of(this) ?? AppLocalizationsEn();
}
