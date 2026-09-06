import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';

final _adminMoney = NumberFormat('#,###', 'en_US');
String _won(int value) => '₩${_adminMoney.format(value)}';

class AdminGatePage extends StatefulWidget {
  const AdminGatePage({super.key});

  @override
  State<AdminGatePage> createState() => _AdminGatePageState();
}

class _AdminGatePageState extends State<AdminGatePage> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool loading = false;
  String? error;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Admin paneli')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              const Icon(Icons.admin_panel_settings_rounded,
                  size: 74, color: Color(0xFF176B45)),
              const SizedBox(height: 14),
              const Text(
                'Muhajeer Books boshqaruvi',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                state.backendConfigured
                    ? 'Admin email va parolingiz bilan kiring.'
                    : 'Hozir demo rejim. Panelni sinab ko‘rishingiz mumkin.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 24),
              if (state.backendConfigured) ...[
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Admin email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Parol',
                    prefixIcon: Icon(Icons.lock_outline),
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
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login),
                  label: const Text('Kirish'),
                ),
              ] else
                FilledButton.icon(
                  onPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminDashboardPage()),
                  ),
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Demo admin panelini ochish'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _login() async {
    final state = context.read<AppState>();
    if (state.backend == null) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final ok = await state.backend!.signInAdmin(email.text, password.text);
      if (!mounted) return;
      if (!ok) {
        await state.backend!.signOut();
        setState(() => error = 'Bu akkaunt admin emas yoki login noto‘g‘ri.');
        return;
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AdminDashboardPage()),
      );
    } catch (e) {
      if (mounted) setState(() => error = 'Kirishda xatolik: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }
}

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  int selected = 0;

  static const sections = [
    ('Bosh sahifa', Icons.dashboard_outlined),
    ('Kitoblar', Icons.menu_book_outlined),
    ('Buyurtmalar', Icons.shopping_cart_outlined),
    ('Chegirma', Icons.percent_outlined),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().refreshBooks(includeInactive: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(sections[selected].$1),
        actions: [
          IconButton(
            tooltip: 'Yangilash',
            onPressed: () => context.read<AppState>().refreshBooks(includeInactive: true),
            icon: const Icon(Icons.refresh),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'logout') {
                final backend = context.read<AppState>().backend;
                if (backend != null) await backend.signOut();
                if (mounted) Navigator.pop(context);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'logout', child: Text('Admin paneldan chiqish')),
            ],
          ),
        ],
      ),
      drawer: MediaQuery.sizeOf(context).width < 900
          ? Drawer(child: SafeArea(child: _AdminMenu(selected: selected, onSelect: _select)))
          : null,
      body: Row(
        children: [
          if (MediaQuery.sizeOf(context).width >= 900)
            SizedBox(
              width: 240,
              child: Material(
                color: const Color(0xFF112A3E),
                child: SafeArea(child: _AdminMenu(selected: selected, onSelect: _select)),
              ),
            ),
          Expanded(child: _section()),
        ],
      ),
    );
  }

  void _select(int value) {
    setState(() => selected = value);
  }

  Widget _section() => switch (selected) {
        0 => const AdminOverview(),
        1 => const AdminBooksPage(),
        2 => const AdminOrdersPage(),
        _ => const AdminDiscountPage(),
      };
}

class _AdminMenu extends StatelessWidget {
  const _AdminMenu({required this.selected, required this.onSelect});
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(8, 8, 8, 20),
          child: Row(
            children: [
              Text('📕', style: TextStyle(fontSize: 28)),
              SizedBox(width: 10),
              Expanded(
                child: Text('Muhajeer Books\nBoshqaruv paneli',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
        ...List.generate(_AdminDashboardPageState.sections.length, (i) {
          final item = _AdminDashboardPageState.sections[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: ListTile(
              selected: selected == i,
              selectedTileColor: const Color(0xFF214761),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              leading: Icon(item.$2, color: Colors.white),
              title: Text(item.$1, style: const TextStyle(color: Colors.white)),
              onTap: () {
                onSelect(i);
                if (MediaQuery.sizeOf(context).width < 900 && Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              },
            ),
          );
        }),
      ],
    );
  }
}

class AdminOverview extends StatelessWidget {
  const AdminOverview({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final stock = state.books.fold<int>(0, (sum, b) => sum + b.stock);
    final lowStock = state.books.where((b) => b.stock <= 2).length;
    final discounted = state.books.where((b) => b.discountPercent > 0).length;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Do‘kon holati', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _StatCard(title: 'Kitoblar', value: '${state.books.length}', icon: Icons.menu_book),
            _StatCard(title: 'Ombor', value: '$stock dona', icon: Icons.inventory_2_outlined),
            _StatCard(title: 'Kam qolgan', value: '$lowStock', icon: Icons.warning_amber_rounded),
            _StatCard(title: 'Chegirmada', value: '$discounted', icon: Icons.percent),
          ],
        ),
        const SizedBox(height: 22),
        const Text('Tezkor nazorat', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        Card(
          child: Column(
            children: state.books
                .where((b) => b.stock <= 2)
                .map((b) => ListTile(
                      leading: const Icon(Icons.inventory_2_outlined),
                      title: Text(b.title),
                      subtitle: Text('Omborda ${b.stock} dona qoldi'),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.title, required this.value, required this.icon});
  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 210,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                CircleAvatar(radius: 24, child: Icon(icon)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(color: Colors.black54)),
                      Text(value, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class AdminBooksPage extends StatefulWidget {
  const AdminBooksPage({super.key});

  @override
  State<AdminBooksPage> createState() => _AdminBooksPageState();
}

class _AdminBooksPageState extends State<AdminBooksPage> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final q = query.trim().toLowerCase();
    final books = state.books
        .where((b) => q.isEmpty || b.title.toLowerCase().contains(q) || b.author.toLowerCase().contains(q))
        .toList();
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => query = v),
                  decoration: const InputDecoration(
                    hintText: 'Kitob nomi yoki muallif bo‘yicha qidirish...',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () => _openForm(context),
                icon: const Icon(Icons.add),
                label: const Text('Kitob qo‘shish'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 850) {
                  return Card(
                    child: SingleChildScrollView(
                      child: SizedBox(
                        width: constraints.maxWidth,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Kitob')),
                            DataColumn(label: Text('Muallif')),
                            DataColumn(label: Text('Ombor')),
                            DataColumn(label: Text('Narx')),
                            DataColumn(label: Text('Chegirma')),
                            DataColumn(label: Text('Amallar')),
                          ],
                          rows: books.map((book) => DataRow(cells: [
                                DataCell(Text(book.title, style: const TextStyle(fontWeight: FontWeight.w700))),
                                DataCell(Text(book.author)),
                                DataCell(Text('${book.stock}')),
                                DataCell(Text(_won(book.currentPrice))),
                                DataCell(Text('${book.discountPercent}%')),
                                DataCell(Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Tahrirlash',
                                      onPressed: () => _openForm(context, book),
                                      icon: const Icon(Icons.edit_outlined),
                                    ),
                                    IconButton(
                                      tooltip: 'O‘chirish',
                                      onPressed: () => _delete(context, book),
                                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    ),
                                  ],
                                )),
                              ])).toList(),
                        ),
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: books.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final book = books[i];
                    return Card(
                      child: ListTile(
                        title: Text(book.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text('${book.author} • ${book.stock} dona • ${_won(book.currentPrice)}'),
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) => v == 'edit' ? _openForm(context, book) : _delete(context, book),
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Text('Tahrirlash')),
                            PopupMenuItem(value: 'delete', child: Text('O‘chirish')),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openForm(BuildContext context, [Book? book]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AdminBookFormPage(book: book)),
    );
  }

  Future<void> _delete(BuildContext context, Book book) async {
    final confirmed = await showDialog<bool>(
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
    if (confirmed == true && context.mounted) {
      await context.read<AppState>().deleteBook(book);
    }
  }
}

class AdminBookFormPage extends StatefulWidget {
  const AdminBookFormPage({super.key, this.book});
  final Book? book;

  @override
  State<AdminBookFormPage> createState() => _AdminBookFormPageState();
}

class _AdminBookFormPageState extends State<AdminBookFormPage> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController title;
  late final TextEditingController author;
  late final TextEditingController category;
  late final TextEditingController description;
  late final TextEditingController price;
  late final TextEditingController stock;
  late final TextEditingController discount;
  late final TextEditingController imageUrl;
  bool active = true;
  bool saving = false;
  XFile? pickedImage;

  @override
  void initState() {
    super.initState();
    final b = widget.book;
    title = TextEditingController(text: b?.title ?? '');
    author = TextEditingController(text: b?.author ?? '');
    category = TextEditingController(text: b?.category ?? 'Badiiy adabiyot');
    description = TextEditingController(text: b?.description ?? '');
    price = TextEditingController(text: b == null ? '' : '${b.price}');
    stock = TextEditingController(text: b == null ? '' : '${b.stock}');
    discount = TextEditingController(text: b == null ? '0' : '${b.discountPercent}');
    imageUrl = TextEditingController(text: b?.imageUrl ?? '');
    active = b?.isActive ?? true;
  }

  @override
  void dispose() {
    for (final c in [title, author, category, description, price, stock, discount, imageUrl]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.book == null ? 'Yangi kitob' : 'Kitobni tahrirlash')),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            _field(title, 'Kitob nomi', required: true),
            _field(author, 'Muallif'),
            _field(category, 'Kategoriya'),
            _field(description, 'Tavsif', maxLines: 4),
            Row(
              children: [
                Expanded(child: _field(price, 'Narx (₩)', number: true, required: true)),
                const SizedBox(width: 10),
                Expanded(child: _field(stock, 'Ombor (dona)', number: true, required: true)),
              ],
            ),
            _field(discount, 'Chegirma (%)', number: true),
            _field(imageUrl, 'Rasm URL (ixtiyoriy)'),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 88);
                if (file != null) setState(() => pickedImage = file);
              },
              icon: const Icon(Icons.image_outlined),
              label: Text(pickedImage == null ? 'Galereyadan muqova tanlash' : pickedImage!.name),
            ),
            SwitchListTile(
              value: active,
              onChanged: (v) => setState(() => active = v),
              title: const Text('Sotuvda ko‘rsatish'),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: saving ? null : _save,
              icon: saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_outlined),
              label: const Text('Saqlash'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool number = false,
    bool required = false,
    int maxLines = 1,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: number ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(labelText: label),
          validator: required
              ? (v) => v == null || v.trim().isEmpty ? 'Majburiy maydon' : null
              : null,
        ),
      );

  Future<void> _save() async {
    if (!formKey.currentState!.validate()) return;
    final p = int.tryParse(price.text.trim()) ?? -1;
    final s = int.tryParse(stock.text.trim()) ?? -1;
    final d = int.tryParse(discount.text.trim()) ?? 0;
    if (p < 0 || s < 0 || d < 0 || d > 99) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Narx, ombor yoki chegirma qiymatini tekshiring.')),
      );
      return;
    }
    setState(() => saving = true);
    try {
      var cover = imageUrl.text.trim();
      if (pickedImage != null) {
        final uploaded = await context.read<AppState>().uploadCover(pickedImage!);
        if (uploaded.isNotEmpty) cover = uploaded;
      }
      final book = Book(
        id: widget.book?.id ?? '',
        title: title.text.trim(),
        author: author.text.trim(),
        category: category.text.trim().isEmpty ? 'Boshqa' : category.text.trim(),
        description: description.text.trim(),
        price: p,
        stock: s,
        discountPercent: d,
        imageUrl: cover,
        isActive: active,
      );
      await context.read<AppState>().saveBook(book);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saqlashda xatolik: $e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}

class AdminDiscountPage extends StatefulWidget {
  const AdminDiscountPage({super.key});

  @override
  State<AdminDiscountPage> createState() => _AdminDiscountPageState();
}

class _AdminDiscountPageState extends State<AdminDiscountPage> {
  final percent = TextEditingController(text: '20');
  bool saving = false;

  @override
  void dispose() {
    percent.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final discounted = context.watch<AppState>().books.where((b) => b.discountPercent > 0).length;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Chegirma boshqaruvi', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: percent,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Chegirma foizi (1–99%)', suffixText: '%'),
                  ),
                ),
                FilledButton.icon(
                  onPressed: saving ? null : _apply,
                  icon: const Icon(Icons.sell_outlined),
                  label: const Text('Barcha kitoblarga berish'),
                ),
                OutlinedButton.icon(
                  onPressed: saving ? null : _clear,
                  icon: const Icon(Icons.delete_sweep_outlined),
                  label: const Text('Chegirmani bekor qilish'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.percent)),
            title: Text('$discounted ta kitobda chegirma bor', style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: const Text('Alohida kitob chegirmasini “Kitoblar → Tahrirlash” orqali o‘zgartirish mumkin.'),
          ),
        ),
      ],
    );
  }

  Future<void> _apply() async {
    final value = int.tryParse(percent.text.trim());
    if (value == null || value < 1 || value > 99) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('1 dan 99 gacha foiz kiriting.')));
      return;
    }
    setState(() => saving = true);
    try {
      await context.read<AppState>().applyDiscountToAll(value);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$value% chegirma qo‘llandi.')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _clear() async {
    setState(() => saving = true);
    try {
      await context.read<AppState>().clearAllDiscounts();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Barcha chegirmalar bekor qilindi.')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}

class AdminOrdersPage extends StatefulWidget {
  const AdminOrdersPage({super.key});

  @override
  State<AdminOrdersPage> createState() => _AdminOrdersPageState();
}

class _AdminOrdersPageState extends State<AdminOrdersPage> {
  Future<List<ShopOrder>>? future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    future ??= _load();
  }

  Future<List<ShopOrder>> _load() async {
    final backend = context.read<AppState>().backend;
    if (backend == null) return [];
    return backend.fetchOrders();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ShopOrder>>(
      future: future,
      builder: (context, snapshot) {
        final orders = snapshot.data ?? const <ShopOrder>[];
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Expanded(child: Text('Buyurtmalar', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900))),
                  IconButton(
                    onPressed: () => setState(() => future = _load()),
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (orders.isEmpty)
              const Expanded(child: Center(child: Text('Hozircha buyurtma yo‘q')))
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  itemCount: orders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final order = orders[i];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const CircleAvatar(child: Icon(Icons.receipt_long_outlined)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(order.customerName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                                  Text('${order.phone} • ${order.deliveryType}'),
                                  Text(order.address, maxLines: 2, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 6),
                                  Text(_won(order.total), style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0A7A3B))),
                                ],
                              ),
                            ),
                            DropdownButton<String>(
                              value: ['new', 'paid', 'shipping', 'done', 'cancelled'].contains(order.status)
                                  ? order.status
                                  : 'new',
                              items: const [
                                DropdownMenuItem(value: 'new', child: Text('Yangi')),
                                DropdownMenuItem(value: 'paid', child: Text('To‘landi')),
                                DropdownMenuItem(value: 'shipping', child: Text('Jo‘natildi')),
                                DropdownMenuItem(value: 'done', child: Text('Yakunlandi')),
                                DropdownMenuItem(value: 'cancelled', child: Text('Bekor')),
                              ],
                              onChanged: (value) async {
                                if (value == null) return;
                                final backend = context.read<AppState>().backend;
                                if (backend == null) return;
                                await backend.updateOrderStatus(order.id, value);
                                if (mounted) setState(() => future = _load());
                              },
                            ),
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
