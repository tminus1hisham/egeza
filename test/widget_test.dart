import 'package:flutter_test/flutter_test.dart';
import 'package:egesha/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const egeshaApp());
    expect(find.byType(egeshaApp), findsOneWidget);
  });
}
