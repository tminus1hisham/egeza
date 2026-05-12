import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../blocs/app_bloc.dart';
import '../../blocs/app_event.dart';
import '../../blocs/app_state.dart';
import '../../core/theme/app_colors.dart';
import '../../models/api_models.dart';
import '../../models/parking_session.dart';
import '../../widgets/app_widgets.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

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
    return Scaffold(
      backgroundColor: context.colors.pageGrey,
      body: SafeArea(
        bottom: false,
        child: BlocBuilder<AppBloc, AppState>(
          builder: (context, state) {
            final transactions = _filteredTransactions(state.walletTransactions);
            final completedSessions = _filteredSessions(
              state.recentSessions
                  .where((s) => !s.isActive)
                  .toList()
                ..sort((a, b) => b.startTime.compareTo(a.startTime)),
            );

            return Column(
              children: [
                _header(),
                Expanded(
                  child: RefreshIndicator(
                    color: context.colors.primary,
                    onRefresh: _onRefresh,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _overviewCard(state.walletTransactions),
                          const SizedBox(height: 18),
                          _sessionsList(completedSessions),
                          const SizedBox(height: 18),
                          _filterBar(),
                          const SizedBox(height: 18),
                          _historyList(transactions),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _header() {
    return Column(
      children: [
        AppPageHeader(
          title: 'History',
          subtitle: 'Wallet transactions and payments',
          icon: Icons.history_rounded,
          trailing: AppHeaderButton(
            icon: _searchOpen ? Icons.close_rounded : Icons.search_rounded,
            active: _searchOpen,
            tooltip: _searchOpen ? 'Close search' : 'Search history',
            onTap: () => setState(() {
              _searchOpen = !_searchOpen;
              if (!_searchOpen) _searchController.clear();
            }),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          child: _searchOpen
              ? Container(
                  color: context.colors.surface,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    onChanged: (_) => setState(() {}),
                    style: GoogleFonts.poppins(fontSize: 14, color: context.colors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search by description or reference...',
                      hintStyle: GoogleFonts.poppins(color: context.colors.textMuted, fontSize: 14),
                      prefixIcon: Icon(Icons.search_rounded, color: context.colors.textMuted, size: 20),
                      filled: true,
                      fillColor: context.colors.inputFill,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: context.colors.primary, width: 1.5),
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _overviewCard(List<WalletTransaction> transactions) {
    // Compute metrics only over the current calendar month (EAT).
    final now = DateTime.now();
    final monthTx = transactions.where((t) {
      if (t.createdAt == null) return false;
      final eat = _toEat(t.createdAt!);
      return eat.year == now.year && eat.month == now.month;
    }).toList();

    final payments = monthTx.where((t) => t.type.toUpperCase() != 'DEPOSIT');
    final totalSpend = payments.fold<double>(0, (sum, t) => sum + t.amount);
    final completed = monthTx.where((t) {
      final s = t.status.toUpperCase();
      return s == 'COMPLETED' || s == 'SUCCESS';
    }).length;
    final autoPayCount = monthTx.where(_isAutoPay).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primaryDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDeep.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Total parking spend',
                  style: GoogleFonts.poppins(
                    color: Colors.white.withValues(alpha: 0.66),
                    fontSize: 13,
                  ),
                ),
              ),
              _monthPill(),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'KES ${_formatAmount(totalSpend)}',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 32,
              height: 1.1,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(child: _overviewMetric('Transactions', '${transactions.length}')),
              _metricDivider(),
              Expanded(child: _overviewMetric('Completed', '$completed')),
              _metricDivider(),
              Expanded(child: _overviewMetric('AutoPay', '$autoPayCount')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterBar() {
    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
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
                      ? (index == 2 ? const Color(0xFF7C3AED) : context.colors.primary)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _filters[index],
                  style: GoogleFonts.poppins(
                    color: selected ? Colors.white : context.colors.textSecondary,
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _historyList(List<WalletTransaction> transactions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Activity',
                style: GoogleFonts.poppins(
                  color: context.colors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '${transactions.length} records',
              style: GoogleFonts.poppins(
                color: context.colors.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: _panelDecoration(),
          child: transactions.isEmpty
              ? _emptyHistory(
                  filterOnly:
                      _filterIndex != 0 || _searchController.text.isNotEmpty,
                )
              : Column(
                  children: [
                    for (var i = 0; i < transactions.length; i++) ...[
                      _transactionRow(transactions[i]),
                      if (i != transactions.length - 1)
                        Divider(
                          color: context.colors.divider,
                          height: 1,
                          indent: 74,
                        ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _sessionsList(List<ParkingSession> sessions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Parking Sessions',
                style: GoogleFonts.poppins(
                  color: context.colors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '${sessions.length} sessions',
              style: GoogleFonts.poppins(
                color: context.colors.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: _panelDecoration(),
          child: sessions.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
                  child: Text(
                    'No completed sessions yet',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: context.colors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                )
              : Column(
                  children: [
                    for (var i = 0; i < sessions.length; i++) ...[
                      _sessionRow(sessions[i]),
                      if (i != sessions.length - 1)
                        Divider(
                          color: context.colors.divider,
                          height: 1,
                          indent: 74,
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: context.colors.accentLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.local_parking_rounded,
              color: context.colors.primary,
              size: 21,
            ),
          ),
          const SizedBox(width: 14),
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
                const SizedBox(height: 3),
                Text(
                  '${session.vehicle.plateNumber} · ${session.vehicle.make}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: context.colors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                _sessionStatusChip(session.status),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amount > 0 ? '- KES ${_formatAmount(amount)}' : 'Free',
                style: GoogleFonts.poppins(
                  color: context.colors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                _dateTimeLabel(session.startTime),
                style: GoogleFonts.poppins(
                  color: context.colors.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyHistory({bool filterOnly = false}) {
    if (filterOnly) {
      return Padding(
        padding: const EdgeInsets.all(26),
        child: Text(
          'No transactions match this filter',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: context.colors.textSecondary,
            fontSize: 13,
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_outlined,
            size: 64,
            color: context.colors.textMuted,
          ),
          const SizedBox(height: 24),
          Text(
            'No parking history',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Your completed sessions will appear here',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: context.colors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _transactionRow(WalletTransaction tx) {
    final autoPay = _isAutoPay(tx);
    final isDeposit = tx.type.toUpperCase() == 'DEPOSIT';
    final isPending = tx.status.toUpperCase() == 'PENDING';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isDeposit
                  ? context.colors.successLight
                  : autoPay
                      ? const Color(0xFF7C3AED).withValues(alpha: 0.1)
                      : context.colors.accentLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isDeposit
                  ? Icons.add_circle_outline_rounded
                  : autoPay
                      ? Icons.bolt_rounded
                      : Icons.payments_outlined,
              color: isDeposit
                  ? context.colors.success
                  : autoPay
                      ? const Color(0xFF7C3AED)
                      : context.colors.primary,
              size: 21,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.description ?? _txTypeLabel(tx.type),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: context.colors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (tx.reference != null && tx.reference!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    tx.reference!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: context.colors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    _statusChip(_txStatusLabel(tx.status), isPending),
                    if (autoPay) ...[
                      const SizedBox(width: 8),
                      _autoPayPill(),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isDeposit ? '+' : '-'} KES ${_formatAmount(tx.amount)}',
                style: GoogleFonts.poppins(
                  color: isDeposit ? context.colors.success : context.colors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                tx.createdAt != null ? _dateTimeLabel(tx.createdAt!) : '—',
                style: GoogleFonts.poppins(
                  color: context.colors.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
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
          Text(
            'AutoPay',
            style: GoogleFonts.poppins(
              color: const Color(0xFF7C3AED),
              fontSize: 10,
              fontWeight: FontWeight.w600,
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

  Widget _monthPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'This month',
        style: GoogleFonts.poppins(
          color: Colors.white.withValues(alpha: 0.82),
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _overviewMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(
            color: Colors.white.withValues(alpha: 0.58),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _metricDivider() {
    return Container(
      width: 1,
      height: 34,
      margin: const EdgeInsets.symmetric(horizontal: 14),
      color: Colors.white.withValues(alpha: 0.14),
    );
  }

  BoxDecoration _panelDecoration() {
    return BoxDecoration(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: context.colors.border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.025),
          blurRadius: 12,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  bool _isAutoPay(WalletTransaction tx) {
    final desc = (tx.description ?? '').toLowerCase();
    final type = tx.type.toLowerCase();
    return desc.contains('autopay') ||
        desc.contains('auto pay') ||
        desc.contains('auto-pay') ||
        type.contains('autopay') ||
        type.contains('auto_debit') ||
        type == 'auto';
  }

  List<WalletTransaction> _filteredTransactions(List<WalletTransaction> transactions) {
    var result = transactions;
    if (_filterIndex == 1) {
      result = result.where((t) {
        final s = t.status.toUpperCase();
        return s == 'COMPLETED' || s == 'SUCCESS';
      }).toList();
    }
    if (_filterIndex == 2) result = result.where(_isAutoPay).toList();

    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      result = result
          .where((t) =>
              (t.description?.toLowerCase().contains(query) ?? false) ||
              (t.reference?.toLowerCase().contains(query) ?? false))
          .toList();
    }
    return result;
  }

  List<ParkingSession> _filteredSessions(List<ParkingSession> sessions) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return sessions;
    return sessions
        .where((s) =>
            s.locationName.toLowerCase().contains(query) ||
            s.vehicle.plateNumber.toLowerCase().contains(query) ||
            s.vehicle.make.toLowerCase().contains(query))
        .toList();
  }

  String _txTypeLabel(String type) {
    switch (type.toUpperCase()) {
      case 'DEPOSIT':
        return 'Wallet Top-up';
      case 'PAYMENT':
        return 'Parking Payment';
      case 'WITHDRAWAL':
        return 'Withdrawal';
      default:
        return type;
    }
  }

  String _txStatusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
      case 'SUCCESS':
        return 'Paid';
      case 'PENDING':
        return 'Pending';
      case 'FAILED':
        return 'Failed';
      case 'CANCELLED':
      case 'CANCELED':
        return 'Cancelled';
      default:
        return status;
    }
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
