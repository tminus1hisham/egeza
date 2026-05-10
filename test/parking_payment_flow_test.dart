import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:park_iq/blocs/app_bloc.dart';
import 'package:park_iq/blocs/app_event.dart';
import 'package:park_iq/blocs/app_state.dart';
import 'package:park_iq/core/api/parking_iq_api.dart';
import 'package:park_iq/core/payment/parking_billing.dart';
import 'package:park_iq/core/payment/payment_validation.dart';
import 'package:park_iq/models/api_models.dart';
import 'package:park_iq/models/parking_session.dart';
import 'package:park_iq/models/vehicle.dart';

void main() {
  // ---------------------------------------------------------------------------
  // 1. Billing logic
  // ---------------------------------------------------------------------------
  group('parking billing', () {
    test('0 minutes is free', () {
      final entry = DateTime(2026, 5, 1, 8);
      expect(
        ParkingBillingCalculator.calculate(
          entryTime: entry,
          currentTime: entry,
        ).amount,
        0,
      );
    });

    test('keeps first 3 minutes free', () {
      final entry = DateTime(2026, 5, 1, 8);

      expect(
        ParkingBillingCalculator.calculate(
          entryTime: entry,
          currentTime: entry.add(const Duration(minutes: 3)),
        ).amount,
        0,
      );
    });

    test('rounds up billable hours at KES 5/hour after grace period', () {
      final entry = DateTime(2026, 5, 1, 8);

      final fourMinutes = ParkingBillingCalculator.calculate(
        entryTime: entry,
        currentTime: entry.add(const Duration(minutes: 4)),
      );
      final sixtyOneMinutes = ParkingBillingCalculator.calculate(
        entryTime: entry,
        currentTime: entry.add(const Duration(minutes: 61)),
      );

      expect(fourMinutes.billableHours, 1);
      expect(fourMinutes.amount, 5);
      expect(sixtyOneMinutes.billableHours, 2);
      expect(sixtyOneMinutes.amount, 10);
    });

    test('keeps the first hour at one billed hour', () {
      final entry = DateTime(2026, 5, 1, 8);

      final quote = ParkingBillingCalculator.calculate(
        entryTime: entry,
        currentTime: entry.add(const Duration(minutes: 60)),
      );

      expect(quote.billableHours, 1);
      expect(quote.amount, 5);
    });

    test('121 minutes = 3 billable hours = KES 15', () {
      final entry = DateTime(2026, 5, 1, 8);

      final quote = ParkingBillingCalculator.calculate(
        entryTime: entry,
        currentTime: entry.add(const Duration(minutes: 121)),
      );

      expect(quote.billableHours, 3);
      expect(quote.amount, 15);
    });

    test('negative elapsed time is treated as zero', () {
      final entry = DateTime(2026, 5, 1, 8);

      final quote = ParkingBillingCalculator.calculate(
        entryTime: entry,
        currentTime: entry.subtract(const Duration(minutes: 5)),
      );

      expect(quote.durationMinutes, 0);
      expect(quote.amount, 0);
    });
  });

  // ---------------------------------------------------------------------------
  // 2. API request / response contracts
  // ---------------------------------------------------------------------------
  group('ParkingIqApi payment flow requests', () {
    test('creates parking session with location', () async {
      late Map<String, dynamic> requestBody;
      final api = ParkingIqApi(
        baseUrl: 'https://example.test/api/v1',
        token: 'token',
        debug: false,
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/v1/parking/entry');
          requestBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'data': {
                'sessionId': 'session-1',
                'plateNumber': 'KBC 123A',
                'location': 'CBD Parking Zone A',
                'entryTime': '2026-05-01T08:00:00Z',
                'status': 'ACTIVE',
              },
            }),
            200,
          );
        }),
      );

      final session = await api.createParkingEntry(
        plateNumber: 'KBC 123A',
        location: 'CBD Parking Zone A',
      );

      expect(requestBody['plateNumber'], 'KBC 123A');
      expect(requestBody['location'], 'CBD Parking Zone A');
      expect(session.id, 'session-1');
      expect(session.locationName, 'CBD Parking Zone A');
    });

    test('createParkingEntry throws when location is empty', () async {
      final api = ParkingIqApi(
        baseUrl: 'https://example.test/api/v1',
        token: 'token',
        debug: false,
        client: MockClient((_) async => http.Response('{}', 200)),
      );

      await expectLater(
        () => api.createParkingEntry(plateNumber: 'KBC123A', location: '   '),
        throwsA(isA<ApiException>()),
      );
    });

    test('parses calculate response with grace period and hourly rate', () async {
      final api = ParkingIqApi(
        baseUrl: 'https://example.test/api/v1',
        token: 'token',
        debug: false,
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(
            request.url.path,
            '/api/v1/parking/session/session-1/calculate',
          );
          return http.Response(
            jsonEncode({
              'data': {
                'sessionId': 'session-1',
                'plateNumber': 'KBC 123A',
                'location': 'CBD Parking Zone A',
                'entryTime': '2026-05-01T08:00:00Z',
                'currentTime': '2026-05-01T08:04:00Z',
                'gracePeriodMinutes': 3,
                'ratePerHour': 5,
                'billableHours': 1,
                'amount': 5,
              },
            }),
            200,
          );
        }),
      );

      final session = await api.calculateParkingSession('session-1');

      expect(session.id, 'session-1');
      expect(session.vehicle.plateNumber, 'KBC 123A');
      expect(session.locationName, 'CBD Parking Zone A');
      expect(session.gracePeriodMinutes, 3);
      expect(session.ratePerHour, 5);
      expect(session.billableHours, 1);
      expect(session.cost, 5);
    });

    test('sends SESSION STK push payload', () async {
      late Map<String, dynamic> requestBody;
      final api = ParkingIqApi(
        baseUrl: 'https://example.test/api/v1',
        token: 'token',
        debug: false,
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/v1/payments/mpesa/stkpush');
          requestBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'data': {
                'paymentId': 'payment-1',
                'checkoutRequestId': 'ws_CO_123',
              },
            }),
            200,
          );
        }),
      );

      final response = await api.startSessionStkPush(
        phoneNumber: '254712345678',
        amount: 10,
        sessionId: 'session-1',
        plateNumber: 'KBC 123A',
        location: 'CBD Parking Zone A',
      );

      expect(requestBody, {
        'type': 'SESSION',
        'phoneNumber': '254712345678',
        'amount': 10,
        'sessionId': 'session-1',
        'plateNumber': 'KBC 123A',
        'location': 'CBD Parking Zone A',
        'transactionDesc': 'Parking session payment',
      });
      expect(response.paymentId, 'payment-1');
      expect(response.checkoutRequestId, 'ws_CO_123');
    });

    test('paymentStatus polls preferred endpoint by paymentId', () async {
      int callCount = 0;
      final api = ParkingIqApi(
        baseUrl: 'https://example.test/api/v1',
        token: 'token',
        debug: false,
        client: MockClient((request) async {
          callCount++;
          expect(request.url.path, '/api/v1/payments/payment-1/status');
          return http.Response(
            jsonEncode({
              'data': {
                'paymentId': 'payment-1',
                'status': 'SUCCESS',
              },
            }),
            200,
          );
        }),
      );

      final snapshot = await api.paymentStatus('payment-1');

      expect(callCount, 1);
      expect(snapshot.isSuccess, isTrue);
    });

    test('fetchTenancyPolicy uses public location policy endpoint', () async {
      final api = ParkingIqApi(
        baseUrl: 'https://example.test/api/v1',
        token: 'token',
        debug: false,
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(
            request.url.path,
            '/api/v1/parking/locations/loc-1/tenancy-policy',
          );
          expect(request.headers['Authorization'], isNull);
          return http.Response(
            jsonEncode({
              'data': {
                'id': 'policy-1',
                'locationId': 'loc-1',
                'locationName': 'Sarit Basement Parking',
                'allocatedSlots': 4,
                'subscriptionFee': 5000,
                'pricingPlanName': 'Monthly Tenant Parking',
                'slotEnforcement': 'ALLOCATED_SLOTS',
                'subscriptionDurationDays': 30,
                'gracePeriodDays': 3,
                'active': true,
              },
            }),
            200,
          );
        }),
      );

      final policy = await api.fetchTenancyPolicy('loc-1');

      expect(policy.subscriptionFee, 5000);
      expect(policy.allocatedSlots, 4);
      expect(policy.subscriptionDurationDays, 30);
    });

    test('submitTenancyRequest does not send policy-owned values', () async {
      late Map<String, dynamic> requestBody;
      final api = ParkingIqApi(
        baseUrl: 'https://example.test/api/v1',
        token: 'token',
        debug: false,
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/v1/tenancy/requests');
          requestBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'data': {
                'id': 'tenancy-req-1',
                'locationId': requestBody['locationId'],
                'tenantName': requestBody['tenantName'],
                'plateNumber': requestBody['plateNumber'],
                'message': requestBody['message'],
                'status': 'PENDING',
                'allocatedSlots': 4,
                'subscriptionFee': 5000,
              },
            }),
            200,
          );
        }),
      );

      final request = await api.submitTenancyRequest(
        locationId: 'loc-sarit',
        tenantName: 'Carrefour Sarit',
        plateNumber: 'KDS132A',
        message: 'Requesting tenant parking.',
      );

      expect(requestBody.keys, unorderedEquals({
        'locationId',
        'tenantName',
        'plateNumber',
        'message',
      }));
      expect(request.subscriptionFee, 5000);
      expect(request.allocatedSlots, 4);
    });

    test('tenant profile payment uses the tapped tenantId', () async {
      final api = ParkingIqApi(
        baseUrl: 'https://example.test/api/v1',
        token: 'token',
        debug: false,
        client: MockClient((request) async {
          if (request.method == 'GET' &&
              request.url.path == '/api/v1/tenancy/my-profiles') {
            return http.Response(
              jsonEncode({
                'data': [
                  {
                    'id': 'tenant_sarit',
                    'name': 'Carrefour Sarit',
                    'locationName': 'Sarit Basement Parking',
                    'status': 'ACTIVE',
                    'paymentStatus': 'PAID',
                  },
                  {
                    'id': 'tenant_two_rivers',
                    'name': 'Carrefour Two Rivers',
                    'locationName': 'Two Rivers Basement Parking',
                    'status': 'PENDING',
                    'paymentStatus': 'PENDING',
                    'subscriptionFee': 8000,
                  },
                ],
              }),
              200,
            );
          }

          if (request.method == 'POST') {
            expect(
              request.url.path,
              '/api/v1/tenancy/tenants/tenant_two_rivers/subscriptions/pay',
            );
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            expect(body, {'phoneNumber': '254711111111'});
            return http.Response(
              jsonEncode({
                'data': {
                  'paymentId': 'pay-two-rivers',
                  'checkoutRequestId': 'ws_CO_123',
                  'customerMessage': 'STK sent',
                },
              }),
              200,
            );
          }

          if (request.method == 'GET') {
            expect(
              request.url.path,
              '/api/v1/tenancy/tenants/tenant_two_rivers/payment-status',
            );
            return http.Response(
              jsonEncode({
                'data': {
                  'paymentId': 'pay-two-rivers',
                  'paymentStatus': 'SUCCESS',
                  'tenantId': 'tenant_two_rivers',
                  'subscriptionStatus': 'ACTIVE',
                  'tenantPaymentStatus': 'PAID',
                },
              }),
              200,
            );
          }

          return http.Response('{}', 404);
        }),
      );

      final profiles = await api.fetchMyTenantProfiles();
      final response = await api.payTenantSubscription(
        tenantId: profiles[1].id,
        phoneNumber: '254711111111',
      );
      final status = await api.tenantPaymentStatus(profiles[1].id);

      expect(profiles[1].id, 'tenant_two_rivers');
      expect(response.paymentId, 'pay-two-rivers');
      expect(status.tenantId, 'tenant_two_rivers');
      expect(status.isSuccess, isTrue);
    });

    test('ParkingSession.fromJson maps sessionId, entryTime, exitTime, status',
        () {
      final json = {
        'sessionId': 'abc123',
        'plateNumber': 'KBC 123A',
        'location': 'CBD Parking Zone A',
        'entryTime': '2026-05-01T08:00:00.000Z',
        'exitTime': '2026-05-01T09:00:00.000Z',
        'status': 'COMPLETED',
        'amount': 5,
      };

      final session = ParkingSession.fromJson(json);

      expect(session.id, 'abc123');
      expect(session.vehicle.plateNumber, 'KBC 123A');
      expect(session.locationName, 'CBD Parking Zone A');
      expect(session.startTime, DateTime.parse('2026-05-01T08:00:00.000Z'));
      expect(session.endTime, isNotNull);
      expect(session.status, 'COMPLETED');
      expect(session.cost, 5);
    });
  });

  // ---------------------------------------------------------------------------
  // 3. Payment validation
  // ---------------------------------------------------------------------------
  group('payment validation', () {
    test('prevents duplicate payment for completed session', () {
      expect(
        () => PaymentValidation.validateSessionCanBePaid(
          _session(status: 'COMPLETED', isActive: false),
        ),
        throwsA(isA<PaymentValidationException>()),
      );
    });

    test('prevents payment when session is not active', () {
      expect(
        () => PaymentValidation.validateSessionCanBePaid(
          _session(status: 'ACTIVE', isActive: false),
        ),
        throwsA(isA<PaymentValidationException>()),
      );
    });

    test('requires paid amount to match calculated amount', () {
      expect(
        () => PaymentValidation.validateAmountMatches(
          providedAmount: 10,
          calculatedAmount: 5,
        ),
        throwsA(isA<PaymentValidationException>()),
      );
    });

    test('accepts matching amounts', () {
      expect(
        () => PaymentValidation.validateAmountMatches(
          providedAmount: 5,
          calculatedAmount: 5,
        ),
        returnsNormally,
      );
    });

    group('phone number validation', () {
      test('accepts 2547XXXXXXXX format', () {
        expect(
          PaymentValidation.requireValidMpesaPhone('254712345678'),
          '254712345678',
        );
      });

      test('accepts 2541XXXXXXXX format', () {
        expect(
          PaymentValidation.requireValidMpesaPhone('254112345678'),
          '254112345678',
        );
      });

      test('normalizes 07XXXXXXXX to 2547XXXXXXXX', () {
        expect(
          PaymentValidation.requireValidMpesaPhone('0712345678'),
          '254712345678',
        );
      });

      test('normalizes 01XXXXXXXX to 2541XXXXXXXX', () {
        expect(
          PaymentValidation.requireValidMpesaPhone('0112345678'),
          '254112345678',
        );
      });

      test('rejects null phone', () {
        expect(
          () => PaymentValidation.requireValidMpesaPhone(null),
          throwsA(isA<PaymentValidationException>()),
        );
      });

      test('rejects empty phone', () {
        expect(
          () => PaymentValidation.requireValidMpesaPhone(''),
          throwsA(isA<PaymentValidationException>()),
        );
      });

      test('rejects non-Kenyan prefix like 2548XXXXXXXX', () {
        expect(
          () => PaymentValidation.requireValidMpesaPhone('254812345678'),
          throwsA(isA<PaymentValidationException>()),
        );
      });

      test('rejects too-short number', () {
        expect(
          () => PaymentValidation.requireValidMpesaPhone('071234'),
          throwsA(isA<PaymentValidationException>()),
        );
      });
    });

    group('plate number validation', () {
      test('accepts valid plate KBC123A', () {
        expect(
          () => PaymentValidation.validatePlateNumber('KBC123A'),
          returnsNormally,
        );
      });

      test('accepts plate with spaces', () {
        expect(
          () => PaymentValidation.validatePlateNumber('KBC 123A'),
          returnsNormally,
        );
      });

      test('rejects empty plate', () {
        expect(
          () => PaymentValidation.validatePlateNumber(''),
          throwsA(isA<PaymentValidationException>()),
        );
      });

      test('rejects plate shorter than 6 characters', () {
        expect(
          () => PaymentValidation.validatePlateNumber('KBC1'),
          throwsA(isA<PaymentValidationException>()),
        );
      });
    });

    test('validateLocation rejects empty string', () {
      expect(
        () => PaymentValidation.validateLocation(''),
        throwsA(isA<PaymentValidationException>()),
      );
    });

    test('validateLocation rejects whitespace-only string', () {
      expect(
        () => PaymentValidation.validateLocation('   '),
        throwsA(isA<PaymentValidationException>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // 4. PaymentStatusSnapshot terminal-status logic
  // ---------------------------------------------------------------------------
  group('PaymentStatusSnapshot terminal status', () {
    test('SUCCESS is terminal and success', () {
      const s = PaymentStatusSnapshot(status: 'SUCCESS');
      expect(s.isTerminal, isTrue);
      expect(s.isSuccess, isTrue);
      expect(s.isFailure, isFalse);
    });

    test('COMPLETED is treated as success', () {
      const s = PaymentStatusSnapshot(status: 'COMPLETED');
      expect(s.isSuccess, isTrue);
    });

    test('FAILED is terminal failure', () {
      const s = PaymentStatusSnapshot(status: 'FAILED');
      expect(s.isTerminal, isTrue);
      expect(s.isFailure, isTrue);
    });

    test('CANCELLED is terminal failure', () {
      expect(
        const PaymentStatusSnapshot(status: 'CANCELLED').isTerminal,
        isTrue,
      );
      expect(
        const PaymentStatusSnapshot(status: 'CANCELLED').isFailure,
        isTrue,
      );
    });

    test('CANCELED (US spelling) is also terminal', () {
      expect(
        const PaymentStatusSnapshot(status: 'CANCELED').isTerminal,
        isTrue,
      );
    });

    test('TIMEOUT is terminal failure', () {
      expect(
        const PaymentStatusSnapshot(status: 'TIMEOUT').isFailure,
        isTrue,
      );
    });

    test('TIMED_OUT is terminal failure', () {
      expect(
        const PaymentStatusSnapshot(status: 'TIMED_OUT').isTerminal,
        isTrue,
      );
    });

    test('PENDING is not terminal', () {
      expect(
        const PaymentStatusSnapshot(status: 'PENDING').isTerminal,
        isFalse,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // 5. AppBloc M-Pesa polling behavior
  // ---------------------------------------------------------------------------
  group('AppBloc M-Pesa polling behavior', () {
    test('successful callback completes the session', () async {
      final api = _FakeParkingIqApi(paymentStatus: 'SUCCESS');
      final bloc = AppBloc(
        api: api,
        initialAuthToken: 'token',
        initialPhoneNumber: '0712345678',
      );

      bloc.add(
        const PayParkingSession(
          sessionId: 'session-1',
          phoneNumber: '0712345678',
          amount: 5,
          plateNumber: 'KBC 123A',
          location: 'CBD Parking Zone A',
        ),
      );

      await expectLater(
        bloc.stream,
        emitsThrough(
          isA<AppState>().having(
            (state) => state.selectedSession?.status,
            'session status',
            'COMPLETED',
          ),
        ),
      );

      expect(api.stkPushCount, 1);
      expect(api.lastStkPayload?['type'], 'SESSION');
      expect(api.lastStkPayload?['sessionId'], 'session-1');
      expect(api.lastStkPayload?['location'], 'CBD Parking Zone A');
      await bloc.close();
    });

    test('successful payment clears isWaitingForPayment flag', () async {
      final bloc = AppBloc(
        api: _FakeParkingIqApi(paymentStatus: 'SUCCESS'),
        initialAuthToken: 'token',
        initialPhoneNumber: '0712345678',
      );

      bloc.add(const PayParkingSession(
        sessionId: 'session-1',
        phoneNumber: '0712345678',
        amount: 5,
        plateNumber: 'KBC 123A',
        location: 'CBD Parking Zone A',
      ));

      await expectLater(
        bloc.stream,
        emitsThrough(
          isA<AppState>()
              .having((s) => s.isWaitingForPayment, 'waiting', isFalse)
              .having((s) => s.selectedSession?.status, 'status', 'COMPLETED'),
        ),
      );
      await bloc.close();
    });

    test('successful payment sets exitTime on selected session', () async {
      final bloc = AppBloc(
        api: _FakeParkingIqApi(paymentStatus: 'SUCCESS'),
        initialAuthToken: 'token',
        initialPhoneNumber: '0712345678',
      );

      bloc.add(const PayParkingSession(
        sessionId: 'session-1',
        phoneNumber: '0712345678',
        amount: 5,
        plateNumber: 'KBC 123A',
        location: 'CBD Parking Zone A',
      ));

      await expectLater(
        bloc.stream,
        emitsThrough(
          isA<AppState>().having(
            (s) => s.selectedSession?.endTime,
            'endTime',
            isNotNull,
          ),
        ),
      );
      await bloc.close();
    });

    test('failed callback stops waiting and keeps session active', () async {
      final api = _FakeParkingIqApi(paymentStatus: 'FAILED');
      final bloc = AppBloc(
        api: api,
        initialAuthToken: 'token',
        initialPhoneNumber: '0712345678',
      );

      bloc.add(
        const PayParkingSession(
          sessionId: 'session-1',
          phoneNumber: '0712345678',
          amount: 5,
          plateNumber: 'KBC 123A',
          location: 'CBD Parking Zone A',
        ),
      );

      await expectLater(
        bloc.stream,
        emitsThrough(
          isA<AppState>()
              .having((state) => state.isWaitingForPayment, 'waiting', false)
              .having(
                (state) => state.errorMessage,
                'error message',
                'M-Pesa payment failed',
              )
              .having(
                (state) => state.selectedSession?.isActive,
                'session active',
                true,
              ),
        ),
      );

      await bloc.close();
    });

    test('failed payment does not mark session as COMPLETED', () async {
      final bloc = AppBloc(
        api: _FakeParkingIqApi(paymentStatus: 'FAILED'),
        initialAuthToken: 'token',
        initialPhoneNumber: '0712345678',
      );

      bloc.add(const PayParkingSession(
        sessionId: 'session-1',
        phoneNumber: '0712345678',
        amount: 5,
        plateNumber: 'KBC 123A',
        location: 'CBD Parking Zone A',
      ));

      await expectLater(
        bloc.stream,
        emitsThrough(
          isA<AppState>().having(
            (s) => s.selectedSession?.status,
            'status',
            isNot('COMPLETED'),
          ),
        ),
      );
      await bloc.close();
    });

    test('cancelled payment shows appropriate error and stops waiting', () async {
      final bloc = AppBloc(
        api: _FakeParkingIqApi(paymentStatus: 'CANCELLED'),
        initialAuthToken: 'token',
        initialPhoneNumber: '0712345678',
      );

      bloc.add(const PayParkingSession(
        sessionId: 'session-1',
        phoneNumber: '0712345678',
        amount: 5,
        plateNumber: 'KBC 123A',
        location: 'CBD Parking Zone A',
      ));

      await expectLater(
        bloc.stream,
        emitsThrough(
          isA<AppState>()
              .having((s) => s.isWaitingForPayment, 'waiting', isFalse)
              .having(
                (s) => s.errorMessage,
                'error',
                contains('cancelled'),
              ),
        ),
      );
      await bloc.close();
    });

    test('cancelled payment keeps session active for retry', () async {
      final bloc = AppBloc(
        api: _FakeParkingIqApi(paymentStatus: 'CANCELLED'),
        initialAuthToken: 'token',
        initialPhoneNumber: '0712345678',
      );

      bloc.add(const PayParkingSession(
        sessionId: 'session-1',
        phoneNumber: '0712345678',
        amount: 5,
        plateNumber: 'KBC 123A',
        location: 'CBD Parking Zone A',
      ));

      await expectLater(
        bloc.stream,
        emitsThrough(
          isA<AppState>().having(
            (s) => s.selectedSession?.isActive,
            'isActive',
            isTrue,
          ),
        ),
      );
      await bloc.close();
    });

    test('timeout status stops waiting with timeout error message', () async {
      final bloc = AppBloc(
        api: _FakeParkingIqApi(paymentStatus: 'TIMEOUT'),
        initialAuthToken: 'token',
        initialPhoneNumber: '0712345678',
      );

      bloc.add(const PayParkingSession(
        sessionId: 'session-1',
        phoneNumber: '0712345678',
        amount: 5,
        plateNumber: 'KBC 123A',
        location: 'CBD Parking Zone A',
      ));

      await expectLater(
        bloc.stream,
        emitsThrough(
          isA<AppState>()
              .having((s) => s.isWaitingForPayment, 'waiting', isFalse)
              .having(
                (s) => s.errorMessage,
                'error',
                contains('timed out'),
              ),
        ),
      );
      await bloc.close();
    });

    test('duplicate PayParkingSession is ignored while waiting', () async {
      final api = _SlowFakeParkingIqApi();
      final bloc = AppBloc(
        api: api,
        initialAuthToken: 'token',
        initialPhoneNumber: '0712345678',
      );

      bloc.add(const PayParkingSession(
        sessionId: 'session-1',
        phoneNumber: '0712345678',
        amount: 5,
        plateNumber: 'KBC 123A',
        location: 'CBD Parking Zone A',
      ));

      // Wait for the waiting state to be emitted
      await expectLater(
        bloc.stream,
        emitsThrough(
          isA<AppState>().having(
            (s) => s.isWaitingForPayment,
            'waiting',
            isTrue,
          ),
        ),
      );

      // Fire a duplicate while isWaitingForPayment is true
      bloc.add(const PayParkingSession(
        sessionId: 'session-1',
        phoneNumber: '0712345678',
        amount: 5,
        plateNumber: 'KBC 123A',
        location: 'CBD Parking Zone A',
      ));

      await Future.delayed(const Duration(milliseconds: 100));

      // STK push must still only have been triggered once
      expect(api.stkPushCount, 1);

      await bloc.close();
    });

    test('location is propagated to STK push payload', () async {
      final api = _FakeParkingIqApi(paymentStatus: 'SUCCESS');
      final bloc = AppBloc(
        api: api,
        initialAuthToken: 'token',
        initialPhoneNumber: '0712345678',
      );

      bloc.add(const PayParkingSession(
        sessionId: 'session-1',
        phoneNumber: '254712345678',
        amount: 5,
        plateNumber: 'KBC 123A',
        location: 'CBD Parking Zone A',
      ));

      await expectLater(
        bloc.stream,
        emitsThrough(isA<AppState>().having(
          (s) => s.selectedSession?.status,
          'status',
          'COMPLETED',
        )),
      );

      expect(api.lastStkPayload?['location'], 'CBD Parking Zone A');
      await bloc.close();
    });

    test('STK push is only sent once per successful payment', () async {
      final api = _FakeParkingIqApi(paymentStatus: 'SUCCESS');
      final bloc = AppBloc(
        api: api,
        initialAuthToken: 'token',
        initialPhoneNumber: '0712345678',
      );

      bloc.add(const PayParkingSession(
        sessionId: 'session-1',
        phoneNumber: '0712345678',
        amount: 5,
        plateNumber: 'KBC 123A',
        location: 'CBD Parking Zone A',
      ));

      await expectLater(
        bloc.stream,
        emitsThrough(isA<AppState>().having(
          (s) => s.selectedSession?.status,
          'status',
          'COMPLETED',
        )),
      );

      expect(api.stkPushCount, 1);
      await bloc.close();
    });

    test('cancelled and timeout statuses are terminal failures', () {
      expect(
        const PaymentStatusSnapshot(status: 'CANCELLED').isTerminal,
        isTrue,
      );
      expect(
        const PaymentStatusSnapshot(status: 'TIMEOUT').isFailure,
        isTrue,
      );
    });
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

ParkingSession _session({
  String status = 'ACTIVE',
  bool isActive = true,
}) {
  return ParkingSession(
    id: 'session-1',
    locationName: 'CBD Parking Zone A',
    startTime: DateTime(2026, 5, 1, 8),
    cost: 5,
    status: status,
    vehicle: const Vehicle(
      plateNumber: 'KBC 123A',
      type: 'Car',
      make: 'Toyota',
      model: 'Vitz',
    ),
    isActive: isActive,
  );
}

/// Fake API where every status poll returns a fixed terminal status immediately.
class _FakeParkingIqApi extends ParkingIqApi {
  final String terminalStatus;
  int stkPushCount = 0;
  Map<String, dynamic>? lastStkPayload;

  _FakeParkingIqApi({required String paymentStatus})
      : terminalStatus = paymentStatus,
        super(debug: false);

  @override
  bool get hasToken => true;

  @override
  Future<ParkingSession> calculateParkingSession(String sessionId) async {
    return _session();
  }

  @override
  Future<MpesaResponse> startSessionStkPush({
    required String phoneNumber,
    required double amount,
    required String sessionId,
    required String plateNumber,
    required String location,
    String transactionDesc = 'Parking session payment',
  }) async {
    stkPushCount++;
    lastStkPayload = {
      'type': 'SESSION',
      'phoneNumber': phoneNumber,
      'amount': amount.toInt(),
      'sessionId': sessionId,
      'plateNumber': plateNumber,
      'location': location,
      'transactionDesc': transactionDesc,
    };
    return const MpesaResponse(
      paymentId: 'payment-1',
      checkoutRequestId: 'ws_CO_123',
      status: 'PENDING',
    );
  }

  @override
  Future<PaymentStatusSnapshot> paymentStatus(String paymentId) async {
    return PaymentStatusSnapshot(
      paymentId: paymentId,
      checkoutRequestId: 'ws_CO_123',
      sessionId: 'session-1',
      status: terminalStatus,
    );
  }

  @override
  Future<ParkingSession> parkingSession(String sessionId) async {
    return _session(status: 'COMPLETED', isActive: false).copyWith(
      endTime: DateTime(2026, 5, 1, 9),
      amountPaid: 5,
    );
  }
}

/// Fake API that stays PENDING — used to test the duplicate-payment guard.
/// The STK push completes instantly but the poll never terminates, so the
/// bloc stays in isWaitingForPayment long enough for the test to fire a
/// second event.
class _SlowFakeParkingIqApi extends ParkingIqApi {
  int stkPushCount = 0;

  _SlowFakeParkingIqApi() : super(debug: false);

  @override
  bool get hasToken => true;

  @override
  Future<ParkingSession> calculateParkingSession(String sessionId) async {
    return _session();
  }

  @override
  Future<MpesaResponse> startSessionStkPush({
    required String phoneNumber,
    required double amount,
    required String sessionId,
    required String plateNumber,
    required String location,
    String transactionDesc = 'Parking session payment',
  }) async {
    stkPushCount++;
    return const MpesaResponse(
      paymentId: 'payment-slow',
      checkoutRequestId: 'ws_CO_slow',
      status: 'PENDING',
    );
  }

  @override
  Future<PaymentStatusSnapshot> paymentStatus(String paymentId) async {
    // Delay long enough that the bloc stays in waiting state during the test
    await Future.delayed(const Duration(seconds: 10));
    return const PaymentStatusSnapshot(status: 'PENDING');
  }
}
