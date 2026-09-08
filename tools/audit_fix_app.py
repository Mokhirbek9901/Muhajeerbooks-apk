from pathlib import Path
import re


def replace_once(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected 1 match, found {count}")
    return text.replace(old, new, 1)

# -------------------------
# App state: source identity must be exact.
# -------------------------
state_path = Path('lib/app_state.dart')
s = state_path.read_text(encoding='utf-8')
s = replace_once(
    s,
    "  bool get isTelegram => source == 'telegram';\n  bool get isApp => !isTelegram;",
    "  bool get isTelegram => source == 'telegram';\n  bool get isInstagram => source == 'instagram';\n  bool get isApp => source == 'app';",
    'ShopOrder source getters',
)
state_path.write_text(s, encoding='utf-8')

# -------------------------
# Admin: sales revenue is final only after Jo‘natildi.
# Instagram/Telegram orders are read-only outside their owner channel.
# -------------------------
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

old_badge = """              if (order.isTelegram) ...[
                const Icon(Icons.send_rounded,
                    size: 15, color: Color(0xFF229ED9)),
                const SizedBox(width: 4),
                const Text(
                  'Telegramdan zakas',
                  style: TextStyle(
                    color: Color(0xFF1976A3),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],"""
new_badge = """              if (order.isTelegram) ...[
                const Icon(Icons.send_rounded,
                    size: 15, color: Color(0xFF229ED9)),
                const SizedBox(width: 4),
                const Text(
                  'Telegramdan zakas',
                  style: TextStyle(
                    color: Color(0xFF1976A3),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ] else if (order.isInstagram) ...[
                const Icon(Icons.photo_camera_outlined,
                    size: 15, color: Color(0xFFC13584)),
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
a = replace_once(a, old_badge, new_badge, 'order source badge')

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
