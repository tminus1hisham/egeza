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
