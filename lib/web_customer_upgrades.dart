import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'uzbek_customer_style.dart';
import 'push_notifications.dart';

// Address data remains on the customer's device: the current phone-only
// profile is not verified strongly enough to expose cloud address records.
class WebSavedAddresses {
  static String key(String phone) =>
      'muhajeer_address_v1_${phone.replaceAll(RegExp(r"[^0-9]"), "")}';
  static Future<List<Map<String,String>>> load(String phone) async {
    if (phone.trim().isEmpty) return [];
    final prefs = await SharedPreferences.getInstance();
    try {
      final rows = jsonDecode(prefs.getString(key(phone)) ?? '[]') as List;
      return rows.whereType<Map>().map((e) => <String,String>{
        'label': (e['label'] ?? 'Manzil').toString(),
        'address': (e['address'] ?? '').toString(),
      }).where((e) => (e['address'] ?? '').isNotEmpty).take(8).toList();
    } catch (_) { return []; }
  }
  static Future<void> save(String phone, List<Map<String,String>> rows) async {
    if (phone.trim().isEmpty) return;
    final p = await SharedPreferences.getInstance();
    await p.setString(key(phone), jsonEncode(rows.take(8).toList()));
  }
}

class WebAddressBookPage extends StatefulWidget {
  const WebAddressBookPage({super.key, required this.phone, this.pick = false});
  final String phone;
  final bool pick;
  @override
  State<WebAddressBookPage> createState() => _WebAddressBookPageState();
}

class _WebAddressBookPageState extends State<WebAddressBookPage> {
  List<Map<String,String>> rows = [];
  bool loading = true;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final loaded = await WebSavedAddresses.load(widget.phone);
    if (mounted) setState(() { rows = loaded; loading = false; });
  }
  Future<void> _edit([int? index]) async {
    final old = index == null ? <String,String>{} : rows[index];
    final label = TextEditingController(text: old['label'] ?? '');
    final address = TextEditingController(text: old['address'] ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(index == null ? 'Yangi manzil' : 'Manzilni tahrirlash'),
        content: SizedBox(width: 420, child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: label, decoration: const InputDecoration(
              labelText: 'Nomi', hintText: 'Uy yoki ish')),
            const SizedBox(height: 12),
            TextField(controller: address, minLines: 2, maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'To‘liq manzil', hintText: 'Ko‘cha, bino, xona raqami')),
          ],
        )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Bekor qilish')),
          FilledButton(onPressed: () {
            if (address.text.trim().length < 8) return;
            Navigator.pop(ctx, true);
          }, child: const Text('Saqlash')),
        ],
      ),
    );
    if (ok == true && mounted) {
      final next = [...rows];
      final entry = <String,String>{
        'label': label.text.trim().isEmpty ? 'Manzil' : label.text.trim(),
        'address': address.text.trim(),
      };
      if (index == null) { if (next.length < 8) next.add(entry); }
      else { next[index] = entry; }
      await WebSavedAddresses.save(widget.phone, next);
      if (mounted) setState(() => rows = next);
    }
    label.dispose(); address.dispose();
  }
  Future<void> _delete(int index) async {
    final next = [...rows]..removeAt(index);
    await WebSavedAddresses.save(widget.phone, next);
    if (mounted) setState(() => rows = next);
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: UzbekCustomerColors.background,
    appBar: AppBar(title: Text(widget.pick ? 'Manzilni tanlang' : 'Manzillarim'),
      backgroundColor: UzbekCustomerColors.background),
    body: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 650),
      child: loading ? const Center(child: CircularProgressIndicator()) :
      ListView(padding: const EdgeInsets.all(18), children: [
        const Text('Saqlangan manzillar shu qurilmada saqlanadi.',
          style: TextStyle(fontSize: 12, color: UzbekCustomerColors.textMuted)),
        const SizedBox(height: 12),
        for (var i = 0; i < rows.length; i++)
          Card(child: ListTile(
            leading: const Icon(Icons.location_on_outlined),
            title: Text(rows[i]['label'] ?? 'Manzil',
              style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(rows[i]['address'] ?? ''),
            onTap: widget.pick ? () => Navigator.pop(context, rows[i]['address']) : null,
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(onPressed: () => _edit(i),
                tooltip: 'Tahrirlash', icon: const Icon(Icons.edit_outlined)),
              IconButton(onPressed: () => _delete(i),
                tooltip: 'O‘chirish', icon: const Icon(Icons.delete_outline)),
            ]),
          )),
        const SizedBox(height: 10),
        FilledButton.icon(onPressed: rows.length >= 8 ? null : () => _edit(),
          icon: const Icon(Icons.add_location_alt_outlined),
          label: const Text('Manzil qo‘shish')),
        if (widget.pick)
          TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('Manzilni qo‘lda kiritish')),
      ]),
    )),
  );
}

class WebCustomerSettingsPage extends StatefulWidget {
  const WebCustomerSettingsPage({super.key});
  @override
  State<WebCustomerSettingsPage> createState() => _WebCustomerSettingsPageState();
}
class _WebCustomerSettingsPageState extends State<WebCustomerSettingsPage> {
  String _status = 'checking';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    if (!kIsWeb || !pushNotificationsSupported) {
      if (mounted) setState(() => _status = 'unsupported');
      return;
    }
    final permission = pushNotificationPermissionStatusSync();
    final endpoint = permission == 'granted'
        ? await existingWebPushEndpoint() : '';
    if (!mounted) return;
    setState(() {
      _status = endpoint.isNotEmpty ? 'enabled'
          : permission == 'denied' ? 'blocked' : 'off';
    });
  }

  Future<void> _clearSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('muhajeer_web_recent_searches_v1');
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Qidiruv tarixi tozalandi ✅')));
  }

  Future<void> _push() async {
    if (_busy || !kIsWeb || !pushNotificationsSupported) return;
    setState(() => _busy = true);
    try {
      final ok = await enablePushNotifications();
      await _checkStatus();
      if (!mounted) return;
      final success = ok && _status == 'enabled';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success
          ? 'Bildirishnomalar muvaffaqiyatli yoqildi ✅'
          : _status == 'blocked'
            ? 'Ruxsat bloklangan. Telefon yoki brauzer sozlamalaridan bildirishnomani yoqing.'
            : 'Push yoqilmadi. Brauzer ruxsatlarini tekshiring.'),
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _info(IconData icon, String title, String description) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 23, color: UzbekCustomerColors.teal),
      const SizedBox(width: 12),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(description, style: const TextStyle(fontSize: 12,
            height: 1.5, color: UzbekCustomerColors.textMuted)),
        ],
      )),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    final enabled = _status == 'enabled';
    final available = kIsWeb && pushNotificationsSupported;
    final statusLabel = _status == 'checking' ? 'Holat tekshirilmoqda…'
      : enabled ? 'Bildirishnomalar faol'
      : _status == 'blocked' ? 'Bildirishnoma ruxsati bloklangan'
      : available ? 'Hozircha yoqilmagan'
      : 'Ushbu versiyada push mavjud emas';
    return Scaffold(
      backgroundColor: UzbekCustomerColors.background,
      appBar: AppBar(title: const Text('Sozlamalar'),
        backgroundColor: UzbekCustomerColors.background),
      body: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 650),
        child: ListView(padding: const EdgeInsets.all(18), children: [
          Card(child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Icon(Icons.notifications_active_outlined,
                    color: UzbekCustomerColors.teal, size: 28),
                  SizedBox(width: 12),
                  Expanded(child: Text('Bildirishnomalar',
                    style: TextStyle(fontSize: 19,
                      fontWeight: FontWeight.w900))),
                ]),
                const SizedBox(height: 10),
                const Text('Muhajeer Books yangiliklari va buyurtmalaringiz haqidagi muhim xabarlarni o‘z vaqtida oling.',
                  style: TextStyle(fontSize: 13, height: 1.5)),
                const SizedBox(height: 12),
                _info(Icons.menu_book_outlined, 'Yangi va qayta kelgan kitoblar',
                  'Yangi kitoblar qo‘shilganda yoki siz kutgan kitob omborga qaytganda.'),
                _info(Icons.receipt_long_outlined, 'Buyurtma xabarlari',
                  'Buyurtmangiz yuborilganda va qabul qilinganda.'),
                _info(Icons.local_shipping_outlined, 'Jo‘natish va yetkazish',
                  'Kitob pochtaga topshirilganda; kuzatuv ma’lumotlari buyurtmalaringizda ko‘rsatiladi.'),
                _info(Icons.rate_review_outlined, 'Kitob haqida fikr',
                  'Xarid qilgan kitoblaringizni baholash va sharh qoldirish eslatmalari.'),
                const Divider(height: 28),
                Row(children: [
                  Icon(enabled ? Icons.check_circle_rounded :
                    _status == 'blocked' ? Icons.warning_amber_rounded :
                      Icons.notifications_none_outlined,
                    color: enabled ? UzbekCustomerColors.teal :
                      UzbekCustomerColors.textMuted, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(statusLabel,
                    style: const TextStyle(fontWeight: FontWeight.w800))),
                ]),
                const SizedBox(height: 12),
                if (available) SizedBox(width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _busy || enabled || _status == 'checking'
                      ? null : _push,
                    icon: Icon(enabled ? Icons.check_circle_outline :
                        Icons.notifications_active_outlined),
                    label: Text(_busy ? 'Yoqilmoqda…'
                      : enabled ? 'Bildirishnomalar yoqilgan'
                      : 'Bildirishnomalarni yoqish'),
                  )),
                if (_status == 'blocked')
                  const Text('Ruxsat avval rad etilgan. Brauzer yoki telefon sozlamalarida bildirishnomaga ruxsat bering.',
                    style: TextStyle(fontSize: 12,
                      color: UzbekCustomerColors.textMuted)),
                if (!available)
                  const Text('Ilova ichidagi xabarlarni ko‘rishingiz mumkin. Bu versiyada telefon ekraniga push yuborish yoqilmagan; mos veb-brauzerda pushdan foydalanish mumkin.',
                    style: TextStyle(fontSize: 12, height: 1.5,
                      color: UzbekCustomerColors.textMuted)),
              ],
            ),
          )),
          const SizedBox(height: 12),
          Card(child: Column(children: [
            ListTile(leading: const Icon(Icons.history_rounded),
              title: const Text('Qidiruv tarixini tozalash'),
              onTap: _clearSearches),
            const Divider(height: 1),
            ListTile(leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Maxfiylik siyosati'),
              onTap: () => launchUrl(Uri.parse(
                'https://muhajeer-books-live-production.up.railway.app/privacy.html'),
                mode: LaunchMode.externalApplication)),
          ])),
        ]),
      )),
    );
  }
}
