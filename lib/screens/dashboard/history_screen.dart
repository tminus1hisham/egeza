import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../blocs/app_bloc.dart';
import '../../blocs/app_event.dart';
import '../../blocs/app_state.dart';
import '../../core/theme/app_colors.dart';
import '../../models/parking_session.dart';
import '../../widgets/app_widgets.dart';

class HistoryScreen extends StatefulWidget {
  /// Set when this is a pushed route rather than a tab — an owner reaches their
  /// own activity from the property sessions screen, and needs a way back.
  final bool showBackButton;

  const HistoryScreen({super.key, this.showBackButton = false});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int _filterIndex = 0;
  bool _searchOpen = false;
  final _searchController = TextEditingController();
  static const _filters = ['All', 'Paid', 'AutoPay'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    context.read<AppBloc>().add(LoadDashboardData());
    await Future.delayed(const Duration(milliseconds: 800));
  }

  // Treat API datetimes as UTC and convert to EAT (UTC+3) for display.
  DateTime _toEat(DateTime dt) {
    final utc = dt.isUtc
        ? dt
        : DateTime.utc(dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second);
    return utc.add(const Duration(hours: 3));
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveStatusBar(
      child: Scaffold(
        backgroundColor: context.colors.pageGrey,
        body: SafeArea(
          bottom: false,
          child: BlocBuilder<AppBloc, AppState>(
          builder: (context, state) {
            // Ongoing sessions belong here too — they're the record of a car
            // that's parked right now. Pinned above the finished ones.
            final parkingSessions = _filteredSessions(
              state.recentSessions.toList()
                ..sort((a, b) {
                  if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
                  return b.startTime.compareTo(a.startTime);
                }),
            );

            return RefreshIndicator(
              color: context.colors.primary,
              onRefresh: _onRefresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _overviewCard(state.recentSessions),
                    const SizedBox(height: 14),
                    _filterBar(),
                    _searchField(),
                    const SizedBox(height: 14),
                    _sessionsList(parkingSessions),
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

  /// Expands under the filter bar when the search action there is toggled on.
  Widget _searchField() {
    return AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: _searchOpen
              ? Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    onChanged: (_) => setState(() {}),
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: context.colors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search by description or reference...',
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
                        borderSide: BorderSide(color: context.colors.inputBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: context.colors.inputBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: context.colors.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity, height: 0),
        );
  }

  Widget _overviewCard(List<ParkingSession> sessions) {
    // Compute metrics only over the current calendar month (EAT).
    final now = DateTime.now();
    final monthSessions = sessions.where((s) {
      final eat = _toEat(s.startTime);
      return eat.year == now.year && eat.month == now.month;
    }).toList();

    // Spend is money that actually left the wallet, so it counts what was
    // paid — an ongoing or exited-unpaid session has accrued a fee, not spent
    // one.
    final totalSpend =
        monthSessions.fold<double>(0, (sum, s) => sum + s.amountPaid);
    final completed = monthSessions.where((s) => s.isSettled).length;
    final autoPayCount = monthSessions.where((s) => s.autoPayEnabled).length;

    return PageHero(
      eyebrow: 'Total parking spend',
      value: 'KES ${_formatAmount(totalSpend)}',
      onBack: widget.showBackButton ? () => Navigator.pop(context) : null,
      pill: const PageHeroPill(
        icon: Icons.calendar_today_rounded,
        label: 'This month',
      ),
      metrics: [
        PageHeroMetric('Sessions', '${sessions.length}'),
        PageHeroMetric('Completed', '$completed'),
        PageHeroMetric('AutoPay', '$autoPayCount'),
      ],
    );
  }

  Widget _filterBar() {
    // Search lives on this row: with the page header gone it is the only
    // remaining entry point, and the filter bar is the control strip for
    // exactly the list below it.
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 40,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.colors.border),
            ),
            child: Row(
              children: List.generate(_filters.length, (index) {
                final selected = index == _filterIndex;

                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _filterIndex = index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 170),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected
                            ? (index == 2
                                ? const Color(0xFF7C3AED)
                                : context.colors.primary)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Text(
                        _filters[index],
                        style: GoogleFonts.poppins(
                          color: selected
                              ? Colors.white
                              : context.colors.textSecondary,
                          fontSize: 13,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
        const SizedBox(width: 4),
        PageAction(
          icon: _searchOpen ? Icons.close_rounded : Icons.search_rounded,
          primary: _searchOpen,
          tooltip: _searchOpen ? 'Close search' : 'Search history',
          onTap: () => setState(() {
            _searchOpen = !_searchOpen;
            if (!_searchOpen) _searchController.clear();
          }),
        ),
      ],
    );
  }

  Widget _sessionsList(List<ParkingSession> sessions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          'Parking Sessions',
          '${sessions.length} sessions',
          // A running session is the one row here anyone is looking for.
          chip: sessions.any((session) => session.isActive)
              ? const StatusBadge(label: 'Live', isActive: true)
              : null,
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: _panelDecoration(),
          child: sessions.isEmpty
              ? _emptyHistory(
                  filterOnly:
                      _filterIndex != 0 || _searchController.text.isNotEmpty,
                )
              : Column(
                  children: [
                    for (var i = 0; i < sessions.length; i++) ...[
                      _sessionRow(sessions[i]),
                      if (i != sessions.length - 1)
                        Divider(
                          color: context.colors.divider,
                          height: 1,
                          indent: 64,
                        ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _sessionRow(ParkingSession session) {
    final amount = session.amountPaid > 0 ? session.amountPaid : session.cost;
    // The debit minus means "this money left your account". An ongoing
    // session's amount is a running total, and an exited-unpaid session's is a
    // bill — neither has been collected, so neither gets the minus.
    final amountLabel = amount <= 0
        ? 'Free'
        : session.isSettled
            ? '- KES ${_formatAmount(amount)}'
            : 'KES ${_formatAmount(amount)}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: LayoutBuilder(
        builder: (context, constraints) => Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: context.colors.accentLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.local_parking_rounded,
                color: context.colors.primary,
                size: 19,
              ),
            ),
            const SizedBox(width: 12),
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
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${session.vehicle.plateNumber} · ${session.vehicle.make}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: context.colors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Two pills fit on one line only while the text is small; a
                  // Wrap drops the second under the first rather than running
                  // it off the edge of the card.
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _sessionStatusChip(session.status),
                      if (session.autoPayEnabled) _autoPayPill(),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _rowTrailing(
              rowWidth: constraints.maxWidth,
              amount: amountLabel,
              amountColor: context.colors.textPrimary,
              caption: _dateTimeLabel(session.startTime),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyHistory({bool filterOnly = false}) {
    if (filterOnly) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          'No parking sessions match this filter',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: context.colors.textSecondary,
            fontSize: 13,
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_outlined,
            size: 46,
            color: context.colors.textMuted,
          ),
          const SizedBox(height: 14),
          Text(
            'No parking history',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your completed sessions will appear here',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: context.colors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  /// The amount and the timestamp are the only unbounded strings in these
  /// rows: a five-figure fee at a large system text size outgrows what the row
  /// can spare and paints the overflow stripes. Capping the column at half the
  /// row makes both wrap onto a second line instead — an ellipsised amount
  /// would be worse than a tall one.
  Widget _rowTrailing({
    required double rowWidth,
    required String amount,
    required Color amountColor,
    required String caption,
  }) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: rowWidth / 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            amount,
            textAlign: TextAlign.end,
            style: GoogleFonts.poppins(
              color: amountColor,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            caption,
            textAlign: TextAlign.end,
            style: GoogleFonts.poppins(
              color: context.colors.textMuted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _autoPayPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt_rounded, size: 10, color: Color(0xFF7C3AED)),
          const SizedBox(width: 3),
          // The pill sits in the narrowest column on the row, so its own label
          // has to be able to give way rather than push the badge past the
          // width it was handed.
          Flexible(
            child: Text(
              'AutoPay',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                color: const Color(0xFF7C3AED),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sessionStatusChip(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
        return _statusChip('Paid', false);
      case 'ACTIVE':
      case 'PAID_ACTIVE':
      case 'IN_PROGRESS':
      case 'OPEN':
        return _statusChip('Ongoing', true);
      case 'EXIT_PENDING_PAYMENT':
        return _statusChip('Pending', true);
      case 'CANCELLED':
      case 'CANCELED':
        return _statusChip('Cancelled', false, isError: true);
      case 'PAYMENT_PENDING':
      case 'UNPAID':
        return _statusChip('Pending', true);
      default:
        return _statusChip(status, false);
    }
  }

  Widget _statusChip(String label, bool isPending, {bool isError = false}) {
    final bg = isPending
        ? context.colors.pageGrey
        : isError
            ? context.colors.error.withValues(alpha: 0.1)
            : context.colors.successLight;
    final borderColor = isPending
        ? context.colors.border
        : isError
            ? context.colors.error.withValues(alpha: 0.3)
            : context.colors.success.withValues(alpha: 0.3);
    final textColor = isPending
        ? context.colors.textSecondary
        : isError
            ? context.colors.error
            : context.colors.success;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Label, optional state chip, then the count.
  Widget _sectionHeader(String label, String count, {Widget? chip}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      spacing: 12,
      children: [
        // Label and chip travel together on the left, and the count is pushed
        // right by spaceBetween rather than by a Spacer — so when the three of
        // them stop fitting they shrink instead of overflowing.
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: context.colors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (chip != null) ...[const SizedBox(width: 8), chip],
            ],
          ),
        ),
        Flexible(
          child: Text(
            count,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: GoogleFonts.poppins(
              color: context.colors.textMuted,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  BoxDecoration _panelDecoration() {
    return BoxDecoration(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: context.colors.border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.025),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  List<ParkingSession> _filteredSessions(List<ParkingSession> sessions) {
    var result = sessions;
    // The filter bar sits above this list too, so it has to bite here — a
    // session is "Paid" once nothing is owed on it, and "AutoPay" when the fee
    // is collected off the wallet without the driver doing anything.
    if (_filterIndex == 1) {
      result = result.where((s) => s.isSettled).toList();
    }
    if (_filterIndex == 2) {
      result = result.where((s) => s.autoPayEnabled).toList();
    }

    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return result;
    return result
        .where((s) =>
            s.locationName.toLowerCase().contains(query) ||
            s.vehicle.plateNumber.toLowerCase().contains(query) ||
            s.vehicle.make.toLowerCase().contains(query))
        .toList();
  }

  String _dateTimeLabel(DateTime dateTime) {
    // Convert UTC API datetime to EAT (UTC+3) before any calendar comparison.
    final eat = _toEat(dateTime);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sessionDay = DateTime(eat.year, eat.month, eat.day);
    final diff = today.difference(sessionDay).inDays;
    final day = diff == 0
        ? 'Today'
        : diff == 1
            ? 'Yesterday'
            : _monthDay(eat);

    return '$day, ${_timeLabel(eat)}';
  }

  String _timeLabel(DateTime eat) {
    final hour = eat.hour == 0
        ? 12
        : eat.hour > 12
            ? eat.hour - 12
            : eat.hour;
    final minute = eat.minute.toString().padLeft(2, '0');
    final period = eat.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute $period';
  }

  String _monthDay(DateTime dateTime) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dateTime.day} ${months[dateTime.month - 1]}';
  }

  String _formatAmount(num amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => ',',
        );
  }
}
