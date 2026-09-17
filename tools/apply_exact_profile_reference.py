from pathlib import Path
p=Path('lib/store_ui.dart')
s=p.read_text()
old="""                const CustomPaint(painter: _ProfileMosaicPainter()),
                Container(
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: .62,
                      colors: [Color(0xD90A3851), Color(0xB50A3851), Color(0x35101D43)],
                    ),
                  ),
                ),"""
new="""                Image.asset(
                  'assets/images/registan_illustrated.webp',
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  filterQuality: FilterQuality.high,
                ),
                const CustomPaint(painter: _ProfileMosaicPainter()),
                Container(
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: .54,
                      colors: [Color(0xE6073150), Color(0xB8073150), Color(0x28021931)],
                      stops: [0, .56, 1],
                    ),
                  ),
                ),"""
if old not in s: raise SystemExit('profile target not found')
s=s.replace(old,new,1)
s=s.replace("height: 292,","height: 300,",1)
s=s.replace("borderRadius: BorderRadius.circular(28),\n              border: Border.all(color: const Color(0xFFD7B35B), width: 1.4),","borderRadius: BorderRadius.circular(30),\n              border: Border.all(color: const Color(0xFFE3BC61), width: 1.6),",1)
s=s.replace("style: const TextStyle(color: Color(0xFFFFF7E6), fontSize: 31, fontWeight: FontWeight.w900, letterSpacing: -.5)","style: const TextStyle(color: Color(0xFFFFFBF1), fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -.7, fontFamily: 'serif')",1)
s=s.replace("Text(displayPhone, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: .4))","Text(displayPhone, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: .5))",1)
s=s.replace("Text('Muhajeer Books', style: TextStyle(color: Color(0xFFFFD875), fontSize: 16, fontWeight: FontWeight.w900))","Text('Muhajeer Books', style: TextStyle(color: Color(0xFFFFD875), fontSize: 17, fontWeight: FontWeight.w900, fontFamily: 'serif'))",1)
s=s.replace("fontSize: 14.5, fontWeight: FontWeight.w700","fontSize: 15.5, fontWeight: FontWeight.w700, fontFamily: 'serif'",1)
p.write_text(s)
