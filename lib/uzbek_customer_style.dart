import 'dart:math' as math;

import 'package:flutter/material.dart';

abstract final class UzbekCustomerColors {
  static const background = Color(0xFFF7F3EA);
  static const surface = Color(0xFFFFFEFA);
  static const ivory = Color(0xFFF5EBD7);
  static const navy = Color(0xFF173F4A);
  static const navy2 = Color(0xFF1B5563);
  static const teal = Color(0xFF0D6E68);
  static const tealDark = Color(0xFF084F4A);
  static const turquoise = Color(0xFF3CA69B);
  static const gold = Color(0xFFC99B45);
  static const goldDeep = Color(0xFF9D6C25);
  static const goldSoft = Color(0xFFF4E2B9);
  static const terracotta = Color(0xFFB85E3F);
  static const border = Color(0xFFE4D7BC);
  static const textMuted = Color(0xFF756D62);
  static const success = Color(0xFF2E7D5B);
  static const red = Color(0xFFB64E4E);
}

class UzbekPatternPanel extends StatelessWidget {
  const UzbekPatternPanel({
    super.key,
    required this.child,
    this.dark = false,
    this.padding = const EdgeInsets.all(16),
    this.radius = 24,
    this.strongPattern = false,
  });

  final Widget child;
  final bool dark;
  final EdgeInsets padding;
  final double radius;
  final bool strongPattern;

  @override
  Widget build(BuildContext context) {
    final background = dark
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF123D46),
              UzbekCustomerColors.tealDark,
              Color(0xFF0A625A),
            ],
            stops: [0, .54, 1],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              UzbekCustomerColors.surface,
              Color(0xFFFFFAF0),
              Color(0xFFF6ECD8),
            ],
            stops: [0, .62, 1],
          );

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: background,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: dark
              ? UzbekCustomerColors.gold.withValues(alpha: .50)
              : UzbekCustomerColors.border,
          width: dark && strongPattern ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: dark ? const Color(0x30103B44) : const Color(0x140F3F47),
            blurRadius: strongPattern ? 28 : 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _ModernAtlasPainter(dark: dark, strong: strongPattern),
              ),
            ),
          ),
          if (dark)
            Positioned(
              right: -36,
              top: -44,
              child: IgnorePointer(
                child: SizedBox(
                  width: 170,
                  height: 170,
                  child: CustomPaint(
                    painter: _SuzaniRosettePainter(
                      color: UzbekCustomerColors.gold.withValues(alpha: .16),
                      lineColor: Colors.white.withValues(alpha: .09),
                    ),
                  ),
                ),
              ),
            ),
          if (!dark)
            Positioned(
              left: -30,
              bottom: -36,
              child: IgnorePointer(
                child: SizedBox(
                  width: 130,
                  height: 130,
                  child: CustomPaint(
                    painter: _SuzaniRosettePainter(
                      color: UzbekCustomerColors.gold.withValues(alpha: .08),
                      lineColor: UzbekCustomerColors.teal.withValues(
                        alpha: .05,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

class UzbekAtlasBand extends StatelessWidget {
  const UzbekAtlasBand({super.key, this.height = 7});

  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(height),
    child: SizedBox(
      height: height,
      width: double.infinity,
      child: const CustomPaint(painter: _AtlasRibbonPainter()),
    ),
  );
}

class UzbekMiniPill extends StatelessWidget {
  const UzbekMiniPill({
    super.key,
    required this.icon,
    required this.text,
    this.color = UzbekCustomerColors.teal,
    this.dark = false,
  });

  final IconData icon;
  final String text;
  final Color color;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final foreground = dark ? Colors.white : UzbekCustomerColors.navy;
    final background = dark
        ? Colors.white.withValues(alpha: .10)
        : UzbekCustomerColors.surface.withValues(alpha: .94);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: dark
              ? UzbekCustomerColors.gold.withValues(alpha: .45)
              : color.withValues(alpha: .20),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: dark
                  ? UzbekCustomerColors.gold.withValues(alpha: .18)
                  : color.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 13,
              color: dark ? UzbekCustomerColors.goldSoft : color,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            text,
            style: TextStyle(
              color: foreground,
              fontSize: 11.4,
              fontWeight: FontWeight.w900,
              letterSpacing: .05,
            ),
          ),
        ],
      ),
    );
  }
}

class UzbekSectionTitle extends StatelessWidget {
  const UzbekSectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.auto_awesome_rounded,
  });

  final String title;
  final String? subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: UzbekCustomerColors.navy,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: UzbekCustomerColors.gold.withValues(alpha: .85),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x17173F4A),
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: CustomPaint(
                    painter: _TileFramePainter(
                      color: UzbekCustomerColors.gold.withValues(alpha: .38),
                    ),
                  ),
                ),
              ),
              Icon(icon, size: 20, color: UzbekCustomerColors.goldSoft),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: UzbekCustomerColors.navy,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.25,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    color: UzbekCustomerColors.textMuted,
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 10),
        const _MiniTile(),
      ],
    );
  }
}

class UzbekAccentLine extends StatelessWidget {
  const UzbekAccentLine({super.key});

  @override
  Widget build(BuildContext context) => const UzbekAtlasBand(height: 5);
}

class UzbekOrnamentDivider extends StatelessWidget {
  const UzbekOrnamentDivider({super.key});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                UzbekCustomerColors.gold.withValues(alpha: .55),
              ],
            ),
          ),
        ),
      ),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 10),
        child: _MiniTile(),
      ),
      Expanded(
        child: Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                UzbekCustomerColors.gold.withValues(alpha: .55),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

class UzbekMedallion extends StatelessWidget {
  const UzbekMedallion({super.key, this.size = 72, this.dark = false});

  final double size;
  final bool dark;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(
      painter: _SuzaniRosettePainter(
        color: (dark ? UzbekCustomerColors.goldSoft : UzbekCustomerColors.gold)
            .withValues(alpha: dark ? .30 : .22),
        lineColor: (dark ? Colors.white : UzbekCustomerColors.teal).withValues(
          alpha: dark ? .23 : .18,
        ),
      ),
    ),
  );
}

class _MiniTile extends StatelessWidget {
  const _MiniTile();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 30,
    height: 30,
    child: CustomPaint(
      painter: _TileMotifPainter(
        lineColor: UzbekCustomerColors.teal.withValues(alpha: .72),
        fillColor: UzbekCustomerColors.gold.withValues(alpha: .72),
      ),
    ),
  );
}

class _ModernAtlasPainter extends CustomPainter {
  const _ModernAtlasPainter({required this.dark, required this.strong});

  final bool dark;
  final bool strong;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strong ? 1.0 : .75
      ..color = (dark ? Colors.white : UzbekCustomerColors.teal).withValues(
        alpha: dark ? (strong ? .085 : .055) : (strong ? .065 : .040),
      );
    final accent = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .8
      ..color = UzbekCustomerColors.gold.withValues(
        alpha: dark ? (strong ? .15 : .10) : (strong ? .10 : .06),
      );

    const stepX = 58.0;
    const stepY = 44.0;
    for (double y = -stepY; y < size.height + stepY; y += stepY) {
      final row = (y / stepY).round();
      final shift = row.isOdd ? stepX / 2 : 0.0;
      for (double x = -stepX; x < size.width + stepX; x += stepX) {
        final center = Offset(x + shift, y);
        final diamond = Path()
          ..moveTo(center.dx, center.dy - 12)
          ..lineTo(center.dx + 15, center.dy)
          ..lineTo(center.dx, center.dy + 12)
          ..lineTo(center.dx - 15, center.dy)
          ..close();
        canvas.drawPath(diamond, line);
        canvas.drawCircle(center, 18, accent);
        canvas.drawCircle(center, 4.5, line);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ModernAtlasPainter oldDelegate) =>
      oldDelegate.dark != dark || oldDelegate.strong != strong;
}

class _AtlasRibbonPainter extends CustomPainter {
  const _AtlasRibbonPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()..color = UzbekCustomerColors.navy;
    canvas.drawRect(Offset.zero & size, background);

    final segmentWidth = math.max(18.0, size.height * 3.1);
    final paints = [
      Paint()..color = UzbekCustomerColors.teal,
      Paint()..color = UzbekCustomerColors.gold,
      Paint()..color = UzbekCustomerColors.terracotta,
      Paint()..color = UzbekCustomerColors.turquoise,
      Paint()..color = UzbekCustomerColors.goldSoft,
    ];

    var i = 0;
    for (
      double x = -segmentWidth;
      x < size.width + segmentWidth;
      x += segmentWidth
    ) {
      final path = Path()
        ..moveTo(x, size.height)
        ..lineTo(x + segmentWidth * .48, 0)
        ..lineTo(x + segmentWidth, 0)
        ..lineTo(x + segmentWidth * .52, size.height)
        ..close();
      canvas.drawPath(path, paints[i % paints.length]);
      i++;
    }

    final line = Paint()
      ..color = Colors.white.withValues(alpha: .28)
      ..strokeWidth = .6;
    canvas.drawLine(Offset(0, .5), Offset(size.width, .5), line);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SuzaniRosettePainter extends CustomPainter {
  const _SuzaniRosettePainter({required this.color, required this.lineColor});

  final Color color;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * .42;
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = color;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = lineColor;

    for (var i = 0; i < 12; i++) {
      final angle = i * math.pi / 6;
      final petalCenter = Offset(
        center.dx + math.cos(angle) * radius * .48,
        center.dy + math.sin(angle) * radius * .48,
      );
      canvas.save();
      canvas.translate(petalCenter.dx, petalCenter.dy);
      canvas.rotate(angle);
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: radius * .54,
        height: radius * .23,
      );
      canvas.drawOval(rect, fill);
      canvas.restore();
    }

    canvas.drawCircle(center, radius * .36, stroke);
    canvas.drawCircle(center, radius * .18, fill);
    canvas.drawCircle(center, radius * .08, stroke);
  }

  @override
  bool shouldRepaint(covariant _SuzaniRosettePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.lineColor != lineColor;
}

class _TileFramePainter extends CustomPainter {
  const _TileFramePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color;
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(10),
    );
    canvas.drawRRect(rect, paint);
    canvas.drawLine(
      Offset(size.width / 2, 2),
      Offset(size.width / 2, 8),
      paint,
    );
    canvas.drawLine(
      Offset(size.width / 2, size.height - 8),
      Offset(size.width / 2, size.height - 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _TileFramePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _TileMotifPainter extends CustomPainter {
  const _TileMotifPainter({required this.lineColor, required this.fillColor});

  final Color lineColor;
  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.35
      ..color = lineColor;
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = fillColor;

    final outer = Path();
    for (var i = 0; i < 8; i++) {
      final angle = -math.pi / 2 + i * math.pi / 4;
      final r = i.isEven ? size.width * .43 : size.width * .28;
      final p = Offset(c.dx + math.cos(angle) * r, c.dy + math.sin(angle) * r);
      if (i == 0) {
        outer.moveTo(p.dx, p.dy);
      } else {
        outer.lineTo(p.dx, p.dy);
      }
    }
    outer.close();
    canvas.drawPath(outer, line);
    canvas.drawCircle(c, size.width * .19, line);
    canvas.drawCircle(c, size.width * .075, fill);
  }

  @override
  bool shouldRepaint(covariant _TileMotifPainter oldDelegate) =>
      oldDelegate.lineColor != lineColor || oldDelegate.fillColor != fillColor;
}
