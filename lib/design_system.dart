import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class _WebNoPageTransitionsBuilder extends PageTransitionsBuilder {
  const _WebNoPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}

Route<T> muhajeerPageRoute<T>({
  required WidgetBuilder builder,
  RouteSettings? settings,
  bool fullscreenDialog = false,
}) {
  if (kIsWeb) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => builder(context),
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      maintainState: true,
      opaque: true,
      fullscreenDialog: fullscreenDialog,
    );
  }
  return MaterialPageRoute<T>(
    settings: settings,
    builder: builder,
    fullscreenDialog: fullscreenDialog,
  );
}

abstract final class AppColors {
  static const navy = Color(0xFF173F4A);
  static const navy2 = Color(0xFF0D625B);
  static const orange = Color(0xFFB85E3F);
  static const gold = Color(0xFFC99B45);
  static const background = Color(0xFFF7F3EA);
  static const surface = Color(0xFFFFFEFA);
  static const surfaceSoft = Color(0xFFF5EBD7);
  static const border = Color(0xFFE4D7BC);
  static const text = Color(0xFF20332F);
  static const muted = Color(0xFF756D62);
  static const success = Color(0xFF2E7D5B);
  static const successSoft = Color(0xFFE7F3EC);
  static const warning = Color(0xFFA76B20);
  static const warningSoft = Color(0xFFFFF2D8);
  static const danger = Color(0xFFB64E4E);
  static const dangerSoft = Color(0xFFFBEAEA);
  static const info = Color(0xFF0D6E68);
  static const infoSoft = Color(0xFFE5F3F0);
}

abstract final class AppRadii {
  static const small = 12.0;
  static const medium = 18.0;
  static const large = 24.0;
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
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.navy2,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.navy2,
          onPrimary: Colors.white,
          secondary: AppColors.orange,
          onSecondary: Colors.white,
          tertiary: AppColors.gold,
          surface: AppColors.surface,
          onSurface: AppColors.text,
          outline: AppColors.border,
          error: AppColors.danger,
        );

    final text = base.textTheme.copyWith(
      headlineLarge: const TextStyle(
        fontSize: 31,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.75,
        height: 1.10,
        color: AppColors.text,
      ),
      headlineMedium: const TextStyle(
        fontSize: 25,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.4,
        height: 1.14,
        color: AppColors.text,
      ),
      titleLarge: const TextStyle(
        fontSize: 19.5,
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
        height: 1.45,
        color: AppColors.text,
      ),
      bodySmall: const TextStyle(
        fontSize: 12,
        height: 1.4,
        color: AppColors.muted,
      ),
      labelLarge: const TextStyle(
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
    );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: text,
      visualDensity: VisualDensity.standard,
      canvasColor: AppColors.background,
      // Safari/iPhone browser edge-swipe already animates the page itself.
      // Flutter web must not add a second route transition on top of it;
      // otherwise the previous screen visibly slides twice / snaps back.
      // Native Android/iOS keep their normal platform transitions.
      pageTransitionsTheme: kIsWeb
          ? const PageTransitionsTheme(
              builders: {
                TargetPlatform.iOS: _WebNoPageTransitionsBuilder(),
                TargetPlatform.macOS: _WebNoPageTransitionsBuilder(),
                TargetPlatform.android: _WebNoPageTransitionsBuilder(),
                TargetPlatform.linux: _WebNoPageTransitionsBuilder(),
                TargetPlatform.windows: _WebNoPageTransitionsBuilder(),
              },
            )
          : const PageTransitionsTheme(
              builders: {
                TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
                TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
                TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
                TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
              },
            ),
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.text,
          fontSize: 20,
          fontWeight: FontWeight.w900,
          letterSpacing: -.25,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.large),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 17,
          vertical: 16,
        ),
        labelStyle: const TextStyle(
          color: AppColors.muted,
          fontWeight: FontWeight.w700,
        ),
        hintStyle: const TextStyle(color: Color(0xFF9A9389)),
        prefixIconColor: AppColors.navy2,
        suffixIconColor: AppColors.muted,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: const BorderSide(color: AppColors.navy2, width: 1.7),
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
          backgroundColor: AppColors.navy2,
          foregroundColor: Colors.white,
          minimumSize: const Size(44, 52),
          padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 14),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.medium),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.navy2,
          minimumSize: const Size(44, 50),
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 13),
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.medium),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.navy2,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 74,
        backgroundColor: AppColors.navy,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.gold,
        elevation: 0,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.navy
                : Colors.white.withValues(alpha: .72),
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11.3,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w900
                : FontWeight.w600,
            color: states.contains(WidgetState.selected)
                ? Colors.white
                : Colors.white.withValues(alpha: .68),
          ),
        ),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: AppColors.navy,
        indicatorColor: AppColors.gold,
        selectedIconTheme: IconThemeData(color: AppColors.navy),
        unselectedIconTheme: IconThemeData(color: Colors.white70),
        selectedLabelTextStyle: TextStyle(
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
        unselectedLabelTextStyle: TextStyle(
          fontWeight: FontWeight.w600,
          color: Colors.white70,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.gold,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.navy2,
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
      border: Border.all(color: borderColor),
      boxShadow: shadow
          ? const [
              BoxShadow(
                color: Color(0x12173F4A),
                blurRadius: 26,
                offset: Offset(0, 10),
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
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.surfaceSoft,
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
          const SizedBox(width: 6),
        ],
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
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
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: AppColors.muted),
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
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: accent.withValues(alpha: .14)),
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
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.w700),
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
