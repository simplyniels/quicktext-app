import 'package:flutter/widgets.dart';

class AppStrings {
  const AppStrings._(this.isGerman);

  final bool isGerman;

  static AppStrings of(BuildContext context) =>
      AppStrings._(Localizations.localeOf(context).languageCode == 'de');

  String text(String german, String english) => isGerman ? german : english;
}
