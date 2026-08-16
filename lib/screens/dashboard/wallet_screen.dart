import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../blocs/app_bloc.dart';
import '../../blocs/app_event.dart';
import '../../blocs/app_state.dart';
import '../../core/error_handler.dart';
import '../../core/theme/app_colors.dart';
import '../../models/parking_session.dart';
import '../../widgets/app_widgets.dart';

class WalletScreen extends StatefulWidget {
  final bool showBackButton;

  /// Switches to the History tab. Null when the screen is pushed rather than
  /// hosted by MainNavigation, in which case "See all" is hidden rather than
  /// rendered as a link that does nothing.
  final VoidCallback? onSeeAllActivity;

  const WalletScreen({
    super.key,
    this.showBackButton = false,
    this.onSeeAllActivity,
  });

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  double? _selectedAmount = 1000;
  final _amountOptions = [500.0, 1000.0, 2000.0, 5000.0];
  final _customAmountController = TextEditingController();

  @override
  void dispose() {
    _customAmountController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() {
    context.read<AppBloc>().add(LoadDashboardData());
    return Future<void>.value();
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveStatusBar(
      child: Scaffold(
        backgroundColor: context.colors.pageGrey,
        body: SafeArea(
          bottom: false,
          child: BlocConsumer<AppBloc, AppState>(
            listenWhen: (prev, curr) =>
                curr.errorMessage != prev.errorMessage ||
                curr.statusMessage != prev.statusMessage,
            listener: (context, state) {
              if (state.errorMessage != null && state.errorMessage!.isNotEmpty) {
                ErrorHandler.showErrorMessage(context, state.errorMessage!);
              } else if (state.statusMessage != null &&
                  state.statusMessage!.isNotEmpty) {
                ErrorHandler.showSuccess(context, state.statusMessage!);
              }
            },
            builder: (context, state) {
              return RefreshIndicator(
                color: context.colors.primary,
                onRefresh: _onRefresh,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _balanceCard(state),
                      const SizedBox(height: 20),
                      _topUpPanel(context),
                      const SizedBox(height: 22),
                      _recentActivity(state),
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

  Widget _balanceCard(AppState state) {
    // Both numbers are about money that actually left the wallet, so they
    // count settled sessions only — an exited session with the fee still
    // outstanding is a bill, not a paid exit.
    final completed = state.recentSessions.where((s) => s.isSettled).length;
    final monthSpend = state.recentSessions
        .where((session) => session.isSettled)
        .fold<double>(
          0,
          (total, session) =>
              total +
              (session.amountPaid > 0 ? session.amountPaid : session.cost),
        );
    final autoPayCars = state.vehicles.where((v) => v.autoPayEnabled).length;

    // These three replace the stat tiles that used to sit under this card:
    // two of them restated metrics already shown here, and the third reported
    // AutoPay as always on regardless of state.
    return PageHero(
      eyebrow: 'Available balance',
      value: 'KES ${_formatAmount(state.walletBalance)}',
      tone: PageHeroTone.brand,
      onBack: widget.showBackButton ? () => Navigator.pop(context) : null,
      pill: const PageHeroPill(
        icon: Icons.phone_android_rounded,
        label: 'M-Pesa linked',
      ),
      metrics: [
        PageHeroMetric('This month', 'KES ${_formatCompact(monthSpend)}'),
        PageHeroMetric('Paid exits', '$completed'),
        PageHeroMetric('AutoPay cars', '$autoPayCars/${state.vehicles.length}'),
      ],
    );
  }

  Widget _topUpPanel(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.add_card_rounded,
                color: context.colors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Top up wallet',
                style: GoogleFonts.poppins(
                  color: context.colors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          // One row rather than a 2x2 grid — four short amounts fit across the
          // panel and it keeps the top-up button above the fold.
          SizedBox(
            height: 46,
            child: Row(
              children: [
                for (var i = 0; i < _amountOptions.length; i++) ...[
                  if (i != 0) const SizedBox(width: 8),
                  Expanded(child: _amountOption(_amountOptions[i])),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _customAmountController,
            keyboardType: TextInputType.number,
            onChanged: (value) {
              final amount = double.tryParse(value);
              setState(() {
                if (amount != null && amount >= 1) {
                  _selectedAmount = amount;
                } else {
                  _selectedAmount = null;
                }
              });
            },
            style: GoogleFonts.poppins(fontSize: 14, color: context.colors.textPrimary, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: 'Custom amount (min KES 100)',
              hintStyle: GoogleFonts.poppins(color: context.colors.textMuted, fontSize: 14, fontWeight: FontWeight.w400),
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 16, right: 10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'KES',
                      style: GoogleFonts.poppins(
                        color: context.colors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
              filled: true,
              fillColor: context.colors.inputFill,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: context.colors.successLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.phone_android_rounded,
                  color: context.colors.success,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'M-Pesa',
                      style: GoogleFonts.poppins(
                        color: context.colors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Instant wallet funding',
                      style: GoogleFonts.poppins(
                        color: context.colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.check_circle_rounded,
                color: context.colors.success,
                size: 22,
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _selectedAmount == null
                  ? null
                  : () => _topUpWallet(context, _selectedAmount!),
              icon: const Icon(Icons.bolt_outlined, size: 19),
              label: Text(
                _selectedAmount == null
                    ? 'Select an Amount'
                    : 'Top Up KES ${_formatAmount(_selectedAmount!)}',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.primary,
                disabledBackgroundColor: const Color(0xFFCAD3D0),
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _recentActivity(AppState state) {
    final sessions = state.recentSessions.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent activity',
              style: GoogleFonts.poppins(
                color: context.colors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (state.recentSessions.isNotEmpty &&
                widget.onSeeAllActivity != null)
              GestureDetector(
                onTap: widget.onSeeAllActivity,
                child: Text(
                  'See all',
                  style: GoogleFonts.poppins(
                    color: context.colors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
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
                  padding: const EdgeInsets.symmetric(
                    vertical: 48,
                    horizontal: 32,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 64,
                        color: context.colors.textMuted,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'No transactions',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: context.colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Top-up or park to see activity here',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: context.colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    for (var i = 0; i < sessions.length; i++) ...[
                      _activityRow(sessions[i]),
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

  Widget _activityRow(ParkingSession session) {
    final amount = session.amountPaid > 0 ? session.amountPaid : session.cost;
    final amountLabel =
        amount > 0 ? '- KES ${_formatAmount(amount)}' : 'Free';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
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
                  '${session.vehicle.plateNumber} - ${_dateLabel(session.startTime)}',
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
                amountLabel,
                style: GoogleFonts.poppins(
                  color: context.colors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
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
      ),
    );
  }

  Widget _amountOption(double amount) {
    final selected = _selectedAmount == amount;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedAmount = amount;
          _customAmountController.clear();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? context.colors.accentLight : context.colors.cardSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? context.colors.primary : context.colors.border,
            width: selected ? 1.6 : 1,
          ),
        ),
        // No "KES" per chip — four across is tight, and the panel's custom
        // field and button both carry the currency already.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            _formatAmount(amount),
            style: GoogleFonts.poppins(
              color: selected ? context.colors.primary : context.colors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration _panelDecoration({double radius = 20}) {
    return BoxDecoration(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  Future<void> _topUpWallet(BuildContext context, double amount) async {
    final state = context.read<AppBloc>().state;
    final phone = state.phoneNumber;
    dev.log(
      'topUpWallet: amount=$amount phone=$phone hasToken=${state.authToken != null && state.authToken!.isNotEmpty}',
      name: 'WalletScreen',
    );

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _StkPushSheet(
        amount: amount,
        phoneNumber: phone,
        formatAmount: _formatAmount,
        onConfirm: (newPhone) => Navigator.of(ctx).pop(newPhone),
        onCancel: () => Navigator.of(ctx).pop(),
      ),
    );

    dev.log(
      'topUpWallet: sheet closed — result=$result (null means cancelled)',
      name: 'WalletScreen',
    );

    if (result == null || !context.mounted) return;

    dev.log(
      'topUpWallet: dispatching TopUpWallet(amount=$amount, phone=$result)',
      name: 'WalletScreen',
    );
    context.read<AppBloc>().add(TopUpWallet(amount, phoneNumber: result));
  }

  String _durationLabel(ParkingSession session) {
    final startUtc = _apiUtc(session.startTime);
    final endUtc = session.endTime == null
        ? DateTime.now().toUtc()
        : _apiUtc(session.endTime!);
    final rawDuration = endUtc.difference(startUtc);
    final duration = rawDuration.isNegative ? Duration.zero : rawDuration;
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    if (hours <= 0) return '${minutes}m';
    if (minutes <= 0) return '${hours}h';
    return '${hours}h ${minutes}m';
  }

  String _dateLabel(DateTime dateTime) {
    final now = DateTime.now().toUtc().add(const Duration(hours: 3));
    final value = _eat(dateTime);
    final today = DateTime(now.year, now.month, now.day);
    final sessionDay = DateTime(value.year, value.month, value.day);
    final diff = today.difference(sessionDay).inDays;

    if (diff <= 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '${diff}d ago';

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${value.day} ${months[value.month - 1]}';
  }

  DateTime _apiUtc(DateTime dt) {
    if (dt.isUtc) return dt;
    return DateTime.utc(
      dt.year,
      dt.month,
      dt.day,
      dt.hour,
      dt.minute,
      dt.second,
      dt.millisecond,
      dt.microsecond,
    );
  }

  DateTime _eat(DateTime dt) => _apiUtc(dt).add(const Duration(hours: 3));

  String _formatCompact(double amount) {
    if (amount >= 1000) {
      final value = amount / 1000;
      return '${value.toStringAsFixed(value >= 10 ? 0 : 1)}k';
    }
    return amount.toStringAsFixed(0);
  }

  String _formatAmount(num amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => ',',
        );
  }
}

class _StkPushSheet extends StatefulWidget {
  final double amount;
  final String? phoneNumber;
  final String Function(num) formatAmount;
  final void Function(String) onConfirm;
  final VoidCallback onCancel;

  const _StkPushSheet({
    required this.amount,
    required this.phoneNumber,
    required this.formatAmount,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<_StkPushSheet> createState() => _StkPushSheetState();
}

class _StkPushSheetState extends State<_StkPushSheet> {
  late TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(text: widget.phoneNumber);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      context.colors.success.withValues(alpha: 0.15),
                      context.colors.success.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.colors.success.withValues(alpha: 0.1)),
                ),
                child: Icon(
                  Icons.phone_android_rounded,
                  color: context.colors.success,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'M-Pesa prompt',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  Text(
                    'Confirm payment details',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Amount',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: context.colors.textSecondary,
                ),
              ),
              Text(
                'KES ${widget.formatAmount(widget.amount)}',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'M-Pesa number',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: context.colors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              filled: true,
              fillColor: context.colors.inputFill,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
          const SizedBox(height: 8),
          Text(
            'A payment prompt will be sent to this number.',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: context.colors.textSecondary,
            ),
          ),
          const SizedBox(height: 28),
          Container(
            width: double.infinity,
            height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [Color(0xFF0E6B5C), Color(0xFF168D7C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0E6B5C).withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: () => widget.onConfirm(_phoneController.text.trim()),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'Send prompt',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: TextButton(
              onPressed: widget.onCancel,
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: context.colors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
