import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:egesha/core/api/parking_iq_api.dart';
import 'package:egesha/screens/instant_parking_page.dart';

/// Body the public instant-pay lookup returns for an active session.
const _sessionBody = {
  'success': true,
  'data': {
    'sessionId': 'session-1',
    'plateNumber': 'KBR656Z',
    'locationName': 'CBD Parking Zone A',
    'entryTime': '2026-05-01T08:00:00Z',
    'currentTime': '2026-05-01T09:30:00Z',
    'amountPayable': 150,
    'amountPaid': 0,
    'status': 'ACTIVE',
  },
};

/// Builds the page with a stubbed API. [onLookup] returns the response for
/// `GET /parking/instant-pay/session`.
Widget _buildPage(http.Response Function(Uri uri) onLookup) {
  final client = MockClient((request) async {
    if (request.url.path.endsWith('/parking/instant-pay/session')) {
      return onLookup(request.url);
    }
    return http.Response('{}', 404);
  });
  return MaterialApp(
    home: InstantParkingPage(api: ParkingIqApi(client: client, debug: false)),
  );
}

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json'});

void main() {
  testWidgets('phone field and pay button appear only after a session is found',
      (tester) async {
    var lookups = 0;
    await tester.pumpWidget(_buildPage((_) {
      lookups++;
      return _json(_sessionBody);
    }));

    // Nothing but the plate field to begin with.
    expect(find.text('07XX XXX XXX'), findsNothing);
    expect(find.textContaining('Pay KES'), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'KBR656Z');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(lookups, 1);
    expect(find.text('CBD Parking Zone A'), findsOneWidget);
    expect(find.text('ACTIVE SESSION'), findsOneWidget);
    expect(find.text('KES 150'), findsOneWidget);
    expect(find.text('1h 30m'), findsOneWidget);
    expect(find.text('07XX XXX XXX'), findsOneWidget);
    expect(find.text('Pay KES 150'), findsOneWidget);
  });

  testWidgets('an empty lookup shows the no-session state', (tester) async {
    await tester.pumpWidget(_buildPage((_) => _json({'success': true})));

    await tester.enterText(find.byType(TextField).first, 'KBR656Z');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(find.text('No session found'), findsOneWidget);
    expect(find.text('07XX XXX XXX'), findsNothing);
    expect(find.textContaining('Pay KES'), findsNothing);
  });

  testWidgets('a 404 lookup is treated as no session, not an error',
      (tester) async {
    await tester.pumpWidget(
      _buildPage((_) => _json({'message': 'Session not found'}, 404)),
    );

    await tester.enterText(find.byType(TextField).first, 'KBR656Z');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(find.text('No session found'), findsOneWidget);
    expect(find.text('Lookup failed'), findsNothing);
  });

  testWidgets('typing is debounced and short plates are not looked up',
      (tester) async {
    var lookups = 0;
    await tester.pumpWidget(_buildPage((_) {
      lookups++;
      return _json(_sessionBody);
    }));

    final field = find.byType(TextField).first;
    await tester.enterText(field, 'K');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(field, 'KB');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(field, 'KBR');
    await tester.pump(const Duration(milliseconds: 700));

    // Below the minimum length — never queried.
    expect(lookups, 0);

    await tester.enterText(field, 'KBR6');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(field, 'KBR656Z');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    // Only the settled plate was queried.
    expect(lookups, 1);
  });

  testWidgets('editing the plate clears the session block', (tester) async {
    await tester.pumpWidget(_buildPage((_) => _json(_sessionBody)));

    final field = find.byType(TextField).first;
    await tester.enterText(field, 'KBR656Z');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(find.text('Pay KES 150'), findsOneWidget);

    await tester.enterText(field, 'KBR65');
    await tester.pump();

    expect(find.text('Pay KES 150'), findsNothing);
    expect(find.text('CBD Parking Zone A'), findsNothing);

    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
  });
}
