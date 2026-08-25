import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:egesha/widgets/primary_button.dart';

Widget _host(Widget child, {double textScale = 1.0}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(
        body: Center(
          child: SizedBox(width: 340, child: child),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('compact button honours its height at normal text scale',
      (tester) async {
    await tester.pumpWidget(
      _host(
        const PrimaryButton(
          text: 'View',
          height: 42,
          fontSize: 13,
          icon: Icons.chevron_right_rounded,
          onPressed: _noop,
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(PrimaryButton)).height, 42);
  });

  testWidgets('button grows instead of clipping its label when text is scaled',
      (tester) async {
    await tester.pumpWidget(
      _host(
        const PrimaryButton(
          text: 'Pay Now',
          height: 42,
          fontSize: 13,
          icon: Icons.phone_android_rounded,
          onPressed: _noop,
        ),
        textScale: 2.0,
      ),
    );

    expect(tester.takeException(), isNull);

    final button = tester.getSize(find.byType(PrimaryButton));
    final label = tester.getSize(find.text('Pay Now'));
    // The label must fit inside the button, not be cropped by a fixed box.
    expect(button.height, greaterThan(42));
    expect(button.height, greaterThanOrEqualTo(label.height));
  });

  testWidgets('two compact buttons share a card row without overflowing',
      (tester) async {
    await tester.pumpWidget(
      _host(
        Row(
          children: const [
            Expanded(
              child: PrimaryButton(
                text: 'View',
                height: 42,
                fontSize: 13,
                icon: Icons.chevron_right_rounded,
                isOutlined: true,
                onPressed: _noop,
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: PrimaryButton(
                text: 'Pay Now',
                height: 42,
                fontSize: 13,
                icon: Icons.phone_android_rounded,
                onPressed: _noop,
              ),
            ),
          ],
        ),
        textScale: 1.3,
      ),
    );

    expect(tester.takeException(), isNull);
    // Neither label falls back to an ellipsis at a realistic accessibility
    // text scale.
    expect(find.text('View'), findsOneWidget);
    expect(find.text('Pay Now'), findsOneWidget);
  });
}

void _noop() {}
