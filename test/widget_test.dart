import 'package:flutter_test/flutter_test.dart';
import 'package:park_iq/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ParkIQApp());
    expect(find.byType(ParkIQApp), findsOneWidget);
  });
}
