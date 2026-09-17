from pathlib import Path

p = Path('lib/store_ui.dart')
s = p.read_text()
start = s.index('          UzbekPatternPanel(\n            dark: true,\n            strongPattern: true,\n            padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),\n            child: Column(', s.index('class ProfilePage'))
end = s.index('          const SizedBox(height: 12),', start)
new = '''          Container(
            height: 292,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFFD7B35B), width: 1.4),
              boxShadow: const [
                BoxShadow(color: Color(0x24113D43), blurRadius: 22, offset: Offset(0, 9)),
              ],
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                const CustomPaint(painter: _ProfileMosaicPainter()),
                Container(
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: .62,
                      colors: [Color(0xD90A3851), Color(0xB50A3851), Color(0x35101D43)],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 35, 22, 22),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onLongPress: () => Navigator.push(
                          context,
                          muhajeerPageRoute(
                            settings: const RouteSettings(name: 'mb:admin'),
                            builder: (_) => const AdminGatePage(),
                          ),
                        ),
                        child: Text(
                          displayName,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Color(0xFFFFF7E6), fontSize: 31, fontWeight: FontWeight.w900, letterSpacing: -.5),
                        ),
                      ),
                      if (displayPhone.trim().isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(displayPhone, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: .4)),
                      ],
                      const SizedBox(height: 13),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 9),
                        decoration: BoxDecoration(
                          color: const Color(0xA6082D43),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFFFD875), width: 1.2),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.menu_book_rounded, color: Color(0xFFFFD875), size: 20),
                            SizedBox(width: 8),
                            Text('Muhajeer Books', style: TextStyle(color: Color(0xFFFFD875), fontSize: 16, fontWeight: FontWeight.w900)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Row(children: [Expanded(child: Divider(color: Color(0xFFFFD875), thickness: 1)), Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Icon(Icons.filter_vintage_rounded, color: Color(0xFFFFD875), size: 18)), Expanded(child: Divider(color: Color(0xFFFFD875), thickness: 1))]),
                      const SizedBox(height: 10),
                      const Text('Koreyadagi O‘zbek kitobxonlari uchun', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFFFF7E6), fontSize: 14.5, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
          ),
'''
s = s[:start] + new + s[end:]
marker = 'class ProfilePage extends StatelessWidget {'
painter = r'''class _ProfileMosaicPainter extends CustomPainter {
  const _ProfileMosaicPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..shader = const LinearGradient(colors: [Color(0xFF071B43), Color(0xFF063F5A), Color(0xFF08737A)]).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bg);
    final gold = Paint()..color = const Color(0xB8E8BE62)..style = PaintingStyle.stroke..strokeWidth = 1.15;
    final cyan = Paint()..color = const Color(0x804BC8D3)..style = PaintingStyle.stroke..strokeWidth = 1;
    final c = Offset(size.width / 2, size.height * .48);
    for (final r in [42.0, 62.0, 84.0, 108.0, 136.0, 170.0, 210.0]) {
      canvas.drawCircle(c, r, r.toInt().isEven ? gold : cyan);
    }
    for (var i = 0; i < 24; i++) {
      final a = i * 3.1415926535 / 12;
      final p1 = c + Offset(44 * MathCos.cos(a), 44 * MathCos.sin(a));
      final p2 = c + Offset(210 * MathCos.cos(a), 210 * MathCos.sin(a));
      canvas.drawLine(p1, p2, i.isEven ? gold : cyan);
    }
    for (var x = -40.0; x < size.width + 40; x += 72) {
      final path = Path()..moveTo(x, size.height)..lineTo(x + 18, size.height - 55)..lineTo(x + 36, size.height - 20)..lineTo(x + 54, size.height - 72)..lineTo(x + 72, size.height);
      canvas.drawPath(path, gold);
    }
    final star = Paint()..color = const Color(0xBFFFF4C7);
    for (var i = 0; i < 38; i++) {
      final x = ((i * 83) % 997) / 997 * size.width;
      final y = ((i * 47) % 311) / 311 * size.height * .72;
      canvas.drawCircle(Offset(x, y), i % 5 == 0 ? 1.6 : .8, star);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class MathCos {
  static double cos(double x) => _sin(x + 1.5707963267948966);
  static double sin(double x) => _sin(x);
  static double _sin(double x) {
    const pi = 3.141592653589793;
    while (x > pi) x -= 2 * pi;
    while (x < -pi) x += 2 * pi;
    final x2 = x * x;
    return x * (1 - x2 / 6 + x2 * x2 / 120 - x2 * x2 * x2 / 5040 + x2 * x2 * x2 * x2 / 362880);
  }
}

'''
if marker not in s: raise SystemExit('ProfilePage marker missing')
s = s.replace(marker, painter + marker, 1)
p.write_text(s)
