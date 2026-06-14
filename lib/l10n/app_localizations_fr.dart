// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get signInTitle => 'Se connecter';

  @override
  String get signUpTitle => 'S\'inscrire';

  @override
  String get createAccount => 'Créer un compte';

  @override
  String get nameLabel => 'Nom';

  @override
  String get emailLabel => 'Email';

  @override
  String get passwordLabel => 'Mot de passe';

  @override
  String get submit => 'Envoyer';

  @override
  String get welcome => 'Bienvenue';

  @override
  String get personalUse => 'Usage personnel';
}
