import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:egesha/screens/payment_success_screen.dart';

Widget _wrap(PaymentSuccessDetails details) {
  return MaterialApp(home: PaymentSuccessScreen(details: details));
}

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('shows the amount and the payment details it was given',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        PaymentSuccessDetails(
          amountPaid: 1260,
          paidAt: DateTime(2026, 8, 28, 9, 19),
          transactionId: 'UHSBV4OBVN',
          siteName: 'Lavington Mall',
          plateNumber: 'KBR 656Z',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Payment Successful'), findsOneWidget);
    // Thousands separator, no stray decimals.
    expect(find.text('KES 1,260'), findsOneWidget);
    expect(find.text('UHSBV4OBVN'), findsOneWidget);
    expect(find.text('Lavington Mall'), findsOneWidget);
    expect(find.text('KBR 656Z'), findsOneWidget);
    expect(find.text('Aug 28, 2026 at 9:19 AM'), findsOneWidget);
  });

  testWidgets('omits the exit window when no window was given', (tester) async {
    await tester.pumpWidget(
      _wrap(
        PaymentSuccessDetails(amountPaid: 60, paidAt: DateTime.now()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PLEASE EXIT BY'), findsNothing);
    expect(find.text('EXIT WINDOW ENDED'), findsNothing);
  });

  testWidgets('counts down the 30-minute exit window', (tester) async {
    await tester.pumpWidget(
      _wrap(
        PaymentSuccessDetails(
          amountPaid: 60,
          paidAt: DateTime.now(),
          siteName: 'Lavington Mall',
          exitWindow: kExitGraceWindow,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PLEASE EXIT BY'), findsOneWidget);
    expect(find.text('To avoid additional charges'), findsOneWidget);
    // Just under the full 30 minutes, depending on where the second landed.
    expect(
      find.textContaining(RegExp(r'^(29|30):\d\d left$')),
      findsOneWidget,
    );

    // Dispose the tree so the countdown's periodic timer is cancelled.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('reports an exit window that has already closed', (tester) async {
    await tester.pumpWidget(
      _wrap(
        PaymentSuccessDetails(
          amountPaid: 60,
          paidAt: DateTime.now().subtract(const Duration(hours: 1)),
          exitWindow: kExitGraceWindow,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('EXIT WINDOW ENDED'), findsOneWidget);
    expect(find.textContaining('left'), findsNothing);
    expect(
      find.text('Additional charges may now apply for this session.'),
      findsOneWidget,
    );
  });

  testWidgets('View Receipt opens the itemised receipt', (tester) async {
    await tester.pumpWidget(
      _wrap(
        PaymentSuccessDetails(
          amountPaid: 40,
          paidAt: DateTime(2026, 8, 28, 9, 19),
          siteName: 'Lavington Mall',
          plateNumber: 'KBR 656Z',
          discountAmount: 20,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('View Receipt'));
    await tester.pumpAndSettle();

    expect(find.text('Parking receipt'), findsOneWidget);
    // The discount is shown against the pre-discount fee.
    expect(find.text('KES 60'), findsOneWidget);
    expect(find.text('- KES 20'), findsWidgets);
    expect(find.text('KES 40'), findsWidgets);
  });
}
