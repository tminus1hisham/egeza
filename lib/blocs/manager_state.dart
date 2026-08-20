import 'package:equatable/equatable.dart';

import '../models/api_models.dart';
import '../models/parking_session.dart';
import '../models/vehicle.dart';
import 'report_metrics.dart';

// ManagerRevenueSource and the report types live in report_metrics.dart, which
// is pure. Re-exported so everything reading this state keeps one import.
export 'report_metrics.dart';

class ManagerState extends Equatable {
  /// First load only — a background refresh must never flip this, or the screen
  /// would blank out on a 20s heartbeat.
  final bool isLoading;

  /// Locations the signed-in user is actually assigned to manage.
  final List<ParkingLocation> locations;
  final String? selectedLocationId;

  /// Sessions that started today at the selected location.
  final List<ParkingSession> todaySessions;

  /// Cars on the ground right now, straight from the active endpoint.
  final List<ParkingSession> activeSessions;

  /// Today's payments at the selected location, settled and unsettled.
  final List<PaymentTransaction> todayPayments;

  /// Every session the location has on record, not just today's. The endpoint
  /// takes no date filter, so this is what the reports and the property
  /// sessions list slice their periods out of.
  final List<ParkingSession> historySessions;

  /// Every payment the location has on record, settled and unsettled.
  final List<PaymentTransaction> historyPayments;

  /// The period the reports screen is showing.
  final ReportRange range;

  /// Bounds of the picked range. Only read when [range] is
  /// [ReportRange.custom].
  final DateTime? customStart;
  final DateTime? customEnd;

  final ManagerRevenueSource revenueSource;
  final DateTime? lastUpdated;

  /// The user holds a manager-ish role but is assigned to no location, so there
  /// is nothing to show. Distinct from an error — nothing went wrong.
  final bool hasNoAssignments;

  final String? errorMessage;

  /// Every figure on screen is generated rather than read from the site. Debug
  /// only, and the screen must say so wherever it says a number.
  final bool isSample;

  const ManagerState({
    this.isLoading = true,
    this.locations = const [],
    this.selectedLocationId,
    this.todaySessions = const [],
    this.activeSessions = const [],
    this.todayPayments = const [],
    this.historySessions = const [],
    this.historyPayments = const [],
    this.range = ReportRange.today,
    this.customStart,
    this.customEnd,
    this.revenueSource = ManagerRevenueSource.payments,
    this.lastUpdated,
    this.hasNoAssignments = false,
    this.errorMessage,
    this.isSample = false,
  });

  ParkingLocation? get selectedLocation {
    for (final location in locations) {
      if (location.id == selectedLocationId) return location;
    }
    return null;
  }

  String get locationName => selectedLocation?.name ?? 'Parking';

  // ── The three numbers a manager opens this screen for ────────────────────

  /// Money taken today. Only settled payments count.
  double get revenueToday {
    if (revenueSource == ManagerRevenueSource.sessions) {
      return todaySessions.fold<double>(
        0,
        (sum, session) => sum + session.amountPaid,
      );
    }
    return todayPayments
        .where((payment) => payment.isSettled)
        .fold<double>(0, (sum, payment) => sum + payment.amount);
  }

  /// Vehicles that came in today. Counted as distinct plates rather than
  /// sessions, so a car that left and came back is still one vehicle.
  int get vehiclesToday => _todayPlates.length;

  /// Entries recorded today. Higher than [vehiclesToday] when a car came back.
  int get entriesToday => todaySessions.length;

  /// Cars still on the ground, live.
  int get stillParked => activeSessions.length;

  Set<String> get _todayPlates => {
        for (final session in todaySessions)
          Vehicle.plateKey(session.vehicle.plateNumber),
      }..remove('');

  // ── Supporting figures ───────────────────────────────────────────────────

  int get settledPaymentsToday =>
      todayPayments.where((payment) => payment.isSettled).length;

  double get averagePaymentToday {
    final count = settledPaymentsToday;
    if (count == 0) return 0;
    return revenueToday / count;
  }

  /// Fees owed on today's sessions that nobody has collected — cars that left
  /// without paying, plus the running total on cars still inside.
  double get outstandingToday {
    return todaySessions.fold<double>(0, (sum, session) {
      final owed = session.cost - session.amountPaid;
      return owed > 0 ? sum + owed : sum;
    });
  }

  /// Sessions that closed today, newest first — the day's exits.
  List<ParkingSession> get completedToday {
    final completed = todaySessions
        .where((session) => !session.isActive)
        .toList()
      ..sort((a, b) {
        final aEnd = a.endTime ?? a.startTime;
        final bEnd = b.endTime ?? b.startTime;
        return bEnd.compareTo(aEnd);
      });
    return completed;
  }

  /// Cars still inside, longest-parked first — the ones worth looking at.
  List<ParkingSession> get parkedNow {
    return activeSessions.toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  int get capacity => selectedLocation?.maxCapacity ?? 0;

  /// Share of the site in use. Driven by the live active count rather than the
  /// location's own `currentOccupancy`, which only refreshes when the locations
  /// list is refetched.
  double get occupancyRatio {
    if (capacity <= 0) return 0;
    return (stillParked / capacity).clamp(0.0, 1.0);
  }

  int get freeSpaces {
    if (capacity <= 0) return 0;
    return (capacity - stillParked).clamp(0, capacity);
  }

  bool get hasData => lastUpdated != null;

  // ── Reports ──────────────────────────────────────────────────────────────

  /// The full session record, newest first.
  ///
  /// Falls back to today's list so a state built from a single day — which is
  /// all the older screens and their tests populate — still reports something
  /// rather than an empty period.
  List<ParkingSession> get reportSessions =>
      historySessions.isNotEmpty ? historySessions : todaySessions;

  List<PaymentTransaction> get reportPayments =>
      historyPayments.isNotEmpty ? historyPayments : todayPayments;

  ReportWindow get window => ReportWindow.of(
        range,
        customStart: customStart,
        customEnd: customEnd,
      );

  /// Every figure the reports screen shows, for the selected period.
  ///
  /// Recomputed per read rather than cached: the state has a const constructor
  /// so it cannot hold a memo, and one pass over the site's sessions costs far
  /// less than the rebuild that asked for it. Screens read it once per build.
  ReportSummary get report => buildReport(
        window: window,
        sessions: reportSessions,
        payments: reportPayments,
        activeSessions: activeSessions,
        revenueSource: revenueSource,
        capacity: capacity,
      );

  ManagerState copyWith({
    bool? isLoading,
    List<ParkingLocation>? locations,
    String? selectedLocationId,
    List<ParkingSession>? todaySessions,
    List<ParkingSession>? activeSessions,
    List<PaymentTransaction>? todayPayments,
    List<ParkingSession>? historySessions,
    List<PaymentTransaction>? historyPayments,
    ReportRange? range,
    DateTime? customStart,
    DateTime? customEnd,
    ManagerRevenueSource? revenueSource,
    DateTime? lastUpdated,
    bool? hasNoAssignments,
    String? errorMessage,
    bool? isSample,
    bool clearError = false,
  }) {
    final nextRange = range ?? this.range;
    return ManagerState(
      isLoading: isLoading ?? this.isLoading,
      locations: locations ?? this.locations,
      selectedLocationId: selectedLocationId ?? this.selectedLocationId,
      todaySessions: todaySessions ?? this.todaySessions,
      activeSessions: activeSessions ?? this.activeSessions,
      todayPayments: todayPayments ?? this.todayPayments,
      historySessions: historySessions ?? this.historySessions,
      historyPayments: historyPayments ?? this.historyPayments,
      range: nextRange,
      // Bounds belong to the picked range alone. Carrying them into a preset
      // would leave a stale pair behind to be read the next time the user
      // picks "Custom" without choosing dates.
      customStart: nextRange == ReportRange.custom
          ? (customStart ?? this.customStart)
          : null,
      customEnd:
          nextRange == ReportRange.custom ? (customEnd ?? this.customEnd) : null,
      revenueSource: revenueSource ?? this.revenueSource,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      hasNoAssignments: hasNoAssignments ?? this.hasNoAssignments,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      isSample: isSample ?? this.isSample,
    );
  }

  @override
  List<Object?> get props => [
        isLoading,
        locations.map((location) => location.id).join(','),
        selectedLocationId,
        // ParkingSession and PaymentTransaction have no value equality, so a
        // poll returning identical data would still emit a "new" state and
        // rebuild the screen. Compare what the screen actually renders.
        _sessionsSignature(todaySessions),
        _sessionsSignature(activeSessions),
        _paymentsSignature(todayPayments),
        // The history lists run to thousands of rows, so they are compared by
        // size rather than by a signature built row by row — every refresh that
        // changes them also moves `lastUpdated`, which is in this list already.
        historySessions.length,
        historyPayments.length,
        range,
        customStart,
        customEnd,
        revenueSource,
        lastUpdated,
        hasNoAssignments,
        errorMessage,
        isSample,
      ];
}

String _sessionsSignature(List<ParkingSession> sessions) {
  return sessions
      .map((session) => [
            session.id,
            session.vehicle.plateNumber,
            session.status,
            session.isActive,
            session.cost,
            session.amountPaid,
            session.startTime.toIso8601String(),
            session.endTime?.toIso8601String() ?? '',
          ].join('|'))
      .join(';');
}

String _paymentsSignature(List<PaymentTransaction> payments) {
  return payments
      .map((payment) => [
            payment.id,
            payment.status,
            payment.amount,
            payment.createdAt?.toIso8601String() ?? '',
          ].join('|'))
      .join(';');
}
