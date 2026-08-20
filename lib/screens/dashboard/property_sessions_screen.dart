import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../blocs/manager_cubit.dart';
import '../../blocs/manager_state.dart';
import '../../core/theme/app_colors.dart';
import '../../models/parking_session.dart';
import '../../models/vehicle.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/manager_widgets.dart';

/// Which sessions to show. The four beyond [all] are the questions an owner
/// actually asks: who is here, who pays without stopping, who owes me, who is
/// settled.
enum SessionStatusFilter { all, parkedNow, autoPay, unpaid, paid }

/// The period the list covers. Separate from the reports period on purpose —
/// a ledger wants an "All" option, and changing the filter on one screen must
/// not silently redraw the other.
enum SessionPeriod { today, week, month, all, custom }

/// A filter handed over from another screen, e.g. "show me the 43 parked now".
///
/// Deliberately without value equality: it is pushed through a [ValueNotifier],
/// and asking for the same filter twice has to arrive twice.
class PropertySessionsPreset {
  final SessionStatusFilter status;
  final SessionPeriod? period;

  const PropertySessionsPreset({
    this.status = SessionStatusFilter.all,
    this.period,
  });
}

/// Every vehicle that has used the property, not just the ones in this
/// account's garage.
///
/// This is the owner's version of the History tab: same place in the app, but
/// the rows are the site's sessions rather than the signed-in driver's.
class PropertySessionsScreen extends StatefulWidget {
  /// Filters pushed in from the reports screen.
  final ValueListenable<PropertySessionsPreset?>? preset;

  /// Opens the driver-side history for this account, which the owner loses the
  /// tab for. Null hides the control.
  final VoidCallback? onOpenMyActivity;

  const PropertySessionsScreen({
    super.key,
    this.preset,
    this.onOpenMyActivity,
  });

  @override
  State<PropertySessionsScreen> createState() => _PropertySessionsScreenState();
}

class _PropertySessionsScreenState extends State<PropertySessionsScreen> {
  SessionStatusFilter _status = SessionStatusFilter.all;
  SessionPeriod _period = SessionPeriod.today;
  DateTime? _customStart;
  DateTime? _customEnd;

  bool _searchOpen = false;
  final _searchController = TextEditingController();

  /// A busy site records thousands of sessions; the list grows a page at a
  /// time rather than building all of them into one scroll view.
  static const _pageSize = 25;
  int _visibleCount = _pageSize;

  @override
  void initState() {
    super.initState();
    widget.preset?.addListener(_applyPreset);
  }

  @override
  void didUpdateWidget(PropertySessionsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.preset != widget.preset) {
      oldWidget.preset?.removeListener(_applyPreset);
      widget.preset?.addListener(_applyPreset);
    }
  }

  @override
  void dispose() {
    widget.preset?.removeListener(_applyPreset);
    _searchController.dispose();
    super.dispose();
  }

  void _applyPreset() {
    final preset = widget.preset?.value;
    if (preset == null || !mounted) return;
    setState(() {
      _status = preset.status;
      if (preset.period != null) _period = preset.period!;
      _visibleCount = _pageSize;
      _searchController.clear();
      _searchOpen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveStatusBar(
      child: Scaffold(
        backgroundColor: context.colors.pageGrey,
        body: SafeArea(
          bottom: false,
          child: BlocBuilder<ManagerCubit, ManagerState>(
            builder: (context, state) {
              if (state.isLoading && !state.hasData) {
                return Center(
                  child:
                      CircularProgressIndicator(color: context.colors.primary),
                );
              }
              if (state.hasNoAssignments) {
                return _message(
                  icon: Icons.business_outlined,
                  title: 'No property yet',
                  body: 'This account is not attached to a parking location, so '
                      'there are no sessions to list.',
                );
              }
              if (!state.hasData && state.errorMessage != null) {
                return _message(
                  icon: Icons.cloud_off_rounded,
                  title: 'Could not load the sessions',
                  body: state.errorMessage!,
                  action: TextButton(
                    onPressed: () => context.read<ManagerCubit>().start(),
                    child: Text(
                      'Try again',
                      style: GoogleFonts.poppins(
                        color: context.colors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }

              final matches = _filtered(state);
              final shown = matches.take(_visibleCount).toList();

              return RefreshIndicator(
                color: context.colors.primary,
                onRefresh: () => context.read<ManagerCubit>().refresh(),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _hero(context, state, matches),
                      if (state.isSample) ...[
                        const SizedBox(height: 10),
                        const SampleDataBanner(),
                      ],
                      if (state.locations.length > 1) ...[
                        const SizedBox(height: 12),
                        _locationSwitcher(context, state),
                      ],
                      const SizedBox(height: 12),
                      _statusFilters(context),
                      if (_status != SessionStatusFilter.parkedNow) ...[
                        const SizedBox(height: 8),
                        _periodFilters(context),
                      ],
                      const SizedBox(height: 8),
                      _searchRow(context),
                      if (state.errorMessage != null) ...[
                        const SizedBox(height: 10),
                        StaleDataBanner(state.errorMessage!),
                      ],
                      const SizedBox(height: 14),
                      _caption(context, matches),
                      const SizedBox(height: 10),
                      if (shown.isEmpty)
                        EmptyStateCard(
                          icon: Icons.search_off_rounded,
                          title: 'No sessions match',
                          subtitle: _emptyHint(),
                        )
                      else ...[
                        ...shown.map(
                          (session) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _sessionRow(context, session),
                          ),
                        ),
                        if (matches.length > shown.length)
                          _showMore(context, matches.length - shown.length),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ── HEADER ────────────────────────────────────────────────────────────────

  Widget _hero(
    BuildContext context,
    ManagerState state,
    List<ParkingSession> matches,
  ) {
    var collected = 0.0;
    var owed = 0.0;
    final plates = <String>{};
    for (final session in matches) {
      collected += session.amountPaid;
      if (!session.isActive) {
        final due = session.cost - session.amountPaid;
        if (due > 0) owed += due;
      }
      final plate = Vehicle.plateKey(session.vehicle.plateNumber);
      if (plate.isNotEmpty) plates.add(plate);
    }

    final openMine = widget.onOpenMyActivity;

    return PageHero(
      eyebrow: '${state.locationName} · Sessions',
      value: '${matches.length}',
      trailing: openMine == null
          ? null
          : PageAction(
              icon: Icons.person_outline_rounded,
              tooltip: 'My own activity',
              onDark: true,
              onTap: openMine,
            ),
      pill: state.isSample
          ? const PageHeroPill(icon: Icons.science_outlined, label: 'Sample')
          : const PageHeroPill(icon: Icons.sensors_rounded, label: 'Live'),
      metrics: [
        PageHeroMetric('Vehicles', '${plates.length}'),
        PageHeroMetric('Collected', 'KES ${compactMoney(collected)}'),
        PageHeroMetric('Unpaid', 'KES ${compactMoney(owed)}'),
      ],
    );
  }

  Widget _locationSwitcher(BuildContext context, ManagerState state) {
    final index = state.locations
        .indexWhere((location) => location.id == state.selectedLocationId);
    return FilterPills(
      labels: [for (final location in state.locations) location.name],
      selectedIndex: index < 0 ? 0 : index,
      onSelected: (picked) {
        setState(() => _visibleCount = _pageSize);
        context.read<ManagerCubit>().selectLocation(state.locations[picked].id);
      },
    );
  }

  Widget _statusFilters(BuildContext context) {
    const order = SessionStatusFilter.values;
    return FilterPills(
      labels: const ['All', 'Parked now', 'AutoPay', 'Unpaid', 'Paid'],
      selectedIndex: order.indexOf(_status),
      onSelected: (index) => setState(() {
        _status = order[index];
        _visibleCount = _pageSize;
      }),
    );
  }

  Widget _periodFilters(BuildContext context) {
    const order = SessionPeriod.values;
    final customLabel = _period == SessionPeriod.custom && _customStart != null
        ? _customWindow()!.chipLabel
        : 'Pick dates';

    return FilterPills(
      labels: ['Today', '7 days', '30 days', 'All time', customLabel],
      selectedIndex: order.indexOf(_period),
      highlighted: const {4},
      onSelected: (index) {
        final picked = order[index];
        if (picked == SessionPeriod.custom) {
          _pickDates(context);
          return;
        }
        setState(() {
          _period = picked;
          _visibleCount = _pageSize;
        });
      },
    );
  }

  Future<void> _pickDates(BuildContext context) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(today.year - 2, today.month, today.day),
      lastDate: today,
      initialDateRange: DateTimeRange(
        start: _customStart ?? today.subtract(const Duration(days: 6)),
        end: _customEnd ?? today,
      ),
      helpText: 'Pick a period',
      saveText: 'Show',
    );
    if (range == null || !mounted) return;

    setState(() {
      _period = SessionPeriod.custom;
      _customStart = range.start;
      _customEnd = range.end;
      _visibleCount = _pageSize;
    });
  }

  Widget _searchRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            alignment: Alignment.centerLeft,
            child: _searchOpen
                ? TextField(
                    controller: _searchController,
                    autofocus: true,
                    textCapitalization: TextCapitalization.characters,
                    onChanged: (_) =>
                        setState(() => _visibleCount = _pageSize),
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: context.colors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Search a number plate...',
                      hintStyle: GoogleFonts.poppins(
                        color: context.colors.textMuted,
                        fontSize: 13,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: context.colors.textMuted,
                        size: 18,
                      ),
                      filled: true,
                      fillColor: context.colors.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: context.colors.inputBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: context.colors.inputBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: context.colors.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  )
                : Text(
                    'Find a vehicle by plate',
                    style: GoogleFonts.poppins(
                      color: context.colors.textMuted,
                      fontSize: 12,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 6),
        PageAction(
          icon: _searchOpen ? Icons.close_rounded : Icons.search_rounded,
          primary: _searchOpen,
          tooltip: _searchOpen ? 'Close search' : 'Search plates',
          compact: true,
          onTap: () => setState(() {
            _searchOpen = !_searchOpen;
            if (!_searchOpen) _searchController.clear();
            _visibleCount = _pageSize;
          }),
        ),
      ],
    );
  }

  Widget _caption(BuildContext context, List<ParkingSession> matches) {
    return Row(
      children: [
        Expanded(
          child: Text(
            _captionText(matches.length),
            style: GoogleFonts.poppins(
              color: context.colors.textSecondary,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  String _captionText(int count) {
    final noun = count == 1 ? 'session' : 'sessions';
    switch (_status) {
      case SessionStatusFilter.parkedNow:
        return '$count $noun on the ground right now. The period does not '
            'apply to cars that have not left.';
      case SessionStatusFilter.autoPay:
        return '$count AutoPay $noun ${_periodPhrase()}. These settle from the '
            'driver wallet without stopping at the gate.';
      case SessionStatusFilter.unpaid:
        return '$count unpaid $noun ${_periodPhrase()} — the car has left and '
            'the fee was never collected.';
      case SessionStatusFilter.paid:
        return '$count settled $noun ${_periodPhrase()}.';
      case SessionStatusFilter.all:
        return '$count $noun ${_periodPhrase()}, newest first.';
    }
  }

  String _periodPhrase() {
    switch (_period) {
      case SessionPeriod.today:
        return 'today';
      case SessionPeriod.week:
        return 'in the last 7 days';
      case SessionPeriod.month:
        return 'in the last 30 days';
      case SessionPeriod.all:
        return 'on record';
      case SessionPeriod.custom:
        final window = _customWindow();
        return window == null ? 'on record' : 'in ${window.label}';
    }
  }

  String _emptyHint() {
    if (_searchController.text.trim().isNotEmpty) {
      return 'No vehicle matching "${_searchController.text.trim()}" in this '
          'period. Try All time.';
    }
    switch (_status) {
      case SessionStatusFilter.parkedNow:
        return 'Nothing is on the ground. Vehicles appear here the moment the '
            'gate reads a plate.';
      case SessionStatusFilter.unpaid:
        return 'Nothing outstanding — every car that left this period paid.';
      case SessionStatusFilter.autoPay:
        return 'No AutoPay vehicle used the site in this period.';
      default:
        return 'Try a longer period, or clear the filter.';
    }
  }

  // ── LIST ──────────────────────────────────────────────────────────────────

  Widget _showMore(BuildContext context, int remaining) {
    return Center(
      child: TextButton(
        onPressed: () => setState(() => _visibleCount += _pageSize),
        child: Text(
          'Show ${remaining < _pageSize ? remaining : _pageSize} more '
          '($remaining left)',
          style: GoogleFonts.poppins(
            color: context.colors.primary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _sessionRow(BuildContext context, ParkingSession session) {
    final parked = session.isActive;
    final owed = session.cost - session.amountPaid;
    final unpaid = owed > 0.005;
    final now = DateTime.now();
    final endedAt = session.endTime ?? now;
    final minutes = parked
        ? now.difference(session.startTime).inMinutes
        : endedAt.difference(session.startTime).inMinutes;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
      decoration: BoxDecoration(
        color: context.colors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(child: PlateTag(session.vehicle.plateNumber)),
                      if (session.autoPayEnabled) ...[
                        const SizedBox(width: 6),
                        const ToneChip(
                          'AutoPay',
                          tone: ChipTone.brand,
                          icon: Icons.bolt_rounded,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    parked
                        ? 'In ${clockLabel(session.startTime)} · '
                            '${durationLabel(minutes)} so far'
                        : '${_dayPrefix(session.startTime, now)}'
                            '${clockLabel(session.startTime)} – '
                            '${clockLabel(endedAt)} · ${durationLabel(minutes)}',
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
            const SizedBox(width: 8),
            // The fee and the chip size themselves to their text, so on a
            // narrow phone a five-figure amount or an "Owes …" chip would run
            // off the card. Half the row is theirs; past that they wrap.
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth / 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'KES ${formatMoney(parked ? session.cost : session.amountPaid)}',
                    textAlign: TextAlign.end,
                    style: GoogleFonts.poppins(
                      color: context.colors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  ToneChip(
                    parked
                        ? (unpaid ? 'Parked' : 'Prepaid')
                        : (unpaid ? 'Owes ${formatMoney(owed)}' : 'Paid'),
                    tone: unpaid
                        ? (parked ? ChipTone.neutral : ChipTone.alert)
                        : ChipTone.good,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Only worth printing a date once the row is not from today.
  String _dayPrefix(DateTime start, DateTime now) {
    final local = start.toLocal();
    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      return '';
    }
    return '${dayLabel(local)} · ';
  }

  // ── FILTERING ─────────────────────────────────────────────────────────────

  ReportWindow? _customWindow() {
    if (_customStart == null) return null;
    return ReportWindow.of(
      ReportRange.custom,
      customStart: _customStart,
      customEnd: _customEnd,
    );
  }

  /// Null means no period filter at all — "All time".
  ReportWindow? _window() {
    switch (_period) {
      case SessionPeriod.today:
        return ReportWindow.of(ReportRange.today);
      case SessionPeriod.week:
        return ReportWindow.of(ReportRange.week);
      case SessionPeriod.month:
        return ReportWindow.of(ReportRange.month);
      case SessionPeriod.all:
        return null;
      case SessionPeriod.custom:
        return _customWindow();
    }
  }

  List<ParkingSession> _filtered(ManagerState state) {
    final query = Vehicle.plateKey(_searchController.text);

    // "Parked now" comes off the active endpoint rather than out of the
    // record: a prepaid car still on the ground is not flagged active in the
    // sessions list, and would vanish from a filter built on that flag.
    final source = _status == SessionStatusFilter.parkedNow
        ? state.parkedNow
        : state.reportSessions;

    final window =
        _status == SessionStatusFilter.parkedNow ? null : _window();

    final matches = <ParkingSession>[];
    for (final session in source) {
      if (window != null && !window.contains(session.startTime)) continue;

      final owed = session.cost - session.amountPaid;
      switch (_status) {
        case SessionStatusFilter.autoPay:
          if (!session.autoPayEnabled) continue;
        case SessionStatusFilter.unpaid:
          if (session.isActive || owed <= 0.005) continue;
        case SessionStatusFilter.paid:
          if (!session.isSettled) continue;
        case SessionStatusFilter.parkedNow:
        case SessionStatusFilter.all:
          break;
      }

      if (query.isNotEmpty &&
          !Vehicle.plateKey(session.vehicle.plateNumber).contains(query)) {
        continue;
      }

      matches.add(session);
    }

    matches.sort((a, b) {
      // A car still inside is the row an owner is looking for, so those pin to
      // the top; within each group the newest arrival leads.
      if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
      return b.startTime.compareTo(a.startTime);
    });
    return matches;
  }

  Widget _message({
    required IconData icon,
    required String title,
    required String body,
    Widget? action,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: context.colors.textMuted),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: context.colors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: context.colors.textSecondary,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 10),
              action,
            ],
          ],
        ),
      ),
    );
  }
}
