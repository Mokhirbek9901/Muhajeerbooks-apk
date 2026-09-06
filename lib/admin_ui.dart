import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'brand.dart';

const _navy = Color(0xFF10213D);
const _orange = Color(0xFFFF8A00);
const _green = Color(0xFF138A4B);
const _cream = Color(0xFFFFFBF1);

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
          constraints: const BoxConstraints(maxWidth: 440),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              const Center(child: MuhajeerLogoBadge(size: 96, radius: 28)),
              const SizedBox(height: 16),
              const Text('Muhajeer Books boshqaruvi', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 7),
              Text(
                state.isOnlineBackend
                    ? 'Admin email va parolingiz bilan kiring.'
                    : 'Sinov rejimi: o‘zgarishlar shu qurilmada saqlanadi. Admin panelni darhol sinab ko‘rishingiz mumkin.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54, height: 1.4),
              ),
              const SizedBox(height: 24),
              if (state.isOnlineBackend) ...[
                TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Admin email', prefixIcon: Icon(Icons.email_outlined))),
                const SizedBox(height: 12),
                TextField(controller: password, obscureText: true, onSubmitted: (_) => _login(), decoration: const InputDecoration(labelText: 'Parol', prefixIcon: Icon(Icons.lock_outline_rounded))),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: loading ? null : _login,
                  icon: loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.login_rounded),
                  label: const Text('Kirish'),
                ),
              ] else
                FilledButton.icon(
                  onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AdminDashboardPage())),
                  icon: const Icon(Icons.dashboard_customize_outlined),
                  label: const Text('Boshqaruv panelini ochish'),
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
    if (email.text.trim().isEmpty || password.text.isEmpty) {
      setState(() => error = 'Email va parolni kiriting.');
      return;
    }
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
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AdminDashboardPage()));
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
    ('Ombor', Icons.inventory_2_outlined),
    ('Buyurtmalar', Icons.shopping_bag_outlined),
    ('Chegirma', Icons.percent_rounded),
    ('Sozlamalar', Icons.settings_outlined),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<AppState>().refreshBooks(includeInactive: true));
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      appBar: AppBar(
        title: Text(sections[selected].$1),
        actions: [
          IconButton(tooltip: 'Yangilash', onPressed: () => context.read<AppState>().refreshBooks(includeInactive: true), icon: const Icon(Icons.refresh_rounded)),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value != 'logout') return;
              final backend = context.read<AppState>().backend;
              if (backend != null) await backend.signOut();
              if (mounted) Navigator.of(context).pop();
            },
            itemBuilder: (_) => const [PopupMenuItem(value: 'logout', child: Text('Admin paneldan chiqish'))],
          ),
        ],
      ),
      drawer: wide ? null : Drawer(child: SafeArea(child: _AdminMenu(selected: selected, onSelect: _select))),
      body: Row(
        children: [
          if (wide)
            SizedBox(
              width: 246,
              child: Material(color: _navy, child: SafeArea(child: _AdminMenu(selected: selected, onSelect: _select))),
            ),
          Expanded(child: _section()),
        ],
      ),
    );
  }

  void _select(int value) => setState(() => selected = value);

  Widget _section() => switch (selected) {
        0 => const AdminOverview(),
        1 => const AdminBooksPage(),
        2 => const AdminStockPage(),
        3 => const AdminOrdersPage(),
        4 => const AdminDiscountPage(),
        _ => const AdminSettingsPage(),
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
              MuhajeerLogoBadge(size: 48, radius: 14, showShadow: false),
              SizedBox(width: 10),
              Expanded(child: Text('Muhajeer Books\nBoshqaruv paneli', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, height: 1.25))),
            ],
          ),
        ),
        ...List.generate(_AdminDashboardPageState.sections.length, (i) {
          final item = _AdminDashboardPageState.sections[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: ListTile(
              selected: selected == i,
              selectedTileColor: const Color(0xFF223E65),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
              leading: Icon(item.$2, color: selected == i ? const Color(0xFFFFC928) : Colors.white70),
              title: Text(item.$1, style: TextStyle(color: Colors.white, fontWeight: selected == i ? FontWeight.w900 : FontWeight.w600)),
              onTap: () {
                onSelect(i);
                if (MediaQuery.sizeOf(context).width < 900 && Navigator.canPop(context)) Navigator.pop(context);
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
    final active = state.books.where((b) => b.isActive).toList();
    final totalStock = active.fold<int>(0, (a, b) => a + b.stock);
    final retailValue = active.fold<int>(0, (a, b) => a + b.currentPrice * b.stock);
    final lowStock = active.where((b) => b.stock <= 2).toList();
    final discounted = active.where((b) => b.isDiscounted).length;

    return FutureBuilder<List<ShopOrder>>(
      future: state.fetchOrders(),
      builder: (context, snapshot) {
        final orders = snapshot.data ?? const <ShopOrder>[];
        final newOrders = orders.where((o) => o.status == 'new').length;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_navy, Color(0xFF1E3A64)]),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                children: [
                  const MuhajeerLogoBadge(size: 68, radius: 20, showShadow: false),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Do‘kon holati', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        Text(state.isOnlineBackend ? 'Onlayn baza ulangan' : 'Mahalliy saqlash faol — ma’lumot yo‘qolmaydi', style: const TextStyle(color: Color(0xFFD7E1EF))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final count = width >= 1000 ? 5 : width >= 650 ? 3 : 2;
                return GridView.count(
                  crossAxisCount: count,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: width < 500 ? 1.35 : 1.65,
                  children: [
                    _StatCard(title: 'Kitoblar', value: '${active.length}', icon: Icons.menu_book_rounded),
                    _StatCard(title: 'Ombor', value: '$totalStock dona', icon: Icons.inventory_2_rounded),
                    _StatCard(title: 'Ombor qiymati', value: _won(retailValue), icon: Icons.payments_outlined),
                    _StatCard(title: 'Yangi buyurtma', value: '$newOrders', icon: Icons.notifications_active_outlined),
                    _StatCard(title: 'Chegirmada', value: '$discounted', icon: Icons.percent_rounded),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            Row(children: [const Text('Kam qolgan kitoblar', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)), const Spacer(), Text('${lowStock.length} ta', style: const TextStyle(color: Colors.black54))]),
            const SizedBox(height: 9),
            if (lowStock.isEmpty)
              const Card(child: ListTile(leading: Icon(Icons.check_circle_outline_rounded, color: _green), title: Text('Kam qolgan kitob yo‘q')))
            else
              ...lowStock.take(8).map((book) => Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Card(
                      child: ListTile(
                        leading: CircleAvatar(backgroundColor: book.stock == 0 ? const Color(0xFFFFE5E5) : const Color(0xFFFFF1D7), child: Icon(book.stock == 0 ? Icons.error_outline_rounded : Icons.warning_amber_rounded, color: book.stock == 0 ? Colors.red : _orange)),
                        title: Text(book.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text(book.stock == 0 ? 'Tugagan' : '${book.stock} dona qoldi'),
                      ),
                    ),
                  )),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.title, required this.value, required this.icon});
  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(radius: 23, backgroundColor: const Color(0xFFFFF1D7), child: Icon(icon, color: _orange)),
              const SizedBox(width: 11),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black54, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                ]),
              ),
            ],
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
  String filter = 'all';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final q = query.trim().toLowerCase();
    final books = state.books.where((b) {
      final search = q.isEmpty || b.title.toLowerCase().contains(q) || b.author.toLowerCase().contains(q) || b.category.toLowerCase().contains(q);
      final status = switch (filter) {
        'active' => b.isActive,
        'hidden' => !b.isActive,
        'out' => b.stock == 0,
        'low' => b.stock <= 2,
        _ => true,
      };
      return search && status;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Wrap(
            runSpacing: 10,
            spacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: MediaQuery.sizeOf(context).width >= 700 ? 360 : 250,
                child: TextField(onChanged: (v) => setState(() => query = v), decoration: const InputDecoration(hintText: 'Kitob qidirish...', prefixIcon: Icon(Icons.search_rounded))),
              ),
              DropdownButton<String>(
                value: filter,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('Barchasi')),
                  DropdownMenuItem(value: 'active', child: Text('Sotuvda')),
                  DropdownMenuItem(value: 'hidden', child: Text('Yashirilgan')),
                  DropdownMenuItem(value: 'low', child: Text('Kam qolgan')),
                  DropdownMenuItem(value: 'out', child: Text('Tugagan')),
                ],
                onChanged: (v) => setState(() => filter = v ?? 'all'),
              ),
              FilledButton.icon(onPressed: () => _openForm(context), icon: const Icon(Icons.add_rounded), label: const Text('Kitob qo‘shish')),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: books.isEmpty
                ? const Center(child: Text('Kitob topilmadi'))
                : LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth >= 900) {
                        return Card(
                          child: SingleChildScrollView(
                            child: SizedBox(
                              width: constraints.maxWidth,
                              child: DataTable(
                                columnSpacing: 18,
                                columns: const [
                                  DataColumn(label: Text('Kitob')),
                                  DataColumn(label: Text('Kategoriya')),
                                  DataColumn(label: Text('Ombor')),
                                  DataColumn(label: Text('Narx')),
                                  DataColumn(label: Text('Holat')),
                                  DataColumn(label: Text('Amallar')),
                                ],
                                rows: books.map((book) => DataRow(cells: [
                                      DataCell(SizedBox(width: 230, child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)), Text(book.author, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black54, fontSize: 11))]))),
                                      DataCell(Text(book.category)),
                                      DataCell(Text('${book.stock}')),
                                      DataCell(Text(_won(book.currentPrice))),
                                      DataCell(_StatusDot(active: book.isActive, stock: book.stock)),
                                      DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                                        IconButton(tooltip: 'Tahrirlash', onPressed: () => _openForm(context, book), icon: const Icon(Icons.edit_outlined)),
                                        IconButton(tooltip: 'O‘chirish', onPressed: () => _delete(context, book), icon: const Icon(Icons.delete_outline_rounded, color: Colors.red)),
                                      ])),
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
                              title: Text(book.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                              subtitle: Text('${book.author}\n${book.stock} dona • ${_won(book.currentPrice)}'),
                              isThreeLine: true,
                              trailing: PopupMenuButton<String>(
                                onSelected: (v) => v == 'edit' ? _openForm(context, book) : _delete(context, book),
                                itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Tahrirlash')), PopupMenuItem(value: 'delete', child: Text('O‘chirish'))],
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
    await Navigator.push(context, MaterialPageRoute(builder: (_) => AdminBookFormPage(book: book)));
  }

  Future<void> _delete(BuildContext context, Book book) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Kitobni o‘chirish'),
        content: Text('“${book.title}” butunlay o‘chirilsinmi? Yashirish uchun tahrirlash oynasidagi “Sotuvda ko‘rsatish”ni o‘chirish xavfsizroq.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Qaytish')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('O‘chirish'))],
      ),
    );
    if (confirmed == true && context.mounted) await context.read<AppState>().deleteBook(book);
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.active, required this.stock});
  final bool active;
  final int stock;

  @override
  Widget build(BuildContext context) {
    final text = !active ? 'Yashirilgan' : stock == 0 ? 'Tugagan' : 'Sotuvda';
    final color = !active ? Colors.grey : stock == 0 ? Colors.red : _green;
    return Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 6), Text(text)]);
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
  late final TextEditingController costPrice;
  late final TextEditingController stock;
  late final TextEditingController discount;
  late final TextEditingController imageUrl;
  String coverType = 'Ko‘rsatilmagan';
  bool active = true;
  bool recommended = false;
  bool saving = false;
  XFile? pickedImage;

  @override
  void initState() {
    super.initState();
    final b = widget.book;
    title = TextEditingController(text: b?.title ?? '');
    author = TextEditingController(text: b?.author ?? '');
    category = TextEditingController(text: b?.category ?? 'Badiiy');
    description = TextEditingController(text: b?.description ?? '');
    price = TextEditingController(text: b == null ? '' : '${b.price}');
    costPrice = TextEditingController(text: b == null ? '0' : '${b.costPrice}');
    stock = TextEditingController(text: b == null ? '' : '${b.stock}');
    discount = TextEditingController(text: b == null ? '0' : '${b.discountPercent}');
    imageUrl = TextEditingController(text: b?.imageUrl ?? '');
    coverType = ['Ko‘rsatilmagan', 'Yumshoq', 'Qattiq'].contains(b?.coverType) ? (b?.coverType ?? 'Ko‘rsatilmagan') : 'Ko‘rsatilmagan';
    active = b?.isActive ?? true;
    recommended = b?.recommended ?? false;
  }

  @override
  void dispose() {
    for (final c in [title, author, category, description, price, costPrice, stock, discount, imageUrl]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final online = context.watch<AppState>().isOnlineBackend;
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
            _field(description, 'Tavsif', maxLines: 5),
            Row(children: [
              Expanded(child: _field(price, 'Sotuv narxi (₩)', number: true, required: true)),
              const SizedBox(width: 10),
              Expanded(child: _field(costPrice, 'Tannarx (₩)', number: true)),
            ]),
            Row(children: [
              Expanded(child: _field(stock, 'Ombor (dona)', number: true, required: true)),
              const SizedBox(width: 10),
              Expanded(child: _field(discount, 'Chegirma (%)', number: true)),
            ]),
            DropdownButtonFormField<String>(
              value: coverType,
              decoration: const InputDecoration(labelText: 'Muqova turi'),
              items: const [DropdownMenuItem(value: 'Ko‘rsatilmagan', child: Text('Ko‘rsatilmagan')), DropdownMenuItem(value: 'Yumshoq', child: Text('Yumshoq')), DropdownMenuItem(value: 'Qattiq', child: Text('Qattiq'))],
              onChanged: (v) => setState(() => coverType = v ?? 'Ko‘rsatilmagan'),
            ),
            const SizedBox(height: 12),
            _field(imageUrl, 'Rasm URL (ixtiyoriy)'),
            OutlinedButton.icon(
              onPressed: online
                  ? () async {
                      final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 88, maxWidth: 1600);
                      if (file != null) setState(() => pickedImage = file);
                    }
                  : null,
              icon: const Icon(Icons.image_outlined),
              label: Text(!online ? 'Rasm yuklash onlayn baza ulangach ishlaydi' : pickedImage == null ? 'Galereyadan muqova tanlash' : pickedImage!.name),
            ),
            SwitchListTile(value: active, onChanged: (v) => setState(() => active = v), title: const Text('Sotuvda ko‘rsatish'), contentPadding: EdgeInsets.zero),
            SwitchListTile(value: recommended, onChanged: (v) => setState(() => recommended = v), title: const Text('Tavsiya etilgan kitob'), contentPadding: EdgeInsets.zero),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: saving ? null : _save,
              icon: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined),
              label: const Text('Saqlash'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController controller, String label, {bool number = false, bool required = false, int maxLines = 1}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: number ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(labelText: label),
          validator: required ? (v) => v == null || v.trim().isEmpty ? 'Majburiy maydon' : null : null,
        ),
      );

  Future<void> _save() async {
    if (!formKey.currentState!.validate()) return;
    final p = int.tryParse(price.text.trim()) ?? -1;
    final cp = int.tryParse(costPrice.text.trim()) ?? 0;
    final s = int.tryParse(stock.text.trim()) ?? -1;
    final d = int.tryParse(discount.text.trim()) ?? 0;
    if (p < 0 || cp < 0 || s < 0 || d < 0 || d > 99) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Narx, tannarx, ombor yoki chegirma qiymatini tekshiring.')));
      return;
    }
    final appState = context.read<AppState>();
    setState(() => saving = true);
    try {
      var cover = imageUrl.text.trim();
      if (pickedImage != null) {
        final uploaded = await appState.uploadCover(pickedImage!);
        if (uploaded.isNotEmpty) cover = uploaded;
      }
      final book = Book(
        id: widget.book?.id ?? '',
        legacyId: widget.book?.legacyId,
        title: title.text.trim(),
        author: author.text.trim().isEmpty ? 'Ko‘rsatilmagan' : author.text.trim(),
        category: category.text.trim().isEmpty ? 'Boshqalar' : category.text.trim(),
        description: description.text.trim(),
        price: p,
        costPrice: cp,
        stock: s,
        discountPercent: d,
        imageUrl: cover,
        isActive: active,
        coverType: coverType,
        recommended: recommended,
        createdAt: widget.book?.createdAt ?? DateTime.now(),
      );
      await appState.saveBook(book);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kitob saqlandi ✅')));
      Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saqlashda xatolik: $e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}

class AdminStockPage extends StatefulWidget {
  const AdminStockPage({super.key});

  @override
  State<AdminStockPage> createState() => _AdminStockPageState();
}

class _AdminStockPageState extends State<AdminStockPage> {
  String query = '';
  bool onlyLow = false;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final q = query.trim().toLowerCase();
    final books = state.books.where((b) => (q.isEmpty || b.title.toLowerCase().contains(q)) && (!onlyLow || b.stock <= 2)).toList()
      ..sort((a, b) => a.stock.compareTo(b.stock));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            Expanded(child: TextField(onChanged: (v) => setState(() => query = v), decoration: const InputDecoration(hintText: 'Ombordan kitob qidirish...', prefixIcon: Icon(Icons.search_rounded)))),
            const SizedBox(width: 10),
            FilterChip(label: const Text('Kam qolgan'), selected: onlyLow, onSelected: (v) => setState(() => onlyLow = v)),
          ]),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            itemCount: books.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final book = books[i];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(book.title, style: const TextStyle(fontWeight: FontWeight.w900)), Text(book.category, style: const TextStyle(color: Colors.black54, fontSize: 12))])),
                    IconButton.outlined(onPressed: book.stock > 0 ? () => _change(context, book, book.stock - 1) : null, icon: const Icon(Icons.remove_rounded)),
                    SizedBox(width: 58, child: Text('${book.stock}', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: book.stock <= 2 ? Colors.red : _navy))),
                    IconButton.outlined(onPressed: () => _change(context, book, book.stock + 1), icon: const Icon(Icons.add_rounded)),
                    const SizedBox(width: 4),
                    IconButton(tooltip: 'Aniq son kiritish', onPressed: () => _setExact(context, book), icon: const Icon(Icons.edit_rounded)),
                  ]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _change(BuildContext context, Book book, int stock) => context.read<AppState>().saveBook(book.copyWith(stock: stock.clamp(0, 999999)));

  Future<void> _setExact(BuildContext context, Book book) async {
    final controller = TextEditingController(text: '${book.stock}');
    final value = await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(book.title),
        content: TextField(controller: controller, autofocus: true, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Ombordagi dona')),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Bekor')), FilledButton(onPressed: () => Navigator.pop(context, int.tryParse(controller.text)), child: const Text('Saqlash'))],
      ),
    );
    controller.dispose();
    if (value != null && value >= 0 && context.mounted) await _change(context, book, value);
  }
}

class AdminDiscountPage extends StatefulWidget {
  const AdminDiscountPage({super.key});

  @override
  State<AdminDiscountPage> createState() => _AdminDiscountPageState();
}

class _AdminDiscountPageState extends State<AdminDiscountPage> {
  final percent = TextEditingController(text: '10');
  bool saving = false;

  @override
  void dispose() {
    percent.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final discounted = state.books.where((b) => b.isDiscounted).length;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Barcha kitoblarga chegirma', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text('Hozir $discounted ta kitob chegirmada.', style: const TextStyle(color: Colors.black54)),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              TextField(controller: percent, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Chegirma foizi (1–99%)', prefixIcon: Icon(Icons.percent_rounded))),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: FilledButton.icon(onPressed: saving ? null : _apply, icon: const Icon(Icons.sell_outlined), label: const Text('Barchasiga qo‘llash'))),
                const SizedBox(width: 10),
                Expanded(child: OutlinedButton.icon(onPressed: saving ? null : _clear, icon: const Icon(Icons.delete_sweep_outlined), label: const Text('Bekor qilish'))),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 18),
        const Text('Chegirmadagi kitoblar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        ...state.books.where((b) => b.isDiscounted).map((b) => Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Card(child: ListTile(leading: CircleAvatar(backgroundColor: const Color(0xFFFFE7E7), child: Text('${b.discountPercent}%', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w900, fontSize: 11))), title: Text(b.title, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('${_won(b.price)} → ${_won(b.currentPrice)}'))),
            )),
      ],
    );
  }

  Future<void> _apply() async {
    final p = int.tryParse(percent.text.trim());
    if (p == null || p < 1 || p > 99) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('1 dan 99 gacha foiz kiriting.')));
      return;
    }
    setState(() => saving = true);
    try {
      await context.read<AppState>().applyDiscountToAll(p);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Barcha sotuvdagi kitoblarga $p% chegirma qo‘llandi ✅')));
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
  String filter = 'all';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    future ??= context.read<AppState>().fetchOrders();
  }

  void _reload() => setState(() => future = context.read<AppState>().fetchOrders());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ShopOrder>>(
      future: future,
      builder: (context, snapshot) {
        var orders = snapshot.data ?? const <ShopOrder>[];
        if (filter != 'all') orders = orders.where((o) => o.status == filter).toList();
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
                const Text('Buyurtmalar', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                DropdownButton<String>(
                  value: filter,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Barchasi')),
                    DropdownMenuItem(value: 'new', child: Text('Yangi')),
                    DropdownMenuItem(value: 'paid', child: Text('To‘landi')),
                    DropdownMenuItem(value: 'shipping', child: Text('Jo‘natildi')),
                    DropdownMenuItem(value: 'done', child: Text('Yakunlandi')),
                    DropdownMenuItem(value: 'cancelled', child: Text('Bekor')),
                  ],
                  onChanged: (v) => setState(() => filter = v ?? 'all'),
                ),
                IconButton(onPressed: _reload, icon: const Icon(Icons.refresh_rounded)),
              ]),
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
                  itemBuilder: (_, i) => _AdminOrderCard(order: orders[i], onChanged: _reload),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AdminOrderCard extends StatelessWidget {
  const _AdminOrderCard({required this.order, required this.onChanged});
  final ShopOrder order;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        leading: const CircleAvatar(backgroundColor: Color(0xFFFFF1D7), child: Icon(Icons.receipt_long_outlined, color: _orange)),
        title: Row(children: [Expanded(child: Text('${order.customerName} • №${order.id}', style: const TextStyle(fontWeight: FontWeight.w900))), Text(_won(order.total), style: const TextStyle(fontWeight: FontWeight.w900))]),
        subtitle: Text('${order.phone} • ${order.deliveryType} • ${DateFormat('MM.dd HH:mm').format(order.createdAt)}'),
        trailing: DropdownButton<String>(
          value: ['new', 'paid', 'shipping', 'done', 'cancelled'].contains(order.status) ? order.status : 'new',
          items: const [
            DropdownMenuItem(value: 'new', child: Text('Yangi')),
            DropdownMenuItem(value: 'paid', child: Text('To‘landi')),
            DropdownMenuItem(value: 'shipping', child: Text('Jo‘natildi')),
            DropdownMenuItem(value: 'done', child: Text('Yakunlandi')),
            DropdownMenuItem(value: 'cancelled', child: Text('Bekor')),
          ],
          onChanged: (value) async {
            if (value == null || value == order.status) return;
            try {
              await context.read<AppState>().updateOrderStatus(order.id, value);
              onChanged();
            } catch (e) {
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Xatolik: $e')));
            }
          },
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Align(alignment: Alignment.centerLeft, child: Text(order.address, style: const TextStyle(height: 1.4))),
          const SizedBox(height: 10),
          ...order.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(children: [Expanded(child: Text('${item['title']} × ${item['quantity']}')), Text(_won((item['line_total'] as num?)?.toInt() ?? 0), style: const TextStyle(fontWeight: FontWeight.w700))]),
              )),
          const Divider(),
          Row(children: [const Text('Yetkazib berish'), const Spacer(), Text(_won(order.deliveryFee))]),
          const SizedBox(height: 4),
          Row(children: [const Text('Jami', style: TextStyle(fontWeight: FontWeight.w900)), const Spacer(), Text(_won(order.total), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17))]),
        ],
      ),
    );
  }
}

class AdminSettingsPage extends StatelessWidget {
  const AdminSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: ListTile(
            leading: CircleAvatar(backgroundColor: state.isOnlineBackend ? const Color(0xFFE4F7EC) : const Color(0xFFFFF1D7), child: Icon(state.isOnlineBackend ? Icons.cloud_done_rounded : Icons.save_rounded, color: state.isOnlineBackend ? _green : _orange)),
            title: const Text('Ma’lumotlar bazasi', style: TextStyle(fontWeight: FontWeight.w900)),
            subtitle: Text(state.isOnlineBackend ? 'Supabase ulangan — ma’lumotlar onlayn saqlanadi.' : 'Mahalliy saqlash faol — qo‘shilgan kitoblar shu qurilmada saqlanadi.'),
          ),
        ),
        const SizedBox(height: 10),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('To‘lov', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
              SizedBox(height: 8),
              Text('${AppState.bankName}\n${AppState.bankAccount}\n${AppState.bankOwner}'),
              SizedBox(height: 12),
              Text('Yetkazib berish', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
              SizedBox(height: 8),
              Text('Koreya bo‘ylab: ₩4,000 • 1–3 ish kuni\n4+ kitob: bepul\nGyeongsan ichida: bepul'),
            ]),
          ),
        ),
        if (!state.isOnlineBackend) ...[
          const SizedBox(height: 18),
          const Text('Mahalliy katalog', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _reset(context),
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('Telegram botdagi 14 ta kitobga qaytarish'),
          ),
          const SizedBox(height: 6),
          const Text('Bu amal shu qurilmadagi kitob tahrirlarini qayta tiklaydi. Buyurtmalar o‘chmaydi.', style: TextStyle(color: Colors.black54, fontSize: 12)),
        ],
      ],
    );
  }

  Future<void> _reset(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(title: const Text('Katalogni qayta tiklash'), content: const Text('Telegram botdan olingan 14 ta kitob bilan mahalliy katalog qayta yozilsinmi?'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Yo‘q')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Tiklash'))]),
    );
    if (ok == true && context.mounted) {
      await context.read<AppState>().resetLocalCatalogFromTelegram();
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Telegram katalogi qayta tiklandi ✅')));
    }
  }
}
