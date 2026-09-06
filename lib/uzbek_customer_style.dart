import 'package:flutter/material.dart';

abstract final class UzbekCustomerColors {
  static const background = Color(0xFFFBF7EF);
  static const surface = Color(0xFFFFFCF7);
  static const ivory = Color(0xFFFFFAF0);
  static const navy = Color(0xFF17324D);
  static const navy2 = Color(0xFF214965);
  static const teal = Color(0xFF0F8B8D);
  static const tealDark = Color(0xFF0B666C);
  static const gold = Color(0xFFE6B84A);
  static const goldDeep = Color(0xFFC98518);
  static const goldSoft = Color(0xFFF8E9C8);
  static const border = Color(0xFFE8D9B9);
  static const textMuted = Color(0xFF6E665C);
  static const success = Color(0xFF1B8C5A);
}

class UzbekPatternPanel extends StatelessWidget {
  const UzbekPatternPanel({
    super.key,
    required this.child,
    this.dark = false,
    this.padding = const EdgeInsets.all(16),
    this.radius = 24,
  });

  final Widget child;
  final bool dark;
  final EdgeInsets padding;
  final double radius;

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
              : const [UzbekCustomerColors.surface, Color(0xFFF8F0DF)],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: dark ? const Color(0x3348C7C9) : UzbekCustomerColors.border,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x100F3B45),
            blurRadius: 22,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _UzbekPatternPainter(dark: dark)),
            ),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
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
            ? const Color(0x16FFFFFF)
            : Colors.white.withValues(alpha: .82),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: dark ? const Color(0x2AFFFFFF) : color.withValues(alpha: .18),
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
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: UzbekCustomerColors.goldSoft,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: UzbekCustomerColors.border),
          ),
          child: Icon(icon, size: 19, color: UzbekCustomerColors.goldDeep),
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
  Widget build(BuildContext context) => Container(
    height: 3,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [
          UzbekCustomerColors.teal,
          UzbekCustomerColors.gold,
          UzbekCustomerColors.teal,
        ],
      ),
    ),
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
      ..color = UzbekCustomerColors.teal.withValues(alpha: .58);
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = UzbekCustomerColors.gold.withValues(alpha: .42);
    final p = Path()
      ..moveTo(center.dx, 2)
      ..lineTo(size.width - 2, center.dy)
      ..lineTo(center.dx, size.height - 2)
      ..lineTo(2, center.dy)
      ..close();
    canvas.drawPath(p, stroke);
    canvas.drawCircle(center, 4, fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _UzbekPatternPainter extends CustomPainter {
  const _UzbekPatternPainter({required this.dark});
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.05
      ..color = (dark ? Colors.white : UzbekCustomerColors.teal).withValues(
        alpha: dark ? .075 : .065,
      );
    final dot = Paint()
      ..style = PaintingStyle.fill
      ..color = UzbekCustomerColors.gold.withValues(alpha: dark ? .10 : .085);

    const step = 58.0;
    for (double y = 18; y < size.height + step; y += step) {
      for (double x = 18; x < size.width + step; x += step) {
        final c = Offset(x, y);
        final diamond = Path()
          ..moveTo(c.dx, c.dy - 11)
          ..lineTo(c.dx + 11, c.dy)
          ..lineTo(c.dx, c.dy + 11)
          ..lineTo(c.dx - 11, c.dy)
          ..close();
        canvas.drawPath(diamond, stroke);
        canvas.drawCircle(c, 2.5, dot);
        canvas.drawCircle(c, 16, stroke);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _UzbekPatternPainter oldDelegate) =>
      oldDelegate.dark != dark;
}
