import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_text_mobile/main.dart';

void main() {
  testWidgets('dictionary shows saved words and stores new ones', (
    tester,
  ) async {
    const channel = MethodChannel('de.quicktext.mobile/system');
    final saved = <Map<Object?, Object?>>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'getStatus') {
            return <String, Object?>{
              'microphone': true,
              'accessibility': true,
              'apiKey': true,
              'language': 'de',
              'workflow': 'transcription',
              'customTerms': 'Anthropic, Blackboat',
              'themeMode': 'system',
            };
          }
          if (call.method == 'saveSettings') {
            saved.add(Map<Object?, Object?>.from(call.arguments as Map));
            return true;
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    await tester.pumpWidget(const QuickTextApp(locale: Locale('de')));
    await tester.pumpAndSettle();

    final addField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          (widget.decoration?.hintText ?? '').startsWith('Wort hinzufügen'),
    );
    await tester.scrollUntilVisible(
      addField,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Wörterbuch'), findsOneWidget);
    expect(find.text('Anthropic'), findsOneWidget);
    expect(find.text('Blackboat'), findsOneWidget);

    await tester.enterText(addField, 'Zettelkasten');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(find.text('Zettelkasten'), findsOneWidget);
    expect(saved.last['customTerms'], 'Anthropic, Blackboat, Zettelkasten');
  });

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
