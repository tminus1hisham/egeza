import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../blocs/app_bloc.dart';
import '../core/in_app_update_service.dart';
import '../core/theme/app_colors.dart';
import 'instant_parking_page.dart';
import 'dashboard/main_nav.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    InAppUpdateService.checkForUpdate();
    Future.delayed(const Duration(milliseconds: 2800), _navigate);
  }

  void _navigate() {
    if (!mounted) return;
    final bloc = context.read<AppBloc>();
    final isAuthenticated = bloc.state.isAuthenticated;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, animation, _) => isAuthenticated
            ? const MainNavigation()
            : const InstantParkingPage(),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          final compactHeight = size.height < 720;
          final logoSize = _clamp(size.width * 0.29, 104, 142);
          final logoTop = _clamp(
            size.height * (compactHeight ? 0.115 : 0.15),
            72,
            150,
          );
          final sceneTop = _clamp(
            size.height * 0.49,
            330,
            math.max(330, size.height * 0.56),
          );
          final sceneHeight = _clamp(size.height * 0.32, 224, 320);

          return Stack(
            children: [
              Positioned.fill(child: _SplashBackground(isDark: isDark)),
              Positioned(
                top: logoTop,
                left: 0,
                right: 0,
                child: _BrandLockup(
                  isDark: isDark,
                  logoSize: logoSize,
                  compact: compactHeight,
                ),
              ),
              Positioned(
                top: sceneTop,
                left: 0,
                right: 0,
                child:
                    SizedBox(
                          height: sceneHeight,
                          child: _ParkingScene(isDark: isDark),
                        )
                        .animate(delay: 650.ms)
                        .fadeIn(duration: 700.ms, curve: Curves.easeOut)
                        .slideY(
                          begin: 0.08,
                          end: 0,
                          duration: 700.ms,
                          curve: Curves.easeOutCubic,
                        ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SplashBackground extends StatelessWidget {
  const _SplashBackground({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? const [
                  Color(0xFF042F2C),
                  Color(0xFF063D38),
                  Color(0xFF052C28),
                  Color(0xFF031F1D),
                ]
              : const [
                  Color(0xFFFFFFFF),
                  Color(0xFFFBFEFD),
                  Color(0xFFF6FCFA),
                  Color(0xFFFFFFFF),
                ],
          stops: isDark ? const [0, 0.36, 0.7, 1] : const [0, 0.45, 0.72, 1],
        ),
      ),
      child: CustomPaint(
        painter: _SplashBackgroundPainter(isDark: isDark),
        size: Size.infinite,
      ),
    );
  }
}

class _SplashBackgroundPainter extends CustomPainter {
  const _SplashBackgroundPainter({required this.isDark});

  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final logoGlowRect = Rect.fromCenter(
      center: Offset(size.width * 0.5, size.height * 0.245),
      width: size.width * 0.64,
      height: size.width * 0.64,
    );
    final logoGlow = Paint()
      ..shader = ui.Gradient.radial(
        logoGlowRect.center,
        logoGlowRect.width * 0.5,
        isDark
            ? [
                const Color(0xFF19B997).withValues(alpha: 0.16),
                const Color(0xFF0B6155).withValues(alpha: 0.06),
                Colors.transparent,
              ]
            : [
                const Color(0xFF36D6AC).withValues(alpha: 0.2),
                const Color(0xFFBAEFE4).withValues(alpha: 0.22),
                Colors.transparent,
              ],
        const [0, 0.45, 1],
      );
    canvas.drawRect(logoGlowRect, logoGlow);

    final lowerMistRect = Rect.fromLTWH(
      0,
      size.height * 0.42,
      size.width,
      size.height * 0.36,
    );
    final lowerMist = Paint()
      ..shader = ui.Gradient.linear(
        lowerMistRect.topCenter,
        lowerMistRect.bottomCenter,
        isDark
            ? [
                Colors.transparent,
                const Color(0xFF11A889).withValues(alpha: 0.12),
                Colors.transparent,
              ]
            : [
                Colors.transparent,
                const Color(0xFFDCF6F0).withValues(alpha: 0.5),
                Colors.transparent,
              ],
        const [0.0, 0.5, 1.0],
      );
    canvas.drawRect(lowerMistRect, lowerMist);

    final sweep = Path()
      ..moveTo(size.width * 0.68, size.height * 0.53)
      ..cubicTo(
        size.width * 0.82,
        size.height * 0.43,
        size.width * 0.9,
        size.height * 0.45,
        size.width,
        size.height * 0.43,
      )
      ..lineTo(size.width, size.height * 0.68)
      ..cubicTo(
        size.width * 0.86,
        size.height * 0.64,
        size.width * 0.76,
        size.height * 0.61,
        size.width * 0.64,
        size.height * 0.66,
      )
      ..close();
    canvas.drawPath(
      sweep,
      Paint()
        ..style = PaintingStyle.fill
        ..color = isDark
            ? const Color(0xFF1EC7A3).withValues(alpha: 0.05)
            : const Color(0xFFD7F4EF).withValues(alpha: 0.62),
    );
  }

  @override
  bool shouldRepaint(covariant _SplashBackgroundPainter oldDelegate) {
    return oldDelegate.isDark != isDark;
  }
}

class _BrandLockup extends StatelessWidget {
  const _BrandLockup({
    required this.isDark,
    required this.logoSize,
    required this.compact,
  });

  final bool isDark;
  final double logoSize;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final titleSize = compact ? 42.0 : 52.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _LogoMark(size: logoSize, isDark: isDark),
        SizedBox(height: compact ? 28 : 34),
        _AppName(isDark: isDark, fontSize: titleSize),
        const SizedBox(height: 7),
        _Tagline(isDark: isDark),
        SizedBox(height: compact ? 26 : 32),
        _LoadingMark(isDark: isDark),
      ],
    );
  }
}

class _LogoMark extends StatelessWidget {
  const _LogoMark({required this.size, required this.isDark});

  final double size;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
          width: size * 1.7,
          height: size * 1.7,
          child: Stack(
            alignment: Alignment.center,
            children: [
              for (final ring in const [1.7, 1.42, 1.18])
                Container(
                  width: size * ring,
                  height: size * ring,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(size * 0.34 * ring),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.018)
                          : const Color(0xFF5BE0C1).withValues(alpha: 0.055),
                      width: 1,
                    ),
                    color: isDark
                        ? const Color(0xFF12B394).withValues(alpha: 0.018)
                        : const Color(0xFF33D0A8).withValues(alpha: 0.03),
                  ),
                ),
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(size * 0.26),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.38)
                          : const Color(0xFF8ADCCB).withValues(alpha: 0.38),
                      blurRadius: 36,
                      spreadRadius: 2,
                      offset: const Offset(0, 18),
                    ),
                    BoxShadow(
                      color: const Color(
                        0xFF31D8A4,
                      ).withValues(alpha: isDark ? 0.2 : 0.22),
                      blurRadius: 52,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(size * 0.26),
                  child: Image.asset(
                    isDark ? 'assets/iconblack.png' : 'assets/iconwhite.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 650.ms, curve: Curves.easeOut)
        .scale(
          begin: const Offset(0.82, 0.82),
          end: const Offset(1, 1),
          duration: 780.ms,
          curve: Curves.easeOutBack,
        );
  }
}

class _AppName extends StatelessWidget {
  const _AppName({required this.isDark, required this.fontSize});

  final bool isDark;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return RichText(
          text: TextSpan(
            style: GoogleFonts.poppins(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
              height: 1,
              shadows: isDark
                  ? [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        offset: const Offset(0, 6),
                        blurRadius: 18,
                      ),
                    ]
                  : null,
            ),
            children: [
              const TextSpan(
                text: 'E',
                style: TextStyle(color: Color(0xFF32D79A)),
              ),
              TextSpan(
                text: 'gesha',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF1D2B34),
                ),
              ),
            ],
          ),
        )
        .animate(delay: 260.ms)
        .fadeIn(duration: 520.ms)
        .slideY(begin: 0.2, end: 0, duration: 520.ms, curve: Curves.easeOut);
  }
}

class _Tagline extends StatelessWidget {
  const _Tagline({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Text(
          'Smart Parking, Simplified',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w400,
            letterSpacing: 0,
            color: isDark
                ? Colors.white.withValues(alpha: 0.68)
                : const Color(0xFF74818A),
          ),
        )
        .animate(delay: 420.ms)
        .fadeIn(duration: 500.ms)
        .slideY(begin: 0.2, end: 0, duration: 500.ms, curve: Curves.easeOut);
  }
}

class _LoadingMark extends StatelessWidget {
  const _LoadingMark({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
          width: 78,
          height: 4,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: 2,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: isDark
                      ? const Color(0xFF47D1B2).withValues(alpha: 0.26)
                      : const Color(0xFFB6F0E2),
                ),
              ),
              Container(
                width: 36,
                height: 3,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: const Color(0xFF2EE68F),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2EE68F).withValues(alpha: 0.4),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
            ],
          ),
        )
        .animate(delay: 620.ms)
        .fadeIn(duration: 450.ms)
        .scaleX(begin: 0, end: 1, duration: 520.ms, curve: Curves.easeOutCubic);
  }
}

class _ParkingScene extends StatelessWidget {
  const _ParkingScene({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ParkingScenePainter(isDark: isDark),
      size: Size.infinite,
    );
  }
}

class _ParkingScenePainter extends CustomPainter {
  const _ParkingScenePainter({required this.isDark});

  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    _drawCity(canvas, size);
    _drawGround(canvas, size);
    _drawParkingSpace(canvas, size);
    _drawSign(canvas, size);
    _drawLocationPin(canvas, size);
    _drawCar(canvas, size);
  }

  void _drawCity(Canvas canvas, Size size) {
    final baseY = size.height * 0.48;
    final buildings = <_BuildingSpec>[
      _BuildingSpec(0.08, 0.28, 0.055, true),
      _BuildingSpec(0.32, 0.16, 0.047, true),
      _BuildingSpec(0.42, 0.2, 0.05, false),
      _BuildingSpec(0.49, 0.12, 0.048, false),
      _BuildingSpec(0.56, 0.18, 0.052, false),
      _BuildingSpec(0.68, 0.25, 0.06, false),
      _BuildingSpec(0.76, 0.12, 0.047, false),
      _BuildingSpec(0.89, 0.24, 0.046, true),
    ];
    final buildingPaint = Paint()
      ..color = isDark
          ? const Color(0xFF13B091).withValues(alpha: 0.1)
          : const Color(0xFFBEECE6).withValues(alpha: 0.58);
    final windowPaint = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.white.withValues(alpha: 0.72);

    for (final building in buildings) {
      final width = size.width * building.widthFactor;
      final height = size.height * building.heightFactor;
      final left = size.width * building.xFactor - width / 2;
      final top = baseY - height;
      final body = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, width, height),
        Radius.circular(width * 0.09),
      );
      canvas.drawRRect(body, buildingPaint);

      if (building.hasSpire) {
        final spire = Path()
          ..moveTo(left + width * 0.5, top - height * 0.18)
          ..lineTo(left + width * 0.72, top)
          ..lineTo(left + width * 0.28, top)
          ..close();
        canvas.drawPath(spire, buildingPaint);
        canvas.drawLine(
          Offset(left + width * 0.5, top - height * 0.32),
          Offset(left + width * 0.5, top - height * 0.14),
          Paint()
            ..color = buildingPaint.color
            ..strokeWidth = 1,
        );
      }

      for (var row = 0; row < 5; row++) {
        for (var column = 0; column < 3; column++) {
          final windowWidth = width * 0.12;
          final x = left + width * (0.22 + column * 0.24);
          final y = top + height * (0.22 + row * 0.14);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x, y, windowWidth, height * 0.045),
              const Radius.circular(1),
            ),
            windowPaint,
          );
        }
      }
    }

    final haze = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, baseY - size.height * 0.06),
        Offset(0, size.height * 0.64),
        [
          Colors.transparent,
          (isDark ? const Color(0xFF062C28) : Colors.white).withValues(
            alpha: isDark ? 0.16 : 0.74,
          ),
        ],
      );
    canvas.drawRect(
      Rect.fromLTWH(
        0,
        baseY - size.height * 0.08,
        size.width,
        size.height * 0.24,
      ),
      haze,
    );
  }

  void _drawGround(Canvas canvas, Size size) {
    final horizon = size.height * 0.48;
    final ground = Rect.fromLTWH(0, horizon, size.width, size.height * 0.42);
    final paint = Paint()
      ..shader = ui.Gradient.linear(
        ground.topCenter,
        ground.bottomCenter,
        isDark
            ? [
                const Color(0xFF13B091).withValues(alpha: 0.05),
                const Color(0xFF10A386).withValues(alpha: 0.1),
                Colors.transparent,
              ]
            : [
                const Color(0xFFE8F9F5).withValues(alpha: 0.72),
                Colors.white.withValues(alpha: 0.72),
                Colors.transparent,
              ],
        const [0.0, 0.5, 1.0],
      );
    canvas.drawRect(ground, paint);

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = isDark
          ? const Color(0xFF5CE0C8).withValues(alpha: 0.06)
          : const Color(0xFFCFEDE7).withValues(alpha: 0.82);

    canvas.drawLine(
      Offset(0, size.height * 0.69),
      Offset(size.width, size.height * 0.56),
      linePaint,
    );
    canvas.drawLine(
      Offset(0, size.height * 0.57),
      Offset(size.width, size.height * 0.67),
      linePaint,
    );
  }

  void _drawParkingSpace(Canvas canvas, Size size) {
    final topLeft = Offset(size.width * 0.33, size.height * 0.68);
    final topRight = Offset(size.width * 0.67, size.height * 0.68);
    final bottomRight = Offset(size.width * 0.79, size.height * 0.88);
    final bottomLeft = Offset(size.width * 0.21, size.height * 0.88);

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFF35E2B1).withValues(alpha: isDark ? 0.16 : 0.1);
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.4
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = isDark ? const Color(0xFF32D8B0) : const Color(0xFF66E3C7);

    final path = Path()
      ..moveTo(topLeft.dx, topLeft.dy)
      ..lineTo(bottomLeft.dx, bottomLeft.dy)
      ..lineTo(bottomRight.dx, bottomRight.dy)
      ..lineTo(topRight.dx, topRight.dy);
    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, linePaint);
  }

  void _drawSign(Canvas canvas, Size size) {
    final signSize = size.width * 0.11;
    final center = Offset(size.width * 0.18, size.height * 0.43);
    final poleTop = center.dy + signSize * 0.52;
    final poleBottom = size.height * 0.75;

    final polePaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(center.dx, poleTop),
        Offset(center.dx, poleBottom),
        isDark
            ? const [Color(0xFF0A2B28), Color(0xFF145F53)]
            : const [Color(0xFFD6E5E2), Color(0xFFAFC9C4)],
      );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(center.dx - 2, poleTop, 4, poleBottom - poleTop),
        const Radius.circular(3),
      ),
      polePaint,
    );

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, poleBottom + 5),
        width: signSize * 0.95,
        height: signSize * 0.2,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: isDark ? 0.2 : 0.08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    final signRect = Rect.fromCenter(
      center: center,
      width: signSize,
      height: signSize,
    );
    final signRRect = RRect.fromRectAndRadius(
      signRect,
      Radius.circular(signSize * 0.15),
    );
    canvas.drawShadow(
      Path()..addRRect(signRRect),
      Colors.black.withValues(alpha: isDark ? 0.5 : 0.22),
      8,
      false,
    );
    canvas.drawRRect(
      signRRect.inflate(2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = const Color(0xFF55E8C6),
    );
    canvas.drawRRect(
      signRRect,
      Paint()
        ..shader = ui.Gradient.linear(
          signRect.topLeft,
          signRect.bottomRight,
          isDark
              ? const [Color(0xFF063C37), Color(0xFF0D7D6D)]
              : const [Color(0xFF6ADCC4), Color(0xFF159E83)],
        ),
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text: 'P',
        style: GoogleFonts.poppins(
          color: isDark ? const Color(0xFF33DCA3) : Colors.white,
          fontSize: signSize * 0.58,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2 + signSize * 0.02,
      ),
    );
  }

  void _drawLocationPin(Canvas canvas, Size size) {
    final pinHeight = size.height * 0.38;
    final pinWidth = pinHeight * 0.58;
    final centerX = size.width * 0.8;
    final topY = size.height * 0.44;
    final bottomY = topY + pinHeight;

    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: isDark ? 0.28 : 0.1)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centerX, bottomY + pinHeight * 0.05),
        width: pinWidth * 0.72,
        height: pinHeight * 0.13,
      ),
      shadow,
    );

    final pinPath = Path()
      ..moveTo(centerX, bottomY)
      ..cubicTo(
        centerX + pinWidth * 0.48,
        topY + pinHeight * 0.57,
        centerX + pinWidth * 0.5,
        topY + pinHeight * 0.18,
        centerX,
        topY,
      )
      ..cubicTo(
        centerX - pinWidth * 0.5,
        topY + pinHeight * 0.18,
        centerX - pinWidth * 0.48,
        topY + pinHeight * 0.57,
        centerX,
        bottomY,
      )
      ..close();
    canvas.drawShadow(
      pinPath,
      Colors.black.withValues(alpha: isDark ? 0.5 : 0.18),
      8,
      false,
    );
    canvas.drawPath(
      pinPath,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(centerX - pinWidth * 0.35, topY),
          Offset(centerX + pinWidth * 0.32, bottomY),
          isDark
              ? const [Color(0xFF41E4BE), Color(0xFF078370)]
              : const [Color(0xFF75E7CA), Color(0xFF20AA8F)],
        ),
    );
    canvas.drawPath(
      pinPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withValues(alpha: isDark ? 0.18 : 0.34),
    );

    final holeRect = Rect.fromCircle(
      center: Offset(centerX, topY + pinHeight * 0.31),
      radius: pinWidth * 0.17,
    );
    canvas.drawOval(
      holeRect,
      Paint()
        ..shader = ui.Gradient.radial(
          holeRect.center,
          holeRect.width * 0.5,
          isDark
              ? const [Color(0xFF022724), Color(0xFF0E6155)]
              : const [Color(0xFFFFFFFF), Color(0xFFDDF4EF)],
        ),
    );
  }

  void _drawCar(Canvas canvas, Size size) {
    final carWidth = size.width * 0.34;
    final carHeight = size.height * 0.35;
    final left = (size.width - carWidth) / 2;
    final top = size.height * 0.42;
    final rect = Rect.fromLTWH(left, top, carWidth, carHeight);

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(rect.center.dx, rect.bottom + carHeight * 0.05),
        width: carWidth * 0.9,
        height: carHeight * 0.16,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: isDark ? 0.38 : 0.13)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );

    final body = Path()
      ..moveTo(rect.left + carWidth * 0.1, rect.top + carHeight * 0.45)
      ..cubicTo(
        rect.left + carWidth * 0.17,
        rect.top + carHeight * 0.16,
        rect.left + carWidth * 0.3,
        rect.top + carHeight * 0.08,
        rect.left + carWidth * 0.5,
        rect.top + carHeight * 0.08,
      )
      ..cubicTo(
        rect.left + carWidth * 0.7,
        rect.top + carHeight * 0.08,
        rect.left + carWidth * 0.83,
        rect.top + carHeight * 0.16,
        rect.left + carWidth * 0.9,
        rect.top + carHeight * 0.45,
      )
      ..cubicTo(
        rect.left + carWidth * 0.96,
        rect.top + carHeight * 0.7,
        rect.left + carWidth * 0.9,
        rect.top + carHeight * 0.86,
        rect.left + carWidth * 0.79,
        rect.top + carHeight * 0.88,
      )
      ..lineTo(rect.left + carWidth * 0.21, rect.top + carHeight * 0.88)
      ..cubicTo(
        rect.left + carWidth * 0.1,
        rect.top + carHeight * 0.86,
        rect.left + carWidth * 0.04,
        rect.top + carHeight * 0.7,
        rect.left + carWidth * 0.1,
        rect.top + carHeight * 0.45,
      )
      ..close();
    canvas.drawShadow(
      body,
      Colors.black.withValues(alpha: isDark ? 0.65 : 0.18),
      12,
      false,
    );
    canvas.drawPath(
      body,
      Paint()
        ..shader = ui.Gradient.linear(
          rect.topCenter,
          rect.bottomCenter,
          isDark
              ? const [Color(0xFF2DD7BC), Color(0xFF0E5F58), Color(0xFF061F22)]
              : const [Color(0xFFE9FFFB), Color(0xFFB8E2DB), Color(0xFFE9F4F1)],
          isDark ? const [0, 0.45, 1] : const [0, 0.56, 1],
        ),
    );
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = isDark
            ? const Color(0xFF67FFE0).withValues(alpha: 0.12)
            : const Color(0xFF4FA895).withValues(alpha: 0.34),
    );

    final glass = Path()
      ..moveTo(rect.left + carWidth * 0.26, rect.top + carHeight * 0.2)
      ..quadraticBezierTo(
        rect.center.dx,
        rect.top + carHeight * 0.09,
        rect.left + carWidth * 0.74,
        rect.top + carHeight * 0.2,
      )
      ..lineTo(rect.left + carWidth * 0.82, rect.top + carHeight * 0.43)
      ..quadraticBezierTo(
        rect.center.dx,
        rect.top + carHeight * 0.37,
        rect.left + carWidth * 0.18,
        rect.top + carHeight * 0.43,
      )
      ..close();
    canvas.drawPath(
      glass,
      Paint()
        ..shader = ui.Gradient.linear(
          rect.topCenter,
          Offset(rect.center.dx, rect.top + carHeight * 0.46),
          isDark
              ? const [Color(0xFF052C2B), Color(0xFF0C5049)]
              : const [Color(0xFFE9F6F3), Color(0xFF7FA59D)],
        ),
    );
    canvas.drawPath(
      glass,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: isDark ? 0.16 : 0.5),
    );

    final trunkLine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = isDark
          ? Colors.black.withValues(alpha: 0.26)
          : const Color(0xFF73968F).withValues(alpha: 0.38);
    canvas.drawLine(
      Offset(rect.left + carWidth * 0.2, rect.top + carHeight * 0.56),
      Offset(rect.left + carWidth * 0.8, rect.top + carHeight * 0.56),
      trunkLine,
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(rect.center.dx, rect.top + carHeight * 0.62),
        width: carWidth * 0.08,
        height: carWidth * 0.08,
      ),
      0,
      6.28,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = isDark
            ? const Color(0xFF032926).withValues(alpha: 0.7)
            : const Color(0xFF9BB6AF),
    );

    _drawTailLight(
      canvas,
      Rect.fromLTWH(
        rect.left + carWidth * 0.08,
        rect.top + carHeight * 0.53,
        carWidth * 0.18,
        carHeight * 0.1,
      ),
    );
    _drawTailLight(
      canvas,
      Rect.fromLTWH(
        rect.left + carWidth * 0.74,
        rect.top + carHeight * 0.53,
        carWidth * 0.18,
        carHeight * 0.1,
      ),
    );

    final wheelPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, rect.top + carHeight * 0.72),
        Offset(0, rect.bottom),
        const [Color(0xFF0B1618), Color(0xFF010606)],
      );
    for (final x in [
      rect.left + carWidth * 0.18,
      rect.left + carWidth * 0.72,
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            x,
            rect.top + carHeight * 0.78,
            carWidth * 0.12,
            carHeight * 0.22,
          ),
          Radius.circular(carWidth * 0.05),
        ),
        wheelPaint,
      );
    }
  }

  void _drawTailLight(Canvas canvas, Rect rect) {
    final lightPath = Path()
      ..moveTo(rect.left, rect.top + rect.height * 0.15)
      ..lineTo(rect.right, rect.top + rect.height * 0.28)
      ..lineTo(rect.right - rect.width * 0.1, rect.bottom)
      ..lineTo(rect.left + rect.width * 0.1, rect.bottom - rect.height * 0.06)
      ..quadraticBezierTo(rect.left, rect.center.dy, rect.left, rect.top)
      ..close();
    canvas.drawPath(
      lightPath,
      Paint()
        ..color = const Color(0xFFFF4B5E).withValues(alpha: isDark ? 0.96 : 0.9)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, isDark ? 2 : 0),
    );
    canvas.drawPath(
      lightPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.54),
    );
  }

  @override
  bool shouldRepaint(covariant _ParkingScenePainter oldDelegate) {
    return oldDelegate.isDark != isDark;
  }
}

class _BuildingSpec {
  const _BuildingSpec(
    this.xFactor,
    this.heightFactor,
    this.widthFactor,
    this.hasSpire,
  );

  final double xFactor;
  final double heightFactor;
  final double widthFactor;
  final bool hasSpire;
}

double _clamp(double value, double min, double max) {
  return value.clamp(min, max).toDouble();
}
