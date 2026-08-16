import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:egesha/screens/dashboard/help_center_screen.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Widget host() {
    return const MaterialApp(home: HelpCenterScreen());
  }

  final articles = <({String topic, String answer})>[
    (topic: 'Parking session not showing', answer: 'Enter the vehicle plate'),
    (topic: 'Payment failed or is pending', answer: 'Check the M-Pesa number'),
    (topic: 'Vehicle AutoPay', answer: 'Open the vehicle profile'),
    (topic: 'Wallet top-up not showing', answer: 'Confirm the prompt'),
    (topic: 'Receipts and parking history', answer: 'Match the plate and date'),
  ];

  for (final article in articles) {
    testWidgets('${article.topic} opens populated help content', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(host());

      final topic = find.text(article.topic);
      await tester.ensureVisible(topic);
      await tester.tap(topic);
      await tester.pumpAndSettle();

      expect(find.text('Quick answer'), findsOneWidget);
      expect(find.text(article.answer), findsOneWidget);
      expect(find.text('Still need help?'), findsOneWidget);
      expect(find.text('Email support'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('contact support opens real contact guidance', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host());

    final contact = find.text('Contact support');
    await tester.ensureVisible(contact);
    await tester.tap(contact);
    await tester.pumpAndSettle();

    expect(find.text('Include these details'), findsOneWidget);
    expect(find.text('support@egesha.co.ke'), findsWidgets);
    expect(find.text('Compose email'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('email support action is tappable', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host());

    final emailSupport = find.text('Email support');
    await tester.ensureVisible(emailSupport);
    await tester.tap(emailSupport);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
