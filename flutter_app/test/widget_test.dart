import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const LocalCastApp());
    expect(find.text('Select a video file to cast'), findsOneWidget);
  });
}
