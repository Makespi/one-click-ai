import 'package:flutter_test/flutter_test.dart';

import 'package:one_click_ai/app.dart';

void main() {
  testWidgets('App renders welcome screen', (WidgetTester tester) async {
    await tester.pumpWidget(const OneClickAiApp());
    // Verify the app renders without error
    expect(find.text('One Click AI'), findsOneWidget);
  });
}
