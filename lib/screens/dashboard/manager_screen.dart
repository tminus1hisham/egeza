import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../blocs/manager_cubit.dart';
import '../../blocs/manager_state.dart';
import '../../core/api/parking_iq_api.dart';
import '../../core/theme/app_colors.dart';
import '../../models/parking_session.dart';
import '../../widgets/app_widgets.dart';

/// The operator's view of a single site: money taken today, vehicles in today,
/// and how many are still on the ground — refreshed on its own heartbeat.
///
/// Provides its own [ManagerCubit] so the polling starts when the screen opens
/// and stops when it closes; nothing here touches the driver-facing app state.
class ManagerScreen extends StatelessWidget {
  /// Supply the app's authenticated client. The screen builds its own only in
  /// the degenerate case where none is passed, which no caller does.
  final ParkingIqApi api;

  /// Debug only — see [ManagerCubit.useSampleData].
  final bool useSampleData;

  const ManagerScreen({
    super.key,
    required this.api,
    this.useSampleData = false,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ManagerCubit>(
      create: (_) =>
          ManagerCubit(api: api, useSampleData: useSampleData)..start(),
      child: const ManagerView(),
    );
  }
}

/// The screen body, split out so tests can drive it with their own cubit.
class ManagerView extends StatefulWidget {
  const ManagerView({super.key});

  @override
  State<ManagerView> createState() => _ManagerViewState();
}

class _ManagerViewState extends State<ManagerView>
    with WidgetsBindingObserver {
  /// Drives the "updated Ns ago" line and the ticking parked-for durations.
  /// Five seconds, matching the active-session screen — a per-second rebuild
  /// buys nothing when the shortest unit on screen is a minute.
  Timer? _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    // No point polling a site nobody is looking at. Restarting on resume also
    // refreshes immediately, so the figures are current the moment the manager
    // comes back rather than up to an interval stale.
    final cubit = context.read<ManagerCubit>();
    if (lifecycleState == AppLifecycleState.resumed) {
      cubit.start();
      setState(() => _now = DateTime.now());
    } else if (lifecycleState == AppLifecycleState.paused ||
        lifecycleState == AppLifecycleState.detached) {
      cubit.stop();
    }
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
                return _loading();
              }
              if (state.hasNoAssignments) {
                return _noAssignments();
              }
              if (!state.hasData && state.errorMessage != null) {
                return _loadFailed(context, state.errorMessage!);
              }

              return RefreshIndicator(
                color: context.colors.primary,
                onRefresh: () => context.read<ManagerCubit>().refresh(),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _hero(context, state),
                      if (state.isSample) ...[
                        const SizedBox(height: 10),
                        _sampleBanner(context),
                      ],
                      if (state.locations.length > 1) ...[
                        const SizedBox(height: 12),
                        _locationSwitcher(context, state),
                      ],
                      const SizedBox(height: 10),
                      _liveRow(context, state),
                      if (state.errorMessage != null) ...[
                        const SizedBox(height: 10),
                        _staleBanner(context, state.errorMessage!),
                      ],
                      const SizedBox(height: 14),
                      _occupancyCard(context, state),
                      const SizedBox(height: 14),
                      _moneyCard(context, state),
                      const SizedBox(height: 16),
                      _parkedNowSection(context, state),
                      const SizedBox(height: 16),
                      _exitsSection(context, state),
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

  // ── HERO ──────────────────────────────────────────────────────────────────

  Widget _hero(BuildContext context, ManagerState state) {
    return PageHero(
      // The eyebrow is the page name, so it carries the site and the period the
      // money figure covers — the value line is takings, not a balance.
      eyebrow: '${state.locationName} · Takings today',
      value: 'KES ${_money(state.revenueToday)}',
      tone: PageHeroTone.brand,
      onBack: () => Navigator.pop(context),
      pill: state.isSample
          ? const PageHeroPill(icon: Icons.science_outlined, label: 'Sample')
          : const PageHeroPill(icon: Icons.sensors_rounded, label: 'Live'),
      metrics: [
        PageHeroMetric('Vehicles today', '${state.vehiclesToday}'),
        PageHeroMetric('Parked now', '${state.stillParked}'),
        PageHeroMetric('Payments', '${state.settledPaymentsToday}'),
      ],
    );
  }

  Widget _locationSwitcher(BuildContext context, ManagerState state) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: state.locations.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final location = state.locations[index];
          final selected = location.id == state.selectedLocationId;

          return Material(
            color: selected ? context.colors.primary : context.colors.surface,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              onTap: () =>
                  context.read<ManagerCubit>().selectLocation(location.id),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: selected
                        ? context.colors.primary
                        : context.colors.border,
                  ),
                ),
                child: Text(
                  location.name,
                  style: GoogleFonts.poppins(
                    color:
                        selected ? Colors.white : context.colors.textSecondary,
                    fontSize: 12.5,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _liveRow(BuildContext context, ManagerState state) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: state.errorMessage == null
                ? context.colors.success
                : context.colors.warning,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            _updatedLabel(state.lastUpdated),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              color: context.colors.textSecondary,
              fontSize: 12,
            ),
          ),
        ),
        PageAction(
          icon: Icons.refresh_rounded,
          tooltip: 'Refresh now',
          compact: true,
          onTap: () => context.read<ManagerCubit>().refresh(),
        ),
      ],
    );
  }

  /// Sits directly under the hero, above every figure it applies to. Deliberately
  /// loud: a plausible invented number that is not labelled is worse than no
  /// number at all.
  Widget _sampleBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: context.colors.infoLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.info.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.science_outlined, size: 15, color: context.colors.info),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Sample data — every figure below is generated for layout '
              'preview. Nothing here came from a real site.',
              style: GoogleFonts.poppins(
                color: context.colors.textSecondary,
                fontSize: 11.5,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _staleBanner(BuildContext context, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: context.colors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: context.colors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 15,
            color: context.colors.warning,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.poppins(
                color: context.colors.textSecondary,
                fontSize: 11.5,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── OCCUPANCY ─────────────────────────────────────────────────────────────

  Widget _occupancyCard(BuildContext context, ManagerState state) {
    final capacity = state.capacity;
    final hasCapacity = capacity > 0;
    final ratio = state.occupancyRatio;
    final barColor = ratio >= 0.9
        ? context.colors.error
        : ratio >= 0.7
            ? context.colors.warning
            : context.colors.primary;

    return _card(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'On the ground now',
                      style: GoogleFonts.poppins(
                        color: context.colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasCapacity
                          ? '${state.stillParked} of $capacity spaces'
                          : '${state.stillParked} vehicles',
                      style: GoogleFonts.poppins(
                        color: context.colors.textPrimary,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasCapacity)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: barColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${(ratio * 100).round()}% full',
                    style: GoogleFonts.poppins(
                      color: barColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          if (hasCapacity) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 6,
                backgroundColor: context.colors.border,
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${state.freeSpaces} spaces free',
              style: GoogleFonts.poppins(
                color: context.colors.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── MONEY ─────────────────────────────────────────────────────────────────

  Widget _moneyCard(BuildContext context, ManagerState state) {
    return _card(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "Today's money",
                  style: GoogleFonts.poppins(
                    color: context.colors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                _dayLabel(_now),
                style: GoogleFonts.poppins(
                  color: context.colors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _metricTile(
                  context,
                  label: 'Collected',
                  value: 'KES ${_money(state.revenueToday)}',
                  icon: Icons.payments_outlined,
                  emphasis: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metricTile(
                  context,
                  label: 'Uncollected',
                  value: 'KES ${_money(state.outstandingToday)}',
                  icon: Icons.hourglass_bottom_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _metricTile(
                  context,
                  label: 'Entries',
                  value: '${state.entriesToday}',
                  icon: Icons.login_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metricTile(
                  context,
                  label: 'Avg payment',
                  value: 'KES ${_money(state.averagePaymentToday)}',
                  icon: Icons.trending_up_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            state.revenueSource == ManagerRevenueSource.payments
                ? 'Collected counts settled payments received today. '
                    'Uncollected is what today’s sessions still owe, '
                    'including cars still inside.'
                : 'Payment records are unavailable, so collected is summed from '
                    'today’s sessions and may miss earlier sessions paid today.',
            style: GoogleFonts.poppins(
              color: context.colors.textMuted,
              fontSize: 11,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricTile(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    bool emphasis = false,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 11),
      decoration: BoxDecoration(
        color: emphasis
            ? context.colors.accentLight
            : context.colors.surfaceRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: emphasis
              ? context.colors.mintBorder
              : context.colors.border.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 14,
            color: emphasis ? context.colors.primary : context.colors.textMuted,
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: GoogleFonts.poppins(
                color: context.colors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              color: context.colors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // ── LISTS ─────────────────────────────────────────────────────────────────

  Widget _parkedNowSection(BuildContext context, ManagerState state) {
    final parked = state.parkedNow;
    // A full site is hundreds of cars; the count in the header is the figure
    // that matters, and the rows exist to show the longest stays at the top.
    final shown = parked.take(_maxRows).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          context,
          'Parked right now',
          '${parked.length} ${parked.length == 1 ? 'vehicle' : 'vehicles'}',
        ),
        const SizedBox(height: 10),
        if (shown.isEmpty)
          _emptyCard(
            context,
            icon: Icons.local_parking_outlined,
            title: 'Nothing on the ground',
            subtitle: 'Vehicles appear here the moment the gate reads a plate.',
          )
        else ...[
          ...shown.map(
            (session) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _sessionRow(context, session, parked: true),
            ),
          ),
          if (parked.length > shown.length)
            _moreRowsLabel(
              context,
              '+${parked.length - shown.length} more parked',
            ),
        ],
      ],
    );
  }

  /// Long enough to scan the top of a list without turning the page into a full
  /// ledger — history and enforcement are not what this screen is for.
  static const _maxRows = 8;

  Widget _moreRowsLabel(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          color: context.colors.textMuted,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _exitsSection(BuildContext context, ManagerState state) {
    final exits = state.completedToday;
    final shown = exits.take(_maxRows).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          context,
          'Exits today',
          '${exits.length} ${exits.length == 1 ? 'session' : 'sessions'}',
        ),
        const SizedBox(height: 10),
        if (shown.isEmpty)
          _emptyCard(
            context,
            icon: Icons.logout_rounded,
            title: 'No exits yet today',
            subtitle: 'Completed sessions show here with what they paid.',
          )
        else ...[
          ...shown.map(
            (session) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _sessionRow(context, session, parked: false),
            ),
          ),
          if (exits.length > shown.length)
            _moreRowsLabel(
              context,
              '+${exits.length - shown.length} more today',
            ),
        ],
      ],
    );
  }

  Widget _sessionRow(
    BuildContext context,
    ParkingSession session, {
    required bool parked,
  }) {
    final owed = session.cost - session.amountPaid;
    final unpaid = owed > 0.005;

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
                  _plateTag(context, session.vehicle.plateNumber),
                  const SizedBox(height: 6),
                  Text(
                    parked
                        ? 'In ${_timeLabel(session.startTime)} · '
                            '${_durationLabel(session.startTime, _now)}'
                        : 'Out ${_timeLabel(session.endTime ?? session.startTime)} · '
                            '${_durationLabel(session.startTime, session.endTime ?? _now)}',
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
            // The fee and the state chip size themselves to their text, so on a
            // narrow phone a five-figure amount or an "Owes …" chip would run
            // off the card. Half the row is theirs; past that they wrap.
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth / 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'KES ${_money(parked ? session.cost : session.amountPaid)}',
                    textAlign: TextAlign.end,
                    style: GoogleFonts.poppins(
                      color: context.colors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  _stateChip(
                    context,
                    parked
                        ? (unpaid ? 'Running' : 'Prepaid')
                        : (unpaid ? 'Owes ${_money(owed)}' : 'Paid'),
                    unpaid ? (parked ? _ChipTone.neutral : _ChipTone.alert)
                           : _ChipTone.good,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── SHARED PIECES ─────────────────────────────────────────────────────────

  Widget _card(BuildContext context, {required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 15),
      decoration: BoxDecoration(
        color: context.colors.cardSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionHeader(BuildContext context, String title, String trailing) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.poppins(
              color: context.colors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          trailing,
          style: GoogleFonts.poppins(
            color: context.colors.textMuted,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _plateTag(BuildContext context, String plate) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: context.colors.plateBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: context.colors.plateYellow.withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        plate.isEmpty ? 'UNKNOWN' : plate,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.poppins(
          color: isDark
              ? context.colors.plateYellow
              : const Color(0xFF573A05),
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _stateChip(BuildContext context, String label, _ChipTone tone) {
    final color = switch (tone) {
      _ChipTone.good => context.colors.success,
      _ChipTone.alert => context.colors.error,
      _ChipTone.neutral => context.colors.textSecondary,
    };
    final background = switch (tone) {
      _ChipTone.good => context.colors.successLight,
      _ChipTone.alert => context.colors.errorLight,
      _ChipTone.neutral => context.colors.surfaceRaised,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _emptyCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
      decoration: BoxDecoration(
        color: context.colors.cardSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: context.colors.textMuted),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: context.colors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: context.colors.textMuted,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _loading() {
    return Center(
      child: CircularProgressIndicator(color: context.colors.primary),
    );
  }

  Widget _noAssignments() {
    return _fullPageMessage(
      icon: Icons.business_outlined,
      title: 'No sites assigned',
      body: 'This account is not assigned to manage a parking location yet. '
          'Ask an administrator to add you as a manager for your site.',
    );
  }

  Widget _loadFailed(BuildContext context, String message) {
    return _fullPageMessage(
      icon: Icons.cloud_off_rounded,
      title: 'Could not load the site',
      body: message,
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

  Widget _fullPageMessage({
    required IconData icon,
    required String title,
    required String body,
    Widget? action,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageBackButton(label: 'Manager view'),
          Expanded(
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
          ),
        ],
      ),
    );
  }

  // ── FORMATTING ────────────────────────────────────────────────────────────

  String _updatedLabel(DateTime? lastUpdated) {
    if (lastUpdated == null) return 'Waiting for the first reading';

    final seconds = _now.difference(lastUpdated).inSeconds;
    if (seconds < 10) return 'Updated just now · refreshes every 15s';
    if (seconds < 60) return 'Updated ${seconds}s ago · refreshes every 15s';
    final minutes = seconds ~/ 60;
    return 'Updated ${minutes}m ago · refreshes every 15s';
  }

  String _durationLabel(DateTime from, DateTime to) {
    final minutes = to.difference(from).inMinutes;
    if (minutes < 1) return 'just now';
    if (minutes < 60) return '${minutes}m';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0 ? '${hours}h' : '${hours}h ${rest}m';
  }

  String _timeLabel(DateTime moment) {
    final local = moment.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _dayLabel(DateTime moment) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${moment.day} ${months[moment.month - 1]}';
  }

  String _money(double amount) {
    return amount
        .toStringAsFixed(0)
        .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',');
  }
}

enum _ChipTone { good, alert, neutral }
