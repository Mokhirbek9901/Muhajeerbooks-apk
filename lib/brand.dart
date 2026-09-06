import 'package:flutter/material.dart';

class MuhajeerLogoBadge extends StatelessWidget {
  const MuhajeerLogoBadge({
    super.key,
    this.size = 52,
    this.radius,
    this.padding,
    this.backgroundColor = Colors.white,
    this.showShadow = true,
  });

  final double size;
  final double? radius;
  final EdgeInsets? padding;
  final Color backgroundColor;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: padding ?? EdgeInsets.all(size * 0.08),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(radius ?? size * 0.28),
        border: Border.all(color: const Color(0xFFFFB74D), width: 1.1),
        boxShadow: showShadow
            ? const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius ?? size * 0.22),
        child: Image.asset(
          'assets/images/muhajeer_logo.jpg',
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class MuhajeerLogoCircle extends StatelessWidget {
  const MuhajeerLogoCircle({super.key, this.size = 52});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.08),
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/muhajeer_logo.jpg',
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
