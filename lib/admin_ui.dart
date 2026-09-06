import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_state.dart';
import 'brand.dart';

const _navy = Color(0xFF10213D);
const _orange = Color(0xFFFF8A00);
final _money = NumberFormat('#,###', 'en_US');
String _won(int value) => '₩${_money.format(value)}';

class _AdminApi {
  _AdminApi(this.secret);
  final String secret;
  SupabaseClient get client => Supabase.instance.client;

  Future<bool> verify() async {
    final result = await client.rpc('admin_verify', params: {'p_secret': secret});
    return result == true;
  }

  Future<List<Book>> books() async {
    final data = await client.rpc('admin_list_books', params: {'p_secret': secret});
    return (data as List)
        .map((e) => Book.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> saveBook(Book book) async {
    await client.rpc('admin_save_book', params: {
      'p_secret': secret,
      'p_id': book.id.isEmpty || book.id.startsWith('local-') || book.id.startsWith('telegram-') ? null : book.id,
      'p_data': {
        'title': book.title,
        'author': book.author,
        'category': book.category,
        'description': book.description,
        'price': book.price,
        'stock': book.stock,
        'discount_percent': book.discountPercent,
        'image_url': book.imageUrl,
        'is_active': book.isActive,
        'cover': book.coverType,
        'cost_price': book.costPrice,
        'recommended': book.recommended,
      },
    });
  }

  Future<void> deleteBook(String id) async {
    await client.rpc('admin_delete_book', params: {'p_secret': secret, 'p_id': id});
  }

  Future<void> applyDiscount(int percent) async {
    await client.rpc('admin_apply_discount', params: {'p_secret': secret, 'p_percent': percent});
  }

  Future<void> clearDiscounts() async {
    await client.rpc('admin_clear_discounts', params: {'p_secret': secret});
  }

  Future<List<ShopOrder>> orders() async {
    final data = await client.rpc('admin_list_orders', params: {'p_secret': secret});
    return (data as List)
        .map((e) => ShopOrder.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> updateOrderStatus(String id, String status) async {
    await client.rpc('admin_update_order_status', params: {
      'p_secret': secret,
      'p_id': id,
      'p_status': status,
    });
  }
}

class AdminGatePage extends StatefulWidget {
  const AdminGatePage({super.key});

  @override
  State<AdminGatePage> createState() => _AdminGatePageState();
}

class _AdminGatePageState extends State<AdminGatePage> {
  final code = TextEditingController();
  bool loading = false;
  bool obscure = true;
  String? error;

  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final value = code.text.trim();
    if (value.isEmpty) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final api = _AdminApi(value);
      if (!await api.verify()) {
        if (mounted) setState(() => error = 'Admin kodi noto‘g‘ri.');
        return;
      }
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => AdminDashboardPage(secret: value)),
      );
    } catch (e) {
      if (mounted) setState(() => error = 'Kirishda xatolik. Internetni tekshiring.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin paneli')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              const Center(child: MuhajeerLogoBadge(size: 94, radius: 26)),
              const SizedBox(height: 18),
              const Text(
                'Muhajeer Books boshqaruvi',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 7),
              const Text(
                'Kitoblar, ombor, chegirmalar va buyurtmalar shu yerdan boshqariladi.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: code,
                obscureText: obscure,
                onSubmitted: (_) => _login(),
                decoration: InputDecoration(
                  labelText: 'Admin kodi',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => obscure = !obscure),
                    icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  ),
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: loading ? null : _login,
                icon: loading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.login_rounded),
                label: const Text('Kirish'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key, required this.secret});
  final String secret;

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  int tab = 0;
  late final _AdminApi api;

  @override
  void initState() {
    super.initState();
    api = _AdminApi(widget.secret);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _BooksAdmin(api: api),
      _OrdersAdmin(api: api),
      _DiscountAdmin(api: api),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            MuhajeerLogoBadge(size: 38, radius: 10, showShadow: false),
            SizedBox(width: 10),
            Text('Boshqaruv paneli'),
          ],
        ),
      ),
      body: pages[tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (v) => setState(() => tab = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), label: 'Kitoblar'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'Buyurtmalar'),
          NavigationDestination(icon: Icon(Icons.percent_rounded), label: 'Chegirma'),
        ],
      ),
    );
  }
}

class _BooksAdmin extends StatefulWidget {
  const _BooksAdmin({required this.api});
  final _AdminApi api;

  @override
  State<_BooksAdmin> createState() => _BooksAdminState();
}

class _BooksAdminState extends State<_BooksAdmin> {
  String query = '';
  late Future<List<Book>> future;

  @override
  void initState() {
    super.initState();
    future = widget.api.books();
  }

  void reload() {
    setState(() => future = widget.api.books());
    context.read<AppState>().refreshBooks();
  }

  Future<void> openForm([Book? book]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => _BookForm(api: widget.api, book: book)),
    );
    if (changed == true && mounted) reload();
  }

  Future<void> remove(Book book) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Kitobni o‘chirish'),
        content: Text('“${book.title}” o‘chirilsinmi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Yo‘q')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('O‘chirish')),
        ],
      ),
    );
    if (yes == true) {
      await widget.api.deleteBook(book.id);
      if (mounted) reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Book>>(
      future: future,
      builder: (context, snap) {
        final all = snap.data ?? const <Book>[];
        final q = query.trim().toLowerCase();
        final books = all.where((b) => q.isEmpty || b.title.toLowerCase().contains(q) || b.author.toLowerCase().contains(q)).toList();
        final totalStock = all.fold<int>(0, (s, b) => s + b.stock);
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _MiniStat(label: 'Kitob', value: '${all.length}'),
                      _MiniStat(label: 'Ombor', value: '$totalStock dona'),
                      _MiniStat(label: 'Kam qolgan', value: '${all.where((b) => b.stock <= 2).length}'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: (v) => setState(() => query = v),
                          decoration: const InputDecoration(hintText: 'Kitob yoki muallif...', prefixIcon: Icon(Icons.search)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(onPressed: reload, icon: const Icon(Icons.refresh_rounded)),
                      const SizedBox(width: 4),
                      FilledButton.icon(onPressed: () => openForm(), icon: const Icon(Icons.add), label: const Text('Qo‘shish')),
                    ],
                  ),
                ],
              ),
            ),
            if (snap.connectionState == ConnectionState.waiting)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (snap.hasError)
              Expanded(child: Center(child: Text('Xatolik: ${snap.error}')))
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
                  itemCount: books.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final b = books[i];
                    return Card(
                      child: ListTile(
                        leading: b.imageUrl.isEmpty
                            ? const CircleAvatar(child: Icon(Icons.menu_book_rounded))
                            : CircleAvatar(backgroundImage: NetworkImage(b.imageUrl)),
                        title: Text(b.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                        subtitle: Text('${b.author} • ${b.stock} dona • ${_won(b.currentPrice)}${b.isActive ? '' : ' • Yashirilgan'}'),
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) => v == 'edit' ? openForm(b) : remove(b),
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Text('Tahrirlash')),
                            PopupMenuItem(value: 'delete', child: Text('O‘chirish')),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE7E9ED))),
        child: Text('$label: $value', style: const TextStyle(fontWeight: FontWeight.w800)),
      );
}

class _BookForm extends StatefulWidget {
  const _BookForm({required this.api, this.book});
  final _AdminApi api;
  final Book? book;

  @override
  State<_BookForm> createState() => _BookFormState();
}

class _BookFormState extends State<_BookForm> {
  final key = GlobalKey<FormState>();
  late final TextEditingController title;
  late final TextEditingController author;
  late final TextEditingController category;
  late final TextEditingController description;
  late final TextEditingController price;
  late final TextEditingController stock;
  late final TextEditingController discount;
  late final TextEditingController image;
  late final TextEditingController cost;
  String cover = 'Ko‘rsatilmagan';
  bool active = true;
  bool recommended = false;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final b = widget.book;
    title = TextEditingController(text: b?.title ?? '');
    author = TextEditingController(text: b?.author == 'Ko‘rsatilmagan' ? '' : b?.author ?? '');
    category = TextEditingController(text: b?.category ?? 'Boshqalar');
    description = TextEditingController(text: b?.description ?? '');
    price = TextEditingController(text: b == null ? '' : '${b.price}');
    stock = TextEditingController(text: b == null ? '' : '${b.stock}');
    discount = TextEditingController(text: b == null ? '0' : '${b.discountPercent}');
    image = TextEditingController(text: b?.imageUrl ?? '');
    cost = TextEditingController(text: b == null || b.costPrice == 0 ? '' : '${b.costPrice}');
    cover = b?.coverType ?? 'Ko‘rsatilmagan';
    active = b?.isActive ?? true;
    recommended = b?.recommended ?? false;
  }

  @override
  void dispose() {
    for (final c in [title, author, category, description, price, stock, discount, image, cost]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget field(TextEditingController c, String label, {bool number = false, bool required = false, int lines = 1}) => Padding(
        padding: const EdgeInsets.only(bottom: 11),
        child: TextFormField(
          controller: c,
          maxLines: lines,
          keyboardType: number ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(labelText: label),
          validator: required ? (v) => v == null || v.trim().isEmpty ? 'Majburiy' : null : null,
        ),
      );

  Future<void> save() async {
    if (!key.currentState!.validate()) return;
    final p = int.tryParse(price.text.trim()) ?? -1;
    final s = int.tryParse(stock.text.trim()) ?? -1;
    final d = int.tryParse(discount.text.trim()) ?? 0;
    final c = int.tryParse(cost.text.trim()) ?? 0;
    if (p < 0 || s < 0 || d < 0 || d > 99 || c < 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Narx, ombor yoki chegirma qiymatini tekshiring.')));
      return;
    }
    setState(() => saving = true);
    try {
      await widget.api.saveBook(Book(
        id: widget.book?.id ?? '',
        legacyId: widget.book?.legacyId,
        title: title.text.trim(),
        author: author.text.trim().isEmpty ? 'Ko‘rsatilmagan' : author.text.trim(),
        category: category.text.trim().isEmpty ? 'Boshqalar' : category.text.trim(),
        description: description.text.trim().isEmpty ? 'Ma’lumot kiritilmagan.' : description.text.trim(),
        price: p,
        stock: s,
        discountPercent: d,
        imageUrl: image.text.trim(),
        isActive: active,
        coverType: cover,
        costPrice: c,
        recommended: recommended,
        createdAt: widget.book?.createdAt,
      ));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saqlashda xatolik: $e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.book == null ? 'Kitob qo‘shish' : 'Kitobni tahrirlash')),
      body: Form(
        key: key,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            field(title, 'Kitob nomi', required: true),
            field(author, 'Muallif'),
            field(category, 'Kategoriya'),
            field(description, 'Tavsif', lines: 4),
            Row(children: [
              Expanded(child: field(price, 'Asl narx (₩)', number: true, required: true)),
              const SizedBox(width: 8),
              Expanded(child: field(stock, 'Ombor', number: true, required: true)),
            ]),
            Row(children: [
              Expanded(child: field(discount, 'Chegirma %', number: true)),
              const SizedBox(width: 8),
              Expanded(child: field(cost, 'Tannarx (₩)', number: true)),
            ]),
            field(image, 'Muqova rasm URL'),
            DropdownButtonFormField<String>(
              initialValue: ['Qattiq', 'Yumshoq', 'Flexible', 'Ko‘rsatilmagan'].contains(cover) ? cover : 'Ko‘rsatilmagan',
              decoration: const InputDecoration(labelText: 'Muqova turi'),
              items: const [
                DropdownMenuItem(value: 'Ko‘rsatilmagan', child: Text('Ko‘rsatilmagan')),
                DropdownMenuItem(value: 'Qattiq', child: Text('Qattiq')),
                DropdownMenuItem(value: 'Yumshoq', child: Text('Yumshoq')),
                DropdownMenuItem(value: 'Flexible', child: Text('Flexible')),
              ],
              onChanged: (v) => cover = v ?? cover,
            ),
            const SizedBox(height: 8),
            SwitchListTile(value: active, onChanged: (v) => setState(() => active = v), title: const Text('Sotuvda ko‘rsatish'), contentPadding: EdgeInsets.zero),
            SwitchListTile(value: recommended, onChanged: (v) => setState(() => recommended = v), title: const Text('Tavsiya etilgan kitob'), contentPadding: EdgeInsets.zero),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: saving ? null : save,
              icon: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined),
              label: const Text('Saqlash'),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrdersAdmin extends StatefulWidget {
  const _OrdersAdmin({required this.api});
  final _AdminApi api;

  @override
  State<_OrdersAdmin> createState() => _OrdersAdminState();
}

class _OrdersAdminState extends State<_OrdersAdmin> {
  late Future<List<ShopOrder>> future;

  @override
  void initState() {
    super.initState();
    future = widget.api.orders();
  }

  void reload() => setState(() => future = widget.api.orders());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ShopOrder>>(
      future: future,
      builder: (context, snap) {
        final orders = snap.data ?? const <ShopOrder>[];
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                const Expanded(child: Text('Buyurtmalar', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900))),
                IconButton(onPressed: reload, icon: const Icon(Icons.refresh_rounded)),
              ]),
            ),
            if (snap.connectionState == ConnectionState.waiting)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (orders.isEmpty)
              const Expanded(child: Center(child: Text('Hozircha buyurtma yo‘q')))
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  itemCount: orders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final o = orders[i];
                    return Card(
                      child: ExpansionTile(
                        leading: const CircleAvatar(child: Icon(Icons.receipt_long_outlined)),
                        title: Text(o.customerName, style: const TextStyle(fontWeight: FontWeight.w900)),
                        subtitle: Text('${_won(o.total)} • ${o.phone}'),
                        trailing: DropdownButton<String>(
                          value: ['new', 'paid', 'shipping', 'done', 'cancelled'].contains(o.status) ? o.status : 'new',
                          items: const [
                            DropdownMenuItem(value: 'new', child: Text('Yangi')),
                            DropdownMenuItem(value: 'paid', child: Text('To‘landi')),
                            DropdownMenuItem(value: 'shipping', child: Text('Jo‘natildi')),
                            DropdownMenuItem(value: 'done', child: Text('Yakunlandi')),
                            DropdownMenuItem(value: 'cancelled', child: Text('Bekor')),
                          ],
                          onChanged: (v) async {
                            if (v == null) return;
                            await widget.api.updateOrderStatus(o.id, v);
                            if (mounted) reload();
                          },
                        ),
                        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        children: [
                          Align(alignment: Alignment.centerLeft, child: Text('📱 ${o.phone}\n📍 ${o.address}\n🚚 ${o.deliveryType} • ${_won(o.deliveryFee)}')),
                          const SizedBox(height: 8),
                          ...o.items.map((item) => Align(
                                alignment: Alignment.centerLeft,
                                child: Text('• ${item['title']} × ${item['quantity']} — ${_won((item['line_total'] as num?)?.toInt() ?? 0)}'),
                              )),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class _DiscountAdmin extends StatefulWidget {
  const _DiscountAdmin({required this.api});
  final _AdminApi api;

  @override
  State<_DiscountAdmin> createState() => _DiscountAdminState();
}

class _DiscountAdminState extends State<_DiscountAdmin> {
  final percent = TextEditingController(text: '20');
  bool loading = false;

  @override
  void dispose() {
    percent.dispose();
    super.dispose();
  }

  Future<void> apply() async {
    final p = int.tryParse(percent.text.trim());
    if (p == null || p < 1 || p > 99) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('1 dan 99 gacha foiz kiriting.')));
      return;
    }
    setState(() => loading = true);
    try {
      await widget.api.applyDiscount(p);
      await context.read<AppState>().refreshBooks();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$p% chegirma qo‘llandi.')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> clear() async {
    setState(() => loading = true);
    try {
      await widget.api.clearDiscounts();
      await context.read<AppState>().refreshBooks();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chegirmalar bekor qilindi.')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Chegirma boshqaruvi', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(controller: percent, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Chegirma foizi', suffixText: '%')),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: FilledButton.icon(onPressed: loading ? null : apply, icon: const Icon(Icons.sell_outlined), label: const Text('Barchasiga berish'))),
                  const SizedBox(width: 8),
                  Expanded(child: OutlinedButton.icon(onPressed: loading ? null : clear, icon: const Icon(Icons.delete_sweep_outlined), label: const Text('Bekor qilish'))),
                ]),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
