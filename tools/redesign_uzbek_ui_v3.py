from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

DESIGN_SYSTEM = r'''import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

abstract final class AppColors {
  // Yangi o‘zbekona palitra: Buxoro ko‘ki, turkuaz, zafaron va iliq fil suyagi.
  static const navy = Color(0xFF123C4A);
  static const navy2 = Color(0xFF0B6570);
  static const orange = Color(0xFFC97822);
  static const gold = Color(0xFFE0B04B);
  static const background = Color(0xFFF7F0E3);
  static const surface = Color(0xFFFFFCF6);
  static const surfaceSoft = Color(0xFFF2E8D7);
  static const border = Color(0xFFD9C5A2);
  static const text = Color(0xFF203338);
  static const muted = Color(0xFF746C61);
  static const success = Color(0xFF2C7B57);
  static const successSoft = Color(0xFFE8F3EA);
  static const warning = Color(0xFFA66416);
  static const warningSoft = Color(0xFFFFF1D4);
  static const danger = Color(0xFFA84943);
  static const dangerSoft = Color(0xFFFBEAE6);
  static const info = Color(0xFF157E83);
  static const infoSoft = Color(0xFFE6F3F1);
}

abstract final class AppRadii {
  static const small = 14.0;
  static const medium = 19.0;
  static const large = 25.0;
  static const xl = 32.0;
}

abstract final class AppSpacing {
  static const xs = 6.0;
  static const sm = 10.0;
  static const md = 16.0;
  static const lg = 22.0;
  static const xl = 30.0;
}

abstract final class MuhajeerDesign {
  static ThemeData get theme {
    final base = ThemeData(useMaterial3: true, brightness: Brightness.light);
    final scheme = const ColorScheme.light(
      primary: AppColors.navy,
      onPrimary: Colors.white,
      secondary: AppColors.orange,
      onSecondary: Colors.white,
      tertiary: AppColors.gold,
      onTertiary: AppColors.text,
      surface: AppColors.surface,
      onSurface: AppColors.text,
      surfaceContainerHighest: AppColors.surfaceSoft,
      outline: AppColors.border,
      error: AppColors.danger,
      onError: Colors.white,
    );

    final text = base.textTheme.copyWith(
      headlineLarge: const TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.8,
        height: 1.10,
        color: AppColors.text,
      ),
      headlineMedium: const TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.45,
        height: 1.14,
        color: AppColors.text,
      ),
      titleLarge: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.2,
        color: AppColors.text,
      ),
      titleMedium: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: AppColors.text,
      ),
      bodyLarge: const TextStyle(
        fontSize: 15.5,
        height: 1.48,
        color: AppColors.text,
      ),
      bodyMedium: const TextStyle(
        fontSize: 14,
        height: 1.44,
        color: AppColors.text,
      ),
      bodySmall: const TextStyle(
        fontSize: 12,
        height: 1.38,
        color: AppColors.muted,
      ),
      labelLarge: const TextStyle(
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
      ),
    );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: text,
      visualDensity: VisualDensity.standard,
      canvasColor: AppColors.background,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
      splashFactory: InkRipple.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.navy,
          fontSize: 21,
          fontWeight: FontWeight.w900,
          letterSpacing: -.25,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: const Color(0x17123C4A),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.large),
          side: const BorderSide(color: AppColors.border, width: 1.05),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 16),
        labelStyle: const TextStyle(
          color: AppColors.muted,
          fontWeight: FontWeight.w700,
        ),
        hintStyle: const TextStyle(color: Color(0xFF9B9184)),
        prefixIconColor: AppColors.navy2,
        suffixIconColor: AppColors.navy2,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: const BorderSide(color: AppColors.navy2, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          minimumSize: const Size(44, 52),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.medium),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.navy,
          backgroundColor: AppColors.surface,
          minimumSize: const Size(44, 50),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          side: const BorderSide(color: AppColors.border, width: 1.05),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.medium),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.navy2,
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 70,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.gold,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11.2,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w900
                : FontWeight.w700,
          ),
        ),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: Color(0xFFF3DEAF),
        selectedIconTheme: IconThemeData(color: AppColors.navy),
        selectedLabelTextStyle: TextStyle(
          fontWeight: FontWeight.w900,
          color: AppColors.navy,
        ),
        unselectedLabelTextStyle: TextStyle(
          fontWeight: FontWeight.w700,
          color: AppColors.muted,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: const Color(0xFFF3DEAF),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        labelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: AppColors.text,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.navy,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.xl),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: AppColors.gold,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.navy2,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
    );
  }
}

class AppSurface extends StatelessWidget {
  const AppSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.backgroundColor = AppColors.surface,
    this.radius = AppRadii.large,
    this.borderColor = AppColors.border,
    this.shadow = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color backgroundColor;
  final double radius;
  final Color borderColor;
  final bool shadow;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor, width: 1.05),
      boxShadow: shadow
          ? const [
              BoxShadow(
                color: Color(0x16123C4A),
                blurRadius: 26,
                offset: Offset(0, 11),
              ),
            ]
          : null,
    ),
    child: child,
  );
}

class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (icon != null) ...[
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF4DEAC), Color(0xFFFFF8EA)],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, color: AppColors.navy2, size: 20),
        ),
        const SizedBox(width: 11),
      ],
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
      if (trailing != null) trailing!,
    ],
  );
}

class AppInfoPill extends StatelessWidget {
  const AppInfoPill({
    super.key,
    required this.label,
    this.icon,
    this.foreground = AppColors.navy,
    this.background = AppColors.surfaceSoft,
    this.border = AppColors.border,
  });

  final String label;
  final IconData? icon;
  final Color foreground;
  final Color background;
  final Color border;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: border),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 15, color: foreground),
          const SizedBox(width: 5),
        ],
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
            color: foreground,
          ),
        ),
      ],
    ),
  );
}

class AppPageHeading extends StatelessWidget {
  const AppPageHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 5,
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.gold,
          borderRadius: BorderRadius.circular(99),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.muted,
                ),
              ),
            ],
          ],
        ),
      ),
      if (trailing != null) trailing!,
    ],
  );
}

class AppMetricCard extends StatelessWidget {
  const AppMetricCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.accent = AppColors.navy,
    this.note,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final String? note;

  @override
  Widget build(BuildContext context) => AppSurface(
    padding: const EdgeInsets.all(15),
    shadow: true,
    child: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withValues(alpha: .16)),
          ),
          child: Icon(icon, color: accent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (note != null) ...[
                const SizedBox(height: 2),
                Text(
                  note!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}
'''

UZBEK_STYLE = r'''import 'package:flutter/material.dart';

abstract final class UzbekCustomerColors {
  static const background = Color(0xFFF7F0E3);
  static const surface = Color(0xFFFFFCF6);
  static const ivory = Color(0xFFFFF7E9);
  static const navy = Color(0xFF123C4A);
  static const navy2 = Color(0xFF18576A);
  static const teal = Color(0xFF0D7E7D);
  static const tealDark = Color(0xFF075E64);
  static const turquoise = Color(0xFF34A7A1);
  static const gold = Color(0xFFE0B04B);
  static const goldDeep = Color(0xFFC97822);
  static const goldSoft = Color(0xFFF4DEAC);
  static const border = Color(0xFFD9C5A2);
  static const textMuted = Color(0xFF746C61);
  static const success = Color(0xFF2C7B57);
  static const red = Color(0xFFA84943);
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
    final border = dark
        ? UzbekCustomerColors.gold.withValues(alpha: .58)
        : UzbekCustomerColors.border;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [Color(0xFF103A49), Color(0xFF08676B)]
              : const [UzbekCustomerColors.surface, Color(0xFFF7E8CE)],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border, width: strongPattern ? 1.35 : 1.05),
        boxShadow: [
          BoxShadow(
            color: UzbekCustomerColors.navy.withValues(alpha: dark ? .22 : .10),
            blurRadius: dark ? 28 : 22,
            offset: const Offset(0, 10),
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
          Positioned.fill(
            child: IgnorePointer(
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius - 5),
                    border: Border.all(
                      color: dark
                          ? Colors.white.withValues(alpha: .09)
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
                width: 94,
                height: 94,
                child: CustomPaint(painter: _CornerSuzaniPainter(dark: dark)),
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
                  width: 94,
                  height: 94,
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
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(99),
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
    final foreground = dark ? Colors.white : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withValues(alpha: .10)
            : UzbekCustomerColors.surface.withValues(alpha: .94),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: dark
              ? UzbekCustomerColors.gold.withValues(alpha: .45)
              : color.withValues(alpha: .22),
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
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: foreground,
              fontSize: 11.3,
              fontWeight: FontWeight.w900,
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
        SizedBox(
          width: 46,
          height: 46,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const UzbekMedallion(size: 46),
              Icon(icon, size: 18, color: UzbekCustomerColors.navy),
            ],
          ),
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
        Container(
          width: 26,
          height: 4,
          decoration: BoxDecoration(
            color: UzbekCustomerColors.gold,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
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
        child: Container(height: 1, color: UzbekCustomerColors.border),
      ),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 9),
        child: _SmallOrnament(),
      ),
      Expanded(
        child: Container(height: 1, color: UzbekCustomerColors.border),
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
      ..strokeWidth = 1.4
      ..color = UzbekCustomerColors.teal.withValues(alpha: .72);
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = UzbekCustomerColors.gold.withValues(alpha: .72);
    final p = Path()
      ..moveTo(center.dx, 2)
      ..lineTo(size.width - 2, center.dy)
      ..lineTo(center.dx, size.height - 2)
      ..lineTo(2, center.dy)
      ..close();
    canvas.drawPath(p, stroke);
    canvas.drawCircle(center, 4.2, fill);
    canvas.drawCircle(center, 9.5, stroke);
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
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strong ? 1.25 : .9
      ..color = (dark ? Colors.white : UzbekCustomerColors.teal).withValues(
        alpha: dark ? (strong ? .13 : .07) : (strong ? .11 : .055),
      );
    final gold = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .9
      ..color = UzbekCustomerColors.gold.withValues(
        alpha: strong ? .18 : .09,
      );

    const step = 58.0;
    for (double y = 18; y < size.height + step; y += step) {
      for (double x = 18; x < size.width + step; x += step) {
        final c = Offset(x, y);
        final diamond = Path()
          ..moveTo(c.dx, c.dy - 13)
          ..lineTo(c.dx + 13, c.dy)
          ..lineTo(c.dx, c.dy + 13)
          ..lineTo(c.dx - 13, c.dy)
          ..close();
        canvas.drawPath(diamond, stroke);
        canvas.drawCircle(c, 18, gold);
        canvas.drawCircle(c, 5, stroke);
        canvas.drawLine(
          Offset(c.dx - 18, c.dy),
          Offset(c.dx + 18, c.dy),
          gold,
        );
        canvas.drawLine(
          Offset(c.dx, c.dy - 18),
          Offset(c.dx, c.dy + 18),
          gold,
        );
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
    final ivory = Paint()..color = UzbekCustomerColors.ivory;
    canvas.drawRect(Offset.zero & size, bg);
    const w = 28.0;
    for (double x = -w; x < size.width + w; x += w) {
      final upper = Path()
        ..moveTo(x, 0)
        ..lineTo(x + w * .5, size.height)
        ..lineTo(x + w, 0)
        ..close();
      canvas.drawPath(upper, ((x / w).round().isEven) ? teal : gold);
      canvas.drawCircle(Offset(x + w * .5, size.height * .5), size.height * .16, ivory);
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
    final base = dark ? UzbekCustomerColors.gold : UzbekCustomerColors.teal;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25
      ..color = base.withValues(alpha: dark ? .34 : .19);
    final c = Offset(size.width * .22, size.height * .22);
    for (final r in [18.0, 30.0, 42.0]) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        0,
        1.5707963268,
        false,
        stroke,
      );
    }
    final p = Path()
      ..moveTo(c.dx + 7, c.dy)
      ..lineTo(c.dx + 20, c.dy + 13)
      ..lineTo(c.dx + 7, c.dy + 26)
      ..lineTo(c.dx - 6, c.dy + 13)
      ..close();
    canvas.drawPath(p, stroke);
    canvas.drawCircle(c.translate(7, 13), 5, stroke);
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
        alpha: .43,
      );
    canvas.drawCircle(c, size.width * .43, ring);
    canvas.drawCircle(c, size.width * .31, soft);
    for (var i = 0; i < 8; i++) {
      final angle = i * 0.7853981634;
      final dx = c.dx + size.width * .29 * MathLike.cos(angle);
      final dy = c.dy + size.width * .29 * MathLike.sin(angle);
      canvas.drawCircle(Offset(dx, dy), size.width * .052, soft);
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
'''

STORE_SHELL = r'''class _StoreShellState extends State<StoreShell> {
  int index = 0;
  String? _lastPresentedNoticeId;

  @override
  Widget build(BuildContext context) {
    final cartCount = context.select<AppState, int>((s) => s.cartCount);
    final latestNoticeId = context.select<AppState, String?>(
      (s) => s.latestUnreadCustomerNotice?['id']?.toString(),
    );
    if (latestNoticeId != null && latestNoticeId != _lastPresentedNoticeId) {
      _lastPresentedNoticeId = latestNoticeId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final notice = context.read<AppState>().latestUnreadCustomerNotice;
        if (notice == null || notice['id']?.toString() != latestNoticeId) {
          return;
        }
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                [
                  (notice['title'] ?? 'Buyurtma yangilandi').toString(),
                  (notice['message'] ?? '').toString(),
                ].where((value) => value.trim().isNotEmpty).join('\n'),
              ),
              duration: const Duration(seconds: 5),
            ),
          );
      });
    }
    const pages = [
      HomePage(),
      CategoriesPage(),
      CartPage(),
      FavoritesPage(),
      ProfilePage(),
    ];

    return Scaffold(
      backgroundColor: UzbekCustomerColors.background,
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: Align(
          alignment: Alignment.bottomCenter,
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    UzbekCustomerColors.navy,
                    UzbekCustomerColors.tealDark,
                  ],
                ),
                borderRadius: BorderRadius.circular(27),
                border: Border.all(
                  color: UzbekCustomerColors.gold.withValues(alpha: .62),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x38123C4A),
                    blurRadius: 28,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: NavigationBarTheme(
                  data: NavigationBarThemeData(
                    backgroundColor: Colors.transparent,
                    surfaceTintColor: Colors.transparent,
                    indicatorColor: UzbekCustomerColors.goldSoft,
                    iconTheme: WidgetStateProperty.resolveWith(
                      (states) => IconThemeData(
                        size: 23,
                        color: states.contains(WidgetState.selected)
                            ? UzbekCustomerColors.navy
                            : Colors.white.withValues(alpha: .76),
                      ),
                    ),
                    labelTextStyle: WidgetStateProperty.resolveWith(
                      (states) => TextStyle(
                        fontSize: 10.6,
                        fontWeight: states.contains(WidgetState.selected)
                            ? FontWeight.w900
                            : FontWeight.w700,
                        color: states.contains(WidgetState.selected)
                            ? UzbekCustomerColors.gold
                            : Colors.white.withValues(alpha: .72),
                      ),
                    ),
                  ),
                  child: NavigationBar(
                    height: 72,
                    backgroundColor: Colors.transparent,
                    indicatorColor: UzbekCustomerColors.goldSoft,
                    selectedIndex: index,
                    onDestinationSelected: (value) => setState(() => index = value),
                    destinations: [
                      const NavigationDestination(
                        icon: Icon(Icons.home_outlined),
                        selectedIcon: Icon(Icons.home_rounded),
                        label: 'Bosh sahifa',
                      ),
                      const NavigationDestination(
                        icon: Icon(Icons.grid_view_rounded),
                        selectedIcon: Icon(Icons.grid_view_rounded),
                        label: 'Kategoriya',
                      ),
                      NavigationDestination(
                        icon: Badge(
                          isLabelVisible: cartCount > 0,
                          label: Text('$cartCount'),
                          child: const Icon(Icons.shopping_cart_outlined),
                        ),
                        selectedIcon: Badge(
                          isLabelVisible: cartCount > 0,
                          label: Text('$cartCount'),
                          child: const Icon(Icons.shopping_cart_rounded),
                        ),
                        label: 'Savatcha',
                      ),
                      const NavigationDestination(
                        icon: Icon(Icons.favorite_border_rounded),
                        selectedIcon: Icon(Icons.favorite_rounded),
                        label: 'Sevimlilar',
                      ),
                      const NavigationDestination(
                        icon: Icon(Icons.person_outline_rounded),
                        selectedIcon: Icon(Icons.person_rounded),
                        label: 'Profil',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
'''

STORE_HEADER = r'''class _StoreHeader extends StatelessWidget {
  const _StoreHeader({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return UzbekPatternPanel(
      radius: 27,
      padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: UzbekCustomerColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: UzbekCustomerColors.gold),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x16123C4A),
                  blurRadius: 14,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: const MuhajeerLogoBadge(size: 52, radius: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Muhajeer Books',
                  style: TextStyle(
                    color: UzbekCustomerColors.navy,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.35,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Koreyadagi O’zbek kitobxonlari uchun',
                  style: TextStyle(
                    color: UzbekCustomerColors.textMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const UzbekAtlasBand(height: 4),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Badge(
            isLabelVisible: state.unreadCustomerNoticeCount > 0,
            label: Text('${state.unreadCustomerNoticeCount}'),
            child: Material(
              color: UzbekCustomerColors.navy,
              borderRadius: BorderRadius.circular(17),
              child: IconButton(
                tooltip: 'Bildirishnomalar',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CustomerNotificationsPage(),
                  ),
                ),
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  color: UzbekCustomerColors.gold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
'''

DELIVERY_PROMO = r'''class _DeliveryPromoCard extends StatelessWidget {
  const _DeliveryPromoCard();

  @override
  Widget build(BuildContext context) {
    return UzbekPatternPanel(
      dark: true,
      strongPattern: true,
      padding: EdgeInsets.zero,
      radius: 30,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 430;
          return Stack(
            children: [
              Positioned(
                right: compact ? -42 : 18,
                top: compact ? 16 : 20,
                child: Opacity(
                  opacity: .82,
                  child: UzbekMedallion(
                    size: compact ? 112 : 132,
                    dark: true,
                  ),
                ),
              ),
              Positioned(
                right: -18,
                bottom: -30,
                child: Icon(
                  Icons.auto_stories_rounded,
                  size: compact ? 138 : 170,
                  color: UzbekCustomerColors.gold.withValues(alpha: .10),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  22,
                  22,
                  compact ? 86 : 150,
                  22,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const UzbekMiniPill(
                      icon: Icons.auto_awesome_rounded,
                      text: 'O‘zbekona ruh',
                      dark: true,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Kitob bilan\nyanada yaqinroq bo‘ling',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        height: 1.07,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.45,
                      ),
                    ),
                    const SizedBox(height: 9),
                    const Text(
                      'Bilim har doim siz bilan!',
                      style: TextStyle(
                        color: Color(0xFFF4DEAC),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _HeroFact(
                          icon: Icons.local_shipping_rounded,
                          text: '1–3 ish kuni',
                        ),
                        _HeroFact(
                          icon: Icons.payments_outlined,
                          text: '택배 ₩4,000',
                        ),
                        _HeroFact(
                          icon: Icons.card_giftcard_rounded,
                          text: '4+ kitob — bepul',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                top: 34,
                bottom: 34,
                child: Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: UzbekCustomerColors.gold,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
'''

QUICK_CATEGORIES = r'''class _QuickCategoryStrip extends StatelessWidget {
  const _QuickCategoryStrip({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  final List<String> categories;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final visible = categories.take(6).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const UzbekSectionTitle(
          title: 'Kategoriyalar',
          subtitle: 'O‘zingizga mos yo‘nalishni tanlang',
          icon: Icons.grid_view_rounded,
        ),
        const SizedBox(height: 13),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: visible.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final c = visible[i];
              final active = c == selected;
              return InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () => onSelected(c),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 92,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
                  decoration: BoxDecoration(
                    gradient: active
                        ? const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              UzbekCustomerColors.navy,
                              UzbekCustomerColors.tealDark,
                            ],
                          )
                        : const LinearGradient(
                            colors: [
                              UzbekCustomerColors.surface,
                              UzbekCustomerColors.ivory,
                            ],
                          ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: active
                          ? UzbekCustomerColors.gold
                          : UzbekCustomerColors.border,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x11123C4A),
                        blurRadius: 14,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 38,
                        height: 38,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            UzbekMedallion(size: 38, dark: active),
                            Icon(
                              c == 'Barchasi'
                                  ? Icons.grid_view_rounded
                                  : _categoryIcon(c),
                              color: active
                                  ? UzbekCustomerColors.gold
                                  : UzbekCustomerColors.navy,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        c,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: active
                              ? Colors.white
                              : UzbekCustomerColors.navy,
                          fontSize: 10.8,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
'''

BOOK_CARD = r'''class BookCard extends StatelessWidget {
  const BookCard({super.key, required this.book});
  final Book book;

  @override
  Widget build(BuildContext context) {
    final favorite = context.select<AppState, bool>((s) => s.isFavorite(book));
    final state = context.read<AppState>();
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [UzbekCustomerColors.surface, UzbekCustomerColors.ivory],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: UzbekCustomerColors.border, width: 1.05),
        boxShadow: const [
          BoxShadow(
            color: Color(0x17123C4A),
            blurRadius: 20,
            offset: Offset(0, 9),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => BookDetailPage(bookId: book.id)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _BookCover(book: book),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          height: 42,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Color(0x99123C4A)],
                            ),
                          ),
                        ),
                      ),
                      const Positioned(
                        left: 8,
                        right: 8,
                        bottom: 7,
                        child: UzbekAccentLine(),
                      ),
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Material(
                          color: UzbekCustomerColors.surface.withValues(alpha: .95),
                          borderRadius: BorderRadius.circular(15),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(15),
                            onTap: () => state.toggleFavorite(book),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Icon(
                                favorite
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                color: favorite
                                    ? UzbekCustomerColors.red
                                    : UzbekCustomerColors.navy,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (book.isDiscounted)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: _Badge(
                            text: '-${book.discountPercent}%',
                            color: AppColors.danger,
                          ),
                        ),
                      if (book.recommended)
                        const Positioned(
                          bottom: 17,
                          left: 12,
                          child: _Badge(
                            text: 'Tavsiya',
                            color: AppColors.orange,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 11, 13, 13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: UzbekCustomerColors.navy,
                      fontWeight: FontWeight.w900,
                      height: 1.14,
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    book.author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: UzbekCustomerColors.textMuted,
                      fontSize: 11.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: book.inStock
                          ? const Color(0xFFE8F3EA)
                          : const Color(0xFFFBEAE6),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          book.inStock
                              ? Icons.check_circle_rounded
                              : Icons.cancel_rounded,
                          size: 13,
                          color: book.inStock
                              ? AppColors.success
                              : AppColors.danger,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            book.inStock
                                ? '${book.stock} dona mavjud'
                                : 'Hozircha mavjud emas',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: book.inStock
                                  ? AppColors.success
                                  : AppColors.danger,
                              fontSize: 10.2,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (book.isDiscounted)
                    Text(
                      won(book.price),
                      style: const TextStyle(
                        color: AppColors.muted,
                        decoration: TextDecoration.lineThrough,
                        fontSize: 10.5,
                      ),
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          won(book.currentPrice),
                          style: const TextStyle(
                            color: UzbekCustomerColors.navy,
                            fontWeight: FontWeight.w900,
                            fontSize: 16.5,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: FilledButton(
                          onPressed: book.inStock
                              ? () {
                                  state.addToCart(book);
                                  ScaffoldMessenger.of(context)
                                    ..hideCurrentSnackBar()
                                    ..showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '${book.title} savatga qo‘shildi ✅',
                                        ),
                                        duration: const Duration(
                                          milliseconds: 900,
                                        ),
                                      ),
                                    );
                                }
                              : null,
                          style: FilledButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(40, 40),
                            backgroundColor: UzbekCustomerColors.navy,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Icon(
                            Icons.add_shopping_cart_rounded,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
'''


def replace_between(text: str, start_marker: str, end_marker: str, replacement: str) -> str:
    start = text.find(start_marker)
    if start < 0:
        raise RuntimeError(f'Missing start marker: {start_marker}')
    end = text.find(end_marker, start)
    if end < 0:
        raise RuntimeError(f'Missing end marker: {end_marker}')
    return text[:start] + replacement.rstrip() + '\n\n' + text[end:]


def main() -> None:
    (ROOT / 'lib' / 'design_system.dart').write_text(DESIGN_SYSTEM, encoding='utf-8')
    (ROOT / 'lib' / 'uzbek_customer_style.dart').write_text(UZBEK_STYLE, encoding='utf-8')

    store_path = ROOT / 'lib' / 'store_ui.dart'
    store = store_path.read_text(encoding='utf-8')
    store = replace_between(store, 'class _StoreShellState', 'class CategoriesPage', STORE_SHELL)
    store = replace_between(store, 'class _StoreHeader', 'class _DeliveryPromoCard', STORE_HEADER)
    store = replace_between(store, 'class _DeliveryPromoCard', 'class _HeroFact', DELIVERY_PROMO)
    store = replace_between(store, 'class _QuickCategoryStrip', 'class _TrustStrip', QUICK_CATEGORIES)
    store = replace_between(store, 'class BookCard', 'class _BookCover', BOOK_CARD)
    store_path.write_text(store, encoding='utf-8')


if __name__ == '__main__':
    main()
