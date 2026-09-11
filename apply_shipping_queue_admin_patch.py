from pathlib import Path

path = Path('lib/admin_ui.dart')
s = path.read_text(encoding='utf-8')


def once(old, new, label):
    global s
    if old not in s:
        raise RuntimeError(f'patch marker not found: {label}')
    s = s.replace(old, new, 1)

# Admin API: shared postal queue RPCs.
once(
    '\n}\n\nclass AdminGatePage extends StatefulWidget {',
    r'''

  Future<List<Map<String, dynamic>>> shippingQueue() async {
    final raw = await client.rpc(
      'admin_shipping_queue_list',
      params: {'p_secret': secret},
    );
    return ((raw as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<Map<String, dynamic>> addShippingQueue({
    required String name,
    required String phone,
    required String address,
    required String books,
  }) async {
    final raw = await client.rpc(
      'admin_shipping_queue_add',
      params: {
        'p_secret': secret,
        'p_name': name,
        'p_phone': phone,
        'p_address': address,
        'p_books': books,
        'p_address_photo_file_id': '',
      },
    );
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  Future<void> dismissShippingQueue({
    required String kind,
    required String id,
  }) async {
    await client.rpc(
      'admin_shipping_queue_dismiss',
      params: {'p_secret': secret, 'p_kind': kind, 'p_id': id},
    );
  }
}

class AdminGatePage extends StatefulWidget {''',
    'admin api methods',
)

# Put Zakaslar as the 4th dashboard item: after Bugungi buyurtma, before Ombor.
anchor = r'''                        SizedBox(
                          width: cardWidth,
                          child: AppMetricCard(
                            icon: Icons.today_outlined,
                            label: 'Bugungi buyurtma',
                            value: '$todayOrders',
                            accent: AppColors.info,
                            note: DateFormat('yyyy.MM.dd').format(now),
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: AppMetricCard(
                            icon: Icons.inventory_2_outlined,'''
replacement = r'''                        SizedBox(
                          width: cardWidth,
                          child: AppMetricCard(
                            icon: Icons.today_outlined,
                            label: 'Bugungi buyurtma',
                            value: '$todayOrders',
                            accent: AppColors.info,
                            note: DateFormat('yyyy.MM.dd').format(now),
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(AppRadii.large),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => Scaffold(
                                    appBar: AppBar(
                                      title: const Text('Zakaslar'),
                                    ),
                                    body: _ShippingQueueAdmin(api: widget.api),
                                  ),
                                ),
                              );
                            },
                            child: const AppMetricCard(
                              icon: Icons.local_shipping_outlined,
                              label: 'Zakaslar',
                              value: 'Ochish',
                              accent: AppColors.navy,
                              note: 'Pochta uchun nusxa olish',
                            ),
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: AppMetricCard(
                            icon: Icons.inventory_2_outlined,'''
once(anchor, replacement, 'dashboard 4th card')

# Full shipping queue page.
page_class = r'''
class _ShippingQueueAdmin extends StatefulWidget {
  const _ShippingQueueAdmin({required this.api});
  final _AdminApi api;

  @override
  State<_ShippingQueueAdmin> createState() => _ShippingQueueAdminState();
}

class _ShippingQueueAdminState extends State<_ShippingQueueAdmin> {
  List<Map<String, dynamic>> rows = const [];
  bool loading = true;
  String? error;
  String filter = 'all';

  @override
  void initState() {
    super.initState();
    unawaited(reload());
  }

  Future<void> reload() async {
    if (mounted) setState(() { loading = true; error = null; });
    try {
      final data = await widget.api.shippingQueue();
      if (!mounted) return;
      setState(() => rows = data);
    } catch (e) {
      if (!mounted) return;
      setState(() => error = 'Zakaslarni yuklab bo‘lmadi.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List<Map<String, dynamic>> get visibleRows {
    if (filter == 'all') return rows;
    return rows.where((row) => (row['source'] ?? '').toString() == filter).toList();
  }

  String sourceLabel(String source) {
    switch (source) {
      case 'telegram': return 'Telegram bot';
      case 'app': return 'Ilova / Web';
      case 'manual': return 'Qo‘lda';
      default: return 'Zakas';
    }
  }

  IconData sourceIcon(String source) {
    switch (source) {
      case 'telegram': return Icons.send_rounded;
      case 'app': return Icons.phone_iphone_rounded;
      case 'manual': return Icons.edit_note_rounded;
      default: return Icons.local_shipping_outlined;
    }
  }

  Future<void> copyValue(String label, String value) async {
    final clean = value.trim();
    if (clean.isEmpty || clean == '—') return;
    await Clipboard.setData(ClipboardData(text: clean));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label nusxalandi')),
    );
  }

  Future<void> addManual() async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final address = TextEditingController();
    final books = TextEditingController();
    bool saving = false;
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Qo‘lda zakas qo‘shish'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(
                      labelText: 'Ism',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Telefon',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: address,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Manzil',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: books,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Kitoblar',
                      hintText: 'Dafina 1 ta\nSaodat asri 2 ta',
                      prefixIcon: Icon(Icons.menu_book_outlined),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext, false),
              child: const Text('Bekor qilish'),
            ),
            FilledButton.icon(
              onPressed: saving ? null : () async {
                if (name.text.trim().isEmpty ||
                    phone.text.trim().isEmpty ||
                    address.text.trim().isEmpty ||
                    books.text.trim().isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Barcha maydonlarni to‘ldiring.')),
                  );
                  return;
                }
                setDialogState(() => saving = true);
                try {
                  await widget.api.addShippingQueue(
                    name: name.text.trim(),
                    phone: phone.text.trim(),
                    address: address.text.trim(),
                    books: books.text.trim(),
                  );
                  if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                } catch (_) {
                  setDialogState(() => saving = false);
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(content: Text('Zakas saqlanmadi.')),
                    );
                  }
                }
              },
              icon: saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_outlined),
              label: Text(saving ? 'Saqlanmoqda...' : 'Saqlash'),
            ),
          ],
        ),
      ),
    );
    name.dispose(); phone.dispose(); address.dispose(); books.dispose();
    if (ok == true) {
      await reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Zakas saqlandi.')),
        );
      }
    }
  }

  Future<void> removeRow(Map<String, dynamic> row) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Zakasni o‘chirish'),
        content: const Text(
          'Rostdan ham bu zakasni pochta ro‘yxatidan o‘chirasizmi?\n\nAsl buyurtma, ombor va statistika o‘zgarmaydi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Yo‘q'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Ha, o‘chirish'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.api.dismissShippingQueue(
        kind: (row['queue_kind'] ?? '').toString(),
        id: (row['queue_id'] ?? '').toString(),
      );
      await reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Zakas pochta ro‘yxatidan o‘chirildi.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Zakasni o‘chirib bo‘lmadi.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = visibleRows;
    if (loading && rows.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(18),
        children: [
          AppPageHeading(
            title: 'Pochta uchun zakaslar',
            subtitle: 'Ism, telefon va manzilni alohida nusxalab pochta ilovasiga joylang.',
            trailing: FilledButton.icon(
              onPressed: addManual,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Qo‘lda qo‘shish'),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(label: Text('Barchasi (${rows.length})'), selected: filter == 'all', onSelected: (_) => setState(() => filter = 'all')),
              ChoiceChip(label: const Text('Bot'), selected: filter == 'telegram', onSelected: (_) => setState(() => filter = 'telegram')),
              ChoiceChip(label: const Text('Ilova'), selected: filter == 'app', onSelected: (_) => setState(() => filter = 'app')),
              ChoiceChip(label: const Text('Qo‘lda'), selected: filter == 'manual', onSelected: (_) => setState(() => filter = 'manual')),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            AppInfoPill(
              icon: Icons.error_outline_rounded,
              label: error!,
              foreground: AppColors.danger,
              background: AppColors.dangerSoft,
            ),
          ],
          const SizedBox(height: 14),
          if (list.isEmpty)
            const AppSurface(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 34),
                child: Center(
                  child: Text('Hozircha zakas yo‘q.', style: TextStyle(color: AppColors.muted)),
                ),
              ),
            )
          else
            ...list.map((row) {
              final source = (row['source'] ?? '').toString();
              final name = (row['name'] ?? '—').toString();
              final phone = (row['phone'] ?? '—').toString();
              final address = (row['address'] ?? '—').toString();
              final books = (row['books'] ?? '• Kitob ma’lumoti yo‘q').toString();
              final orderNumber = row['order_number'];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppSurface(
                  shadow: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceSoft,
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Icon(sourceIcon(source), color: AppColors.navy),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                                Text(
                                  '${sourceLabel(source)}${orderNumber == null ? '' : ' · №$orderNumber'}',
                                  style: const TextStyle(fontSize: 11.5, color: AppColors.muted, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Pochta ro‘yxatidan o‘chirish',
                            onPressed: () => removeRow(row),
                            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _ShippingCopyRow(
                        icon: Icons.person_outline_rounded,
                        label: 'Ism',
                        value: name,
                        onCopy: () => copyValue('Ism', name),
                      ),
                      const SizedBox(height: 9),
                      _ShippingCopyRow(
                        icon: Icons.phone_outlined,
                        label: 'Telefon',
                        value: phone,
                        onCopy: () => copyValue('Telefon', phone),
                      ),
                      const SizedBox(height: 9),
                      _ShippingCopyRow(
                        icon: Icons.location_on_outlined,
                        label: 'Manzil',
                        value: address,
                        onCopy: () => copyValue('Manzil', address),
                      ),
                      const SizedBox(height: 14),
                      const Divider(),
                      const SizedBox(height: 8),
                      const Text('📚 Kitoblar', style: TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 6),
                      SelectableText(books, style: const TextStyle(height: 1.45)),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 60),
        ],
      ),
    );
  }
}

class _ShippingCopyRow extends StatelessWidget {
  const _ShippingCopyRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onCopy,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: AppColors.muted),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              SelectableText(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.35)),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Nusxa olish',
          onPressed: onCopy,
          icon: const Icon(Icons.copy_rounded, size: 20),
        ),
      ],
    );
  }
}

'''
once(
    '\nclass _AdminProgressStat extends StatelessWidget {',
    '\n' + page_class + 'class _AdminProgressStat extends StatelessWidget {',
    'shipping queue page',
)

path.write_text(s, encoding='utf-8')
print('shipping queue admin patch applied')
