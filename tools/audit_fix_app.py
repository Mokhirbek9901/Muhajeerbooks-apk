from pathlib import Path
import re


def replace_once(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected 1 match, found {count}")
    return text.replace(old, new, 1)

# App state: exact channel ownership.
state_path = Path('lib/app_state.dart')
s = state_path.read_text(encoding='utf-8')
s = replace_once(
    s,
    "  bool get isTelegram => source == 'telegram';\n  bool get isApp => !isTelegram;",
    "  bool get isTelegram => source == 'telegram';\n  bool get isInstagram => source == 'instagram';\n  bool get isApp => source == 'app';",
    'ShopOrder source getters',
)
state_path.write_text(s, encoding='utf-8')

# Admin: only Jo‘natildi is a realized sale.
admin_path = Path('lib/admin_ui.dart')
a = admin_path.read_text(encoding='utf-8')

a = replace_once(
    a,
    "          final monthRevenue = monthOrders\n              .where((o) => activeStatuses.contains(o.status))\n              .fold<int>(0, (sum, o) => sum + o.total);",
    "          final monthRevenue = monthOrders\n              .where((o) => o.status == 'shipping')\n              .fold<int>(0, (sum, o) => sum + o.total);",
    'month shipped revenue',
)

a = replace_once(
    a,
    "                activeStatuses.contains(o.status);",
    "                o.status == 'shipping';",
    'today shipped revenue',
)

old_change = """  Future<void> changeStatus(ShopOrder order, String status) async {
    if (order.isTelegram) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Telegram buyurtmasi botdan boshqariladi.')),
        );
      }
      return;
    }"""
new_change = """  Future<void> changeStatus(ShopOrder order, String status) async {
    if (!order.isApp) {
      if (mounted) {
        final message = order.isInstagram
            ? 'Instagram savdosi Telegram botdan boshqariladi.'
            : 'Telegram buyurtmasi botdan boshqariladi.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
      return;
    }"""
a = replace_once(a, old_change, new_change, 'order source management guard')

# Add a distinct Instagram badge after the existing Telegram source badge.
badge_pattern = re.compile(
    r"(\s+if \(order\.isTelegram\) \.\.\.\[.*?'Telegramdan zakas'.*?\n\s*\],)",
    re.S,
)
match = badge_pattern.search(a)
if not match:
    raise SystemExit('order source badge: Telegram badge not found')
instagram_badge = """
              if (order.isInstagram) ...[
                const Icon(
                  Icons.photo_camera_outlined,
                  size: 15,
                  color: Color(0xFFC13584),
                ),
                const SizedBox(width: 4),
                const Text(
                  'Instagram savdo',
                  style: TextStyle(
                    color: Color(0xFFC13584),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],"""
a = a[:match.end()] + instagram_badge + a[match.end():]

old_action_guard = """    if (order.isTelegram) {
      return const AppInfoPill(
        icon: Icons.send_rounded,
        label: 'Telegram buyurtmasi — botdan boshqariladi',
        foreground: Color(0xFF1976A3),
        background: Color(0xFFEAF7FD),"""
new_action_guard = """    if (!order.isApp) {
      return AppInfoPill(
        icon: order.isInstagram ? Icons.photo_camera_outlined : Icons.send_rounded,
        label: order.isInstagram
            ? 'Instagram savdo — botdan boshqariladi'
            : 'Telegram buyurtmasi — botdan boshqariladi',
        foreground: order.isInstagram
            ? const Color(0xFFC13584)
            : const Color(0xFF1976A3),
        background: order.isInstagram
            ? const Color(0xFFFCEAF4)
            : const Color(0xFFEAF7FD),"""
a = replace_once(a, old_action_guard, new_action_guard, 'order action source lock')

admin_path.write_text(a, encoding='utf-8')
print('App audit fixes applied: shipped-only revenue + exact order source ownership.')
