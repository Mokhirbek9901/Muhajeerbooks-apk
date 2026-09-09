import 'package:flutter/material.dart';

abstract final class UzbekCustomerColors {
  static const background = Color(0xFFF4EBDD);
  static const surface = Color(0xFFFFFCF6);
  static const ivory = Color(0xFFFFF7E7);
  static const navy = Color(0xFF082F49);
  static const navy2 = Color(0xFF0C4A6E);
  static const teal = Color(0xFF0F766E);
  static const tealDark = Color(0xFF115E59);
  static const turquoise = Color(0xFF14B8A6);
  static const gold = Color(0xFFD9A441);
  static const goldDeep = Color(0xFFB7791F);
  static const goldSoft = Color(0xFFF8E7BE);
  static const terracotta = Color(0xFFB85C45);
  static const border = Color(0xFFD8C3A3);
  static const textMuted = Color(0xFF74695D);
  static const success = Color(0xFF2E7D5B);
  static const red = Color(0xFFB85042);
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
    final borderColor = dark
        ? UzbekCustomerColors.gold.withValues(alpha: .62)
        : UzbekCustomerColors.border;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [
                  UzbekCustomerColors.navy,
                  UzbekCustomerColors.tealDark,
                  Color(0xFF0D5B66),
                ]
              : const [
                  UzbekCustomerColors.surface,
                  Color(0xFFFFF6E5),
                  Color(0xFFF8EBD5),
                ],
          stops: const [0, .58, 1],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor, width: strongPattern ? 1.8 : 1),
        boxShadow: [
          BoxShadow(
            color: (dark ? UzbekCustomerColors.navy : const Color(0xFF5D452F))
                .withValues(alpha: dark ? .22 : .10),
            blurRadius: strongPattern ? 30 : 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _IkatFieldPainter(dark: dark, strong: strongPattern),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Padding(
                padding: const EdgeInsets.all(7),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular((radius - 7).clamp(8, 99)),
                    border: Border.all(
                      color: dark
                          ? Colors.white.withValues(alpha: .13)
                          : UzbekCustomerColors.gold.withValues(alpha: .22),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: -18,
            top: -18,
            child: IgnorePointer(
              child: SizedBox(
                width: 112,
                height: 112,
                child: CustomPaint(painter: _CornerRosettePainter(dark: dark)),
              ),
            ),
          ),
          Positioned(
            right: -18,
            bottom: -18,
            child: Transform.rotate(
              angle: 3.1415926535,
              child: IgnorePointer(
                child: SizedBox(
                  width: 112,
                  height: 112,
                  child: CustomPaint(painter: _CornerRosettePainter(dark: dark)),
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
      child: const CustomPaint(painter: _AtlasBandPainter()),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: dark
              ? [
                  Colors.white.withValues(alpha: .13),
                  UzbekCustomerColors.gold.withValues(alpha: .12),
                ]
              : [
                  Colors.white.withValues(alpha: .96),
                  UzbekCustomerColors.goldSoft.withValues(alpha: .7),
                ],
        ),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: dark
              ? UzbekCustomerColors.gold.withValues(alpha: .42)
              : color.withValues(alpha: .26),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dark
                  ? UzbekCustomerColors.gold.withValues(alpha: .18)
                  : color.withValues(alpha: .10),
            ),
            child: Icon(
              icon,
              size: 12,
              color: dark ? UzbekCustomerColors.gold : color,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: foreground,
              fontSize: 11.3,
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
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [UzbekCustomerColors.navy, UzbekCustomerColors.teal],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: UzbekCustomerColors.gold, width: 1.2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A082F49),
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.all(4),
                  child: CustomPaint(painter: _TinyFramePainter()),
                ),
              ),
              Icon(icon, size: 20, color: UzbekCustomerColors.goldSoft),
            ],
          ),
        ),
        const SizedBox(width: 11),
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
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 3,
                    decoration: BoxDecoration(
                      color: UzbekCustomerColors.gold,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 16,
                    height: 3,
                    decoration: BoxDecoration(
                      color: UzbekCustomerColors.teal,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        const _SmallOrnament(),
      ],
    );
  }
}

class UzbekAccentLine extends StatelessWidget {
  const UzbekAccentLine({super.key});

  @override
  Widget build(BuildContext context) => const UzbekAtlasBand(height: 6);
}

class UzbekOrnamentDivider extends StatelessWidget {
  const UzbekOrnamentDivider({super.key});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Container(
          height: 1,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.transparent, UzbekCustomerColors.border],
            ),
          ),
        ),
      ),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 10),
        child: _SmallOrnament(),
      ),
      Expanded(
        child: Container(
          height: 1,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [UzbekCustomerColors.border, Colors.transparent],
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
    child: CustomPaint(painter: _MedallionPainter(dark: dark)),
  );
}

class _SmallOrnament extends StatelessWidget {
  const _SmallOrnament();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 30,
    height: 30,
    child: CustomPaint(painter: _SingleMotifPainter()),
  );
}

class _TinyFramePainter extends CustomPainter {
  const _TinyFramePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = UzbekCustomerColors.gold.withValues(alpha: .36);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(10),
      ),
      paint,
    );
    canvas.drawLine(Offset(3, size.height / 2), Offset(9, size.height / 2), paint);
    canvas.drawLine(
      Offset(size.width - 9, size.height / 2),
      Offset(size.width - 3, size.height / 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SingleMotifPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.45
      ..color = UzbekCustomerColors.teal.withValues(alpha: .72);
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = UzbekCustomerColors.gold.withValues(alpha: .68);
    final diamond = Path()
      ..moveTo(center.dx, 2)
      ..lineTo(size.width - 2, center.dy)
      ..lineTo(center.dx, size.height - 2)
      ..lineTo(2, center.dy)
      ..close();
    canvas.drawPath(diamond, stroke);
    canvas.drawCircle(center, 10, stroke);
    canvas.drawCircle(center, 4, fill);
    for (final angle in [0.0, 1.5707963268, 3.1415926535, 4.7123889803]) {
      final dx = center.dx + 8 * _cos(angle);
      final dy = center.dy + 8 * _sin(angle);
      canvas.drawCircle(Offset(dx, dy), 1.7, fill);
    }
  }

  double _sin(double x) {
    if (x == 0 || x == 3.1415926535) return 0;
    return x < 3 ? 1 : -1;
  }

  double _cos(double x) {
    if (x == 1.5707963268 || x == 4.7123889803) return 0;
    return x < 1 ? 1 : -1;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _IkatFieldPainter extends CustomPainter {
  const _IkatFieldPainter({required this.dark, required this.strong});
  final bool dark;
  final bool strong;

  @override
  void paint(Canvas canvas, Size size) {
    final motif = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strong ? 1.2 : .9
      ..color = (dark ? Colors.white : UzbekCustomerColors.teal).withValues(
        alpha: strong ? (dark ? .11 : .085) : (dark ? .07 : .05),
      );
    final gold = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .9
      ..color = UzbekCustomerColors.gold.withValues(
        alpha: strong ? (dark ? .18 : .12) : .07,
      );

    const stepX = 62.0;
    const stepY = 48.0;
    for (double y = -10; y < size.height + stepY; y += stepY) {
      for (double x = -12; x < size.width + stepX; x += stepX) {
        final rowOffset = ((y / stepY).round().isOdd) ? stepX / 2 : 0;
        final c = Offset(x + rowOffset, y);
        final p = Path()
          ..moveTo(c.dx, c.dy - 13)
          ..quadraticBezierTo(c.dx + 11, c.dy - 6, c.dx + 13, c.dy)
          ..quadraticBezierTo(c.dx + 11, c.dy + 6, c.dx, c.dy + 13)
          ..quadraticBezierTo(c.dx - 11, c.dy + 6, c.dx - 13, c.dy)
          ..quadraticBezierTo(c.dx - 11, c.dy - 6, c.dx, c.dy - 13)
          ..close();
        canvas.drawPath(p, motif);
        canvas.drawCircle(c, 18, gold);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _IkatFieldPainter oldDelegate) =>
      oldDelegate.dark != dark || oldDelegate.strong != strong;
}

class _AtlasBandPainter extends CustomPainter {
  const _AtlasBandPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = UzbekCustomerColors.navy;
    final teal = Paint()..color = UzbekCustomerColors.teal;
    final turquoise = Paint()..color = UzbekCustomerColors.turquoise;
    final gold = Paint()..color = UzbekCustomerColors.gold;
    final terra = Paint()..color = UzbekCustomerColors.terracotta;
    canvas.drawRect(Offset.zero & size, bg);
    const w = 34.0;
    for (double x = -w; x < size.width + w; x += w) {
      final index = ((x / w).floor()).abs() % 4;
      final paint = switch (index) {
        0 => teal,
        1 => gold,
        2 => turquoise,
        _ => terra,
      };
      final p = Path()
        ..moveTo(x, 0)
        ..lineTo(x + w * .34, size.height)
        ..lineTo(x + w * .68, 0)
        ..lineTo(x + w, 0)
        ..lineTo(x + w * .66, size.height)
        ..lineTo(x + w * .32, 0)
        ..close();
      canvas.drawPath(p, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CornerRosettePainter extends CustomPainter {
  const _CornerRosettePainter({required this.dark});
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * .22, size.height * .22);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25
      ..color = (dark ? UzbekCustomerColors.gold : UzbekCustomerColors.teal)
          .withValues(alpha: dark ? .28 : .14);
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = (dark ? UzbekCustomerColors.gold : UzbekCustomerColors.terracotta)
          .withValues(alpha: dark ? .08 : .055);
    for (final r in [18.0, 30.0, 43.0]) {
      canvas.drawCircle(center, r, stroke);
    }
    for (var i = 0; i < 4; i++) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(i * 1.5707963268);
      final petal = Path()
        ..moveTo(0, -7)
        ..quadraticBezierTo(14, -23, 28, 0)
        ..quadraticBezierTo(14, 9, 0, 7)
        ..quadraticBezierTo(-5, 0, 0, -7)
        ..close();
      canvas.drawPath(petal, fill);
      canvas.drawPath(petal, stroke);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MedallionPainter extends CustomPainter {
  const _MedallionPainter({required this.dark});
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..color = dark ? UzbekCustomerColors.gold : UzbekCustomerColors.teal;
    final soft = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = (dark ? Colors.white : UzbekCustomerColors.goldDeep).withValues(
        alpha: .42,
      );
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = (dark ? UzbekCustomerColors.gold : UzbekCustomerColors.teal)
          .withValues(alpha: .11);

    canvas.drawCircle(c, size.width * .43, soft);
    canvas.drawCircle(c, size.width * .34, ring);
    canvas.drawCircle(c, size.width * .14, fill);
    for (var i = 0; i < 8; i++) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(i * .7853981634);
      final p = Path()
        ..moveTo(0, -size.width * .13)
        ..quadraticBezierTo(
          size.width * .08,
          -size.width * .25,
          0,
          -size.width * .31,
        )
        ..quadraticBezierTo(
          -size.width * .08,
          -size.width * .25,
          0,
          -size.width * .13,
        );
      canvas.drawPath(p, ring);
      canvas.restore();
    }
    canvas.drawCircle(c, size.width * .055, Paint()..color = UzbekCustomerColors.gold);
  }

  @override
  bool shouldRepaint(covariant _MedallionPainter oldDelegate) =>
      oldDelegate.dark != dark;
}
