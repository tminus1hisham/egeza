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

    emit(state.copyWith(
      selectedLocationId: locationId,
      isLoading: true,
      todaySessions: const [],
      activeSessions: const [],
      todayPayments: const [],
      clearError: true,
    ));
    await refresh();
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
      emit(state.copyWith(
        isLoading: false,
        todaySessions: _todaySessions(
          snapshot.sessions,
          snapshot.activeSessions,
        ),
        activeSessions: snapshot.activeSessions,
        todayPayments: _todayPayments(snapshot.payments),
        revenueSource: ManagerRevenueSource.payments,
        lastUpdated: DateTime.now(),
        clearError: true,
      ));
      return;
    }

    if (!_api.hasToken) return;

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
      revenueSource: payments == null
          ? ManagerRevenueSource.sessions
          : ManagerRevenueSource.payments,
      lastUpdated: DateTime.now(),
      clearError: true,
    ));
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
  /// There is no "list my locations" endpoint for a manager, so the sites are
  /// found by asking each public location for its active sessions: the
  /// `/manager/*` routes 403 for anything the user is not assigned to, which
  /// makes a successful call the assignment check.
  Future<List<ParkingLocation>> _resolveManagedLocations() async {
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
