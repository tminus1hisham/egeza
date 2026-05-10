import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../blocs/app_bloc.dart';
import '../../blocs/app_event.dart';
import '../../core/theme/app_colors.dart';
import '../../models/parking_session.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/app_widgets.dart';

class ActiveSessionScreen extends StatefulWidget {
  final ParkingSession session;
  const ActiveSessionScreen({super.key, required this.session});

  @override
  State<ActiveSessionScreen> createState() => _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends State<ActiveSessionScreen> {
  late Timer _timer;
  late Duration _elapsed;

  // Treat naive (non-UTC) API datetimes as UTC to match server intent
  DateTime get _startUtc {
    final dt = widget.session.startTime;
    return dt.isUtc
        ? dt
        : DateTime.utc(dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second);
  }

  @override
  void initState() {
    super.initState();
    _elapsed = DateTime.now().toUtc().difference(_startUtc);
    // Update display every 5s; elapsed is computed from real start time so accuracy is maintained
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      setState(() => _elapsed = DateTime.now().toUtc().difference(_startUtc));
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String get _formattedTime {
    final h = _elapsed.inHours.toString().padLeft(2, '0');
    final m = (_elapsed.inMinutes % 60).toString().padLeft(2, '0');
    final s = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  double get _accruedCost {
    return (_elapsed.inMinutes / 60) * widget.session.cost;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  context.colors.primaryDeep,
                  context.colors.primaryDark,
                  context.colors.primary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryDeep.withValues(alpha: 0.26),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Material(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            onTap: () => Navigator.pop(context),
                            borderRadius: BorderRadius.circular(14),
                            child: const SizedBox(
                              width: 40,
                              height: 40,
                              child: Icon(
                                Icons.arrow_back_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Active Session',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'Live billing in progress',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  color: Colors.white.withValues(alpha: 0.62),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const StatusBadge(label: 'Active Now', isActive: true),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Text(
                      widget.session.locationName,
                      style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'KES ${_accruedCost.toStringAsFixed(2)}',
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Duration: $_formattedTime',
                      style: GoogleFonts.poppins(color: Colors.white54, fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Text(
                        '${widget.session.vehicle.plateNumber} - ${widget.session.vehicle.make}',
                        style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Session Details',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: context.colors.border),
                    ),
                    child: Column(
                      children: [
                        _detailRow('Rate', 'KES ${widget.session.cost.toStringAsFixed(0)}/hr'),
                        _detailRow('Started', _formatTime(widget.session.startTime)),
                        _detailRow('Location', widget.session.locationName),
                        _detailRow('Vehicle', '${widget.session.vehicle.make} ${widget.session.vehicle.model}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.colors.accentLight,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.colors.mintBorder),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: context.colors.primary, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Cost will be automatically deducted from your Park IQ wallet when you end this session.',
                            style: GoogleFonts.poppins(fontSize: 12, color: context.colors.primary, height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  PrimaryButton(
                    text: 'End Session & Pay',
                    onPressed: () => _showEndDialog(context),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.colors.divider))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.poppins(fontSize: 13, color: context.colors.textSecondary)),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final eat = (dt.isUtc ? dt : DateTime.utc(
      dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second,
    )).add(const Duration(hours: 3));
    final hour = eat.hour == 0 ? 12 : eat.hour > 12 ? eat.hour - 12 : eat.hour;
    final minute = eat.minute.toString().padLeft(2, '0');
    final period = eat.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  void _showEndDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: context.colors.border, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text('End Session?', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
            const SizedBox(height: 8),
            Text(
              'KES ${_accruedCost.toStringAsFixed(2)} will be deducted from your wallet.',
              style: GoogleFonts.poppins(fontSize: 13, color: context.colors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              text: 'Confirm & Pay',
              onPressed: () {
                context.read<AppBloc>().add(
                      PayParkingSession(sessionId: widget.session.id),
                    );
                Navigator.pop(context);
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.poppins(color: context.colors.textSecondary)),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
