import 'package:equatable/equatable.dart';

import '../models/api_models.dart';
import '../models/parking_session.dart';
import '../models/vehicle.dart';

/// Where a takings figure came from.
///
/// [ManagerRevenueSource.payments] is the real one — money that actually
/// landed, dated by when it landed. [ManagerRevenueSource.sessions] is the
/// fallback used when the payments endpoint is unavailable; it sums what the
/// period's sessions recorded as paid, so it misses a car that drove in
/// yesterday and settled this morning. Every screen says which it is showing
/// rather than passing off an estimate as the till.
enum ManagerRevenueSource { payments, sessions }

/// The periods an owner can look at. Deliberately four — a long menu of ranges
/// is a worse answer than three obvious ones and a date picker.
enum ReportRange { today, week, month, custom }

/// A half-open span of whole local days: [start] up to but excluding [end].
///
/// Whole days because every figure an owner compares — yesterday's takings,
/// last week's — is counted by the day, and because none of the manager
/// endpoints filter by date, so the slicing happens here in the device's own
/// local day.
class ReportWindow extends Equatable {
  final ReportRange range;

  /// Local midnight on the first day, inclusive.
  final DateTime start;

  /// Local midnight on the day *after* the last day, exclusive.
  final DateTime end;

  const ReportWindow({
    required this.range,
    required this.start,
    required this.end,
  });

  factory ReportWindow.of(
    ReportRange range, {
    DateTime? now,
    DateTime? customStart,
    DateTime? customEnd,
  }) {
    final moment = (now ?? DateTime.now()).toLocal();
    final today = DateTime(moment.year, moment.month, moment.day);
    final tomorrow = today.add(const Duration(days: 1));

    switch (range) {
      case ReportRange.today:
        return ReportWindow(range: range, start: today, end: tomorrow);
      case ReportRange.week:
        return ReportWindow(
          range: range,
          start: today.subtract(const Duration(days: 6)),
          end: tomorrow,
        );
      case ReportRange.month:
        return ReportWindow(
          range: range,
          start: today.subtract(const Duration(days: 29)),
          end: tomorrow,
        );
      case ReportRange.custom:
        final rawStart = (customStart ?? today).toLocal();
        final rawEnd = (customEnd ?? customStart ?? today).toLocal();
        var first = DateTime(rawStart.year, rawStart.month, rawStart.day);
        var last = DateTime(rawEnd.year, rawEnd.month, rawEnd.day);
        if (last.isBefore(first)) {
          final swapped = first;
          first = last;
          last = swapped;
        }
        return ReportWindow(
          range: range,
          start: first,
          end: last.add(const Duration(days: 1)),
        );
    }
  }

  int get days {
    final span = end.difference(start).inDays;
    return span < 1 ? 1 : span;
  }

  bool contains(DateTime moment) {
    final local = moment.toLocal();
    return !local.isBefore(start) && local.isBefore(end);
  }

  /// The same length of time immediately before this one — what "vs previous"
  /// on the screen is measured against.
  ReportWindow get previous => ReportWindow(
        range: range,
        start: start.subtract(Duration(days: days)),
        end: start,
      );

  /// Chart bars are hours on a single day and days on anything longer.
  bool get isHourly => days <= 1;

  /// Names the period in full, e.g. on the hero.
  String get label {
    switch (range) {
      case ReportRange.today:
        return 'Today';
      case ReportRange.week:
        return 'Last 7 days';
      case ReportRange.month:
        return 'Last 30 days';
      case ReportRange.custom:
        final last = end.subtract(const Duration(days: 1));
        if (days == 1) return dayLabel(start, withYear: true);
        return '${dayLabel(start)} – ${dayLabel(last, withYear: true)}';
    }
  }

  /// Short enough for a filter chip.
  String get chipLabel {
    switch (range) {
      case ReportRange.today:
        return 'Today';
      case ReportRange.week:
        return '7 days';
      case ReportRange.month:
        return '30 days';
      case ReportRange.custom:
        return days == 1 ? dayLabel(start) : '$days days';
    }
  }

  /// What the change figure is being compared against, in words.
  String get comparisonLabel {
    switch (range) {
      case ReportRange.today:
        return 'vs yesterday';
      case ReportRange.week:
        return 'vs the 7 days before';
      case ReportRange.month:
        return 'vs the 30 days before';
      case ReportRange.custom:
        return 'vs the $days days before';
    }
  }

  @override
  List<Object?> get props => [range, start, end];
}

/// One bar on the trend chart.
class ReportBucket extends Equatable {
  final DateTime start;

  /// Printed under the bar. Two or three characters, so 30 of them fit.
  final String label;

  /// Read out when the bar is tapped, e.g. "Tue 12 Aug" or "14:00 – 15:00".
  final String fullLabel;

  final double revenue;
  final int entries;

  const ReportBucket({
    required this.start,
    required this.label,
    required this.fullLabel,
    required this.revenue,
    required this.entries,
  });

  @override
  List<Object?> get props => [start, label, revenue, entries];
}

/// An hour of the day and how many cars came in during it, across the period.
class HourLoad extends Equatable {
  final int hour;
  final int entries;

  const HourLoad(this.hour, this.entries);

  String get label {
    final from = hour.toString().padLeft(2, '0');
    final to = ((hour + 1) % 24).toString().padLeft(2, '0');
    return '$from:00 – $to:00';
  }

  @override
  List<Object?> get props => [hour, entries];
}

/// A plate and what it did over the period.
class VehicleVisits extends Equatable {
  final String plate;
  final int visits;
  final double spend;

  const VehicleVisits({
    required this.plate,
    required this.visits,
    required this.spend,
  });

  @override
  List<Object?> get props => [plate, visits, spend];
}

/// Everything the reports screen puts on the page, computed in one pass.
class ReportSummary extends Equatable {
  final ReportWindow window;
  final ManagerRevenueSource revenueSource;

  /// Money that actually landed in the period.
  final double revenue;

  /// The same figure for the period immediately before, for the change line.
  final double previousRevenue;

  /// Entries recorded in the period. A car that came back counts twice.
  final int entries;

  /// Distinct plates. A car that came back counts once.
  final int vehicles;

  final int settledPayments;

  /// Sessions whose vehicle is on AutoPay.
  final int autoPayEntries;

  /// Owed on sessions that have already ended — the money being chased.
  final double owedFromExits;

  /// Running total on cars still inside. Not due yet, so never mixed into
  /// [owedFromExits].
  final double runningTab;

  /// Billed and collected across the period's *finished* sessions, which is
  /// the only fair basis for a collection rate — a car still inside has not
  /// failed to pay.
  final double billedOnExits;
  final double collectedOnExits;

  /// Mean stay of the finished sessions, in minutes.
  final double averageStayMinutes;

  final List<ReportBucket> buckets;
  final List<HourLoad> busiestHours;

  /// Busiest day of the week over the period. Null for a single-day window,
  /// where it would only name that day back at you.
  final String? busiestWeekday;

  final List<VehicleVisits> topVehicles;

  /// Live, from the active endpoint — not derived from the period.
  final int parkedNow;
  final int capacity;

  const ReportSummary({
    required this.window,
    required this.revenueSource,
    required this.revenue,
    required this.previousRevenue,
    required this.entries,
    required this.vehicles,
    required this.settledPayments,
    required this.autoPayEntries,
    required this.owedFromExits,
    required this.runningTab,
    required this.billedOnExits,
    required this.collectedOnExits,
    required this.averageStayMinutes,
    required this.buckets,
    required this.busiestHours,
    required this.busiestWeekday,
    required this.topVehicles,
    required this.parkedNow,
    required this.capacity,
  });

  bool get hasActivity => entries > 0 || revenue > 0;

  int get repeatVisits => entries - vehicles < 0 ? 0 : entries - vehicles;

  double get averagePayment =>
      settledPayments == 0 ? 0 : revenue / settledPayments;

  double get revenuePerVehicle => vehicles == 0 ? 0 : revenue / vehicles;

  double get revenuePerDay => revenue / window.days;

  double get autoPayShare => entries == 0 ? 0 : autoPayEntries / entries;

  /// Share of what finished sessions were billed that has actually been
  /// collected. One when nothing was billed — nothing is outstanding.
  double get collectionRate {
    if (billedOnExits <= 0) return 1;
    return (collectedOnExits / billedOnExits).clamp(0.0, 1.0);
  }

  /// Growth against the previous period. Null when there is nothing to compare
  /// against, which the screen says rather than printing a fake 100%.
  double? get revenueChange {
    if (previousRevenue <= 0) return null;
    return (revenue - previousRevenue) / previousRevenue;
  }

  double get occupancyRatio {
    if (capacity <= 0) return 0;
    return (parkedNow / capacity).clamp(0.0, 1.0);
  }

  int get freeSpaces {
    if (capacity <= 0) return 0;
    return (capacity - parkedNow).clamp(0, capacity);
  }

  ReportBucket? get bestBucket {
    ReportBucket? best;
    for (final bucket in buckets) {
      if (best == null || bucket.revenue > best.revenue) best = bucket;
    }
    return best == null || best.revenue <= 0 ? null : best;
  }

  double get peakBucketRevenue {
    var peak = 0.0;
    for (final bucket in buckets) {
      if (bucket.revenue > peak) peak = bucket.revenue;
    }
    return peak;
  }

  @override
  List<Object?> get props => [
        window,
        revenueSource,
        revenue,
        previousRevenue,
        entries,
        vehicles,
        settledPayments,
        autoPayEntries,
        owedFromExits,
        runningTab,
        billedOnExits,
        collectedOnExits,
        averageStayMinutes,
        buckets,
        busiestHours,
        busiestWeekday,
        topVehicles,
        parkedNow,
        capacity,
      ];
}

/// Slices the site's whole history down to one period's figures.
///
/// Pure on purpose: [sessions] and [payments] are the full lists the manager
/// endpoints returned — neither endpoint takes a date filter — and every
/// number the reports screen shows falls out of this one function.
ReportSummary buildReport({
  required ReportWindow window,
  required List<ParkingSession> sessions,
  required List<PaymentTransaction> payments,
  List<ParkingSession> activeSessions = const [],
  ManagerRevenueSource revenueSource = ManagerRevenueSource.payments,
  int capacity = 0,
  DateTime? now,
}) {
  final moment = (now ?? DateTime.now()).toLocal();
  final previous = window.previous;

  final inWindow = <ParkingSession>[];
  for (final session in sessions) {
    if (window.contains(session.startTime)) inWindow.add(session);
  }

  final plates = <String>{};
  var autoPayEntries = 0;
  var owedFromExits = 0.0;
  var runningTab = 0.0;
  var billedOnExits = 0.0;
  var collectedOnExits = 0.0;
  var stayMinutesTotal = 0.0;
  var finishedCount = 0;
  var sessionRevenue = 0.0;
  final entriesByHour = <int, int>{};
  final entriesByWeekday = <int, int>{};
  final visitsByPlate = <String, VehicleVisits>{};

  for (final session in inWindow) {
    final plate = Vehicle.plateKey(session.vehicle.plateNumber);
    if (plate.isNotEmpty) plates.add(plate);
    if (session.autoPayEnabled) autoPayEntries++;
    sessionRevenue += session.amountPaid;

    final startedAt = session.startTime.toLocal();
    entriesByHour[startedAt.hour] = (entriesByHour[startedAt.hour] ?? 0) + 1;
    entriesByWeekday[startedAt.weekday] =
        (entriesByWeekday[startedAt.weekday] ?? 0) + 1;

    if (plate.isNotEmpty) {
      final seen = visitsByPlate[plate];
      visitsByPlate[plate] = VehicleVisits(
        plate: session.vehicle.plateNumber.isEmpty
            ? plate
            : session.vehicle.plateNumber,
        visits: (seen?.visits ?? 0) + 1,
        spend: (seen?.spend ?? 0) + session.amountPaid,
      );
    }

    final owed = session.cost - session.amountPaid;
    if (session.isActive) {
      if (owed > 0) runningTab += owed;
      continue;
    }

    finishedCount++;
    billedOnExits += session.cost;
    collectedOnExits += session.amountPaid;
    if (owed > 0) owedFromExits += owed;

    final endedAt = session.endTime?.toLocal();
    final minutes = endedAt != null
        ? endedAt.difference(startedAt).inMinutes
        : (session.durationMinutes ?? 0);
    if (minutes > 0) stayMinutesTotal += minutes;
  }

  double settledIn(ReportWindow span) {
    var total = 0.0;
    for (final payment in payments) {
      final at = payment.createdAt;
      if (at == null || !payment.isSettled) continue;
      if (span.contains(at)) total += payment.amount;
    }
    return total;
  }

  int settledCountIn(ReportWindow span) {
    var count = 0;
    for (final payment in payments) {
      final at = payment.createdAt;
      if (at == null || !payment.isSettled) continue;
      if (span.contains(at)) count++;
    }
    return count;
  }

  double sessionRevenueIn(ReportWindow span) {
    var total = 0.0;
    for (final session in sessions) {
      if (span.contains(session.startTime)) total += session.amountPaid;
    }
    return total;
  }

  final fromPayments = revenueSource == ManagerRevenueSource.payments;
  final revenue = fromPayments ? settledIn(window) : sessionRevenue;
  final previousRevenue =
      fromPayments ? settledIn(previous) : sessionRevenueIn(previous);
  final settledPayments = fromPayments ? settledCountIn(window) : finishedCount;

  final buckets = _buildBuckets(
    window: window,
    sessions: inWindow,
    payments: payments,
    useSessionAmounts: !fromPayments,
    now: moment,
  );

  final busiestHours =
      entriesByHour.entries.map((e) => HourLoad(e.key, e.value)).toList()
        ..sort((a, b) => b.entries.compareTo(a.entries));

  final rankedVehicles = visitsByPlate.values.toList()
    ..sort((a, b) {
      final byVisits = b.visits.compareTo(a.visits);
      return byVisits != 0 ? byVisits : b.spend.compareTo(a.spend);
    });

  String? busiestWeekday;
  if (!window.isHourly && entriesByWeekday.isNotEmpty) {
    final ranked = entriesByWeekday.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    busiestWeekday = weekdayName(ranked.first.key);
  }

  return ReportSummary(
    window: window,
    revenueSource: revenueSource,
    revenue: revenue,
    previousRevenue: previousRevenue,
    entries: inWindow.length,
    vehicles: plates.length,
    settledPayments: settledPayments,
    autoPayEntries: autoPayEntries,
    owedFromExits: owedFromExits,
    runningTab: runningTab,
    billedOnExits: billedOnExits,
    collectedOnExits: collectedOnExits,
    averageStayMinutes:
        finishedCount == 0 ? 0 : stayMinutesTotal / finishedCount,
    buckets: buckets,
    busiestHours: busiestHours.take(3).toList(),
    busiestWeekday: busiestWeekday,
    // A single visit is not a "regular", and a list of one-time plates is just
    // the sessions list again.
    topVehicles: rankedVehicles.where((v) => v.visits > 1).take(5).toList(),
    parkedNow: activeSessions.length,
    capacity: capacity,
  );
}

/// One bar per hour on a single day, one per day on anything longer.
///
/// Buckets that have not happened yet are left off entirely — a day still in
/// the future drawn as a zero bar reads as a collapse in trade, not as a clock.
List<ReportBucket> _buildBuckets({
  required ReportWindow window,
  required List<ParkingSession> sessions,
  required List<PaymentTransaction> payments,
  required bool useSessionAmounts,
  required DateTime now,
}) {
  final hourly = window.isHourly;

  final starts = <DateTime>[];
  var cursor = window.start;
  while (cursor.isBefore(window.end)) {
    if (cursor.isAfter(now)) break;
    starts.add(cursor);
    cursor = hourly
        ? cursor.add(const Duration(hours: 1))
        : DateTime(cursor.year, cursor.month, cursor.day + 1);
  }
  if (starts.isEmpty) starts.add(window.start);

  final revenue = List<double>.filled(starts.length, 0);
  final entries = List<int>.filled(starts.length, 0);

  int? indexFor(DateTime moment) {
    final local = moment.toLocal();
    if (local.isBefore(window.start) || !local.isBefore(window.end)) return null;
    final index = hourly
        ? local.difference(window.start).inHours
        : DateTime(local.year, local.month, local.day)
            .difference(window.start)
            .inDays;
    if (index < 0 || index >= starts.length) return null;
    return index;
  }

  for (final session in sessions) {
    final index = indexFor(session.startTime);
    if (index != null) {
      entries[index]++;
      if (useSessionAmounts) revenue[index] += session.amountPaid;
    }
  }

  if (!useSessionAmounts) {
    for (final payment in payments) {
      final at = payment.createdAt;
      if (at == null || !payment.isSettled) continue;
      final index = indexFor(at);
      if (index != null) revenue[index] += payment.amount;
    }
  }

  return [
    for (var i = 0; i < starts.length; i++)
      ReportBucket(
        start: starts[i],
        label: hourly
            ? starts[i].hour.toString().padLeft(2, '0')
            : starts[i].day.toString(),
        fullLabel: hourly
            ? '${starts[i].hour.toString().padLeft(2, '0')}:00 – '
                '${((starts[i].hour + 1) % 24).toString().padLeft(2, '0')}:00'
            : '${weekdayName(starts[i].weekday).substring(0, 3)} '
                '${dayLabel(starts[i])}',
        revenue: revenue[i],
        entries: entries[i],
      ),
  ];
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

const _weekdays = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', //
  'Friday', 'Saturday', 'Sunday',
];

String dayLabel(DateTime moment, {bool withYear = false}) {
  final local = moment.toLocal();
  final base = '${local.day} ${_months[local.month - 1]}';
  return withYear ? '$base ${local.year}' : base;
}

String weekdayName(int weekday) => _weekdays[(weekday - 1) % 7];
