import 'package:flutter_test/flutter_test.dart';

import 'package:egesha/blocs/report_metrics.dart';
import 'package:egesha/models/api_models.dart';
import 'package:egesha/models/parking_session.dart';
import 'package:egesha/models/vehicle.dart';

void main() {
  // A fixed Thursday afternoon, so every window and bucket in here is exact.
  final now = DateTime(2026, 8, 20, 15, 30);
  final today = DateTime(2026, 8, 20);

  group('ReportWindow', () {
    test('today is the local day, not the last 24 hours', () {
      final window = ReportWindow.of(ReportRange.today, now: now);

      expect(window.start, today);
      expect(window.end, DateTime(2026, 8, 21));
      expect(window.days, 1);
      expect(window.isHourly, isTrue);
      expect(window.contains(DateTime(2026, 8, 20, 0, 1)), isTrue);
      // Yesterday evening is yesterday, however recent it is.
      expect(window.contains(DateTime(2026, 8, 19, 23, 59)), isFalse);
    });

    test('7 and 30 days both include today', () {
      final week = ReportWindow.of(ReportRange.week, now: now);
      final month = ReportWindow.of(ReportRange.month, now: now);

      expect(week.days, 7);
      expect(week.start, DateTime(2026, 8, 14));
      expect(week.end, DateTime(2026, 8, 21));
      expect(month.days, 30);
      expect(month.start, DateTime(2026, 7, 22));
      expect(week.isHourly, isFalse);
    });

    test('a custom range covers both picked days in full, in any order', () {
      final window = ReportWindow.of(
        ReportRange.custom,
        now: now,
        // Handed over backwards, as a picker can.
        customStart: DateTime(2026, 8, 12, 18),
        customEnd: DateTime(2026, 8, 10, 6),
      );

      expect(window.start, DateTime(2026, 8, 10));
      expect(window.end, DateTime(2026, 8, 13));
      expect(window.days, 3);
      expect(window.contains(DateTime(2026, 8, 12, 23, 30)), isTrue);
    });

    test('the previous window is the same length, ending where this starts',
        () {
      final week = ReportWindow.of(ReportRange.week, now: now);
      final before = week.previous;

      expect(before.end, week.start);
      expect(before.days, 7);
      expect(before.start, DateTime(2026, 8, 7));
    });
  });

  group('buildReport', () {
    ReportSummary reportFor(
      ReportRange range, {
      List<ParkingSession>? sessions,
      List<PaymentTransaction>? payments,
      List<ParkingSession> active = const [],
      ManagerRevenueSource source = ManagerRevenueSource.payments,
      int capacity = 0,
    }) {
      return buildReport(
        window: ReportWindow.of(range, now: now),
        sessions: sessions ?? _sessions(now),
        payments: payments ?? _payments(now),
        activeSessions: active,
        revenueSource: source,
        capacity: capacity,
        now: now,
      );
    }

    test('counts only the money that landed inside the period', () {
      final today = reportFor(ReportRange.today);

      // 400 + 150 settled today. The pending 900 is not takings, and
      // yesterday's 600 belongs to yesterday.
      expect(today.revenue, 550);
      expect(today.settledPayments, 2);
      expect(today.averagePayment, 275);
    });

    test('measures the period against the one before it', () {
      final today = reportFor(ReportRange.today);

      expect(today.previousRevenue, 600);
      expect(today.revenueChange, closeTo((550 - 600) / 600, 0.0001));
    });

    test('says nothing rather than 100% when there is no period to compare',
        () {
      final report = buildReport(
        window: ReportWindow.of(ReportRange.today, now: now),
        sessions: [_session('s', 'KAA111A', start: _at(now, 9), paid: 100)],
        payments: [_payment('p', 100, 'SUCCESS', _at(now, 9))],
        now: now,
      );

      expect(report.previousRevenue, 0);
      expect(report.revenueChange, isNull);
    });

    test('counts vehicles by plate and entries by session', () {
      final today = reportFor(ReportRange.today);

      // KBR656Z came in twice today; KDA123X and KCC999Y once each.
      expect(today.entries, 4);
      expect(today.vehicles, 3);
      expect(today.repeatVisits, 1);
    });

    test('separates money left unpaid from a tab still running', () {
      final report = reportFor(ReportRange.today);

      // KDA123X drove off owing 150. The car still inside owes 80 so far,
      // which is not due yet and must not read as a loss.
      expect(report.owedFromExits, 150);
      expect(report.runningTab, 80);
    });

    test('rates collection over finished sessions only', () {
      final report = reportFor(ReportRange.today);

      // Billed on exits: 300 + 150 + 200. Collected: 300 + 200.
      expect(report.billedOnExits, 650);
      expect(report.collectedOnExits, 500);
      expect(report.collectionRate, closeTo(500 / 650, 0.0001));
    });

    test('counts AutoPay sessions and their share', () {
      final report = reportFor(ReportRange.today);

      expect(report.autoPayEntries, 1);
      expect(report.autoPayShare, closeTo(0.25, 0.0001));
    });

    test('falls back to session amounts when payments are unavailable', () {
      final report = reportFor(
        ReportRange.today,
        source: ManagerRevenueSource.sessions,
      );

      // 300 paid + 200 paid, both from sessions started today.
      expect(report.revenue, 500);
      // Yesterday's session paid 600.
      expect(report.previousRevenue, 600);
    });

    test('buckets today by the hour and stops at the current one', () {
      final report = reportFor(ReportRange.today);

      // 00:00 through 15:00 inclusive — nothing is drawn for hours that have
      // not happened.
      expect(report.buckets, hasLength(16));
      expect(report.buckets.first.label, '00');
      expect(report.buckets.last.label, '15');

      final nineAm = report.buckets[9];
      expect(nineAm.revenue, 400);
      expect(nineAm.entries, 1);
    });

    test('buckets a longer period by the day', () {
      final report = reportFor(ReportRange.week);

      expect(report.buckets, hasLength(7));
      expect(report.buckets.last.start, today);
      expect(report.buckets.last.revenue, 550);
      // Yesterday, with its own settled 600.
      expect(report.buckets[5].revenue, 600);
      expect(report.buckets[5].fullLabel, 'Wed 19 Aug');
    });

    test('ranks the busiest hours and names the busiest weekday', () {
      final report = reportFor(ReportRange.week);

      expect(report.busiestHours.first.entries, greaterThan(0));
      expect(report.busiestHours.length, lessThanOrEqualTo(3));
      expect(report.busiestWeekday, isNotNull);
      // A single day would only name itself back at the reader.
      expect(reportFor(ReportRange.today).busiestWeekday, isNull);
    });

    test('lists only vehicles that actually came back', () {
      final report = reportFor(ReportRange.today);

      expect(report.topVehicles, hasLength(1));
      expect(report.topVehicles.first.plate, 'KBR656Z');
      expect(report.topVehicles.first.visits, 2);
      expect(report.topVehicles.first.spend, 500);
    });

    test('reads parked-now and occupancy off the live list, not the period',
        () {
      final report = reportFor(
        ReportRange.today,
        active: [
          _session('a-1', 'KCC999Y', start: _at(now, 10), active: true),
          _session('a-2', 'KDD111B', start: _at(now, 14), active: true),
        ],
        capacity: 50,
      );

      expect(report.parkedNow, 2);
      expect(report.occupancyRatio, closeTo(0.04, 0.0001));
      expect(report.freeSpaces, 48);
    });

    test('an empty period reports no activity rather than zeros with a chart',
        () {
      final report = buildReport(
        window: ReportWindow.of(
          ReportRange.custom,
          now: now,
          customStart: DateTime(2026, 1, 5),
          customEnd: DateTime(2026, 1, 6),
        ),
        sessions: _sessions(now),
        payments: _payments(now),
        now: now,
      );

      expect(report.hasActivity, isFalse);
      expect(report.revenue, 0);
      expect(report.collectionRate, 1, reason: 'nothing billed, nothing owed');
    });
  });
}

DateTime _at(DateTime day, int hour) =>
    DateTime(day.year, day.month, day.day, hour);

/// Today: two visits from KBR656Z (one paid, one still parked), an exit that
/// never paid, and an AutoPay exit. Yesterday: one paid session.
List<ParkingSession> _sessions(DateTime now) {
  final yesterday = now.subtract(const Duration(days: 1));
  return [
    _session('s-1', 'KBR656Z', start: _at(now, 9), paid: 300, cost: 300),
    _session('s-2', 'KDA123X', start: _at(now, 10), paid: 0, cost: 150),
    _session('s-3', 'KCC999Y', start: _at(now, 11), cost: 80, active: true),
    _session('s-4', 'KBR656Z', start: _at(now, 13), paid: 200, cost: 200,
        autoPay: true),
    _session('s-0', 'KEE777C', start: _at(yesterday, 9), paid: 600, cost: 600),
  ];
}

List<PaymentTransaction> _payments(DateTime now) {
  final yesterday = now.subtract(const Duration(days: 1));
  return [
    _payment('p-1', 400, 'SUCCESS', _at(now, 9)),
    _payment('p-2', 150, 'COMPLETED', _at(now, 13)),
    _payment('p-3', 900, 'PENDING', _at(now, 14)),
    _payment('p-0', 600, 'SUCCESS', _at(yesterday, 10)),
  ];
}

ParkingSession _session(
  String id,
  String plate, {
  required DateTime start,
  double cost = 0,
  double paid = 0,
  bool active = false,
  bool autoPay = false,
}) {
  return ParkingSession(
    id: id,
    locationName: 'Sarit',
    startTime: start,
    endTime: active ? null : start.add(const Duration(hours: 1)),
    cost: cost > 0 ? cost : paid,
    amountPaid: paid,
    status: active ? 'ACTIVE' : 'COMPLETED',
    autoPayEnabled: autoPay,
    vehicle: Vehicle(
      plateNumber: plate,
      type: 'Saloon',
      make: 'Toyota',
      model: 'Axio',
      autoPayEnabled: autoPay,
    ),
    isActive: active,
  );
}

PaymentTransaction _payment(
  String id,
  double amount,
  String status,
  DateTime createdAt,
) {
  return PaymentTransaction(
    id: id,
    amount: amount,
    status: status,
    createdAt: createdAt,
    plateNumber: 'KBR656Z',
  );
}
