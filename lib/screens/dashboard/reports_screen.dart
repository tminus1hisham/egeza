import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../blocs/manager_cubit.dart';
import '../../blocs/manager_state.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/manager_widgets.dart';
import 'property_sessions_screen.dart';

/// What the trend chart is counting. The same bars answer two questions —
/// what the site took, and how many cars turned up — and which one an owner
/// wants changes with what they are worried about that morning.
enum _TrendMetric { money, vehicles }

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

  _TrendMetric _trendMetric = _TrendMetric.money;

  void _clearSelection() {
    _selectedBucket = null;
    _selectionWindow = null;
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
                return const _ReportsSkeleton();
              }
              if (state.hasNoAssignments) {
                return _message(
                  icon: Icons.business_outlined,
                  title: 'No property yet',
                  body:
                      'This account is not attached to a parking location, so '
                      'there are no reports to show. Ask an administrator to '
                      'add your site.',
                );
              }
              if (!state.hasData && state.errorMessage != null) {
                return _message(
                  icon: Icons.cloud_off_rounded,
                  title: 'Could not load your reports',
                  body: state.errorMessage!,
                  tone: context.colors.error,
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
              final multiSite = state.locations.length > 1;

              return RefreshIndicator(
                color: context.colors.primary,
                onRefresh: () => context.read<ManagerCubit>().refresh(),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _hero(context, state, report),
                            if (state.isSample) ...[
                              const SizedBox(height: 10),
                              const SampleDataBanner(),
                            ],
                          ],
                        ),
                      ),
                    ),

                    // The period is the one control the whole page answers to,
                    // so it stays put while the cards under it scroll — an
                    // owner comparing two weeks should never have to hunt back
                    // up the page for the switch.
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _StickyFilters(
                        height: multiSite ? 96 : 54,
                        signature:
                            '${state.range}|${state.window.chipLabel}'
                            '|${state.selectedLocationId}'
                            '|${state.locations.length}',
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (multiSite) ...[
                              _locationSwitcher(context, state),
                              const SizedBox(height: 8),
                            ],
                            _periodPicker(context, state),
                          ],
                        ),
                      ),
                    ),

                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _updatedRow(context, state),
                            if (state.errorMessage != null) ...[
                              const SizedBox(height: 10),
                              StaleDataBanner(state.errorMessage!),
                            ],
                            if (!report.hasActivity) ...[
                              const SizedBox(height: 14),
                              EmptyStateCard(
                                icon: Icons.query_stats_rounded,
                                title: 'Nothing recorded in this period',
                                subtitle:
                                    'No vehicle came in between ${dayLabel(report.window.start)} '
                                    'and ${dayLabel(report.window.end.subtract(const Duration(days: 1)))}. '
                                    'Try a longer period.',
                              ),
                            ] else ...[
                              _groupLabel(context, 'Overview'),
                              _shortVersion(context, report),
                              const SizedBox(height: 12),
                              _rightNowCard(context, report),
                              _groupLabel(context, 'The money'),
                              _trendCard(context, report),
                              const SizedBox(height: 12),
                              _moneyCard(context, report),
                              const SizedBox(height: 12),
                              _paymentMixCard(context, report),
                              _groupLabel(context, 'Patterns'),
                              _busiestCard(context, report),
                              if (report.topVehicles.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                _regularsCard(context, report),
                              ],
                              const SizedBox(height: 16),
                              _footnote(context, report),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
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
      // The comparison belongs on the figure it qualifies, where it is read
      // with the number rather than four sentences further down the page.
      trailing: _deltaChip(report),
      metrics: [
        PageHeroMetric('Vehicles', '${report.vehicles}'),
        PageHeroMetric('Sessions', '${report.entries}'),
        PageHeroMetric('Parked now', '${report.parkedNow}'),
      ],
    );
  }

  Widget? _deltaChip(ReportSummary report) {
    final change = report.revenueChange;
    if (change == null) return null;
    final up = change >= 0;
    // Mint and salmon rather than the page's success/error, which are mixed
    // for contrast against white and go muddy on the hero's gradient.
    final tint = up ? AppColors.accent : const Color(0xFFFF9E8C);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            size: 12,
            color: tint,
          ),
          const SizedBox(width: 3),
          Text(
            '${(change.abs() * 100).round()}%',
            style: GoogleFonts.poppins(
              color: tint,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _locationSwitcher(BuildContext context, ManagerState state) {
    final index = state.locations.indexWhere(
      (location) => location.id == state.selectedLocationId,
    );
    return FilterPills(
      labels: [for (final location in state.locations) location.name],
      selectedIndex: index < 0 ? 0 : index,
      onSelected: (picked) => context.read<ManagerCubit>().selectLocation(
        state.locations[picked].id,
      ),
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
        setState(_clearSelection);
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

    setState(_clearSelection);
    cubit.selectCustomRange(picked.start, picked.end);
  }

  Widget _updatedRow(BuildContext context, ManagerState state) {
    final tone = state.errorMessage == null
        ? context.colors.success
        : context.colors.warning;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          // The dot carries a halo, so one glance at the top of the report is
          // enough to tell a live page from a stalled one.
          Container(
            width: 14,
            height: 14,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 7),
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
      ),
    );
  }

  /// The rule between groups of cards. Seven cards in a row read as one long
  /// wall; three labelled runs read as a report with sections.
  Widget _groupLabel(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 18, 2, 10),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.poppins(
              color: context.colors.textMuted,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Container(height: 1, color: context.colors.divider)),
        ],
      ),
    );
  }

  // ── THE SHORT VERSION ─────────────────────────────────────────────────────

  /// The whole period in five plain sentences.
  ///
  /// First on the page and deliberately wordy: an owner should be able to read
  /// this block alone and know how the site is doing, with everything below it
  /// there to answer the next question rather than the first one.
  Widget _shortVersion(BuildContext context, ReportSummary report) {
    final colors = context.colors;
    final change = report.revenueChange;
    final lines = <_Line>[];

    final money = 'KES ${formatMoney(report.revenue)} collected';
    if (change == null) {
      lines.add(
        _Line(
          Icons.payments_outlined,
          '$money — no figures for ${report.window.comparisonLabel.replaceAll('vs ', '')} to compare with.',
          colors.primary,
          lead: true,
        ),
      );
    } else {
      final up = change >= 0;
      final percent = (change.abs() * 100).round();
      lines.add(
        _Line(
          up ? Icons.trending_up_rounded : Icons.trending_down_rounded,
          '$money — $percent% ${up ? 'more' : 'less'} than ${report.window.comparisonLabel.replaceAll('vs ', '')}.',
          up ? colors.success : colors.error,
          lead: true,
        ),
      );
    }

    lines.add(
      _Line(
        Icons.directions_car_outlined,
        '${report.vehicles} ${report.vehicles == 1 ? 'vehicle' : 'vehicles'} came in'
        '${report.repeatVisits > 0 ? ', ${report.entries} entries in all (${report.repeatVisits} were return visits)' : ''}.',
        colors.primary,
      ),
    );

    if (report.vehicles > 0) {
      final stay = report.averageStayMinutes.round();
      lines.add(
        _Line(
          Icons.schedule_rounded,
          'About KES ${formatMoney(report.revenuePerVehicle)} a vehicle'
          '${stay > 0 ? ', staying ${durationLabel(stay)} on average' : ''}.',
          colors.primary,
        ),
      );
    }

    if (report.owedFromExits > 0.5) {
      lines.add(
        _Line(
          Icons.error_outline_rounded,
          'KES ${formatMoney(report.owedFromExits)} was never collected from cars '
          'that have already left.',
          colors.error,
        ),
      );
    } else if (report.entries > 0) {
      lines.add(
        _Line(
          Icons.verified_outlined,
          'Every car that left the site paid.',
          colors.success,
        ),
      );
    }

    lines.add(
      _Line(
        Icons.local_parking_rounded,
        report.capacity > 0
            ? '${report.parkedNow} parked right now — '
                  '${(report.occupancyRatio * 100).round()}% of your ${report.capacity} spaces.'
            : '${report.parkedNow} parked right now.',
        colors.primary,
      ),
    );

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(
            'The short version',
            icon: Icons.auto_awesome_rounded,
            trailing: report.window.label,
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < lines.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: lines[i].tone.withValues(alpha: 0.11),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(lines[i].icon, size: 13, color: lines[i].tone),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      lines[i].text,
                      style: GoogleFonts.poppins(
                        // The headline sentence is the one an owner reads if
                        // they read nothing else, so it is set to be read.
                        color: lines[i].lead
                            ? colors.textPrimary
                            : colors.textSecondary,
                        fontSize: 12.5,
                        fontWeight: lines[i].lead
                            ? FontWeight.w500
                            : FontWeight.w400,
                        height: 1.45,
                      ),
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
    final hourly = report.window.isHourly;
    final buckets = report.buckets;
    final byMoney = _trendMetric == _TrendMetric.money;

    double valueOf(ReportBucket bucket) =>
        byMoney ? bucket.revenue : bucket.entries.toDouble();
    String readingOf(ReportBucket bucket) => byMoney
        ? 'KES ${formatMoney(bucket.revenue)}'
        : '${bucket.entries} ${bucket.entries == 1 ? 'vehicle' : 'vehicles'}';

    var peak = 0.0;
    var bestIndex = -1;
    for (var i = 0; i < buckets.length; i++) {
      final value = valueOf(buckets[i]);
      if (value > peak) {
        peak = value;
        bestIndex = i;
      }
    }

    final hasSelection =
        _selectionWindow == report.window &&
        _selectedBucket != null &&
        _selectedBucket! < buckets.length;
    final selected = hasSelection ? buckets[_selectedBucket!] : null;
    final unit = hourly ? 'hour' : 'day';

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(
            byMoney ? 'Money by $unit' : 'Arrivals by $unit',
            icon: Icons.bar_chart_rounded,
            trailing: byMoney
                ? (hourly
                      ? 'KES ${formatMoney(report.revenue)} today'
                      : 'KES ${formatMoney(report.revenuePerDay)} a day')
                : '${report.entries} in all',
          ),
          const SizedBox(height: 12),
          _metricToggle(context),
          const SizedBox(height: 12),

          // One slot that either names the best bar or reports the tapped one,
          // held at the same shape either way so the chart under it does not
          // hop about as the reader taps along the axis.
          ConstrainedBox(
            // A floor rather than a fixed height: it holds the slot steady at
            // ordinary text sizes without clipping a reader who has scaled
            // their type up.
            constraints: const BoxConstraints(minHeight: 58),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: selected != null
                  ? _selectionBanner(
                      context,
                      key: ValueKey('sel-${selected.start}-$_trendMetric'),
                      title: selected.fullLabel,
                      reading: readingOf(selected),
                      detail: byMoney
                          ? '${selected.entries} ${selected.entries == 1 ? 'vehicle' : 'vehicles'}'
                          : 'KES ${formatMoney(selected.revenue)}',
                    )
                  : _bestBanner(
                      context,
                      key: ValueKey('best-$bestIndex-$_trendMetric'),
                      text: bestIndex < 0 || peak <= 0
                          ? 'Nothing recorded in this period yet'
                          : 'Best $unit: ${buckets[bestIndex].fullLabel} · '
                                '${readingOf(buckets[bestIndex])}',
                    ),
            ),
          ),
          const SizedBox(height: 14),

          _chart(
            context,
            buckets: buckets,
            peak: peak,
            bestIndex: bestIndex,
            selectedIndex: hasSelection ? _selectedBucket : null,
            valueOf: valueOf,
            window: report.window,
          ),
          const SizedBox(height: 9),
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
          CardNote(
            'Each bar is one $unit. Tap a bar to read it'
            '${hasSelection ? ', or tap it again to clear' : ''}.',
            icon: Icons.touch_app_outlined,
          ),
        ],
      ),
    );
  }

  /// Money or vehicles, as one control rather than two charts.
  Widget _metricToggle(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: 34,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colors.pageGrey,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.border.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          for (final option in _TrendMetric.values)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _trendMetric = option),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _trendMetric == option
                        ? colors.cardSurface
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: _trendMetric == option
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 5,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    option == _TrendMetric.money ? 'Money' : 'Vehicles',
                    style: GoogleFonts.poppins(
                      color: _trendMetric == option
                          ? colors.primary
                          : colors.textSecondary,
                      fontSize: 12,
                      fontWeight: _trendMetric == option
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _selectionBanner(
    BuildContext context, {
    required Key key,
    required String title,
    required String reading,
    required String detail,
  }) {
    final colors = context.colors;
    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(11, 8, 6, 8),
      decoration: BoxDecoration(
        color: colors.accentLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.mintBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: colors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$reading · $detail',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: colors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(_clearSelection),
            child: Padding(
              padding: const EdgeInsets.all(5),
              child: Icon(Icons.close_rounded, size: 15, color: colors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bestBanner(
    BuildContext context, {
    required Key key,
    required String text,
  }) {
    final colors = context.colors;
    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(11, 12, 11, 12),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          Icon(Icons.emoji_events_outlined, size: 14, color: colors.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                color: colors.textSecondary,
                fontSize: 12,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The bars themselves, over three gridlines and a baseline.
  ///
  /// The gridlines are what turn a row of blocks into a chart: without them a
  /// tall bar has nothing to be tall against.
  Widget _chart(
    BuildContext context, {
    required List<ReportBucket> buckets,
    required double peak,
    required int bestIndex,
    required int? selectedIndex,
    required double Function(ReportBucket) valueOf,
    required ReportWindow window,
  }) {
    final colors = context.colors;
    final tight = buckets.length > 16;

    return SizedBox(
      height: 124,
      child: Stack(
        children: [
          Positioned.fill(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var line = 0; line < 3; line++)
                  Container(
                    height: 1,
                    color: colors.border.withValues(alpha: 0.55),
                  ),
                Container(height: 1.5, color: colors.border),
              ],
            ),
          ),
          Positioned.fill(
            child: TweenAnimationBuilder<double>(
              // Keyed on the period and the metric, so switching either one
              // runs the bars up again instead of snapping to a new shape.
              key: ValueKey(
                '${window.start}-${window.end}'
                '-$_trendMetric-${buckets.length}',
              ),
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 520),
              curve: Curves.easeOutCubic,
              builder: (context, grown, _) => Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < buckets.length; i++)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() {
                          final alreadyOn =
                              selectedIndex == i && _selectionWindow == window;
                          _selectedBucket = alreadyOn ? null : i;
                          _selectionWindow = alreadyOn ? null : window;
                        }),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: tight ? 1 : 2.5,
                          ),
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              // A floor of 3% keeps an empty hour visible as an
                              // empty hour rather than as a gap in the axis.
                              heightFactor:
                                  grown *
                                  (peak <= 0
                                      ? 0.03
                                      : (valueOf(buckets[i]) / peak).clamp(
                                          0.03,
                                          1.0,
                                        )),
                              // A Container rather than a DecoratedBox: with
                              // no child of its own to size to, only the
                              // Container expands to fill the bar's slot.
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: _barGradient(
                                    context,
                                    empty: valueOf(buckets[i]) <= 0,
                                    lit:
                                        selectedIndex == i ||
                                        (selectedIndex == null &&
                                            i == bestIndex),
                                    dimmed:
                                        selectedIndex != null &&
                                        selectedIndex != i,
                                  ),
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(5),
                                  ),
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
          ),
        ],
      ),
    );
  }

  /// One bar's fill. Four states, in the order they take precedence: nothing
  /// happened here, this is the bar you asked about (or the best one in the
  /// period), something else is selected, or it is an ordinary bar.
  LinearGradient _barGradient(
    BuildContext context, {
    required bool empty,
    required bool lit,
    required bool dimmed,
  }) {
    final primary = context.colors.primary;
    if (empty) {
      final flat = context.colors.border.withValues(alpha: 0.75);
      return LinearGradient(colors: [flat, flat]);
    }
    if (lit) {
      return LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [context.colors.accent, primary],
      );
    }
    if (dimmed) {
      final faint = primary.withValues(alpha: 0.16);
      return LinearGradient(colors: [faint, faint]);
    }
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        primary.withValues(alpha: 0.34),
        primary.withValues(alpha: 0.68),
      ],
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
          SectionHeading(
            'The money',
            icon: Icons.payments_outlined,
            trailing: report.window.label,
          ),
          const SizedBox(height: 14),
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
                  // Red only when there is something to chase — a zero here is
                  // good news and should not be dressed as an alarm.
                  valueColor: report.owedFromExits > 0.5 ? colors.error : null,
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
          const SizedBox(height: 16),
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
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          MeterBar(value: rate, color: rateColor),
          CardNote(
            'Of the KES ${formatMoney(report.billedOnExits)} billed to cars that '
            'have already left, KES ${formatMoney(report.collectedOnExits)} came '
            'in. Cars still inside are not counted here — their fee is not due '
            'yet.',
          ),
        ],
      ),
    );
  }

  // ── RIGHT NOW ─────────────────────────────────────────────────────────────

  Widget _rightNowCard(BuildContext context, ReportSummary report) {
    final colors = context.colors;
    final hasCapacity = report.capacity > 0;
    final ratio = report.occupancyRatio;
    final tone = ratio >= 0.9
        ? colors.error
        : ratio >= 0.7
        ? colors.warning
        : colors.primary;

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeading(
            'On the ground now',
            icon: Icons.local_parking_rounded,
            trailing: 'This minute',
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              // A dial rather than one more bar: this is the reading an owner
              // checks in a second, and it should not look like the four
              // progress bars further down the page.
              if (hasCapacity)
                RingGauge(
                  value: ratio,
                  color: tone,
                  centerLabel: '${(ratio * 100).round()}%',
                  caption: 'full',
                )
              else
                Container(
                  width: 78,
                  height: 78,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.accentLight,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.mintBorder),
                  ),
                  child: Text(
                    '${report.parkedNow}',
                    style: GoogleFonts.poppins(
                      color: colors.primary,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasCapacity
                          ? '${report.parkedNow} of ${report.capacity} spaces'
                          : '${report.parkedNow} vehicles on site',
                      style: GoogleFonts.poppins(
                        color: colors.textPrimary,
                        fontSize: 17,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 7),
                    if (hasCapacity)
                      ToneChip(
                        '${report.freeSpaces} spaces free',
                        tone: ratio >= 0.9
                            ? ChipTone.alert
                            : ratio >= 0.7
                            ? ChipTone.warn
                            : ChipTone.good,
                        icon: Icons.event_available_rounded,
                      )
                    else
                      Text(
                        'No capacity set for this site',
                        style: GoogleFonts.poppins(
                          color: colors.textMuted,
                          fontSize: 11.5,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      'KES ${formatMoney(report.runningTab)} is running on the '
                      'cars inside',
                      style: GoogleFonts.poppins(
                        color: colors.textSecondary,
                        fontSize: 11.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (widget.onOpenSessions != null) ...[
            const SizedBox(height: 14),
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
                  backgroundColor: colors.accentLight,
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
    final autoFlex = (share * 1000).round().clamp(0, 1000);
    final manualFlex = 1000 - autoFlex;

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(
            'How people pay',
            icon: Icons.bolt_rounded,
            iconColor: autoPayColor,
            actionLabel: widget.onOpenSessions == null ? null : 'AutoPay list',
            onAction: widget.onOpenSessions == null
                ? null
                : () => widget.onOpenSessions!(
                    const PropertySessionsPreset(
                      status: SessionStatusFilter.autoPay,
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          // Two separated segments rather than one split bar: the gap is what
          // stops a 3% sliver reading as a rounding error on its neighbour.
          SizedBox(
            height: 12,
            child: Row(
              children: [
                if (autoFlex > 0)
                  Expanded(flex: autoFlex, child: _segment(autoPayColor)),
                if (autoFlex > 0 && manualFlex > 0) const SizedBox(width: 4),
                if (manualFlex > 0)
                  Expanded(
                    flex: manualFlex,
                    child: _segment(colors.primary.withValues(alpha: 0.5)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _legendRow(
            context,
            color: autoPayColor,
            label: 'AutoPay',
            percent: (share * 100).round(),
            detail:
                '${report.autoPayEntries} '
                '${report.autoPayEntries == 1 ? 'session' : 'sessions'}',
          ),
          const SizedBox(height: 10),
          _legendRow(
            context,
            color: colors.primary.withValues(alpha: 0.5),
            label: 'Paid at the gate',
            percent: 100 - (share * 100).round(),
            detail: '$manual ${manual == 1 ? 'session' : 'sessions'}',
          ),
          const CardNote(
            'AutoPay vehicles settle from their wallet without stopping, so a '
            'higher share here means a faster exit lane and less to chase.',
          ),
        ],
      ),
    );
  }

  Widget _segment(Color color) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }

  Widget _legendRow(
    BuildContext context, {
    required Color color,
    required String label,
    required int percent,
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
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
            color: context.colors.textMuted,
            fontSize: 11.5,
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 42,
          child: Text(
            '$percent%',
            textAlign: TextAlign.end,
            style: GoogleFonts.poppins(
              color: context.colors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
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
          SectionHeading(
            'Busiest times',
            icon: Icons.schedule_rounded,
            // On its own line rather than beside the title: at 320px a weekday
            // name is the first thing to be truncated, and it is one of the
            // more useful facts on the page.
            subtitle: report.busiestWeekday == null
                ? null
                : 'Busiest day of the week: ${report.busiestWeekday}',
          ),
          const SizedBox(height: 16),
          if (hours.isEmpty)
            Text(
              'No arrivals recorded in this period.',
              style: GoogleFonts.poppins(color: colors.textMuted, fontSize: 12),
            )
          else
            for (var i = 0; i < hours.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              Row(
                children: [
                  SizedBox(
                    width: 92,
                    child: Text(
                      hours[i].label,
                      style: GoogleFonts.poppins(
                        color: i == 0
                            ? colors.textPrimary
                            : colors.textSecondary,
                        fontSize: 12,
                        fontWeight: i == 0 ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                  Expanded(
                    child: MeterBar(
                      value: busiest == 0 ? 0 : hours[i].entries / busiest,
                      // The peak hour is the answer this card was opened for;
                      // the runners-up are the context for it.
                      color: i == 0
                          ? colors.primary
                          : colors.primary.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 26,
                    child: Text(
                      '${hours[i].entries}',
                      textAlign: TextAlign.end,
                      style: GoogleFonts.poppins(
                        color: colors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          const CardNote(
            'When cars arrive, counted across the whole period. Useful for '
            'staffing the gate and timing the cleaning.',
          ),
        ],
      ),
    );
  }

  // ── REGULARS ──────────────────────────────────────────────────────────────

  Widget _regularsCard(BuildContext context, ReportSummary report) {
    final colors = context.colors;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeading(
            'Who keeps coming back',
            icon: Icons.repeat_rounded,
            trailing: 'Most visits',
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < report.topVehicles.length; i++) ...[
            if (i > 0)
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(vertical: 11),
                color: colors.divider,
              ),
            Row(
              children: [
                // The rank is what makes this a leaderboard rather than five
                // plates in an order nobody explained.
                Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == 0
                        ? colors.primary.withValues(alpha: 0.12)
                        : colors.surfaceRaised,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      color: i == 0 ? colors.mintBorder : colors.border,
                    ),
                  ),
                  child: Text(
                    '${i + 1}',
                    style: GoogleFonts.poppins(
                      color: i == 0 ? colors.primary : colors.textMuted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                PlateTag(report.topVehicles[i].plate),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${report.topVehicles[i].visits} visits',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: colors.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                ),
                Text(
                  'KES ${formatMoney(report.topVehicles[i].spend)}',
                  style: GoogleFonts.poppins(
                    color: colors.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
          const CardNote(
            'Vehicles that came in more than once in this period, and what they '
            'have paid.',
          ),
        ],
      ),
    );
  }

  // ── FOOTNOTE ──────────────────────────────────────────────────────────────

  Widget _footnote(BuildContext context, ReportSummary report) {
    final fromPayments = report.revenueSource == ManagerRevenueSource.payments;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          fromPayments
              ? Icons.info_outline_rounded
              : Icons.warning_amber_rounded,
          size: 13,
          color: fromPayments
              ? context.colors.textMuted
              : context.colors.warning,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            fromPayments
                ? 'Collected counts payments that actually landed, dated by when '
                      'they landed. Vehicles counts number plates, so a car that '
                      'came back twice is one vehicle and two sessions.'
                : 'Payment records are unavailable right now, so collected is '
                      'summed from the sessions themselves and may miss an earlier '
                      'session paid inside this period.',
            style: GoogleFonts.poppins(
              color: context.colors.textMuted,
              fontSize: 11,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }

  Widget _message({
    required IconData icon,
    required String title,
    required String body,
    Color? tone,
    Widget? action,
  }) {
    final accent = tone ?? context.colors.textMuted;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: accent),
            ),
            const SizedBox(height: 16),
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
            if (action != null) ...[const SizedBox(height: 10), action],
          ],
        ),
      ),
    );
  }
}

/// One sentence in the short version.
class _Line {
  final IconData icon;
  final String text;
  final Color tone;

  /// The sentence that answers the question the owner opened the app with.
  final bool lead;

  const _Line(this.icon, this.text, this.tone, {this.lead = false});
}

/// Holds the period pills under the hero while the report scrolls past them.
class _StickyFilters extends SliverPersistentHeaderDelegate {
  final double height;

  /// What the pills are showing. Rebuilding on every scroll frame is wasted
  /// work; rebuilding when the selection changes is the whole point.
  final String signature;
  final Widget child;

  const _StickyFilters({
    required this.height,
    required this.signature,
    required this.child,
  });

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
      color: context.colors.pageGrey,
      // In the foreground, not the decoration: a border on the decoration
      // insets the child by its width, which would push the pills past the
      // extent this delegate promised the viewport.
      foregroundDecoration: BoxDecoration(
        border: Border(
          // Drawn only once something has scrolled under it — an unattached
          // rule sitting in open space just cuts the page in half.
          bottom: BorderSide(
            color: overlapsContent ? context.colors.border : Colors.transparent,
          ),
        ),
      ),
      child: child,
    );
  }

  @override
  bool shouldRebuild(_StickyFilters old) =>
      old.signature != signature || old.height != height;
}

/// The page's shape while the first poll is in flight.
///
/// A spinner on a screen this tall says only "wait"; the blocks say what is
/// coming and stop the report jumping into place around the reader.
class _ReportsSkeleton extends StatelessWidget {
  const _ReportsSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonBlock(height: 158, radius: 20),
          const SizedBox(height: 18),
          Row(
            children: [
              for (final width in [64.0, 76.0, 82.0, 90.0]) ...[
                SkeletonBlock(height: 34, width: width, radius: 999),
                const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 18),
          const SkeletonBlock(height: 166, radius: 18),
          const SizedBox(height: 12),
          const SkeletonBlock(height: 196, radius: 18),
          const SizedBox(height: 12),
          const SkeletonBlock(height: 150, radius: 18),
        ],
      ),
    );
  }
}
