import 'dart:math';

import '../models/api_models.dart';
import '../models/parking_session.dart';
import '../models/vehicle.dart';

/// One location's generated day, in the shape [ManagerCubit] would have got
/// back from the API.
class ManagerSampleSnapshot {
  final List<ParkingSession> sessions;
  final List<ParkingSession> activeSessions;
  final List<PaymentTransaction> payments;

  const ManagerSampleSnapshot({
    required this.sessions,
    required this.activeSessions,
    required this.payments,
  });
}

/// Generated figures for previewing the manager view without a manager account
/// or a live site behind it.
///
/// Debug-only, and the screen badges every reading it produces as sample — a
/// plausible number that is silently invented is worse than no number at all.
///
/// The day is **scheduled, not sampled**: a fixed timetable of arrivals is laid
/// out from the site's opening hour, and only the ones whose entry time has
/// already passed are returned. That makes it deterministic — the same site
/// shows the same day on every poll instead of jittering on a 15s heartbeat —
/// while still moving in real time, because a car whose stay has run out exits
/// on its own and its payment lands in the takings while you watch.
class ManagerSampleData {
  const ManagerSampleData._();

  static const saritId = 'sample-sarit';
  static const cbdId = 'sample-cbd';

  static const locations = <ParkingLocation>[
    ParkingLocation(
      id: saritId,
      name: 'Sarit',
      address: 'Sarit Centre, Westlands',
      ratePerHour: 60,
      maxCapacity: 300,
    ),
    ParkingLocation(
      id: cbdId,
      name: 'Nairobi CBD Parking',
      address: 'Kimathi Street',
      ratePerHour: 50,
      maxCapacity: 250,
    ),
  ];

  /// Builds [locationId]'s day as it stands at [now].
  static ManagerSampleSnapshot forLocation(
    String locationId, {
    DateTime? now,
  }) {
    final moment = now ?? DateTime.now();
    final location = locations.firstWhere(
      (item) => item.id == locationId,
      orElse: () => locations.first,
    );

    // Seeded off the location so each site keeps its own steady day rather than
    // redrawing itself every time you switch back to it.
    final random = Random(locationId.hashCode ^ 0x5AA17);

    final midnight = DateTime(moment.year, moment.month, moment.day);
    var open = midnight.add(const Duration(hours: 6));
    if (moment.isBefore(open.add(const Duration(hours: 2)))) {
      // Opened too recently for a 06:00 start to have produced a day worth
      // looking at — run the sample day from just after midnight instead.
      open = midnight.add(const Duration(minutes: 5));
    }

    final sessions = <ParkingSession>[];
    final active = <ParkingSession>[];
    final payments = <PaymentTransaction>[];

    // A 16-hour trading day at a busy mall: an arrival every 90 seconds or so,
    // which against a two-hour average stay settles at roughly a quarter of the
    // site occupied — enough for the occupancy bar to mean something.
    const arrivals = 700;
    for (var i = 0; i < arrivals; i++) {
      final entry = open.add(
        Duration(seconds: i * 90 + random.nextInt(60)),
      );
      if (entry.isAfter(moment)) break;

      final stay = _stayMinutes(random);
      final plannedExit = entry.add(Duration(minutes: stay));
      final stillParked = plannedExit.isAfter(moment);
      final minutes = stillParked ? moment.difference(entry).inMinutes : stay;
      final cost = _fee(minutes, location.ratePerHour);

      final plate = _plate(random, i);
      final vehicle = _vehicle(random, plate);
      final sessionId = '${location.id}-s$i';

      if (stillParked) {
        // A handful settled at a payment machine before walking back to the
        // car, which is what puts a "Prepaid" chip on a parked vehicle.
        final prepaid = i % 17 == 0;
        final session = ParkingSession(
          id: sessionId,
          locationName: location.name,
          startTime: entry,
          cost: cost,
          amountPaid: prepaid ? cost : 0,
          durationMinutes: minutes,
          ratePerHour: location.ratePerHour.round(),
          status: 'ACTIVE',
          autoPayEnabled: vehicle.autoPayEnabled,
          vehicle: vehicle,
          isActive: true,
        );
        sessions.add(session);
        active.add(session);

        if (prepaid) {
          payments.add(
            _payment(
              id: '$sessionId-p',
              sessionId: sessionId,
              location: location,
              vehicle: vehicle,
              amount: cost,
              status: 'SUCCESS',
              at: moment.subtract(const Duration(minutes: 4)),
              random: random,
            ),
          );
        }
        continue;
      }

      // Exited. Most paid on the way out; the rest is what the site is chasing.
      final roll = random.nextInt(100);
      final paymentStatus = roll < 86
          ? 'SUCCESS'
          : roll < 92
              ? 'PENDING'
              : roll < 96
                  ? 'FAILED'
                  : null;
      final settled = paymentStatus == 'SUCCESS';

      sessions.add(
        ParkingSession(
          id: sessionId,
          locationName: location.name,
          startTime: entry,
          endTime: plannedExit,
          cost: cost,
          amountPaid: settled ? cost : 0,
          durationMinutes: minutes,
          ratePerHour: location.ratePerHour.round(),
          status: settled ? 'COMPLETED' : 'EXIT_PENDING_PAYMENT',
          autoPayEnabled: vehicle.autoPayEnabled,
          vehicle: vehicle,
          isActive: false,
        ),
      );

      if (paymentStatus != null) {
        payments.add(
          _payment(
            id: '$sessionId-p',
            sessionId: sessionId,
            location: location,
            vehicle: vehicle,
            amount: cost,
            status: paymentStatus,
            at: plannedExit,
            random: random,
          ),
        );
      }
    }

    return ManagerSampleSnapshot(
      sessions: sessions,
      activeSessions: active,
      payments: payments,
    );
  }

  /// The days *before* today, so a period longer than today has something in
  /// it — and so "vs the 30 days before" is measured against a real figure.
  ///
  /// Every session here is finished: yesterday's cars have all gone home. The
  /// result is cached per site per day because 60 days of trade is far too much
  /// to redraw on a 15s poll, and because the past must not shift under a
  /// period the user is reading.
  static ManagerSampleSnapshot historyFor(
    String locationId, {
    DateTime? now,
    int days = 60,
  }) {
    final moment = (now ?? DateTime.now()).toLocal();
    final today = DateTime(moment.year, moment.month, moment.day);
    final key = '$locationId|${today.toIso8601String()}|$days';
    final cached = _historyCache[key];
    if (cached != null) return cached;

    final location = locations.firstWhere(
      (item) => item.id == locationId,
      orElse: () => locations.first,
    );

    final sessions = <ParkingSession>[];
    final payments = <PaymentTransaction>[];

    for (var back = 1; back <= days; back++) {
      final day = DateTime(today.year, today.month, today.day - back);
      // Seeded off the day itself, so yesterday reads the same whenever it is
      // asked for and each day still differs from the next.
      final random = Random(locationId.hashCode ^ (day.year * 10000 + day.month * 100 + day.day));

      // A mall: Saturday is the week, Sunday is quiet, and trade has been
      // creeping up, which is what gives the period comparison a direction.
      final weekdayFactor = switch (day.weekday) {
        DateTime.saturday => 1.35,
        DateTime.friday => 1.15,
        DateTime.sunday => 0.72,
        _ => 1.0,
      };
      final growth = 1 + (days - back) * 0.004;
      final arrivals =
          (180 * weekdayFactor * growth + random.nextInt(30) - 15).round();

      final open = day.add(const Duration(hours: 6));
      for (var i = 0; i < arrivals; i++) {
        final entry = open.add(
          Duration(seconds: (i * 57600 / arrivals).round() + random.nextInt(90)),
        );
        final stay = _stayMinutes(random);
        final exit = entry.add(Duration(minutes: stay));
        final cost = _fee(stay, location.ratePerHour);
        final vehicle = _vehicle(random, _historyPlate(random, back, i));
        final sessionId = '${location.id}-h$back-$i';

        final roll = random.nextInt(100);
        final paymentStatus = roll < 88
            ? 'SUCCESS'
            : roll < 93
                ? 'PENDING'
                : roll < 97
                    ? 'FAILED'
                    : null;
        final settled = paymentStatus == 'SUCCESS';

        sessions.add(
          ParkingSession(
            id: sessionId,
            locationName: location.name,
            startTime: entry,
            endTime: exit,
            cost: cost,
            amountPaid: settled ? cost : 0,
            durationMinutes: stay,
            ratePerHour: location.ratePerHour.round(),
            status: settled ? 'COMPLETED' : 'EXIT_PENDING_PAYMENT',
            autoPayEnabled: vehicle.autoPayEnabled,
            vehicle: vehicle,
            isActive: false,
          ),
        );

        if (paymentStatus != null) {
          payments.add(
            _payment(
              id: '$sessionId-p',
              sessionId: sessionId,
              location: location,
              vehicle: vehicle,
              amount: cost,
              status: paymentStatus,
              at: exit,
              random: random,
            ),
          );
        }
      }
    }

    final snapshot = ManagerSampleSnapshot(
      sessions: sessions,
      activeSessions: const [],
      payments: payments,
    );
    // One site's past at a time; switching sites is not worth holding two
    // months of generated trade in memory for.
    _historyCache
      ..clear()
      ..[key] = snapshot;
    return snapshot;
  }

  static final Map<String, ManagerSampleSnapshot> _historyCache = {};

  /// A handful of plates come back week after week, which is what the regulars
  /// list on the reports screen is made of.
  static const _regulars = ['KDG221M', 'KBR656Z', 'KCX404P', 'KDA118T'];

  static String _historyPlate(Random random, int dayIndex, int index) {
    if (index % 19 == 0) return _regulars[(dayIndex + index) % _regulars.length];
    return _plate(random, index);
  }

  /// Mall parking: most people are an hour or two, a few are there all day.
  static int _stayMinutes(Random random) {
    final roll = random.nextInt(100);
    if (roll < 18) return 20 + random.nextInt(35);
    if (roll < 62) return 55 + random.nextInt(75);
    if (roll < 88) return 130 + random.nextInt(120);
    return 250 + random.nextInt(230);
  }

  /// Charged by the started hour, which is how the tiers on these sites read.
  static double _fee(int minutes, double ratePerHour) {
    final hours = (minutes / 60).ceil().clamp(1, 12);
    final rate = ratePerHour <= 0 ? 50 : ratePerHour;
    return (hours * rate).clamp(rate, rate * 8).toDouble();
  }

  static const _plateLetters = 'ABCDEFGHJKLMNPQRSTUVWXY';

  /// Kenyan plates, written the way the gate cameras write them — unspaced and
  /// uppercase. Every 23rd car is a repeat visitor, so vehicles-today and
  /// entries-today are not the same number.
  static String _plate(Random random, int index) {
    if (index > 0 && index % 23 == 0) return 'KDG221M';

    final a = _plateLetters[random.nextInt(_plateLetters.length)];
    final b = _plateLetters[random.nextInt(_plateLetters.length)];
    final digits = random.nextInt(1000).toString().padLeft(3, '0');
    final suffix = _plateLetters[random.nextInt(_plateLetters.length)];
    return 'K$a$b$digits$suffix';
  }

  static const _makes = <(String, String, String)>[
    ('Toyota', 'Axio', 'Saloon'),
    ('Toyota', 'Prado', 'SUV'),
    ('Nissan', 'X-Trail', 'SUV'),
    ('Mazda', 'Demio', 'Saloon'),
    ('Subaru', 'Forester', 'SUV'),
    ('Honda', 'Fit', 'Saloon'),
    ('Isuzu', 'D-Max', 'Pickup'),
    ('Volkswagen', 'Golf', 'Saloon'),
  ];

  static Vehicle _vehicle(Random random, String plate) {
    final (make, model, type) = _makes[random.nextInt(_makes.length)];
    return Vehicle(
      plateNumber: plate,
      type: type,
      make: make,
      model: model,
      // Roughly a third of a mall's traffic is on AutoPay, which is what makes
      // the AutoPay filter and the payment-mix bar worth looking at.
      autoPayEnabled: random.nextInt(100) < 34,
    );
  }

  static const _names = <String>[
    'Achieng Otieno',
    'Brian Kimani',
    'Faith Wanjiru',
    'Hassan Ali',
    'Joy Chelimo',
    'Kevin Mutua',
    'Mercy Njeri',
    'Peter Omondi',
  ];

  static PaymentTransaction _payment({
    required String id,
    required String sessionId,
    required ParkingLocation location,
    required Vehicle vehicle,
    required double amount,
    required String status,
    required DateTime at,
    required Random random,
  }) {
    return PaymentTransaction(
      id: id,
      sessionId: sessionId,
      userName: _names[random.nextInt(_names.length)],
      phoneNumber: '2547${random.nextInt(90000000) + 10000000}',
      plateNumber: vehicle.plateNumber,
      locationId: location.id,
      locationName: location.name,
      amount: amount,
      paymentMethod: 'MPESA',
      status: status,
      mpesaReceiptNumber: status == 'SUCCESS'
          ? 'S${random.nextInt(900000) + 100000}XY'
          : null,
      createdAt: at,
    );
  }
}
