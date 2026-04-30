import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../blocs/app_bloc.dart';
import '../../blocs/app_event.dart';
import '../../blocs/app_state.dart';
import '../../core/theme/app_colors.dart';
import '../../models/parking_session.dart';
import '../../models/vehicle.dart';

class VehicleDetailScreen extends StatefulWidget {
  final Vehicle vehicle;
  const VehicleDetailScreen({super.key, required this.vehicle});

  @override
  State<VehicleDetailScreen> createState() => _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends State<VehicleDetailScreen> {
  late bool _autoPayOn;

  static const _ink = Color(0xFF172133);
  static const _muted = Color(0xFF9AA4B4);
  static const _line = Color(0xFFE2E6EC);
  static const _teal = Color(0xFF0E6B5C);
  static const _tealLight = Color(0xFF168D7C);

  @override
  void initState() {
    super.initState();
    _autoPayOn = widget.vehicle.autoPayEnabled;
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F2F5),
        body: BlocBuilder<AppBloc, AppState>(
          builder: (context, state) {
            final sessions = state.recentSessions
                .where((s) => s.vehicle.plateNumber == widget.vehicle.plateNumber)
                .toList();
            final activeSession = sessions
                .where((s) => s.isActive)
                .cast<ParkingSession?>()
                .firstOrNull;
            final pastSessions = sessions.where((s) => !s.isActive).toList();

            return CustomScrollView(
              slivers: [
                _heroSliver(context, pastSessions),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _autoPayCard(),
                      if (activeSession != null) ...[
                        const SizedBox(height: 16),
                        _activeParkingCard(activeSession),
                      ],
                      const SizedBox(height: 24),
                      _sessionsSection(pastSessions),
                      const SizedBox(height: 24),
                      _dangerZone(context),
                    ]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _heroSliver(BuildContext context, List<ParkingSession> pastSessions) {
    final totalSpent = pastSessions.fold<double>(0, (sum, s) => sum + s.cost);
    return SliverToBoxAdapter(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A4F44), Color(0xFF168D7C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(32),
            bottomRight: Radius.circular(32),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      'Vehicle Details',
                      style: GoogleFonts.poppins(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.directions_car_filled_rounded,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${widget.vehicle.make} ${widget.vehicle.model}',
                            style: GoogleFonts.poppins(
                              color: Colors.white.withValues(alpha: 0.72),
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Text(
                              widget.vehicle.plateNumber,
                              style: GoogleFonts.poppins(
                                color: const Color(0xFF172133),
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2.8,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              widget.vehicle.type,
                              style: GoogleFonts.poppins(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: _statChip(
                        '${pastSessions.length}',
                        'Sessions',
                        Icons.local_parking_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _statChip(
                        'KES ${totalSpent.toStringAsFixed(0)}',
                        'Total Spent',
                        Icons.payments_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _statChip(
                        _autoPayOn ? 'ON' : 'OFF',
                        'AutoPay',
                        Icons.bolt_rounded,
                        highlight: _autoPayOn,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statChip(
    String value,
    String label,
    IconData icon, {
    bool highlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: highlight ? 0.25 : 0.12),
        borderRadius: BorderRadius.circular(16),
        border: highlight
            ? Border.all(
                color: Colors.white.withValues(alpha: 0.4), width: 1.5)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.8), size: 17),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: Colors.white.withValues(alpha: 0.62),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _autoPayCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: _autoPayOn
                        ? _teal.withValues(alpha: 0.1)
                        : const Color(0xFFF1F3F6),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Icon(
                    Icons.bolt_rounded,
                    color: _autoPayOn ? _teal : _muted,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AutoPay',
                        style: GoogleFonts.poppins(
                          color: _ink,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Payments deduct automatically at exit',
                        style: GoogleFonts.poppins(
                          color: _muted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Transform.scale(
                  scale: 0.9,
                  child: Switch(
                    value: _autoPayOn,
                    activeTrackColor: _teal,
                    activeThumbColor: Colors.white,
                    inactiveTrackColor: const Color(0xFFE3E7ED),
                    inactiveThumbColor: Colors.white,
                    trackOutlineColor:
                        const WidgetStatePropertyAll(Colors.transparent),
                    onChanged: (value) {
                      setState(() => _autoPayOn = value);
                      context.read<AppBloc>().add(
                            SetVehicleAutoPay(
                              vehicleId: widget.vehicle.id,
                              plateNumber: widget.vehicle.plateNumber,
                              enabled: value,
                            ),
                          );
                    },
                  ),
                ),
              ],
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
            decoration: BoxDecoration(
              color: _autoPayOn
                  ? const Color(0xFFEFFFFB)
                  : const Color(0xFFF6F7F9),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
              border: Border(
                top: BorderSide(
                  color: _autoPayOn ? const Color(0xFFC8F5EC) : _line,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _autoPayOn
                      ? Icons.check_circle_rounded
                      : Icons.info_outline_rounded,
                  color: _autoPayOn ? _teal : _muted,
                  size: 15,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _autoPayOn
                        ? 'AutoPay is ON — exits are processed automatically.'
                        : 'AutoPay is OFF. Enable to skip manual payment at exit.',
                    style: GoogleFonts.poppins(
                      color: _autoPayOn ? _teal : const Color(0xFF6D7889),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _activeParkingCard(ParkingSession session) {
    final duration = _durationLabel(session);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF26C766).withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: const Color(0xFF71F0D8), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
            decoration: const BoxDecoration(
              color: Color(0xFFD9FBE6),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(22),
                topRight: Radius.circular(22),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                    color: Color(0xFF26C766),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Currently Parked',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF15964B),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF15964B).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    duration,
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF15964B),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    _locationIcon(),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session.locationName,
                            style: GoogleFonts.poppins(
                              color: _ink,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _locationSubtitle(session),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color: _muted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _metricTile(
                        'Entry Time',
                        _timeLabel(session.startTime),
                        Icons.access_time_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _metricTile(
                        'Amount Due',
                        'KES ${session.cost.toStringAsFixed(0)}',
                        null,
                        highlighted: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      context.read<AppBloc>().add(
                            PayParkingSession(sessionId: session.id),
                          );
                    },
                    icon: const Icon(Icons.check_circle_outline_rounded,
                        size: 19),
                    label: Text(
                        'Pay KES ${session.cost.toStringAsFixed(0)} Now'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _tealLight,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Or pay at the exit barrier',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(color: _muted, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricTile(
    String label,
    String value,
    IconData? icon, {
    bool highlighted = false,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 15),
      decoration: BoxDecoration(
        color: highlighted
            ? const Color(0xFFEFFFFB)
            : const Color(0xFFF1F3F6),
        borderRadius: BorderRadius.circular(16),
        border: highlighted
            ? Border.all(color: const Color(0xFF71F0D8))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 13, color: _muted),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: GoogleFonts.poppins(
                  color: highlighted ? const Color(0xFF12A04A) : _muted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            value,
            style: GoogleFonts.poppins(
              color: highlighted ? _tealLight : _ink,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sessionsSection(List<ParkingSession> sessions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.history_rounded,
                color: Color(0xFF6D7889), size: 18),
            const SizedBox(width: 8),
            Text(
              'Parking History',
              style: GoogleFonts.poppins(
                color: _ink,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (sessions.isNotEmpty)
              Text(
                '${sessions.length} session${sessions.length == 1 ? '' : 's'}',
                style: GoogleFonts.poppins(color: _muted, fontSize: 13),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (sessions.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F3F6),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.history_rounded,
                      color: Color(0xFFB0BAC9), size: 26),
                ),
                const SizedBox(height: 12),
                Text(
                  'No sessions yet',
                  style: GoogleFonts.poppins(
                    color: _ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Parking history will appear here',
                  style: GoogleFonts.poppins(color: _muted, fontSize: 13),
                ),
              ],
            ),
          )
        else
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                for (var i = 0; i < sessions.length; i++) ...[
                  _sessionRow(sessions[i]),
                  if (i != sessions.length - 1)
                    const Divider(
                        color: _line, height: 1, indent: 20, endIndent: 20),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _sessionRow(ParkingSession session) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Row(
        children: [
          _locationIcon(),
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
                    color: _ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _locationSubtitle(session),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(color: _muted, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F3F6),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _dateLabel(session.startTime),
                        style: GoogleFonts.poppins(
                          color: _muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _durationLabel(session),
                      style: GoogleFonts.poppins(color: _muted, fontSize: 12),
                    ),
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
                'KES ${session.cost.toStringAsFixed(0)}',
                style: GoogleFonts.poppins(
                  color: _ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        color: Color(0xFF26C766), size: 11),
                    const SizedBox(width: 3),
                    Text(
                      'Paid',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF15964B),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _locationIcon() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFEFFFFB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(
        Icons.location_on_outlined,
        color: Color(0xFF168D7C),
        size: 22,
      ),
    );
  }

  Widget _dangerZone(BuildContext context) {
    return GestureDetector(
      onTap: () => _confirmRemove(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF6B6B).withValues(alpha: 0.1),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
              color: const Color(0xFFFFE0E0).withValues(alpha: 0.8),
              width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: Color(0xFFFF6B6B),
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Remove Vehicle',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFFFF6B6B),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Permanently delete from your account',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFFFF6B6B).withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFFFF6B6B),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  String _durationLabel(ParkingSession session) {
    final endTime = session.endTime ?? DateTime.now();
    final duration = endTime.difference(session.startTime);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    if (hours <= 0) return '${minutes}m';
    if (minutes <= 0) return '${hours}h';
    return '${hours}h ${minutes}m';
  }

  String _timeLabel(DateTime dateTime) {
    final hour = dateTime.hour == 0
        ? 12
        : dateTime.hour > 12
            ? dateTime.hour - 12
            : dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _locationSubtitle(ParkingSession session) {
    final lowerName = session.locationName.toLowerCase();
    if (lowerName.contains('garden')) return 'Thika rd, Nairobi, Kenya';
    if (lowerName.contains('two rivers')) return 'Ground Floor · Bay A-07';
    if (lowerName.contains('hub')) return 'Level 1 · Bay D-05';
    if (lowerName.contains('sarit')) return 'Basement · Bay B-11';
    if (lowerName.contains('westgate')) return 'Rooftop · Bay C-12';
    return 'Ground Floor · Bay A-07';
  }

  String _dateLabel(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sessionDay =
        DateTime(dateTime.year, dateTime.month, dateTime.day);
    final diff = today.difference(sessionDay).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '${diff}d ago';

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dateTime.day} ${months[dateTime.month - 1]}';
  }

  void _confirmRemove(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Remove Vehicle?',
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700, fontSize: 16),
        ),
        content: Text(
          'Are you sure you want to remove ${widget.vehicle.plateNumber} from your account?',
          style: GoogleFonts.poppins(
              fontSize: 13, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              context.read<AppBloc>().add(
                    RemoveVehicle(
                      vehicleId: widget.vehicle.id,
                      plateNumber: widget.vehicle.plateNumber,
                    ),
                  );
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text(
              'Remove',
              style: GoogleFonts.poppins(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
