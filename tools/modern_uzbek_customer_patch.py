from pathlib import Path
import re

store_path = Path('lib/store_ui.dart')
pubspec_path = Path('pubspec.yaml')
style_path = Path('lib/uzbek_customer_style.dart')

store = store_path.read_text(encoding='utf-8')


def sub_one(pattern: str, replacement: str, label: str, flags=re.S):
    global store
    updated, count = re.subn(pattern, replacement, store, count=1, flags=flags)
    if count != 1:
        raise RuntimeError(f'{label}: expected 1 replacement, got {count}')
    store = updated


# Customer-only visual language: warm ivory, Uzbek teal, deep navy and restrained gold.
if "import 'uzbek_customer_style.dart';" not in store:
    store = store.replace(
        "import 'design_system.dart';",
        "import 'design_system.dart';\nimport 'uzbek_customer_style.dart';",
        1,
    )

store = store.replace("const _navy = Color(0xFF10213D);", "const _navy = UzbekCustomerColors.navy;", 1)
store = store.replace("const _orange = Color(0xFFFF8A00);", "const _orange = UzbekCustomerColors.goldDeep;", 1)
store = store.replace("const _gold = Color(0xFFFFC928);", "const _gold = UzbekCustomerColors.gold;", 1)
store = store.replace("const _cream = Color(0xFFFFFBF1);", "const _cream = UzbekCustomerColors.ivory;", 1)
store = store.replace("const _green = Color(0xFF138A4B);", "const _green = UzbekCustomerColors.success;", 1)

# Warm customer background without touching admin_ui.dart.
store = store.replace(
    "return Scaffold(\n      body: IndexedStack(index: index, children: pages),",
    "return Scaffold(\n      backgroundColor: UzbekCustomerColors.background,\n      body: IndexedStack(index: index, children: pages),",
    1,
)
store = store.replace(
    "return const Scaffold(",
    "return const Scaffold(backgroundColor: UzbekCustomerColors.background,",
)
store = store.replace(
    "return Scaffold(\n      appBar:",
    "return Scaffold(\n      backgroundColor: UzbekCustomerColors.background,\n      appBar:",
)
store = store.replace(
    "appBar: AppBar(",
    "appBar: AppBar(backgroundColor: UzbekCustomerColors.background, surfaceTintColor: Colors.transparent, ",
)

# Category controls should feel warm and editorial instead of generic Material defaults.
store = store.replace(
    "selected: category == c,\n                      onSelected:",
    "selected: category == c,\n                      selectedColor: UzbekCustomerColors.goldSoft,\n                      backgroundColor: Colors.white,\n                      side: const BorderSide(color: UzbekCustomerColors.border),\n                      labelStyle: TextStyle(\n                        color: category == c ? UzbekCustomerColors.navy : AppColors.text,\n                        fontWeight: category == c ? FontWeight.w900 : FontWeight.w700,\n                      ),\n                      onSelected:",
    1,
)

new_header = r'''class _StoreHeader extends StatelessWidget {
  const _StoreHeader({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final active = state.books.where((b) => b.isActive).length;
    final available = state.books.where((b) => b.isActive && b.inStock).length;
    return UzbekPatternPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const MuhajeerLogoBadge(size: 62, radius: 18),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Muhajeer Books',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: UzbekCustomerColors.navy,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Koreyadagi O’zbek kitobxonlari uchun',
                      style: TextStyle(
                        color: UzbekCustomerColors.textMuted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              UzbekMiniPill(
                icon: state.isOnlineBackend
                    ? Icons.cloud_done_rounded
                    : Icons.save_rounded,
                text: state.isOnlineBackend ? 'Onlayn' : 'Saqlanadi',
                color: state.isOnlineBackend
                    ? UzbekCustomerColors.success
                    : UzbekCustomerColors.goldDeep,
              ),
            ],
          ),
          const SizedBox(height: 13),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              UzbekMiniPill(
                icon: Icons.auto_stories_outlined,
                text: '$active kitob',
              ),
              UzbekMiniPill(
                icon: Icons.inventory_2_outlined,
                text: '$available mavjud',
                color: UzbekCustomerColors.success,
              ),
              const UzbekMiniPill(
                icon: Icons.auto_awesome_rounded,
                text: 'Milliy ruh',
                color: UzbekCustomerColors.goldDeep,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

'''
sub_one(r"class _StoreHeader extends StatelessWidget \{.*?(?=class _DeliveryPromoCard)", new_header, 'store header')

new_promo = r'''class _DeliveryPromoCard extends StatelessWidget {
  const _DeliveryPromoCard();

  @override
  Widget build(BuildContext context) {
    return UzbekPatternPanel(
      dark: true,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const UzbekMiniPill(
            icon: Icons.local_shipping_rounded,
            text: 'Koreya bo‘ylab yetkazib berish',
            dark: true,
          ),
          const SizedBox(height: 15),
          const Text(
            'O‘zbek kitoblari —\nKoreyadagi xonadoningizga.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1.14,
              letterSpacing: -.25,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Sodda buyurtma, ishonchli xizmat va kitobxonlarga mehr bilan.',
            style: TextStyle(
              color: Color(0xFFE9F3F0),
              fontSize: 12.5,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeroFact(icon: Icons.payments_outlined, text: '택배 ₩4,000'),
              _HeroFact(icon: Icons.schedule_rounded, text: '1–3 ish kuni'),
              _HeroFact(icon: Icons.card_giftcard_rounded, text: '4+ kitob — bepul'),
            ],
          ),
        ],
      ),
    );
  }
}

'''
sub_one(r"class _DeliveryPromoCard extends StatelessWidget \{.*?(?=class _HeroFact)", new_promo, 'delivery hero')

new_trust = r'''class _TrustStrip extends StatelessWidget {
  const _TrustStrip();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    decoration: BoxDecoration(
      color: UzbekCustomerColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: UzbekCustomerColors.border),
      boxShadow: const [
        BoxShadow(
          color: Color(0x09000000),
          blurRadius: 14,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: const Row(
      children: [
        Expanded(
          child: _TrustItem(
            icon: Icons.verified_outlined,
            text: 'Ishonchli buyurtma',
          ),
        ),
        _TrustDivider(),
        Expanded(
          child: _TrustItem(icon: Icons.schedule_rounded, text: '1–3 ish kuni'),
        ),
        _TrustDivider(),
        Expanded(
          child: _TrustItem(
            icon: Icons.favorite_border_rounded,
            text: 'Kitobxonga e’tibor',
          ),
        ),
      ],
    ),
  );
}

'''
sub_one(r"class _TrustStrip extends StatelessWidget \{.*?(?=class _TrustDivider)", new_trust, 'trust strip')

# Keep existing small trust widgets, only bring them into the new palette.
trust_start = store.index('class _TrustDivider')
trust_end = store.index('class _FeaturedBooksStrip')
trust_segment = store[trust_start:trust_end]
trust_segment = trust_segment.replace("const Color(0xFFE7E9ED)", "UzbekCustomerColors.border")
trust_segment = trust_segment.replace("color: _navy", "color: UzbekCustomerColors.teal")
store = store[:trust_start] + trust_segment + store[trust_end:]

# Editorial section heading for recommended books.
featured_start = store.index('class _FeaturedBooksStrip')
featured_end = store.index('class BookCard')
featured_segment = store[featured_start:featured_end]
featured_segment, count = re.subn(
    r"const Row\(\s*children: \[\s*Icon\(Icons\.auto_awesome_rounded,.*?\],\s*\),",
    "const UzbekSectionTitle(title: 'Tavsiya etamiz', icon: Icons.auto_awesome_rounded),",
    featured_segment,
    count=1,
    flags=re.S,
)
if count != 1:
    raise RuntimeError(f'featured heading: expected 1 replacement, got {count}')
store = store[:featured_start] + featured_segment + store[featured_end:]

# Book cards: warmer border/shadow + subtle national accent below cover.
card_start = store.index('class BookCard')
card_end = store.index('class _BookCover')
card_segment = store[card_start:card_end]
card_segment = card_segment.replace(
    "border: Border.all(color: AppColors.border),",
    "border: Border.all(color: UzbekCustomerColors.border),",
    1,
)
card_segment = card_segment.replace(
    "color: Color(0x0B0F172A),",
    "color: Color(0x100F4C5C),",
    1,
)
card_segment = card_segment.replace(
    "_BookCover(book: book),",
    "_BookCover(book: book),\n                  const Positioned(\n                    left: 0,\n                    right: 0,\n                    bottom: 0,\n                    child: UzbekAccentLine(),\n                  ),",
    1,
)
store = store[:card_start] + card_segment + store[card_end:]

# Payment block becomes a patterned light card; functionality stays identical.
payment_start = store.index('class _PaymentCard')
payment_end = store.index('Widget _priceRow', payment_start)
payment_segment = store[payment_start:payment_end]
payment_segment = payment_segment.replace(
    "Widget build(BuildContext context) => Container(\n    padding: const EdgeInsets.all(16),\n    decoration: BoxDecoration(\n      gradient: const LinearGradient(\n        colors: [Color(0xFFFFFBF1), Color(0xFFFFF2D2)],\n      ),\n      borderRadius: BorderRadius.circular(20),\n      border: Border.all(color: const Color(0xFFFFD88A)),\n    ),",
    "Widget build(BuildContext context) => UzbekPatternPanel(\n    padding: const EdgeInsets.all(16),",
    1,
)
store = store[:payment_start] + payment_segment + store[payment_end:]

# Customer profile: national visual identity, while admin entry remains intact.
new_profile = r'''class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final name = state.savedCustomer['name'] ?? '';
    final phone = state.savedCustomer['phone'] ?? '';
    return Scaffold(
      backgroundColor: UzbekCustomerColors.background,
      appBar: AppBar(
        backgroundColor: UzbekCustomerColors.background,
        surfaceTintColor: Colors.transparent,
        title: const Text('Profil'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          UzbekPatternPanel(
            dark: true,
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                const MuhajeerLogoCircle(size: 70),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.trim().isEmpty ? 'Muhajeer Books kitobxoni' : name.trim(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        phone.trim().isEmpty
                            ? 'Kitobga mehr — ma’rifatga qadam.'
                            : phone,
                        style: const TextStyle(
                          color: Color(0xFFE6F2EF),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          UzbekMiniPill(
                            icon: state.isOnlineBackend
                                ? Icons.cloud_done_rounded
                                : Icons.save_rounded,
                            text: state.isOnlineBackend
                                ? 'Onlayn hisob'
                                : 'Qurilmada saqlanadi',
                            dark: true,
                          ),
                          const UzbekMiniPill(
                            icon: Icons.auto_stories_rounded,
                            text: 'Kitobxon profili',
                            dark: true,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 19),
          const UzbekSectionTitle(
            title: 'Hisob va xizmatlar',
            subtitle: 'Buyurtmalaringiz va do‘kon xizmatlari',
            icon: Icons.person_outline_rounded,
          ),
          const SizedBox(height: 10),
          AppSurface(
            padding: EdgeInsets.zero,
            borderColor: UzbekCustomerColors.border,
            child: Column(
              children: [
                ListTile(
                  minTileHeight: 68,
                  leading: const _ProfileIcon(icon: Icons.receipt_long_outlined),
                  title: const Text(
                    'Mening buyurtmalarim',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    phone.isEmpty
                        ? 'Buyurtma berganingizdan keyin ko‘rinadi'
                        : 'Holatini kuzatish va tarixni ko‘rish',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MyOrdersPage()),
                  ),
                ),
                const Divider(),
                ListTile(
                  minTileHeight: 68,
                  leading: _ProfileIcon(
                    icon: state.isOnlineBackend
                        ? Icons.cloud_done_outlined
                        : Icons.save_outlined,
                  ),
                  title: const Text(
                    'Ma’lumotlar holati',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    state.isOnlineBackend
                        ? 'Barcha qurilmalarda sinxron ishlaydi'
                        : 'Hozir shu qurilmada saqlanadi',
                  ),
                ),
                const Divider(),
                ListTile(
                  minTileHeight: 68,
                  leading: const _ProfileIcon(
                    icon: Icons.admin_panel_settings_outlined,
                  ),
                  title: const Text(
                    'Admin paneli',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: const Text(
                    'Kitoblar, ombor, chegirma va buyurtmalar',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminGatePage()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          UzbekPatternPanel(
            padding: const EdgeInsets.all(14),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.format_quote_rounded, color: UzbekCustomerColors.goldDeep),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '“Kitob — insonning eng sokin, ammo eng dono hamrohidir.”',
                    style: TextStyle(
                      color: UzbekCustomerColors.navy,
                      fontWeight: FontWeight.w700,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

'''
sub_one(r"class ProfilePage extends StatelessWidget \{.*?(?=class _ProfileIcon)", new_profile, 'profile page')

# Checkout numbered steps use the customer palette.
store = store.replace("color: AppColors.navy,\n          borderRadius: BorderRadius.circular(11),", "color: UzbekCustomerColors.teal,\n          borderRadius: BorderRadius.circular(11),", 1)

store_path.write_text(store, encoding='utf-8')

style_path.write_text(r'''import 'package:flutter/material.dart';

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
              child: CustomPaint(
                painter: _UzbekPatternPainter(dark: dark),
              ),
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
        color: dark ? const Color(0x16FFFFFF) : Colors.white.withValues(alpha: .82),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: dark ? const Color(0x2AFFFFFF) : color.withValues(alpha: .18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: dark ? UzbekCustomerColors.gold : foreground),
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
      ..color = (dark ? Colors.white : UzbekCustomerColors.teal)
          .withValues(alpha: dark ? .075 : .065);
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
''', encoding='utf-8')

pubspec = pubspec_path.read_text(encoding='utf-8')
pubspec = re.sub(r'^version:\s*[^\n]+', 'version: 2.3.0+5', pubspec, count=1, flags=re.M)
pubspec_path.write_text(pubspec, encoding='utf-8')

print('Modern Uzbek customer design applied.')
