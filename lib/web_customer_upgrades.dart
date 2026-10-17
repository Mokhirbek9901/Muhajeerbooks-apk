import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'uzbek_customer_style.dart';
import 'push_notifications.dart';

// Address data remains on the customer's browser: the current phone-only
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
        const Text('Saqlangan manzillar shu brauzerda saqlanadi.',
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
  Future<void> _clearSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('muhajeer_web_recent_searches_v1');
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Qidiruv tarixi tozalandi ✅')));
  }
  Future<void> _push() async {
    final ok = await enablePushNotifications();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok
        ? 'Bildirishnomalar yoqildi ✅'
        : 'Ruxsat berilmadi. Brauzer sozlamalarini tekshiring.')));
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: UzbekCustomerColors.background,
    appBar: AppBar(title: const Text('Sozlamalar'),
      backgroundColor: UzbekCustomerColors.background),
    body: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 650),
      child: ListView(padding: const EdgeInsets.all(18), children: [
        Card(child: Column(children: [
          ListTile(leading: const Icon(Icons.notifications_outlined),
            title: const Text('Bildirishnomalar'),
            subtitle: const Text('Brauzerdan ruxsat so‘rash'),
            onTap: _push),
          const Divider(height: 1),
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
