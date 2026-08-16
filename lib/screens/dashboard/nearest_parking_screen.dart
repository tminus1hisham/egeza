import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../blocs/app_bloc.dart';
import '../../core/api/parking_iq_api.dart';
import '../../core/theme/app_colors.dart';
import '../../models/api_models.dart';
import '../../widgets/app_widgets.dart';

// Nairobi CBD — fallback when location permission is denied
const _fallbackLat = -1.2921;
const _fallbackLng = 36.8219;

class NearestParkingScreen extends StatefulWidget {
  const NearestParkingScreen({super.key});

  @override
  State<NearestParkingScreen> createState() => _NearestParkingScreenState();
}

class _NearestParkingScreenState extends State<NearestParkingScreen> {
  List<NearestParkingLocation> _locations = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    dev.log('NearestParking: loading locations', name: 'NearestParking');
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // NOTE: `fallback` says we fell back to Nairobi CBD because location was
      // denied. It used to be surfaced as the header subtitle; with page
      // wordings removed there is nowhere left showing it.
      final (lat, lng, _) = await _resolveLocation();

      final token = context.read<AppBloc>().state.authToken;
      final api = ParkingIqApi(token: token);
      final locations = await api.fetchNearestLocations(
        latitude: lat,
        longitude: lng,
      );
      dev.log(
        'NearestParking: got ${locations.length} locations',
        name: 'NearestParking',
      );
      if (mounted) {
        setState(() {
          _locations = locations;
          _loading = false;
        });
      }
    } catch (e, st) {
      dev.log(
        'NearestParking: failed to load',
        name: 'NearestParking',
        error: e,
        stackTrace: st,
      );
      if (mounted) {
        setState(() {
          _error = 'Could not load parking locations. Please try again.';
          _loading = false;
        });
      }
    }
  }

  Future<(double lat, double lng, bool fallback)> _resolveLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        dev.log('NearestParking: requesting location permission', name: 'NearestParking');
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        dev.log(
          'NearestParking: location permission denied — using fallback',
          name: 'NearestParking',
        );
        return (_fallbackLat, _fallbackLng, true);
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 8),
        ),
      );
      dev.log(
        'NearestParking: got location lat=${pos.latitude} lng=${pos.longitude}',
        name: 'NearestParking',
      );
      return (pos.latitude, pos.longitude, false);
    } catch (e) {
      dev.log(
        'NearestParking: location error — using fallback: $e',
        name: 'NearestParking',
      );
      return (_fallbackLat, _fallbackLng, true);
    }
  }

  Future<void> _openMaps(NearestParkingLocation loc) async {
    final uris = <Uri>[];

    if (loc.hasCoordinates) {
      final lat = loc.latitude!;
      final lng = loc.longitude!;
      // Native Google Maps — starts turn-by-turn navigation immediately
      uris.add(Uri.parse('google.navigation:q=$lat,$lng&mode=d'));
      uris.add(Uri.parse('comgooglemaps://?daddr=$lat,$lng&directionsmode=driving'));
      // Web fallback — opens directions panel
      uris.add(Uri.parse(
        'https://www.google.com/maps/dir/?api=1'
        '&destination=$lat,$lng&travelmode=driving',
      ));
    } else {
      final query = Uri.encodeComponent(loc.address ?? loc.name);
      uris.add(Uri.parse('https://www.google.com/maps/search/?api=1&query=$query'));
    }

    for (final uri in uris) {
      dev.log(
        'NearestParking: trying "$uri" for "${loc.name}"',
        name: 'NearestParking',
      );
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }

    dev.log('NearestParking: no maps URI could be launched', name: 'NearestParking');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Google Maps')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveStatusBar(
      child: Scaffold(
      backgroundColor: context.colors.pageGrey,
      // Refresh moved to pull-to-refresh on the list, matching every
      // other screen — see _buildBody. The back control lives inside the
      // scrolling body too, so it scrolls away like every other screen's.
      body: SafeArea(bottom: false, child: _buildBody()),
      ),
    );
  }

  /// The page's only chrome. It rides inside whichever scroll view the current
  /// state builds, so it scrolls away as on every other screen.
  Widget get _backRow => const Padding(
        padding: EdgeInsets.fromLTRB(20, 22, 20, 12),
        child: PageBackButton(label: 'Find parking'),
      );

  Widget _buildBody() {
    if (_loading) {
      return Column(
        children: [
          _backRow,
          Expanded(
            child: Center(
              child: CircularProgressIndicator(color: context.colors.primary),
            ),
          ),
        ],
      );
    }

    if (_error != null) {
      return Column(
        children: [
          _backRow,
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.wifi_off_rounded,
                      size: 48,
                      color: context.colors.textMuted,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: context.colors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded, size: 17),
                      label: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (_locations.isEmpty) {
      return RefreshIndicator(
        color: context.colors.primary,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _backRow,
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.local_parking_rounded,
                    size: 56,
                    color: context.colors.textMuted,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No parking locations found',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Pull down to refresh.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Pull-to-refresh replaces the header's refresh button, and matches how
    // every other list in the app reloads.
    return RefreshIndicator(
      color: context.colors.primary,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _backRow,
          for (var i = 0; i < _locations.length; i++)
            Padding(
              padding: EdgeInsets.fromLTRB(16, i == 0 ? 0 : 10, 16, 0),
              child: _locationCard(_locations[i]),
            ),
        ],
      ),
    );
  }

  Widget _locationCard(NearestParkingLocation loc) {
    final isFull = loc.maxCapacity > 0 && loc.availableSpots == 0;
    final Color availColor = loc.maxCapacity == 0
        ? context.colors.primary
        : loc.occupancyRatio < 0.5
            ? context.colors.success
            : loc.occupancyRatio < 0.85
                ? AppColors.warning
                : AppColors.error;

    return Material(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: () => _openMaps(loc),
        borderRadius: BorderRadius.circular(22),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: context.colors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Image banner (when available) ────────────────────
              if (loc.displayImage != null && loc.displayImage!.isNotEmpty)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                  child: Image.network(
                    loc.displayImage!,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        height: 160,
                        color: context.colors.pageGrey,
                        child: Center(
                          child: CircularProgressIndicator(
                            value: progress.expectedTotalBytes != null
                                ? progress.cumulativeBytesLoaded /
                                    progress.expectedTotalBytes!
                                : null,
                            color: context.colors.primary,
                            strokeWidth: 2,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stack) => const SizedBox.shrink(),
                  ),
                ),

              // ── Header row ──────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (loc.displayImage == null || loc.displayImage!.isEmpty)
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primaryDark, AppColors.primaryDeep],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.local_parking_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    if (loc.displayImage == null || loc.displayImage!.isEmpty)
                      const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  loc.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: context.colors.textPrimary,
                                  ),
                                ),
                              ),
                              if (loc.distanceKm != null) ...[
                                const SizedBox(width: 8),
                                _chip(
                                  Icons.near_me_rounded,
                                  '${loc.distanceKm!.toStringAsFixed(1)} km',
                                  AppColors.info,
                                  AppColors.infoLight,
                                ),
                              ],
                            ],
                          ),
                          if (loc.address != null && loc.address!.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on_outlined,
                                  size: 12,
                                  color: context.colors.textMuted,
                                ),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(
                                    loc.address!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: context.colors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Occupancy bar ────────────────────────────────────
              if (loc.maxCapacity > 0) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isFull ? 'Full' : '${loc.availableSpots} of ${loc.maxCapacity} spots available',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: availColor,
                            ),
                          ),
                          Text(
                            '${(loc.occupancyRatio * 100).toStringAsFixed(0)}% occupied',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: context.colors.textMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: loc.occupancyRatio,
                          minHeight: 6,
                          backgroundColor: context.colors.pageGrey,
                          valueColor: AlwaysStoppedAnimation<Color>(availColor),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // ── Divider ──────────────────────────────────────────
              Divider(height: 1, color: context.colors.divider),

              // ── Pricing grid ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    if (loc.ratePerHour > 0)
                      Expanded(
                        child: _infoCell(
                          Icons.payments_outlined,
                          'Rate',
                          'KES ${_fmt(loc.ratePerHour)}/hr',
                          context.colors.primary,
                        ),
                      ),
                    if (loc.maxDailyCharge != null) ...[
                      if (loc.ratePerHour > 0) _vertDivider(),
                      Expanded(
                        child: _infoCell(
                          Icons.today_rounded,
                          'Daily cap',
                          'KES ${_fmt(loc.maxDailyCharge!)}',
                          AppColors.info,
                        ),
                      ),
                    ],
                    if (loc.gracePeriodMinutes > 0) ...[
                      if (loc.ratePerHour > 0 || loc.maxDailyCharge != null)
                        _vertDivider(),
                      Expanded(
                        child: _infoCell(
                          Icons.timer_outlined,
                          'Grace period',
                          '${loc.gracePeriodMinutes} min ',
                          context.colors.success,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // ── Pricing tiers ─────────────────────────────────────
              if (loc.pricingTiers.isNotEmpty) ...[
                const SizedBox(height: 4),
                Divider(height: 1, color: context.colors.divider),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 13,
                        color: context.colors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'PRICING SCHEME',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: context.colors.textMuted,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: Container(
                    decoration: BoxDecoration(
                      color: context.colors.pageGrey,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: context.colors.border),
                    ),
                    child: Column(
                      children: [
                        // Header row
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Text(
                                  'Duration',
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: context.colors.textMuted,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'Type',
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: context.colors.textMuted,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 62,
                                child: Text(
                                  'Rate (KES)',
                                  textAlign: TextAlign.right,
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: context.colors.textMuted,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Divider(height: 1, color: context.colors.border),
                        // Data rows
                        ...loc.pricingTiers.asMap().entries.map((entry) {
                          final i = entry.key;
                          final t = entry.value;
                          final isLast = i == loc.pricingTiers.length - 1;
                          final isEven = i % 2 == 0;
                          return Column(
                            children: [
                              Container(
                                color: isEven
                                    ? Colors.transparent
                                    : context.colors.surface.withValues(alpha: 0.6),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 11,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 6,
                                            height: 6,
                                            margin: const EdgeInsets.only(right: 7),
                                            decoration: BoxDecoration(
                                              color: context.colors.primary,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          Text(
                                            '${t.fromLabel} – ${t.toLabel}',
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: context.colors.textPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: t.isFlat
                                                ? AppColors.infoLight
                                                : context.colors.accentLight,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            t.isFlat ? 'Flat fee' : 'Per hour',
                                            style: GoogleFonts.poppins(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: t.isFlat
                                                  ? AppColors.info
                                                  : context.colors.primary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 62,
                                      child: Text(
                                        _fmt(t.price),
                                        textAlign: TextAlign.right,
                                        style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: context.colors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!isLast)
                                Divider(
                                  height: 1,
                                  indent: 14,
                                  endIndent: 14,
                                  color: context.colors.border,
                                ),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ],

              // ── Navigate button ───────────────────────────────────
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _openMaps(loc),
                    style: FilledButton.styleFrom(
                      backgroundColor: isFull
                          ? context.colors.textMuted
                          : AppColors.primaryDark,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    icon: Icon(
                      isFull ? Icons.block_rounded : Icons.directions_rounded,
                      size: 18,
                    ),
                    label: Text(isFull ? 'Lot Full — Navigate Anyway' : 'Navigate Here'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoCell(IconData icon, String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: context.colors.textMuted,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: context.colors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _vertDivider() {
    return Container(
      width: 1,
      height: 36,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: context.colors.divider,
    );
  }

  Widget _chip(IconData icon, String label, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(double v) =>
      v.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
}
