import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../blocs/app_bloc.dart';
import '../../blocs/app_event.dart';
import '../../blocs/app_state.dart';
import '../../core/theme/app_colors.dart';
import '../../models/parking_session.dart';
import '../../models/vehicle.dart';
import '../../widgets/app_widgets.dart';

/// One registered plate: what it is, whether it is parked right now, how it is
/// configured, and where it has been.
///
/// The order is deliberate. A live session is time-sensitive and costs money,
/// so it sits directly under the hero; AutoPay is a setting a driver touches
/// twice a year, so it drops into a settings group below it.
///
/// Every colour on this screen resolves through `context.colors`. The screen
/// used to carry five private constants and its own gradient, which is why it
/// was the only page in the dashboard that did not survive dark mode.
class VehicleDetailScreen extends StatefulWidget {
  final Vehicle vehicle;

  const VehicleDetailScreen({super.key, required this.vehicle});

  @override
  State<VehicleDetailScreen> createState() => _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends State<VehicleDetailScreen> {
  /// History is capped until the driver asks for the rest.
  static const _historyPreviewCount = 5;

  bool _showAllHistory = false;

  /// The AutoPay value the driver asked for, held only until the bloc confirms
  /// it. The switch renders this while in flight so it never sits mid-way, and
  /// the listener below drops it — reverting the switch — if the call fails.
  /// Nothing else on the screen keeps a local copy of server state.
  bool? _pendingAutoPay;

  @override
  Widget build(BuildContext context) {
    return AdaptiveStatusBar(
      child: Scaffold(
        backgroundColor: context.colors.pageGrey,
        body: SafeArea(
          bottom: false,
          child: BlocConsumer<AppBloc, AppState>(
            listenWhen: (previous, current) =>
                previous.vehicles != current.vehicles ||
                previous.errorMessage != current.errorMessage,
            listener: _onStateChanged,
            builder: (context, state) {
              final vehicle = _resolveVehicle(state);
              final sessions = _sessionsFor(state, vehicle);
              // Anything still owing gets the card, whether the car is inside
              // or already gone — an exited-unpaid session needs the Pay now
              // button more than a running one does.
              final active = sessions.where((s) => !s.isSettled).firstOrNull;

              // Settled sessions only. The hero's count and total are drawn
              // from this one list so the two numbers always reconcile — a
              // running session is money in progress, not money spent, and it
              // has its own card above.
              final settled = sessions.where((s) => s.isSettled).toList();

              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 34),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back stands on the page, not on the hero. Inside the
                    // gradient it read as decoration next to the eyebrow;
                    // out here it is the only control on its row.
                    const PageBackButton(),
                    const SizedBox(height: 4),
                    _hero(vehicle, sessions, settled),
                    if (active != null) ...[
                      const SizedBox(height: 18),
                      _liveSession(active, vehicle),
                    ],
                    const SizedBox(height: 22),
                    _setupGroup(vehicle),
                    const SizedBox(height: 22),
                    _history(settled),
                    const SizedBox(height: 22),
                    _removeButton(vehicle),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // HERO
  // ───────────────────────────────────────────────────────────────────────────

  Widget _hero(
    Vehicle vehicle,
    List<ParkingSession> sessions,
    List<ParkingSession> settled,
  ) {
    final spent = settled.fold<double>(0, (sum, s) => sum + s.cost);
    final autoPayOn = _pendingAutoPay ?? vehicle.autoPayEnabled;

    return PageHero(
      // The eyebrow names the page on every other screen. Here the car does —
      // the plate is what a driver recognises, so it takes the value line.
      eyebrow: _describe(vehicle),
      value: vehicle.plateNumber,
      valueLetterSpacing: 2.2,
      valueLeading: Container(
        width: 6,
        height: 30,
        decoration: BoxDecoration(
          color: context.colors.plateYellow,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      pill: PageHeroPill(
        icon: autoPayOn ? Icons.bolt_rounded : Icons.account_balance_wallet_outlined,
        label: autoPayOn ? 'AutoPay on' : 'AutoPay off',
      ),
      metrics: [
        PageHeroMetric('Sessions', '${settled.length}'),
        PageHeroMetric('Spent', 'KES ${_money(spent)}'),
        PageHeroMetric('Last seen', _lastSeenLabel(sessions)),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // LIVE SESSION
  // ───────────────────────────────────────────────────────────────────────────

  /// Only built when the plate is parked. Leads with the running total, since
  /// that is the number the driver opened the screen to check.
  Widget _liveSession(ParkingSession session, Vehicle vehicle) {
    final autoPayOn = _pendingAutoPay ?? vehicle.autoPayEnabled;
    // The car has left and the fee wasn't collected: same card, but it's a
    // bill now, not a meter, so the green "Parked now" framing would lie.
    final due = session.isAwaitingPayment;
    final tone = due ? context.colors.warning : context.colors.success;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: due ? tone.withValues(alpha: 0.45) : context.colors.mintBorder,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: tone.withValues(alpha: 0.14),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
            color: due
                ? tone.withValues(alpha: 0.12)
                : context.colors.successLight,
            child: Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    '${due ? 'Payment due' : 'Parked now'} · '
                    '${session.locationName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: tone,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _durationLabel(session),
                  style: GoogleFonts.poppins(
                    color: tone,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            due ? 'Amount due' : 'Running total',
                            style: GoogleFonts.poppins(
                              color: context.colors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'KES ${_money(session.cost)}',
                            style: GoogleFonts.poppins(
                              color: context.colors.textPrimary,
                              fontSize: 26,
                              height: 1.1,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Entered',
                          style: GoogleFonts.poppins(
                            color: context.colors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _timeLabel(session.startTime),
                          style: GoogleFonts.poppins(
                            color: context.colors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => context
                        .read<AppBloc>()
                        .add(PayParkingSession(sessionId: session.id)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.colors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      textStyle: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('Pay now'),
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  // Each state describes itself. The old copy told drivers with
                  // AutoPay off that they would be charged automatically.
                  due
                      ? 'This exit was not paid for — settle it here'
                      : autoPayOn
                          ? 'AutoPay will charge this at the barrier'
                          : 'Pay here or at the exit barrier',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: context.colors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // SETUP
  // ───────────────────────────────────────────────────────────────────────────

  /// AutoPay plus the vehicle's registered facts, in one grouped card.
  ///
  /// The three fact rows are read-only on purpose: the API exposes no vehicle
  /// update endpoint (`/vehicles/{id}` is DELETE only), so a chevron here would
  /// promise an edit screen that cannot exist yet. Getting the details right at
  /// registration is handled in the add sheet instead.
  Widget _setupGroup(Vehicle vehicle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Vehicle setup'),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: context.colors.border),
          ),
          child: Column(
            children: [
              _autoPayRow(vehicle),
              _rowDivider(),
              _factRow('Vehicle type', vehicle.type),
              _rowDivider(),
              _factRow('Make & model', _makeAndModel(vehicle)),
              _rowDivider(),
              _factRow('Plate number', vehicle.plateNumber),
            ],
          ),
        ),
      ],
    );
  }

  Widget _autoPayRow(Vehicle vehicle) {
    final on = _pendingAutoPay ?? vehicle.autoPayEnabled;
    final inFlight = _pendingAutoPay != null;

    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: on ? context.colors.accentLight : context.colors.surfaceRaised,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.colors.border.withValues(alpha: 0.6)),
          ),
          child: Icon(
            Icons.bolt_rounded,
            color: on ? context.colors.primary : context.colors.textMuted,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AutoPay',
                style: GoogleFonts.poppins(
                  color: context.colors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                on
                    ? 'Charged at the barrier when you exit'
                    : 'You pay for each session yourself',
                style: GoogleFonts.poppins(
                  color: context.colors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Transform.scale(
          scale: 0.85,
          child: Switch(
            value: on,
            activeThumbColor: Colors.white,
            activeTrackColor: context.colors.primary,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: context.colors.inputBorder,
            trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
            // Locked while the change is in flight, so a second tap cannot
            // queue a request that contradicts the first.
            onChanged: inFlight ? null : (value) => _setAutoPay(vehicle, value),
          ),
        ),
      ],
    );
  }

  Widget _factRow(String label, String value) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              color: context.colors.textPrimary,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: GoogleFonts.poppins(
              color: context.colors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _rowDivider() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Container(height: 1, color: context.colors.divider),
      );

  void _setAutoPay(Vehicle vehicle, bool enabled) {
    setState(() => _pendingAutoPay = enabled);
    context.read<AppBloc>().add(
          SetVehicleAutoPay(
            vehicleId: vehicle.id,
            plateNumber: vehicle.plateNumber,
            enabled: enabled,
          ),
        );
  }

  /// Resolves the pending toggle once the bloc has spoken. A confirmed change
  /// arrives as a new vehicle list; a failure arrives as an error message, and
  /// dropping the pending value snaps the switch back to what the server holds.
  void _onStateChanged(BuildContext context, AppState state) {
    final pending = _pendingAutoPay;
    if (pending == null) return;

    if (_resolveVehicle(state).autoPayEnabled == pending) {
      setState(() => _pendingAutoPay = null);
      return;
    }

    if (state.errorMessage != null) {
      setState(() => _pendingAutoPay = null);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: context.colors.error,
            content: Text(
              'AutoPay unchanged — ${state.errorMessage}',
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.white),
            ),
          ),
        );
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // HISTORY
  // ───────────────────────────────────────────────────────────────────────────

  /// Settled sessions only — the live one has its own card, so it is not
  /// listed twice, and the count here matches the hero's.
  Widget _history(List<ParkingSession> settled) {
    final capped = _showAllHistory || settled.length <= _historyPreviewCount;
    final shown = capped ? settled : settled.take(_historyPreviewCount).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _sectionLabel('Parking history')),
            if (settled.length > _historyPreviewCount)
              GestureDetector(
                onTap: () => setState(() => _showAllHistory = !_showAllHistory),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Text(
                    _showAllHistory ? 'Show less' : 'View all ${settled.length}',
                    style: GoogleFonts.poppins(
                      color: context.colors.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (shown.isEmpty) _historyEmpty() else _historyList(shown),
      ],
    );
  }

  Widget _historyList(List<ParkingSession> sessions) {
    // Sessions arrive newest-first from the bloc's merge, so walking them in
    // order emits each month's header exactly once.
    String? lastGroup;
    final children = <Widget>[];

    for (final session in sessions) {
      final group = _monthLabel(session.startTime);
      if (group != lastGroup) {
        children.add(
          Padding(
            padding: EdgeInsets.only(top: lastGroup == null ? 0 : 16, bottom: 10),
            child: Text(
              group,
              style: GoogleFonts.poppins(
                color: context.colors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.9,
              ),
            ),
          ),
        );
        lastGroup = group;
      } else {
        children.add(_rowDivider());
      }
      children.add(_historyRow(session));
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _historyRow(ParkingSession session) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                session.locationName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  color: context.colors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                // Real times, from the session itself. This line used to hold a
                // floor and bay number invented by string-matching the location
                // name — data the API never sent.
                _sessionTimeRange(session),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  color: context.colors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'KES ${_money(session.cost)}',
              style: GoogleFonts.poppins(
                color: context.colors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _durationLabel(session),
              style: GoogleFonts.poppins(
                color: context.colors.textMuted,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _historyEmpty() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 24),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: context.colors.surfaceRaised,
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: context.colors.border),
            ),
            child: Icon(
              Icons.history_rounded,
              color: context.colors.textMuted,
              size: 24,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'No sessions yet',
            style: GoogleFonts.poppins(
              color: context.colors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Parking history will appear here',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: context.colors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // REMOVE
  // ───────────────────────────────────────────────────────────────────────────

  /// Quiet at rest. Destructive weight belongs in the confirmation, not in a
  /// red card competing with the settings above it.
  Widget _removeButton(Vehicle vehicle) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () => _confirmRemove(vehicle),
        style: OutlinedButton.styleFrom(
          foregroundColor: context.colors.error,
          side: BorderSide(color: context.colors.border),
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: const Text('Remove this vehicle'),
      ),
    );
  }

  void _confirmRemove(Vehicle vehicle) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Remove ${vehicle.plateNumber}?',
          style: GoogleFonts.poppins(
            color: context.colors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        content: Text(
          'The plate stops being recognised at barriers and AutoPay will no '
          'longer cover it. Past sessions stay in your history.',
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: context.colors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Keep it',
              style: GoogleFonts.poppins(
                color: context.colors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              context.read<AppBloc>().add(
                    RemoveVehicle(
                      vehicleId: vehicle.id,
                      plateNumber: vehicle.plateNumber,
                    ),
                  );
              Navigator.pop(dialogContext);
              Navigator.pop(context);
            },
            child: Text(
              'Remove',
              style: GoogleFonts.poppins(
                color: context.colors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // SHARED
  // ───────────────────────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        color: context.colors.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  /// The vehicle as the bloc currently holds it, so the AutoPay switch reads
  /// server state rather than a copy taken when the route was pushed. Falls
  /// back to the pushed vehicle while the list is loading, or after removal.
  Vehicle _resolveVehicle(AppState state) {
    final key = Vehicle.plateKey(widget.vehicle.plateNumber);
    for (final vehicle in state.vehicles) {
      if (Vehicle.plateKey(vehicle.plateNumber) == key) return vehicle;
    }
    return widget.vehicle;
  }

  List<ParkingSession> _sessionsFor(AppState state, Vehicle vehicle) {
    final key = Vehicle.plateKey(vehicle.plateNumber);
    return state.recentSessions
        .where((s) => Vehicle.plateKey(s.vehicle.plateNumber) == key)
        .toList();
  }

  String _describe(Vehicle vehicle) {
    final name = _makeAndModel(vehicle);
    final type = vehicle.type.trim();
    if (type.isEmpty) return name;
    return '$name · $type';
  }

  String _makeAndModel(Vehicle vehicle) {
    final parts = [vehicle.make.trim(), vehicle.model.trim()]
        .where((part) => part.isNotEmpty);
    return parts.isEmpty ? 'Unnamed vehicle' : parts.join(' ');
  }

  String _lastSeenLabel(List<ParkingSession> sessions) {
    if (sessions.isEmpty) return 'Never';
    var latest = sessions.first.startTime;
    for (final session in sessions) {
      if (session.startTime.isAfter(latest)) latest = session.startTime;
    }
    return _dateLabel(latest);
  }

  String _money(double amount) {
    final digits = amount.abs().round().toString();
    final buffer = StringBuffer(amount < 0 ? '-' : '');
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  /// Treat naive (non-UTC) datetimes from the API as UTC.
  DateTime _asUtc(DateTime dt) => dt.isUtc
      ? dt
      : DateTime.utc(dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second);

  DateTime _toEat(DateTime dt) => _asUtc(dt).add(const Duration(hours: 3));

  String _durationLabel(ParkingSession session) {
    final start = _asUtc(session.startTime);
    final end = session.endTime != null
        ? _asUtc(session.endTime!)
        : DateTime.now().toUtc();
    final duration = end.difference(start);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    if (duration.isNegative || (hours <= 0 && minutes <= 0)) return '0m';
    if (hours <= 0) return '${minutes}m';
    if (minutes <= 0) return '${hours}h';
    return '${hours}h ${minutes}m';
  }

  String _timeLabel(DateTime dateTime) {
    final eat = _toEat(dateTime);
    final hour = eat.hour == 0
        ? 12
        : eat.hour > 12
            ? eat.hour - 12
            : eat.hour;
    final minute = eat.minute.toString().padLeft(2, '0');
    final period = eat.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _clock(DateTime dateTime) {
    final eat = _toEat(dateTime);
    return '${eat.hour.toString().padLeft(2, '0')}:'
        '${eat.minute.toString().padLeft(2, '0')}';
  }

  String _sessionTimeRange(ParkingSession session) {
    final day = '${_toEat(session.startTime).day} '
        '${_months[_toEat(session.startTime).month - 1]}';
    if (session.endTime == null) return '$day · from ${_clock(session.startTime)}';
    return '$day · ${_clock(session.startTime)} → ${_clock(session.endTime!)}';
  }

  String _monthLabel(DateTime dateTime) {
    final eat = _toEat(dateTime);
    final month = _months[eat.month - 1].toUpperCase();
    return eat.year == DateTime.now().year ? month : '$month ${eat.year}';
  }

  String _dateLabel(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sessionDay = DateTime(dateTime.year, dateTime.month, dateTime.day);
    final diff = today.difference(sessionDay).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '${diff}d ago';
    return '${dateTime.day} ${_months[dateTime.month - 1]}';
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
}
