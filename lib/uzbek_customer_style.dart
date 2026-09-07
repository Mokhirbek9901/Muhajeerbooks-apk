import 'package:flutter/material.dart';

abstract final class UzbekCustomerColors {
  static const background = Color(0xFFF8F1E6);
  static const surface = Color(0xFFFFFCF7);
  static const ivory = Color(0xFFFFF8ED);
  static const navy = Color(0xFF0E2B45);
  static const navy2 = Color(0xFF183F5D);
  static const teal = Color(0xFF087F83);
  static const tealDark = Color(0xFF075B61);
  static const turquoise = Color(0xFF2DA7A3);
  static const gold = Color(0xFFE1AE45);
  static const goldDeep = Color(0xFFC98218);
  static const goldSoft = Color(0xFFF8E6BF);
  static const border = Color(0xFFE4CFAB);
  static const textMuted = Color(0xFF6D6256);
  static const success = Color(0xFF1B8C5A);
  static const red = Color(0xFFB74B42);
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
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [UzbekCustomerColors.navy, UzbekCustomerColors.tealDark]
              : const [UzbekCustomerColors.surface, Color(0xFFF7EAD3)],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: dark ? const Color(0x665AC7C4) : UzbekCustomerColors.border,
          width: strongPattern ? 1.4 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x16082D36),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _UzbekPatternPainter(
                  dark: dark,
                  strong: strongPattern,
                ),
              ),
            ),
          ),
          Positioned(
            left: -14,
            top: -14,
            child: IgnorePointer(
              child: SizedBox(
                width: 82,
                height: 82,
                child: CustomPaint(painter: _CornerSuzaniPainter(dark: dark)),
              ),
            ),
          ),
          Positioned(
            right: -14,
            bottom: -14,
            child: Transform.rotate(
              angle: 3.1415926535,
              child: IgnorePointer(
                child: SizedBox(
                  width: 82,
                  height: 82,
                  child: CustomPaint(painter: _CornerSuzaniPainter(dark: dark)),
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
  Widget build(BuildContext context) => SizedBox(
    height: height,
    width: double.infinity,
    child: const CustomPaint(painter: _AtlasBandPainter()),
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
    final foreground = dark ? Colors.white : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: dark
            ? const Color(0x18FFFFFF)
            : Colors.white.withValues(alpha: .9),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: dark ? const Color(0x38FFFFFF) : color.withValues(alpha: .22),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: dark ? UzbekCustomerColors.gold : foreground,
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: foreground,
              fontSize: 11.3,
              fontWeight: FontWeight.w800,
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [UzbekCustomerColors.goldSoft, Color(0xFFFFF5DF)],
            ),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: UzbekCustomerColors.border),
          ),
          child: Icon(icon, size: 20, color: UzbekCustomerColors.goldDeep),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: UzbekCustomerColors.navy,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.2,
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
                  ),
                ),
              ],
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
  Widget build(BuildContext context) => const UzbekAtlasBand(height: 5);
}

class UzbekOrnamentDivider extends StatelessWidget {
  const UzbekOrnamentDivider({super.key});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Container(height: 1, color: UzbekCustomerColors.border)),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 9),
        child: _SmallOrnament(),
      ),
      Expanded(child: Container(height: 1, color: UzbekCustomerColors.border)),
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
    width: 28,
    height: 28,
    child: CustomPaint(painter: _SingleMotifPainter()),
  );
}

class _SingleMotifPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = UzbekCustomerColors.teal.withValues(alpha: .62);
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = UzbekCustomerColors.gold.withValues(alpha: .55);
    final p = Path()
      ..moveTo(center.dx, 2)
      ..lineTo(size.width - 2, center.dy)
      ..lineTo(center.dx, size.height - 2)
      ..lineTo(2, center.dy)
      ..close();
    canvas.drawPath(p, stroke);
    canvas.drawCircle(center, 4, fill);
    canvas.drawCircle(center, 9, stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _UzbekPatternPainter extends CustomPainter {
  const _UzbekPatternPainter({required this.dark, required this.strong});
  final bool dark;
  final bool strong;

  @override
  void paint(Canvas canvas, Size size) {
    final alpha = strong ? .16 : .085;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strong ? 1.25 : 1.05
      ..color = (dark ? Colors.white : UzbekCustomerColors.teal).withValues(
        alpha: dark ? alpha * .72 : alpha,
      );
    final gold = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = UzbekCustomerColors.gold.withValues(alpha: strong ? .18 : .11);

    const step = 54.0;
    for (double y = 16; y < size.height + step; y += step) {
      for (double x = 16; x < size.width + step; x += step) {
        final c = Offset(x, y);
        final diamond = Path()
          ..moveTo(c.dx, c.dy - 12)
          ..lineTo(c.dx + 12, c.dy)
          ..lineTo(c.dx, c.dy + 12)
          ..lineTo(c.dx - 12, c.dy)
          ..close();
        canvas.drawPath(diamond, stroke);
        canvas.drawCircle(c, 17, gold);
        canvas.drawCircle(c, 4.5, stroke);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _UzbekPatternPainter oldDelegate) =>
      oldDelegate.dark != dark || oldDelegate.strong != strong;
}

class _AtlasBandPainter extends CustomPainter {
  const _AtlasBandPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = UzbekCustomerColors.navy;
    final teal = Paint()..color = UzbekCustomerColors.teal;
    final gold = Paint()..color = UzbekCustomerColors.gold;
    canvas.drawRect(Offset.zero & size, bg);
    const w = 24.0;
    for (double x = -w; x < size.width + w; x += w) {
      final p1 = Path()
        ..moveTo(x, 0)
        ..lineTo(x + w * .5, size.height)
        ..lineTo(x + w, 0)
        ..close();
      canvas.drawPath(p1, ((x / w).round().isEven) ? teal : gold);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CornerSuzaniPainter extends CustomPainter {
  const _CornerSuzaniPainter({required this.dark});
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = (dark ? UzbekCustomerColors.gold : UzbekCustomerColors.teal)
          .withValues(alpha: dark ? .32 : .18);
    final c = Offset(size.width * .22, size.height * .22);
    for (final r in [18.0, 28.0, 38.0]) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        0,
        1.5707963268,
        false,
        stroke,
      );
    }
    final p = Path()
      ..moveTo(c.dx + 6, c.dy)
      ..lineTo(c.dx + 18, c.dy + 12)
      ..lineTo(c.dx + 6, c.dy + 24)
      ..lineTo(c.dx - 6, c.dy + 12)
      ..close();
    canvas.drawPath(p, stroke);
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
      ..strokeWidth = 2
      ..color = dark ? UzbekCustomerColors.gold : UzbekCustomerColors.teal;
    final soft = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = (dark ? Colors.white : UzbekCustomerColors.goldDeep).withValues(
        alpha: .45,
      );
    canvas.drawCircle(c, size.width * .42, ring);
    canvas.drawCircle(c, size.width * .30, soft);
    for (var i = 0; i < 8; i++) {
      final angle = i * 0.7853981634;
      final dx = c.dx + size.width * .28 * MathLike.cos(angle);
      final dy = c.dy + size.width * .28 * MathLike.sin(angle);
      canvas.drawCircle(Offset(dx, dy), size.width * .055, soft);
    }
    final diamond = Path()
      ..moveTo(c.dx, c.dy - size.width * .18)
      ..lineTo(c.dx + size.width * .18, c.dy)
      ..lineTo(c.dx, c.dy + size.width * .18)
      ..lineTo(c.dx - size.width * .18, c.dy)
      ..close();
    canvas.drawPath(diamond, ring);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

abstract final class MathLike {
  static double sin(double x) {
    var term = x;
    var sum = x;
    for (var i = 1; i < 8; i++) {
      term *= -x * x / ((2 * i) * (2 * i + 1));
      sum += term;
    }
    return sum;
  }

  static double cos(double x) => sin(x + 1.5707963268);
}
