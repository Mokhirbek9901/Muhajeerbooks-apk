import 'package:flutter/material.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String? fullName;
  String? phone;
  String? address;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Bildirishnomalar',
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () => _openPlaceholder(context, 'Bildirishnomalar'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _headerCard(theme),
          const SizedBox(height: 16),

          // --- Sozlamalar bo‘limi
          Text('Sozlamalar', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          _tile(
            icon: Icons.person_outline_rounded,
            title: 'Profilni sozlash',
            subtitle: 'Ism, telefon va manzil',
            onTap: () async {
              final result = await Navigator.of(context).push<_ProfileData>(
                MaterialPageRoute(builder: (_) => EditProfilePage(
                  initial: _ProfileData(
                    fullName: fullName,
                    phone: phone,
                    address: address,
                  ),
                )),
              );
              if (result != null) {
                setState(() {
                  fullName = result.fullName;
                  phone = result.phone;
                  address = result.address;
                });
              }
            },
          ),
          _tile(
            icon: Icons.receipt_long_outlined,
            title: 'Buyurtmalarim',
            subtitle: 'So‘nggi buyurtmalar va holati',
            onTap: () => _openPlaceholder(context, 'Buyurtmalarim'),
          ),
          _tile(
            icon: Icons.translate_rounded,
            title: 'Tilni sozlash',
            subtitle: "O'zbekcha / Русский / English",
            onTap: () => _openPlaceholder(context, 'Tilni sozlash'),
          ),
          _tile(
            icon: Icons.help_outline_rounded,
            title: "Biz bilan bog'lanish",
            subtitle: "Telegram / Telefon / Email",
            onTap: () => _openPlaceholder(context, "Biz bilan bog'lanish"),
          ),

          const SizedBox(height: 16),
          // --- Hisob bo‘limi
          Text('Hisob', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          _tile(
            icon: Icons.logout_rounded,
            title: 'Chiqish',
            onTap: () => _confirm(
              context,
              title: 'Chiqish',
              message: 'Hisobdan chiqishni tasdiqlaysizmi?',
              onYes: () => _snack(context, 'Chiqildi (demo).'),
            ),
          ),
          _tile(
            icon: Icons.delete_forever_outlined,
            title: "Akkountni o'chirish",
            titleColor: Colors.red,
            onTap: () => _confirm(
              context,
              title: "Akkountni o'chirish",
              message:
                  "Haqiqatan ham akkountni o'chirmoqchimisiz? Bu amal bekor qilib bo'lmaydi.",
              onYes: () => _snack(context, "Akkount o'chirildi (demo)."),
            ),
          ),

          const SizedBox(height: 24),
          Center(
            child: Text(
              'Versiya: 1.0.5',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerCard(ThemeData theme) {
    final initials = (fullName ?? 'Mavjud emas')
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .map((e) => e.characters.first.toUpperCase())
        .take(2)
        .join();

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              child: Text(
                initials.isEmpty ? '?' : initials,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(fullName ?? 'Mavjud emas',
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.phone_rounded,
                          size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          phone ?? 'Telefon kiritilmagan',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: Colors.grey.shade700),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          address ?? 'Manzil kiritilmagan',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: Colors.grey.shade700),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Taxrirlash',
              onPressed: () async {
                final result = await Navigator.of(context).push<_ProfileData>(
                  MaterialPageRoute(
                    builder: (_) => EditProfilePage(
                      initial: _ProfileData(
                        fullName: fullName,
                        phone: phone,
                        address: address,
                      ),
                    ),
                  ),
                );
                if (result != null) {
                  setState(() {
                    fullName = result.fullName;
                    phone = result.phone;
                    address = result.address;
                  });
                }
              },
              icon: const Icon(Icons.edit_rounded),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? titleColor,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: Colors.grey.shade100,
          child: Icon(icon, color: Colors.black87),
        ),
        title: Text(
          title,
          style: TextStyle(color: titleColor),
        ),
        subtitle: subtitle == null ? null : Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }

  void _openPlaceholder(BuildContext context, String title) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _SimplePage(title: title),
      ),
    );
  }

  Future<void> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required VoidCallback onYes,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Bekor qilish')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Ha')),
        ],
      ),
    );
    if (ok == true) onYes();
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

/// Soddalashtirilgan tahrirlash sahifasi (faqat lokal holatda saqlanadi).
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({Key? key, required this.initial}) : super(key: key);
  final _ProfileData initial;

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late final TextEditingController _name =
      TextEditingController(text: widget.initial.fullName ?? '');
  late final TextEditingController _phone =
      TextEditingController(text: widget.initial.phone ?? '');
  late final TextEditingController _address =
      TextEditingController(text: widget.initial.address ?? '');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profilni sozlash')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'To‘liq ism',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Telefon',
              prefixIcon: Icon(Icons.phone_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _address,
            decoration: const InputDecoration(
              labelText: 'Manzil',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            icon: const Icon(Icons.save_rounded),
            label: const Text('Saqlash'),
            onPressed: () {
              Navigator.pop(
                context,
                _ProfileData(
                  fullName: _name.text.trim().isEmpty ? null : _name.text.trim(),
                  phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
                  address: _address.text.trim().isEmpty ? null : _address.text.trim(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SimplePage extends StatelessWidget {
  const _SimplePage({Key? key, required this.title}) : super(key: key);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
       
