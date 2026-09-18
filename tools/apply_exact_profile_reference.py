from pathlib import Path

p = Path("lib/store_ui.dart")
s = p.read_text()

a = s.index("class _ProfileMosaicPainter extends CustomPainter {")
b = s.index("class MathCos {", a)
painter = r'''class _ProfileMosaicPainter extends CustomPainter {
  const _ProfileMosaicPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final gold = Paint()
      ..color = const Color(0xBFE8C66A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.05;
    final teal = Paint()
      ..color = const Color(0x8059B7C3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .8;
    final center = Offset(size.width * .5, size.height * .49);

    // Dark central medallion exactly like the supplied reference.
    final medallion = Rect.fromCenter(
      center: center,
      width: size.width * .52,
      height: size.height * .98,
    );
    canvas.drawOval(
      medallion,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xF5052C45), Color(0xEB07344D), Color(0xB0052943), Color(0x00052943)],
          stops: [0, .58, .82, 1],
        ).createShader(medallion),
    );

    // Concentric Uzbek/Islamic arches around the central medallion.
    void arch(double inset, Paint paint) {
      final left = size.width * inset;
      final right = size.width * (1 - inset);
      final bottom = size.height * .98;
      final shoulder = size.height * .37;
      final top = size.height * .015;
      final path = Path()
        ..moveTo(left, bottom)
        ..lineTo(left, shoulder)
        ..quadraticBezierTo(left, size.height * .12, center.dx, top)
        ..quadraticBezierTo(right, size.height * .12, right, shoulder)
        ..lineTo(right, bottom);
      canvas.drawPath(path, paint);
    }

    arch(.035, gold);
    arch(.085, teal);
    arch(.135, gold);
    arch(.19, teal);
    arch(.245, gold);

    // Fine geometric diamonds on both sides.
    for (var y = 12.0; y < size.height - 8; y += 22) {
      for (final x in [size.width * .055, size.width * .945]) {
        final d = Path()
          ..moveTo(x, y - 5)
          ..lineTo(x + 5, y)
          ..lineTo(x, y + 5)
          ..lineTo(x - 5, y)
          ..close();
        canvas.drawPath(d, gold);
        canvas.drawCircle(Offset(x, y), 1.1, teal);
      }
    }

    // Subtle central rosette behind the customer's name.
    for (var i = 0; i < 16; i++) {
      final aa = i * 3.141592653589793 / 8;
      final p1 = center + Offset(
        size.width * .12 * MathCos.cos(aa),
        size.height * .23 * MathCos.sin(aa),
      );
      final p2 = center + Offset(
        size.width * .205 * MathCos.cos(aa),
        size.height * .40 * MathCos.sin(aa),
      );
      canvas.drawLine(p1, p2, i.isEven ? gold : teal);
    }
    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: size.width * .34,
        height: size.height * .70,
      ),
      teal,
    );

    // Small star points like the reference.
    final star = Paint()..color = const Color(0xBFFFF2B5);
    for (var i = 0; i < 38; i++) {
      final x = ((i * 83) % 997) / 997 * size.width;
      final y = ((i * 47) % 311) / 311 * size.height * .72;
      if ((x - center.dx).abs() < size.width * .27) continue;
      canvas.drawCircle(Offset(x, y), i % 6 == 0 ? 1.15 : .55, star);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

'''
s = s[:a] + painter + s[b:]

# Exact visible proportions from the supplied screenshot.
s = s.replace("height: 205,", "height: 162,", 1)
s = s.replace("padding: const EdgeInsets.fromLTRB(18, 20, 18, 12),", "padding: const EdgeInsets.fromLTRB(16, 10, 16, 7),", 1)
s = s.replace("fontSize: 29, fontWeight: FontWeight.w900", "fontSize: 23, fontWeight: FontWeight.w900", 1)
s = s.replace("fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: .5", "fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: .45", 1)
s = s.replace("const SizedBox(height: 9),\n                      Container(", "const SizedBox(height: 6),\n                      Container(", 1)
s = s.replace("padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 9),", "padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),", 1)
s = s.replace("Icon(Icons.menu_book_rounded, color: Color(0xFFFFD875), size: 20)", "Icon(Icons.menu_book_rounded, color: Color(0xFFFFD875), size: 18)", 1)
s = s.replace("fontSize: 17, fontWeight: FontWeight.w900, fontFamily: 'serif'", "fontSize: 15, fontWeight: FontWeight.w900, fontFamily: 'serif'", 1)
s = s.replace("const SizedBox(height: 9),\n                      const Row(children:", "const SizedBox(height: 6),\n                      const Row(children:", 1)
s = s.replace("const SizedBox(height: 6),\n                      const Text('Koreyadagi O‘zbek kitobxonlari uchun'", "const SizedBox(height: 4),\n                      const Text('Koreyadagi O‘zbek kitobxonlari uchun'", 1)
s = s.replace("fontSize: 15.5, fontWeight: FontWeight.w700, fontFamily: 'serif'", "fontSize: 12.5, fontWeight: FontWeight.w700, fontFamily: 'serif'", 1)

# The reference's background is the detailed Registan image itself; remove the
# extra dark radial wash that changed its appearance.
old = """                Container(
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: .54,
                      colors: [Color(0xE6073150), Color(0xB8073150), Color(0x28021931)],
                      stops: [0, .56, 1],
                    ),
                  ),
                ),
"""
s = s.replace(old, "", 1)

p.write_text(s)
