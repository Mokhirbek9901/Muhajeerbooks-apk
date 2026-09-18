from pathlib import Path

p = Path("lib/store_ui.dart")
s = p.read_text()

# Card proportions and transparent ornamental overlay so the detailed
# Registan/Uzbek background remains visible, matching the supplied reference.
s = s.replace("height: 300,", "height: 205,", 1)
s = s.replace(
    "colors: [Color(0xFF06234C), Color(0xFF074F6A), Color(0xFF061D43)],",
    "colors: [Color(0xB806234C), Color(0xA8074F6A), Color(0xB8061D43)],",
    1,
)

# Compact the content vertically like the supplied profile reference.
s = s.replace(
    "fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: .5",
    "fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: .5",
    1,
)
s = s.replace(
    "const SizedBox(height: 13),\n                      Container(",
    "const SizedBox(height: 9),\n                      Container(",
    1,
)
s = s.replace(
    "const SizedBox(height: 14),\n                      const Row(children:",
    "const SizedBox(height: 9),\n                      const Row(children:",
    1,
)
s = s.replace(
    "const SizedBox(height: 10),\n                      const Text('Koreyadagi O‘zbek kitobxonlari uchun'",
    "const SizedBox(height: 6),\n                      const Text('Koreyadagi O‘zbek kitobxonlari uchun'",
    1,
)

# Replace the old technical stats with the three reference action cards.
start = s.find(
    "          const SizedBox(height: 12),\n"
    "          Row(\n"
    "            children: [\n"
    "              Expanded(\n"
    "                child: _ProfileStat"
)
end_marker = "          const SizedBox(height: 19),"
if start != -1:
    end = s.find(end_marker, start)
    if end == -1:
        raise SystemExit("profile action block end not found")
    replacement = """          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ProfileReferenceAction(
                  icon: Icons.shopping_bag_outlined,
                  label: 'Buyurtmalarim',
                  onTap: () => Navigator.push(
                    context,
                    muhajeerPageRoute(
                      settings: const RouteSettings(name: 'mb:orders'),
                      builder: (_) => const MyOrdersPage(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ProfileReferenceAction(
                  icon: Icons.favorite_border_rounded,
                  label: 'Sevimlilarim',
                  onTap: () => Navigator.push(
                    context,
                    muhajeerPageRoute(
                      settings: const RouteSettings(name: 'mb:favorites'),
                      builder: (_) => const FavoritesPage(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ProfileReferenceAction(
                  icon: Icons.settings_outlined,
                  label: 'Sozlamalar',
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sozlamalar pastdagi profil xizmatlarida.')),
                  ),
                ),
              ),
            ],
          ),
"""
    s = s[:start] + replacement + s[end:]

p.write_text(s)
