import 'package:flutter_test/flutter_test.dart';
import 'package:quick_text_mobile/main.dart';

void main() {
  testWidgets('renders Quick Text onboarding', (tester) async {
    await tester.pumpWidget(const QuickTextApp());
    expect(find.text('Quick Text'), findsOneWidget);
    expect(find.text('Einrichtung'), findsOneWidget);
  });
}
