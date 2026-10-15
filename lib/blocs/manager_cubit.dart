import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/api/parking_iq_api.dart';
import '../core/error_handler.dart';
import '../models/api_models.dart';
import '../models/parking_session.dart';
import 'manager_sample_data.dart';
import 'manager_state.dart';

/// Drives the manager view: one parking site, three live numbers.
///
/// Deliberately its own controller rather than more surface on [AppBloc] — the
/// polling here is location-scoped and only runs while the screen is open, and
/// none of it belongs to the driver-facing app state.
class ManagerCubit extends Cubit<ManagerState> {
  final ParkingIqApi _api;

  /// Debug only: serve a generated day instead of calling the API at all, so
  /// the view can be looked at without a manager account behind it. Never
  /// blends with live data — it replaces it wholesale, and the state carries
  /// `isSample` so the screen can say which it is showing.
  final bool useSampleData;

  Timer? _timer;
  bool _pollInFlight = false;

  /// Set once the sites were resolved from `/client/locations`: this account is
  /// the property's OWNER, not one of its managers, and the `/manager/*` routes
  /// 403 for it. Its figures have to come from the `/client/*` endpoints — see
  /// [_refreshFromClientEndpoints].
  bool _clientScoped = false;

  /// The window `/client/reports/*` was last read for. Kept so switching back
  /// to a period already in hand costs nothing, and so a 15s poll does not
  /// refetch a month of history it already has.
  String? _loadedPeriodKey;

  ManagerCubit({required ParkingIqApi api, this.useSampleData = false})
      : _api = api,
        super(ManagerState(isSample: useSampleData));

  /// How often the numbers refresh. Sessions are opened by the gate cameras and
  /// payments land via the M-Pesa callback, so — as everywhere else in this app
  /// — there is nothing to subscribe to and the screen has to go looking.
  static const defaultInterval = Duration(seconds: 15);

  /// Resolves which locations this user may manage, then loads the first one
  /// and starts the refresh loop. Safe to call again; the loop is restarted
  /// rather than duplicated.
  Future<void> start({Duration interval = defaultInterval}) async {
    _timer?.cancel();

    if (useSampleData) {
      emit(state.copyWith(
        locations: ManagerSampleData.locations,
        selectedLocationId:
            state.selectedLocationId ?? ManagerSampleData.locations.first.id,
        hasNoAssignments: false,
        clearError: true,
      ));
      await refresh();
      if (isClosed) return;
      _timer = Timer.periodic(interval, (_) => _poll());
      return;
    }

    if (!_api.hasToken) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Sign in again to open the manager view',
      ));
      return;
    }

    if (state.locations.isEmpty) {
      final resolved = await _resolveManagedLocations();
      if (isClosed) return;

      if (resolved.isEmpty) {
        emit(state.copyWith(isLoading: false, hasNoAssignments: true));
        return;
      }

      emit(state.copyWith(
        locations: resolved,
        selectedLocationId: state.selectedLocationId ?? resolved.first.id,
        hasNoAssignments: false,
        clearError: true,
      ));
    }

    await refresh();
    if (isClosed) return;

    _timer = Timer.periodic(interval, (_) => _poll());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> selectLocation(String locationId) async {
    if (locationId == state.selectedLocationId) return;

    _loadedPeriodKey = null;

    emit(state.copyWith(
      selectedLocationId: locationId,
      isLoading: true,
      todaySessions: const [],
      activeSessions: const [],
      todayPayments: const [],
      historySessions: const [],
      historyPayments: const [],
      clearError: true,
    ));
    await refresh();
  }

  /// Switches the period the reports read.
  ///
  /// On the manager side nothing is refetched — those endpoints take no dates
  /// and have already handed over the site's whole record. An owner's period
  /// comes from `/client/reports/*`, which does filter by date, so the new
  /// window is fetched — see [_loadClientPeriod].
  void selectRange(ReportRange range) {
    if (range == state.range && range != ReportRange.custom) return;
    emit(state.copyWith(range: range));
    unawaited(_loadClientPeriod());
  }

  /// Applies a picked pair of dates. Order does not matter; the window sorts
  /// them and covers both days in full.
  void selectCustomRange(DateTime start, DateTime end) {
    emit(state.copyWith(
      range: ReportRange.custom,
      customStart: start,
      customEnd: end,
    ));
    unawaited(_loadClientPeriod());
  }

  /// One pass over the selected location's sessions and payments.
  Future<void> refresh() async {
    final locationId = state.selectedLocationId;
    if (locationId == null) return;

    if (useSampleData) {
      // Regenerated each pass on purpose: the schedule is fixed, so the day
      // only ever moves forward — cars whose stay has run out exit and their
      // payment joins the takings while the screen is open.
      final snapshot = ManagerSampleData.forLocation(locationId);
      // The weeks behind today are generated once and cached, so only the
      // current day is redrawn on a poll.
      final past = ManagerSampleData.historyFor(locationId);
      emit(state.copyWith(
        isLoading: false,
        todaySessions: _todaySessions(
          snapshot.sessions,
          snapshot.activeSessions,
        ),
        activeSessions: snapshot.activeSessions,
        todayPayments: _todayPayments(snapshot.payments),
        historySessions: [...snapshot.sessions, ...past.sessions],
        historyPayments: [...snapshot.payments, ...past.payments],
        revenueSource: ManagerRevenueSource.payments,
        lastUpdated: DateTime.now(),
        clearError: true,
      ));
      return;
    }

    if (!_api.hasToken) return;

    if (_clientScoped) {
      await _refreshFromClientEndpoints(locationId);
      return;
    }

    var failures = 0;

    final sessionsFuture = _api
        .managerLocationSessions(locationId)
        .then<Object?>((value) => value)
        .catchError((Object error, StackTrace st) {
      failures++;
      _logError('refresh/sessions', error, st);
      return null;
    });
    final activeFuture = _api
        .managerActiveLocationSessions(locationId)
        .then<Object?>((value) => value)
        .catchError((Object error, StackTrace st) {
      failures++;
      _logError('refresh/activeSessions', error, st);
      return null;
    });
    final paymentsFuture = _api
        .managerLocationPayments(locationId)
        .then<Object?>((value) => value)
        .catchError((Object error, StackTrace st) {
      failures++;
      _logError('refresh/payments', error, st);
      return null;
    });

    final results = await Future.wait([
      sessionsFuture,
      activeFuture,
      paymentsFuture,
    ]);
    if (isClosed) return;

    final allSessions = results[0] is List<ParkingSession>
        ? results[0] as List<ParkingSession>
        : null;
    final activeSessions = results[1] is List<ParkingSession>
        ? results[1] as List<ParkingSession>
        : null;
    final payments = results[2] is List<PaymentTransaction>
        ? results[2] as List<PaymentTransaction>
        : null;

    // Every call failed — keep whatever is on screen and say so rather than
    // blanking a manager's numbers because one poll could not reach the API.
    if (failures == 3) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: state.hasData
            ? 'Could not refresh — showing the last known figures'
            : 'Could not load this location',
      ));
      return;
    }

    final effectiveActive = activeSessions ?? state.activeSessions;
    final todaySessions = allSessions == null
        ? state.todaySessions
        : _todaySessions(allSessions, effectiveActive);

    emit(state.copyWith(
      isLoading: false,
      todaySessions: todaySessions,
      activeSessions: effectiveActive,
      todayPayments:
          payments == null ? state.todayPayments : _todayPayments(payments),
      // Kept whole for the reports and the sessions list, which pick their own
      // period out of it. A failed call leaves the last good record in place.
      historySessions: allSessions == null
          ? state.historySessions
          : _mergedHistory(allSessions, effectiveActive),
      historyPayments: payments ?? state.historyPayments,
      revenueSource: payments == null
          ? ManagerRevenueSource.sessions
          : ManagerRevenueSource.payments,
      lastUpdated: DateTime.now(),
      clearError: true,
    ));
  }

  /// The owner's pass over the same three numbers.
  ///
  /// `/client/sessions` and `/client/transactions/payments` are estate-wide and
  /// take no parameters, so both lists are filtered here to the selected site.
  /// There is no client equivalent of the manager's active-sessions endpoint;
  /// a car that has not left is one with no exit time, which — unlike
  /// [ParkingSession.isActive] — stays true for a car that has already paid but
  /// is still on the ground.
  Future<void> _refreshFromClientEndpoints(String locationId) async {
    final location = state.locations.where((l) => l.id == locationId).firstOrNull;

    var failures = 0;
    final sessionsFuture = _api
        .clientSessions()
        .then<Object?>((value) => value)
        .catchError((Object error, StackTrace st) {
      failures++;
      _logError('refresh/clientSessions', error, st);
      return null;
    });
    final paymentsFuture = _api
        .clientPayments()
        .then<Object?>((value) => value)
        .catchError((Object error, StackTrace st) {
      failures++;
      _logError('refresh/clientPayments', error, st);
      return null;
    });

    final results = await Future.wait([sessionsFuture, paymentsFuture]);
    if (isClosed) return;

    final allSessions = results[0] is List<ParkingSession>
        ? _sessionsAt(results[0] as List<ParkingSession>, locationId, location)
        : null;
    final payments = results[1] is List<PaymentTransaction>
        ? _paymentsAt(results[1] as List<PaymentTransaction>)
        : null;

    if (failures == 2) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: state.hasData
            ? 'Could not refresh — showing the last known figures'
            : 'Could not load this location',
      ));
      return;
    }

    final activeSessions = allSessions == null
        ? state.activeSessions
        : allSessions.where((s) => s.endTime == null).toList(growable: false);

    emit(state.copyWith(
      isLoading: false,
      todaySessions: allSessions == null
          ? state.todaySessions
          : _todaySessions(allSessions, activeSessions),
      activeSessions: activeSessions,
      todayPayments:
          payments == null ? state.todayPayments : _todayPayments(payments),
      // The live lists are all-time already; the ranged period rows are merged
      // in rather than dropped, so a window that reaches further back than the
      // list survives the next poll.
      historySessions: allSessions == null
          ? state.historySessions
          : _dedupedSessions([
              ..._mergedHistory(allSessions, activeSessions),
              ...state.historySessions,
            ]),
      historyPayments: payments == null
          ? state.historyPayments
          : _dedupedPayments([...payments, ...state.historyPayments]),
      revenueSource: payments == null
          ? ManagerRevenueSource.sessions
          : ManagerRevenueSource.payments,
      lastUpdated: DateTime.now(),
      clearError: true,
    ));

    await _loadClientPeriod();
  }

  /// Loads the selected period from the ranged report endpoints and folds it
  /// into the record the screens slice.
  ///
  /// Covers the comparison period as well as the selected one, because every
  /// reports figure is shown "vs previous". Only the owner path has this: no
  /// `/manager/*` route takes a date, so a manager's history stays whatever the
  /// unfiltered lists returned.
  Future<void> _loadClientPeriod({bool force = false}) async {
    if (!_clientScoped || useSampleData || isClosed) return;
    if (!_api.hasToken || state.selectedLocationId == null) return;

    final window = state.window;
    final start = window.previous.start;
    final end = window.end;
    final key = '${start.toIso8601String()}|${end.toIso8601String()}';
    if (!force && key == _loadedPeriodKey) return;

    final results = await Future.wait([
      _api
          .clientSessionReport(start: start, end: end)
          .then<Object?>((value) => value)
          .catchError((Object error, StackTrace st) {
        _logError('period/sessions', error, st);
        return null;
      }),
      _api
          .clientPaymentReport(start: start, end: end)
          .then<Object?>((value) => value)
          .catchError((Object error, StackTrace st) {
        _logError('period/payments', error, st);
        return null;
      }),
    ]);
    if (isClosed) return;

    final sessions = results[0] is List<ParkingSession>
        ? _sessionsAt(
            results[0] as List<ParkingSession>,
            state.selectedLocationId!,
            state.selectedLocation,
          )
        : null;
    final payments = results[1] is List<PaymentTransaction>
        ? _paymentsAt(results[1] as List<PaymentTransaction>)
        : null;

    if (sessions == null && payments == null) return;
    _loadedPeriodKey = key;

    emit(state.copyWith(
      // Merged rather than replaced: the ranged calls filter sessions on entry
      // time, so a car that drove in before this window and is still parked is
      // not in them — and it is still one of this site's cars.
      historySessions: sessions == null
          ? state.historySessions
          : _dedupedSessions([...sessions, ...state.historySessions]),
      historyPayments: payments == null
          ? state.historyPayments
          : _dedupedPayments([...payments, ...state.historyPayments]),
    ));
  }

  List<ParkingSession> _dedupedSessions(List<ParkingSession> sessions) {
    final seen = <String>{};
    return [
      for (final session in sessions)
        if (session.id.isEmpty || seen.add(session.id)) session,
    ]..sort((a, b) => b.startTime.compareTo(a.startTime));
  }

  List<PaymentTransaction> _dedupedPayments(List<PaymentTransaction> payments) {
    final seen = <String>{};
    return [
      for (final payment in payments)
        if (payment.id.isEmpty || seen.add(payment.id)) payment,
    ];
  }

  List<PaymentTransaction> _paymentsAt(List<PaymentTransaction> payments) {
    final locationId = state.selectedLocationId;
    if (state.locations.length < 2 || locationId == null) return payments;
    return payments
        .where((p) =>
            p.locationId == null ||
            p.locationId!.isEmpty ||
            p.locationId == locationId)
        .toList(growable: false);
  }

  /// The estate-wide list narrowed to one site. Sessions name their location by
  /// id when a gate is attached and by name otherwise, so both are accepted; a
  /// session that names neither is kept rather than dropped from the owner's
  /// own figures.
  List<ParkingSession> _sessionsAt(
    List<ParkingSession> sessions,
    String locationId,
    ParkingLocation? location,
  ) {
    if (state.locations.length < 2) return sessions;
    final name = location?.name.trim().toLowerCase();
    return sessions.where((session) {
      final id = session.locationId;
      if (id != null && id.isNotEmpty) return id == locationId;
      if (name == null || name.isEmpty) return true;
      final sessionName = session.locationName.trim().toLowerCase();
      return sessionName.isEmpty ||
          sessionName == 'parking location' ||
          sessionName == name;
    }).toList(growable: false);
  }

  Future<void> _poll() async {
    if (isClosed || _pollInFlight) return;
    _pollInFlight = true;
    try {
      await refresh();
    } finally {
      _pollInFlight = false;
    }
  }

  /// Which sites this user actually manages.
  ///
  /// Two kinds of account reach this screen and the backend treats them
  /// differently. An OWNER (`CLIENT`/`PATNER`) owns the property and can list
  /// their sites outright — and is *not* assigned as a manager of them, so every
  /// `/manager/*` probe below 403s and would leave them with no property at all.
  /// Ask `/client/locations` first for that reason; only a MANAGER, for whom it
  /// 403s in turn, falls through to the probe.
  Future<List<ParkingLocation>> _resolveManagedLocations() async {
    try {
      final owned = await _api.clientLocations();
      if (owned.isNotEmpty) {
        _clientScoped = true;
        _log('resolved ${owned.length} owned location(s) from /client/locations');
        return owned;
      }
    } catch (error, st) {
      // 403 here is the ordinary answer for a manager account; anything else is
      // logged and still falls through to the probe, which may yet succeed.
      _logError('resolveManagedLocations/clientLocations', error, st);
    }

    final List<ParkingLocation> candidates;
    try {
      candidates = await _api.fetchParkingLocations();
    } catch (error, st) {
      _logError('resolveManagedLocations/fetchParkingLocations', error, st);
      if (!isClosed) {
        emit(state.copyWith(
          isLoading: false,
          errorMessage: ErrorHandler.toMessage(error),
        ));
      }
      return const [];
    }

    final probes = await Future.wait(
      candidates.map((location) async {
        try {
          await _api.managerActiveLocationSessions(location.id);
          return location;
        } catch (error) {
          if (error is ApiException &&
              (error.statusCode == 403 || error.statusCode == 401)) {
            return null;
          }
          // Anything else (network, 5xx) is not a "no access" answer. Keep the
          // location rather than silently hiding a site the manager runs.
          _log('probe ${location.name}: kept despite $error');
          return location;
        }
      }),
    );

    return [for (final location in probes) ?location];
  }

  /// The site's whole record, newest first, with the live list folded in.
  ///
  /// Same reason as [_todaySessions]: a session the gate opened moments ago can
  /// be missing from the full list while the active endpoint already has it.
  /// Deduped on session id so nothing is counted twice.
  List<ParkingSession> _mergedHistory(
    List<ParkingSession> allSessions,
    List<ParkingSession> activeSessions,
  ) {
    final byKey = <String, ParkingSession>{};
    var index = 0;

    for (final session in [...allSessions, ...activeSessions]) {
      final key = session.id.isNotEmpty ? session.id : 'row-${index++}';
      byKey.putIfAbsent(key, () => session);
    }

    return byKey.values.toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
  }

  /// Today's sessions, in the device's local day.
  ///
  /// The active list is folded in because a session the gate opened moments ago
  /// can be missing from the full list while the active endpoint already has
  /// it; dedupe on session id so it is never counted twice.
  List<ParkingSession> _todaySessions(
    List<ParkingSession> allSessions,
    List<ParkingSession> activeSessions,
  ) {
    final byKey = <String, ParkingSession>{};
    var index = 0;

    for (final session in [...allSessions, ...activeSessions]) {
      if (!_isToday(session.startTime)) continue;
      final key = session.id.isNotEmpty ? session.id : 'row-${index++}';
      byKey.putIfAbsent(key, () => session);
    }

    return byKey.values.toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
  }

  List<PaymentTransaction> _todayPayments(List<PaymentTransaction> payments) {
    return payments
        .where((payment) =>
            payment.createdAt != null && _isToday(payment.createdAt!))
        .toList()
      ..sort((a, b) => b.createdAt!.compareTo(a.createdAt!));
  }

  bool _isToday(DateTime moment) {
    final local = moment.toLocal();
    final now = DateTime.now();
    return local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
  }

  void _log(String message) {
    if (kDebugMode) dev.log(message, name: 'ManagerCubit');
  }

  void _logError(String handler, Object error, StackTrace st) {
    dev.log(
      '✗ $handler — $error',
      name: 'ManagerCubit',
      error: error,
      stackTrace: st,
    );
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    _timer = null;
    return super.close();
  }
}
