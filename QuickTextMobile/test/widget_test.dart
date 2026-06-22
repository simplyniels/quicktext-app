import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_text_mobile/main.dart';

void main() {
  testWidgets('uses English when the phone language is not German', (
    tester,
  ) async {
    await tester.pumpWidget(const QuickTextApp(locale: Locale('fr')));
    expect(find.text('Quick Text'), findsOneWidget);
    expect(find.text('Setup'), findsWidgets);
    expect(find.text('Einrichtung'), findsNothing);
  });

  testWidgets('uses German when the phone language is German', (tester) async {
    await tester.pumpWidget(const QuickTextApp(locale: Locale('de')));
    expect(find.text('Einrichtung'), findsOneWidget);
  });
}
