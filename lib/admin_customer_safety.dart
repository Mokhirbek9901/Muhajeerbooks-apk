part of 'admin_ui.dart';

class _CustomerSafetyAdmin extends StatefulWidget {
  const _CustomerSafetyAdmin({required this.api});
  final _AdminApi api;
  @override
  State<_CustomerSafetyAdmin> createState() => _CustomerSafetyAdminState();
}

class _CustomerSafetyAdminState extends State<_CustomerSafetyAdmin> {
  List<Map<String, dynamic>> recoveries = [], reports = [];
  bool loading = true, busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final results = await Future.wait([
        widget.api._rpc(
          'admin_release_recover_pin',
          params: {'p_secret': widget.api.secret, 'p_action': 'list'},
        ),
        widget.api._rpc(
          'admin_release_review_reports',
          params: {'p_secret': widget.api.secret, 'p_action': 'list'},
        ),
      ]);
      if (mounted)
        setState(() {
          recoveries = (results[0] as List)
              .map((x) => Map<String, dynamic>.from(x as Map))
              .toList();
          reports = (results[1] as List)
              .map((x) => Map<String, dynamic>.from(x as Map))
              .toList();
          loading = false;
          error = null;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          error = '$e';
          loading = false;
        });
    }
  }

  Future<void> act(String name, Map<String, dynamic> params) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await widget.api._rpc(
        name,
        params: {'p_secret': widget.api.secret, ...params},
      );
      await load();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> reset(Map<String, dynamic> row) async {
    final pin = TextEditingController();
    bool verified = false;
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: const Text('PINni admin orqali tiklash'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${row['full_name']} • ${row['phone_key']}\n${row['note']}'),
              CheckboxListTile(
                value: verified,
                onChanged: (v) => update(() => verified = v ?? false),
                title: const Text(
                  'Shaxs va eski buyurtmalarni mustaqil tekshirdim',
                ),
              ),
              TextField(
                controller: pin,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Yangi vaqtinchalik PIN',
                ),
              ),
              const Text(
                'PINni faqat tasdiqlangan mijozga shaxsan yetkazing. Barcha eski sessiyalar bekor qilinadi.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hozir emas'),
            ),
            FilledButton(
              onPressed: verified ? () => Navigator.pop(ctx, pin.text) : null,
              child: const Text('PINni almashtirish'),
            ),
          ],
        ),
      ),
    );
    pin.dispose();
    if (value != null && mounted)
      await act('admin_release_recover_pin', {
        'p_action': 'reset',
        'p_id': row['id'],
        'p_pin': value,
      });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Profil tiklash va sharhlar'),
      actions: [
        IconButton(
          onPressed: busy ? null : load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(18),
            children: [
              if (error != null) Text(error!),
              if (busy) const LinearProgressIndicator(),
              const Text(
                'PIN tiklash so‘rovlari',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              if (recoveries.isEmpty) const Text('Yangi so‘rov yo‘q'),
              for (final r in recoveries)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${r['full_name']} • ${r['phone_key']}\n${r['note']}',
                        ),
                        Wrap(
                          spacing: 10,
                          children: [
                            FilledButton(
                              onPressed: busy ? null : () => reset(r),
                              child: const Text('Tekshirish va tiklash'),
                            ),
                            TextButton(
                              onPressed: busy
                                  ? null
                                  : () => act('admin_release_recover_pin', {
                                      'p_action': 'reject',
                                      'p_id': r['id'],
                                    }),
                              child: const Text('Rad etish'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              const Divider(height: 32),
              const Text(
                'Sharh shikoyatlari',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              if (reports.isEmpty) const Text('Yangi shikoyat yo‘q'),
              for (final r in reports)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${r['reviewer_name']}: ${r['comment']}\nShikoyat: ${r['reason']}',
                        ),
                        Wrap(
                          spacing: 10,
                          children: [
                            FilledButton(
                              onPressed: busy
                                  ? null
                                  : () => act('admin_release_review_reports', {
                                      'p_action': 'hide',
                                      'p_id': r['id'],
                                    }),
                              child: const Text('Sharhni yashirish'),
                            ),
                            TextButton(
                              onPressed: busy
                                  ? null
                                  : () => act('admin_release_review_reports', {
                                      'p_action': 'dismiss',
                                      'p_id': r['id'],
                                    }),
                              child: const Text('Shikoyatni yopish'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
  );
}
