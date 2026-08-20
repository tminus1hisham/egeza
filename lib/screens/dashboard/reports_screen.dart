import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../blocs/manager_cubit.dart';
import '../../blocs/manager_state.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/manager_widgets.dart';
import 'property_sessions_screen.dart';

/// What an owner opens the app for: what the site took, who came in, and
/// whether anything is being left on the table — over a period they choose.
///
/// Reads the [ManagerCubit] that the owner tabs provide, so the sessions list
/// and this screen are the same data on one poll rather than two.
class ReportsScreen extends StatefulWidget {
  /// Jumps to the property sessions tab with a filter already applied, so
  /// "43 parked now" on this screen leads to the 43 rows behind it.
  final ValueChanged<PropertySessionsPreset>? onOpenSessions;

  const ReportsScreen({super.key, this.onOpenSessions});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  /// The bar the user tapped, and the window it was tapped in — a selection
  /// from the last period would point at a different day in this one.
  int? _selectedBucket;
  ReportWindow? _selectionWindow;

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
                  child: CircularProgressIndicator(color: context.colors.primary),
                );
              }
              if (state.hasNoAssignments) {
                return _message(
                  icon: Icons.business_outlined,
                  title: 'No property yet',
                  body: 'This account is not attached to a parking location, so '
                      'there are no reports to show. Ask an administrator to '
                      'add your site.',
                );
              }
              if (!state.hasData && state.errorMessage != null) {
                return _message(
                  icon: Icons.cloud_off_rounded,
                  title: 'Could not load your reports',
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

              final report = state.report;

              return RefreshIndicator(
                color: context.colors.primary,
                onRefresh: () => context.read<ManagerCubit>().refresh(),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _hero(context, state, report),
                      if (state.isSample) ...[
                        const SizedBox(height: 10),
                        const SampleDataBanner(),
                      ],
                      if (state.locations.length > 1) ...[
                        const SizedBox(height: 12),
                        _locationSwitcher(context, state),
                      ],
                      const SizedBox(height: 12),
                      _periodPicker(context, state),
                      const SizedBox(height: 8),
                      _updatedRow(context, state),
                      if (state.errorMessage != null) ...[
                        const SizedBox(height: 10),
                        StaleDataBanner(state.errorMessage!),
                      ],
                      const SizedBox(height: 14),
                      if (!report.hasActivity)
                        EmptyStateCard(
                          icon: Icons.query_stats_rounded,
                          title: 'Nothing recorded in this period',
                          subtitle:
                              'No vehicle came in between ${dayLabel(report.window.start)} '
                              'and ${dayLabel(report.window.end.subtract(const Duration(days: 1)))}. '
                              'Try a longer period.',
                        )
                      else ...[
                        _shortVersion(context, state, report),
                        const SizedBox(height: 14),
                        _trendCard(context, report),
                        const SizedBox(height: 14),
                        _moneyCard(context, report),
                        const SizedBox(height: 14),
                        _rightNowCard(context, state, report),
                        const SizedBox(height: 14),
                        _paymentMixCard(context, report),
                        const SizedBox(height: 14),
                        _busiestCard(context, report),
                        if (report.topVehicles.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          _regularsCard(context, report),
                        ],
                        const SizedBox(height: 14),
                        _footnote(context, report),
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

  Widget _hero(BuildContext context, ManagerState state, ReportSummary report) {
    return PageHero(
      // The eyebrow is the page name, so it carries both the site and the
      // period — the value below is takings for that period, not a balance.
      eyebrow: '${state.locationName} · ${report.window.label}',
      value: 'KES ${formatMoney(report.revenue)}',
      tone: PageHeroTone.brand,
      pill: state.isSample
          ? const PageHeroPill(icon: Icons.science_outlined, label: 'Sample')
          : const PageHeroPill(icon: Icons.sensors_rounded, label: 'Live'),
      metrics: [
        PageHeroMetric('Vehicles', '${report.vehicles}'),
        PageHeroMetric('Sessions', '${report.entries}'),
        PageHeroMetric('Parked now', '${report.parkedNow}'),
      ],
    );
  }

  Widget _locationSwitcher(BuildContext context, ManagerState state) {
    final index = state.locations
        .indexWhere((location) => location.id == state.selectedLocationId);
    return FilterPills(
      labels: [for (final location in state.locations) location.name],
      selectedIndex: index < 0 ? 0 : index,
      onSelected: (picked) =>
          context.read<ManagerCubit>().selectLocation(state.locations[picked].id),
    );
  }

  /// Three presets and a date picker. The custom pill shows the dates it holds
  /// once one is picked, so the period on screen is never a guess.
  Widget _periodPicker(BuildContext context, ManagerState state) {
    const presets = [ReportRange.today, ReportRange.week, ReportRange.month];
    final selectedIndex = switch (state.range) {
      ReportRange.today => 0,
      ReportRange.week => 1,
      ReportRange.month => 2,
      ReportRange.custom => 3,
    };
    final customLabel = state.range == ReportRange.custom
        ? state.window.chipLabel
        : 'Pick dates';

    return FilterPills(
      labels: ['Today', '7 days', '30 days', customLabel],
      selectedIndex: selectedIndex,
      onSelected: (index) {
        if (index == 3) {
          _pickDates(context, state);
          return;
        }
        setState(() {
          _selectedBucket = null;
          _selectionWindow = null;
        });
        context.read<ManagerCubit>().selectRange(presets[index]);
      },
    );
  }

  Future<void> _pickDates(BuildContext context, ManagerState state) async {
    final cubit = context.read<ManagerCubit>();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final current = state.window;

    final picked = await showDateRangePicker(
      context: context,
      // Two years back is further than any of these sites have been running,
      // and nothing can be reported from a day that has not happened.
      firstDate: DateTime(today.year - 2, today.month, today.day),
      lastDate: today,
      initialDateRange: DateTimeRange(
        start: current.start.isBefore(today) ? current.start : today,
        end: current.end.subtract(const Duration(days: 1)),
      ),
      helpText: 'Pick a period',
      saveText: 'Show',
    );
    if (picked == null) return;

    setState(() {
      _selectedBucket = null;
      _selectionWindow = null;
    });
    cubit.selectCustomRange(picked.start, picked.end);
  }

  Widget _updatedRow(BuildContext context, ManagerState state) {
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
            state.lastUpdated == null
                ? 'Waiting for the first reading'
                : 'Updated ${clockLabel(state.lastUpdated!)} · refreshes on its own',
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

  // ── THE SHORT VERSION ─────────────────────────────────────────────────────

  /// The whole period in five plain sentences.
  ///
  /// First on the page and deliberately wordy: an owner should be able to read
  /// this block alone and know how the site is doing, with everything below it
  /// there to answer the next question rather than the first one.
  Widget _shortVersion(
    BuildContext context,
    ManagerState state,
    ReportSummary report,
  ) {
    final colors = context.colors;
    final change = report.revenueChange;
    final lines = <(IconData, String, Color)>[];

    final money = 'KES ${formatMoney(report.revenue)} collected';
    if (change == null) {
      lines.add((
        Icons.payments_outlined,
        '$money — no figures for ${report.window.comparisonLabel.replaceAll('vs ', '')} to compare with.',
        colors.textPrimary,
      ));
    } else {
      final up = change >= 0;
      final percent = (change.abs() * 100).round();
      lines.add((
        up ? Icons.trending_up_rounded : Icons.trending_down_rounded,
        '$money — $percent% ${up ? 'more' : 'less'} than ${report.window.comparisonLabel.replaceAll('vs ', '')}.',
        up ? colors.success : colors.error,
      ));
    }

    lines.add((
      Icons.directions_car_outlined,
      '${report.vehicles} ${report.vehicles == 1 ? 'vehicle' : 'vehicles'} came in'
      '${report.repeatVisits > 0 ? ', ${report.entries} entries in all (${report.repeatVisits} were return visits)' : ''}.',
      colors.textPrimary,
    ));

    if (report.vehicles > 0) {
      final stay = report.averageStayMinutes.round();
      lines.add((
        Icons.schedule_rounded,
        'About KES ${formatMoney(report.revenuePerVehicle)} a vehicle'
        '${stay > 0 ? ', staying ${durationLabel(stay)} on average' : ''}.',
        colors.textPrimary,
      ));
    }

    if (report.owedFromExits > 0.5) {
      lines.add((
        Icons.error_outline_rounded,
        'KES ${formatMoney(report.owedFromExits)} was never collected from cars '
        'that have already left.',
        colors.error,
      ));
    } else if (report.entries > 0) {
      lines.add((
        Icons.verified_outlined,
        'Every car that left the site paid.',
        colors.success,
      ));
    }

    lines.add((
      Icons.local_parking_rounded,
      report.capacity > 0
          ? '${report.parkedNow} parked right now — '
              '${(report.occupancyRatio * 100).round()}% of your ${report.capacity} spaces.'
          : '${report.parkedNow} parked right now.',
      colors.textPrimary,
    ));

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'The short version',
                  style: GoogleFonts.poppins(
                    color: colors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                report.window.label,
                style: GoogleFonts.poppins(
                  color: colors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < lines.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(lines[i].$1, size: 16, color: lines[i].$3),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    lines[i].$2,
                    style: GoogleFonts.poppins(
                      color: colors.textSecondary,
                      fontSize: 12.5,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── TREND ─────────────────────────────────────────────────────────────────

  Widget _trendCard(BuildContext context, ReportSummary report) {
    final colors = context.colors;
    final hourly = report.window.isHourly;
    final buckets = report.buckets;
    final peak = report.peakBucketRevenue;

    final selected = _selectionWindow == report.window &&
            _selectedBucket != null &&
            _selectedBucket! < buckets.length
        ? buckets[_selectedBucket!]
        : null;
    final best = report.bestBucket;

    final caption = selected != null
        ? '${selected.fullLabel} · KES ${formatMoney(selected.revenue)} · '
            '${selected.entries} ${selected.entries == 1 ? 'vehicle' : 'vehicles'}'
        : best != null
            ? 'Best ${hourly ? 'hour' : 'day'}: ${best.fullLabel} · '
                'KES ${formatMoney(best.revenue)}'
            : 'Nothing collected in this period yet';

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  hourly ? 'Money by hour' : 'Money by day',
                  style: GoogleFonts.poppins(
                    color: colors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                hourly
                    ? 'KES ${formatMoney(report.revenue)} today'
                    : 'KES ${formatMoney(report.revenuePerDay)} a day',
                style: GoogleFonts.poppins(
                  color: colors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            caption,
            maxLines: 2,
            style: GoogleFonts.poppins(
              color: selected != null ? colors.primary : colors.textSecondary,
              fontSize: 12,
              fontWeight: selected != null ? FontWeight.w600 : FontWeight.w400,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 112,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < buckets.length; i++)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() {
                        final alreadyOn = _selectedBucket == i &&
                            _selectionWindow == report.window;
                        _selectedBucket = alreadyOn ? null : i;
                        _selectionWindow = alreadyOn ? null : report.window;
                      }),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: buckets.length > 16 ? 1 : 3,
                        ),
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: FractionallySizedBox(
                            // A floor of 3% keeps an empty hour visible as an
                            // empty hour rather than as a gap in the axis.
                            heightFactor: peak <= 0
                                ? 0.03
                                : (buckets[i].revenue / peak).clamp(0.03, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: _selectedBucket == i &&
                                        _selectionWindow == report.window
                                    ? colors.primary
                                    : colors.primary.withValues(
                                        alpha: buckets[i].revenue <= 0
                                            ? 0.15
                                            : 0.55,
                                      ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Three labels rather than one per bar: 30 of them will not fit on a
          // phone, and the bars are readable by their ends and middle.
          if (buckets.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _axisLabel(context, buckets.first.label),
                if (buckets.length > 2)
                  _axisLabel(context, buckets[buckets.length ~/ 2].label),
                if (buckets.length > 1) _axisLabel(context, buckets.last.label),
              ],
            ),
          const SizedBox(height: 8),
          Text(
            hourly
                ? 'Each bar is one hour. Tap a bar for that hour.'
                : 'Each bar is one day. Tap a bar for that day.',
            style: GoogleFonts.poppins(
              color: colors.textMuted,
              fontSize: 11,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _axisLabel(BuildContext context, String label) {
    return Text(
      label,
      style: GoogleFonts.poppins(
        color: context.colors.textMuted,
        fontSize: 10.5,
      ),
    );
  }

  // ── MONEY ─────────────────────────────────────────────────────────────────

  Widget _moneyCard(BuildContext context, ReportSummary report) {
    final colors = context.colors;
    final rate = report.collectionRate;
    final rateColor = rate >= 0.95
        ? colors.success
        : rate >= 0.85
            ? colors.warning
            : colors.error;

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading('The money', trailing: report.window.label),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: MetricTile(
                  label: 'Collected',
                  value: 'KES ${formatMoney(report.revenue)}',
                  icon: Icons.payments_outlined,
                  emphasis: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: MetricTile(
                  label: 'Per vehicle',
                  value: 'KES ${formatMoney(report.revenuePerVehicle)}',
                  icon: Icons.directions_car_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: MetricTile(
                  label: 'Left unpaid',
                  value: 'KES ${formatMoney(report.owedFromExits)}',
                  icon: Icons.error_outline_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: MetricTile(
                  label: 'Running now',
                  value: 'KES ${formatMoney(report.runningTab)}',
                  icon: Icons.hourglass_bottom_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Fees collected',
                  style: GoogleFonts.poppins(
                    color: colors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
              Text(
                '${(rate * 100).round()}%',
                style: GoogleFonts.poppins(
                  color: rateColor,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: rate,
              minHeight: 6,
              backgroundColor: colors.border,
              valueColor: AlwaysStoppedAnimation<Color>(rateColor),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Of the KES ${formatMoney(report.billedOnExits)} billed to cars that '
            'have already left, KES ${formatMoney(report.collectedOnExits)} came '
            'in. Cars still inside are not counted here — their fee is not due '
            'yet.',
            style: GoogleFonts.poppins(
              color: colors.textMuted,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ── RIGHT NOW ─────────────────────────────────────────────────────────────

  Widget _rightNowCard(
    BuildContext context,
    ManagerState state,
    ReportSummary report,
  ) {
    final colors = context.colors;
    final hasCapacity = report.capacity > 0;
    final ratio = report.occupancyRatio;
    final barColor = ratio >= 0.9
        ? colors.error
        : ratio >= 0.7
            ? colors.warning
            : colors.primary;

    return SurfaceCard(
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
                        color: colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasCapacity
                          ? '${report.parkedNow} of ${report.capacity} spaces'
                          : '${report.parkedNow} vehicles',
                      style: GoogleFonts.poppins(
                        color: colors.textPrimary,
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
                backgroundColor: colors.border,
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${report.freeSpaces} spaces free',
              style: GoogleFonts.poppins(
                color: colors.textMuted,
                fontSize: 12,
              ),
            ),
          ],
          if (widget.onOpenSessions != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => widget.onOpenSessions!(
                  const PropertySessionsPreset(
                    status: SessionStatusFilter.parkedNow,
                  ),
                ),
                icon: const Icon(Icons.directions_car_rounded, size: 17),
                label: const Text('See the vehicles parked now'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.primary,
                  side: BorderSide(color: colors.mintBorder),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── HOW PEOPLE PAY ────────────────────────────────────────────────────────

  Widget _paymentMixCard(BuildContext context, ReportSummary report) {
    final colors = context.colors;
    const autoPayColor = Color(0xFF7C3AED);
    final share = report.autoPayShare;
    final manual = report.entries - report.autoPayEntries;

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(
            'How people pay',
            actionLabel: widget.onOpenSessions == null ? null : 'AutoPay list',
            onAction: widget.onOpenSessions == null
                ? null
                : () => widget.onOpenSessions!(
                      const PropertySessionsPreset(
                        status: SessionStatusFilter.autoPay,
                      ),
                    ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  Expanded(
                    flex: (share * 1000).round().clamp(0, 1000),
                    child: Container(color: autoPayColor),
                  ),
                  Expanded(
                    flex: (1000 - (share * 1000).round()).clamp(0, 1000),
                    child: Container(
                      color: colors.primary.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _legendRow(
            context,
            color: autoPayColor,
            label: 'AutoPay',
            detail: '${report.autoPayEntries} sessions · '
                '${(share * 100).round()}%',
          ),
          const SizedBox(height: 8),
          _legendRow(
            context,
            color: colors.primary.withValues(alpha: 0.45),
            label: 'Paid at the gate',
            detail: '$manual sessions · ${(100 - (share * 100).round())}%',
          ),
          const SizedBox(height: 10),
          Text(
            'AutoPay vehicles settle from their wallet without stopping, so a '
            'higher share here means a faster exit lane and less to chase.',
            style: GoogleFonts.poppins(
              color: colors.textMuted,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendRow(
    BuildContext context, {
    required Color color,
    required String label,
    required String detail,
  }) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              color: context.colors.textPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          detail,
          style: GoogleFonts.poppins(
            color: context.colors.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  // ── BUSIEST TIMES ─────────────────────────────────────────────────────────

  Widget _busiestCard(BuildContext context, ReportSummary report) {
    final colors = context.colors;
    final hours = report.busiestHours;
    final busiest = hours.isEmpty ? 0 : hours.first.entries;

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeading('Busiest times'),
          // Its own line rather than a trailing note: at 320px a weekday name
          // beside the title is the first thing to get truncated, and it is
          // one of the more useful facts on the page.
          if (report.busiestWeekday != null) ...[
            const SizedBox(height: 4),
            Text(
              'Busiest day of the week: ${report.busiestWeekday}',
              style: GoogleFonts.poppins(
                color: colors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (hours.isEmpty)
            Text(
              'No arrivals recorded in this period.',
              style: GoogleFonts.poppins(
                color: colors.textMuted,
                fontSize: 12,
              ),
            )
          else
            for (var i = 0; i < hours.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              Row(
                children: [
                  SizedBox(
                    width: 96,
                    child: Text(
                      hours[i].label,
                      style: GoogleFonts.poppins(
                        color: colors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: busiest == 0 ? 0 : hours[i].entries / busiest,
                        minHeight: 6,
                        backgroundColor: colors.border,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(colors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${hours[i].entries}',
                    style: GoogleFonts.poppins(
                      color: colors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          const SizedBox(height: 10),
          Text(
            'When cars arrive, counted across the whole period. Useful for '
            'staffing the gate and timing the cleaning.',
            style: GoogleFonts.poppins(
              color: colors.textMuted,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ── REGULARS ──────────────────────────────────────────────────────────────

  Widget _regularsCard(BuildContext context, ReportSummary report) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeading(
            'Who keeps coming back',
            trailing: 'Most visits',
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < report.topVehicles.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            Row(
              children: [
                PlateTag(report.topVehicles[i].plate),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${report.topVehicles[i].visits} visits',
                    style: GoogleFonts.poppins(
                      color: context.colors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
                Text(
                  'KES ${formatMoney(report.topVehicles[i].spend)}',
                  style: GoogleFonts.poppins(
                    color: context.colors.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Text(
            'Vehicles that came in more than once in this period, and what they '
            'have paid.',
            style: GoogleFonts.poppins(
              color: context.colors.textMuted,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ── FOOTNOTE ──────────────────────────────────────────────────────────────

  Widget _footnote(BuildContext context, ReportSummary report) {
    final fromPayments = report.revenueSource == ManagerRevenueSource.payments;
    return Text(
      fromPayments
          ? 'Collected counts payments that actually landed, dated by when they '
              'landed. Vehicles counts number plates, so a car that came back '
              'twice is one vehicle and two sessions.'
          : 'Payment records are unavailable right now, so collected is summed '
              'from the sessions themselves and may miss an earlier session '
              'paid inside this period.',
      style: GoogleFonts.poppins(
        color: context.colors.textMuted,
        fontSize: 11,
        height: 1.45,
      ),
    );
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
