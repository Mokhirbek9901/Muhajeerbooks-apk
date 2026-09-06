from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"Pattern not found: {label}")
    return text.replace(old, new, 1)


def replace_between(text: str, start: str, end: str, new: str, label: str) -> str:
    i = text.find(start)
    if i < 0:
        raise SystemExit(f"Start marker not found: {label}")
    j = text.find(end, i)
    if j < 0:
        raise SystemExit(f"End marker not found: {label}")
    return text[:i] + new.rstrip() + "\n\n" + text[j:]


# =========================
# APP STATE / ORDER MODEL
# =========================
p = Path("lib/app_state.dart")
text = p.read_text(encoding="utf-8")

shop_order = r'''class ShopOrder {
  const ShopOrder({
    required this.id,
    required this.customerName,
    required this.phone,
    required this.address,
    required this.deliveryType,
    required this.deliveryFee,
    required this.subtotal,
    required this.total,
    required this.status,
    required this.items,
    required this.createdAt,
    this.paymentProofPath = '',
    this.paymentSubmittedAt,
    this.stockReserved = false,
  });

  final String id;
  final String customerName;
  final String phone;
  final String address;
  final String deliveryType;
  final int deliveryFee;
  final int subtotal;
  final int total;
  final String status;
  final List<Map<String, dynamic>> items;
  final DateTime createdAt;
  final String paymentProofPath;
  final DateTime? paymentSubmittedAt;
  final bool stockReserved;

  bool get hasPaymentProof => paymentProofPath.trim().isNotEmpty;

  factory ShopOrder.fromMap(Map<String, dynamic> map) => ShopOrder(
        id: (map['id'] ?? '').toString(),
        customerName: (map['customer_name'] ?? '').toString(),
        phone: (map['phone'] ?? '').toString(),
        address: (map['address'] ?? '').toString(),
        deliveryType: (map['delivery_type'] ?? '').toString(),
        deliveryFee: (map['delivery_fee'] as num?)?.toInt() ?? 0,
        subtotal: (map['subtotal'] as num?)?.toInt() ?? 0,
        total: (map['total'] as num?)?.toInt() ?? 0,
        status: (map['status'] ?? 'new').toString(),
        items: ((map['items'] as List?) ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
        createdAt: DateTime.tryParse((map['created_at'] ?? '').toString()) ?? DateTime.now(),
        paymentProofPath: (map['payment_proof_path'] ?? '').toString(),
        paymentSubmittedAt: DateTime.tryParse((map['payment_submitted_at'] ?? '').toString()),
        stockReserved: map['stock_reserved'] as bool? ?? false,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'customer_name': customerName,
        'phone': phone,
        'address': address,
        'delivery_type': deliveryType,
        'delivery_fee': deliveryFee,
        'subtotal': subtotal,
        'total': total,
        'status': status,
        'items': items,
        'created_at': createdAt.toIso8601String(),
        'payment_proof_path': paymentProofPath,
        'payment_submitted_at': paymentSubmittedAt?.toIso8601String(),
        'stock_reserved': stockReserved,
      };

  ShopOrder copyWith({
    String? status,
    String? paymentProofPath,
    DateTime? paymentSubmittedAt,
    bool? stockReserved,
  }) =>
      ShopOrder(
        id: id,
        customerName: customerName,
        phone: phone,
        address: address,
        deliveryType: deliveryType,
        deliveryFee: deliveryFee,
        subtotal: subtotal,
        total: total,
        status: status ?? this.status,
        items: items,
        createdAt: createdAt,
        paymentProofPath: paymentProofPath ?? this.paymentProofPath,
        paymentSubmittedAt: paymentSubmittedAt ?? this.paymentSubmittedAt,
        stockReserved: stockReserved ?? this.stockReserved,
      );
}'''
text = replace_between(text, "class ShopOrder {", "class BackendService {", shop_order, "ShopOrder")

backend_order = r'''  Future<String> uploadPaymentProof(XFile file) async {
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) throw StateError('Chek rasmi bo‘sh.');
    if (bytes.length > 7 * 1024 * 1024) {
      throw StateError('Chek rasmi 7 MB dan kichik bo‘lishi kerak.');
    }

    final lower = file.name.toLowerCase();
    final contentType = lower.endsWith('.png')
        ? 'image/png'
        : lower.endsWith('.webp')
            ? 'image/webp'
            : 'image/jpeg';

    final response = await client.functions.invoke(
      'payment-proof',
      body: {
        'action': 'upload',
        'file_name': file.name,
        'content_type': contentType,
        'data_base64': base64Encode(bytes),
      },
    );
    final raw = response.data;
    final data = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    final path = (data['path'] ?? '').toString();
    if (path.isEmpty) {
      throw StateError((data['error'] ?? 'To‘lov cheki yuklanmadi.').toString());
    }
    return path;
  }

  Future<String> createOrder({
    required String customerName,
    required String phone,
    required String address,
    required String deliveryType,
    required int deliveryFee,
    required int subtotal,
    required int total,
    required List<CartLine> lines,
    String paymentProofPath = '',
  }) async {
    final payload = {
      'customer_name': customerName.trim(),
      'phone': phone.trim(),
      'address': address.trim(),
      'delivery_type': deliveryType,
      'delivery_fee': deliveryFee,
      'subtotal': subtotal,
      'total': total,
      'status': 'new',
      'items': lines.map(_lineToMap).toList(),
      'payment_proof_path': paymentProofPath,
      'payment_submitted_at': paymentProofPath.isEmpty ? null : DateTime.now().toIso8601String(),
    };
    final data = await client.from('orders').insert(payload).select('id').single();
    return data['id'].toString();
  }

  Future<Map<String, Map<String, dynamic>>> fetchOrderStatuses(List<String> ids) async {
    if (ids.isEmpty) return {};
    final data = await client.rpc('customer_order_statuses', params: {'p_ids': ids.take(50).toList()});
    final result = <String, Map<String, dynamic>>{};
    for (final row in (data as List)) {
      final map = Map<String, dynamic>.from(row as Map);
      result[(map['id'] ?? '').toString()] = map;
    }
    return result;
  }'''
text = replace_between(
    text,
    "  Future<String> createOrder({",
    "  Future<List<ShopOrder>> fetchOrders() async {",
    backend_order,
    "Backend order methods",
)

text = replace_once(
    text,
    "    savedCustomer = await _local.loadCustomer();\n\n    if (backendConfigured) {",
    "    savedCustomer = await _local.loadCustomer();\n    _localOrders\n      ..clear()\n      ..addAll(await _local.loadOrders());\n\n    if (backendConfigured) {",
    "load local receipts in online mode",
)
text = replace_once(
    text,
    "    if (_backend == null) {\n      _localOrders\n        ..clear()\n        ..addAll(await _local.loadOrders());\n      await _initializeLocalCatalog();",
    "    if (_backend == null) {\n      await _initializeLocalCatalog();",
    "avoid duplicate local order load",
)

place_order = r'''  Future<String> placeOrder({
    required String customerName,
    required String phone,
    required String address,
    required String deliveryType,
    required int deliveryFee,
    XFile? paymentProof,
  }) async {
    final lines = cartLines;
    if (lines.isEmpty) throw StateError('Savatcha bo‘sh.');
    for (final line in lines) {
      if (line.quantity > line.book.stock) {
        throw StateError('${line.book.title} omborda yetarli emas.');
      }
    }

    final subtotal = cartSubtotal;
    final total = subtotal + deliveryFee;
    await _local.saveCustomer(customerName.trim(), phone.trim(), address.trim());
    savedCustomer = {'name': customerName.trim(), 'phone': phone.trim(), 'address': address.trim()};

    var paymentProofPath = '';
    if (paymentProof != null) {
      paymentProofPath = _backend != null
          ? await _backend!.uploadPaymentProof(paymentProof)
          : 'local:${paymentProof.name}';
    }

    final now = DateTime.now();
    final items = lines.map(BackendService._lineToMap).toList();

    if (_backend != null) {
      final id = await _backend!.createOrder(
        customerName: customerName,
        phone: phone,
        address: address,
        deliveryType: deliveryType,
        deliveryFee: deliveryFee,
        subtotal: subtotal,
        total: total,
        lines: lines,
        paymentProofPath: paymentProofPath,
      );

      final receipt = ShopOrder(
        id: id,
        customerName: customerName.trim(),
        phone: phone.trim(),
        address: address.trim(),
        deliveryType: deliveryType,
        deliveryFee: deliveryFee,
        subtotal: subtotal,
        total: total,
        status: 'new',
        items: items,
        createdAt: now,
        paymentProofPath: paymentProofPath,
        paymentSubmittedAt: paymentProofPath.isEmpty ? null : now,
        stockReserved: false,
      );
      _localOrders.removeWhere((o) => o.id == id);
      _localOrders.insert(0, receipt);
      _cart.clear();
      await Future.wait([
        _local.saveOrders(_localOrders),
        _local.saveCart(_cart),
      ]);
      await refreshBooks();
      return id;
    }

    final id = 'MB-${now.millisecondsSinceEpoch.toString().substring(5)}';
    final order = ShopOrder(
      id: id,
      customerName: customerName.trim(),
      phone: phone.trim(),
      address: address.trim(),
      deliveryType: deliveryType,
      deliveryFee: deliveryFee,
      subtotal: subtotal,
      total: total,
      status: 'new',
      items: items,
      createdAt: now,
      paymentProofPath: paymentProofPath,
      paymentSubmittedAt: paymentProofPath.isEmpty ? null : now,
      stockReserved: false,
    );

    _localOrders.insert(0, order);
    _cart.clear();
    await Future.wait([
      _local.saveOrders(_localOrders),
      _local.saveCart(_cart),
    ]);
    notifyListeners();
    return id;
  }'''
text = replace_between(text, "  Future<String> placeOrder({", "  Future<List<ShopOrder>> fetchOrders() async {", place_order, "placeOrder")

local_status = r'''  Future<void> updateOrderStatus(String id, String status) async {
    if (_backend != null) {
      await _backend!.updateOrderStatus(id, status);
      await refreshBooks(includeInactive: true);
      return;
    }
    final index = _localOrders.indexWhere((o) => o.id == id);
    if (index < 0) return;
    final old = _localOrders[index];
    if (old.status == 'cancelled' && status != 'cancelled') {
      throw StateError('Bekor qilingan buyurtmani qayta ochib bo‘lmaydi.');
    }

    final shouldReserve = ['accepted', 'paid', 'shipping', 'done'].contains(status);
    var reserved = old.stockReserved;

    if (shouldReserve && !reserved) {
      if (!_canReserveLocalStock(old.items)) {
        throw StateError('Buyurtmani qabul qilish uchun ombor yetarli emas.');
      }
      _reserveLocalStock(old.items);
      reserved = true;
    } else if (status == 'cancelled' && reserved) {
      _restoreLocalStock(old.items);
      reserved = false;
    }

    _localOrders[index] = old.copyWith(status: status, stockReserved: reserved);
    await Future.wait([
      _local.saveOrders(_localOrders),
      _local.saveBooks(_books),
    ]);
    notifyListeners();
  }'''
text = replace_between(text, "  Future<void> updateOrderStatus(String id, String status) async {", "  Future<void> resetLocalCatalogFromTelegram() async {", local_status, "local status flow")

customer_orders = r'''  Future<List<ShopOrder>> customerOrdersByPhone(String phone) async {
    final clean = phone.replaceAll(RegExp(r'\D'), '');
    if (clean.length < 7) return [];

    _localOrders
      ..clear()
      ..addAll(await _local.loadOrders());

    if (_backend != null && _localOrders.isNotEmpty) {
      try {
        final uuidIds = _localOrders
            .map((o) => o.id)
            .where((id) => RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(id))
            .toList();
        final statuses = await _backend!.fetchOrderStatuses(uuidIds);
        for (var i = 0; i < _localOrders.length; i++) {
          final row = statuses[_localOrders[i].id];
          if (row == null) continue;
          _localOrders[i] = _localOrders[i].copyWith(
            status: (row['status'] ?? _localOrders[i].status).toString(),
            stockReserved: row['stock_reserved'] as bool? ?? _localOrders[i].stockReserved,
          );
        }
        await _local.saveOrders(_localOrders);
      } catch (_) {
        // Buyurtma tarixi qurilmada saqlangan nusxa bilan ishlashda davom etadi.
      }
    }

    return _localOrders
        .where((o) => o.phone.replaceAll(RegExp(r'\D'), '') == clean)
        .toList();
  }'''
text = replace_between(text, "  Future<List<ShopOrder>> customerOrdersByPhone(String phone) async {", "  void _sanitizeCart() {", customer_orders, "customer order history")

p.write_text(text, encoding="utf-8")


# =========================
# STOREFRONT / CHECKOUT
# =========================
p = Path("lib/store_ui.dart")
text = p.read_text(encoding="utf-8")
text = replace_once(
    text,
    "import 'package:intl/intl.dart';\nimport 'package:provider/provider.dart';",
    "import 'package:image_picker/image_picker.dart';\nimport 'package:intl/intl.dart';\nimport 'package:provider/provider.dart';",
    "store image picker import",
)
text = replace_once(
    text,
    "    final categories = <String>{'Barchasi', ...state.books.where((b) => b.isActive).map((b) => b.category)}.toList();",
    "    final categories = <String>{'Barchasi', ...state.books.where((b) => b.isActive).map((b) => b.category)}.toList();\n    final featured = state.books.where((b) => b.isActive && b.recommended && b.inStock).take(6).toList();",
    "featured books list",
)
text = replace_once(
    text,
    "            const SliverPadding(\n              padding: EdgeInsets.fromLTRB(16, 8, 16, 6),\n              sliver: SliverToBoxAdapter(child: _DeliveryPromoCard()),\n            ),\n            SliverPadding(\n              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),",
    "            const SliverPadding(\n              padding: EdgeInsets.fromLTRB(16, 8, 16, 6),\n              sliver: SliverToBoxAdapter(child: _DeliveryPromoCard()),\n            ),\n            const SliverPadding(\n              padding: EdgeInsets.fromLTRB(16, 6, 16, 4),\n              sliver: SliverToBoxAdapter(child: _TrustStrip()),\n            ),\n            if (featured.isNotEmpty)\n              SliverPadding(\n                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),\n                sliver: SliverToBoxAdapter(child: _FeaturedBooksStrip(books: featured)),\n              ),\n            SliverPadding(\n              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),",
    "home professional sections",
)

home_widgets = r'''class _TrustStrip extends StatelessWidget {
  const _TrustStrip();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE7E9ED)),
        ),
        child: const Row(
          children: [
            Expanded(child: _TrustItem(icon: Icons.verified_outlined, text: 'Ishonchli buyurtma')),
            _TrustDivider(),
            Expanded(child: _TrustItem(icon: Icons.schedule_rounded, text: '1–3 ish kuni')),
            _TrustDivider(),
            Expanded(child: _TrustItem(icon: Icons.support_agent_rounded, text: 'Yordam mavjud')),
          ],
        ),
      );
}

class _TrustDivider extends StatelessWidget {
  const _TrustDivider();
  @override
  Widget build(BuildContext context) => Container(width: 1, height: 30, color: const Color(0xFFE7E9ED));
}

class _TrustItem extends StatelessWidget {
  const _TrustItem({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: _navy),
            const SizedBox(height: 4),
            Text(text, textAlign: TextAlign.center, maxLines: 2, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

class _FeaturedBooksStrip extends StatelessWidget {
  const _FeaturedBooksStrip({required this.books});
  final List<Book> books;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: _orange, size: 20),
              SizedBox(width: 7),
              Text('Tavsiya etamiz', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 9),
          SizedBox(
            height: 176,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: books.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final b = books[i];
                return SizedBox(
                  width: 265,
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BookDetailPage(bookId: b.id))),
                      child: Row(
                        children: [
                          SizedBox(width: 108, height: double.infinity, child: _BookCover(book: b)),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(b.title, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, height: 1.15)),
                                  const SizedBox(height: 5),
                                  Text(b.author, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black54, fontSize: 11)),
                                  const Spacer(),
                                  Text(won(b.currentPrice), style: const TextStyle(color: _navy, fontWeight: FontWeight.w900, fontSize: 16)),
                                  const SizedBox(height: 3),
                                  Text('${b.stock} dona mavjud', style: const TextStyle(color: _green, fontSize: 10.5, fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );
}

'''
text = replace_once(text, "class BookCard extends StatelessWidget {", home_widgets + "class BookCard extends StatelessWidget {", "home helper widgets")

checkout = r'''class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final formKey = GlobalKey<FormState>();
  final picker = ImagePicker();
  late final TextEditingController name;
  late final TextEditingController phone;
  late final TextEditingController address;
  String delivery = '택배';
  bool saving = false;
  bool paymentDone = false;
  XFile? paymentProof;

  @override
  void initState() {
    super.initState();
    final saved = context.read<AppState>().savedCustomer;
    name = TextEditingController(text: saved['name'] ?? '');
    phone = TextEditingController(text: saved['phone'] ?? '');
    address = TextEditingController(text: saved['address'] ?? '');
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    address.dispose();
    super.dispose();
  }

  Future<void> _pickPaymentProof() async {
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 88, maxWidth: 1800);
    if (file == null || !mounted) return;
    setState(() => paymentProof = file);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final deliveryFee = delivery == 'Gyeongsan' || state.cartCount >= 4 ? 0 : AppState.deliveryFee;
    final total = state.cartSubtotal + deliveryFee;

    return Scaffold(
      appBar: AppBar(title: const Text('Buyurtmani rasmiylashtirish')),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            const _CheckoutStepHeader(number: '1', title: 'Qabul qiluvchi'),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    TextFormField(
                      controller: name,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Ism va familiya', prefixIcon: Icon(Icons.person_outline_rounded)),
                      validator: (v) => v == null || v.trim().length < 2 ? 'Ismingizni kiriting' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: phone,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Telefon raqam', hintText: '010-1234-5678', prefixIcon: Icon(Icons.phone_outlined)),
                      validator: (v) => v == null || v.replaceAll(RegExp(r'\D'), '').length < 7 ? 'Telefon raqamni to‘liq kiriting' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: address,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Manzil',
                        alignLabelWithHint: true,
                        helperMaxLines: 3,
                        helperText: 'Manzil va xona raqamini to‘liq yozing.\nMasalan: 경상북도 경산시 계양로 37길 7-3, 808호',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                      validator: (v) => v == null || v.trim().length < 8 ? 'To‘liq manzilni kiriting' : null,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            const _CheckoutStepHeader(number: '2', title: 'Yetkazib berish'),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  RadioListTile<String>(
                    value: '택배',
                    groupValue: delivery,
                    onChanged: (v) => setState(() => delivery = v!),
                    title: const Text('Koreya bo‘ylab 택배', style: TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(state.cartCount >= 4 ? '4+ kitob — BEPUL • 1–3 ish kuni' : '₩4,000 • 1–3 ish kuni'),
                  ),
                  const Divider(height: 1),
                  RadioListTile<String>(
                    value: 'Gyeongsan',
                    groupValue: delivery,
                    onChanged: (v) => setState(() => delivery = v!),
                    title: const Text('Gyeongsan ichida', style: TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: const Text('Bepul yetkazib berish'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const _CheckoutStepHeader(number: '3', title: 'To‘lov va chek'),
            const SizedBox(height: 8),
            _PaymentCard(onCopy: _copyAccount),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: paymentDone,
                      onChanged: (v) => setState(() {
                        paymentDone = v;
                        if (!v) paymentProof = null;
                      }),
                      title: const Text('To‘lovni amalga oshirdim', style: TextStyle(fontWeight: FontWeight.w900)),
                      subtitle: const Text('To‘lov qilgan bo‘lsangiz, chek skrinshotini yuboring.'),
                    ),
                    if (paymentDone) ...[
                      const Divider(height: 20),
                      if (paymentProof == null)
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _pickPaymentProof,
                            icon: const Icon(Icons.add_photo_alternate_outlined),
                            label: const Text('Chek skrinshotini tanlash'),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF7EF),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFBDE2C9)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, color: _green),
                              const SizedBox(width: 10),
                              Expanded(child: Text(paymentProof!.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800))),
                              IconButton(onPressed: _pickPaymentProof, tooltip: 'Almashtirish', icon: const Icon(Icons.edit_outlined)),
                              IconButton(onPressed: () => setState(() => paymentProof = null), tooltip: 'Olib tashlash', icon: const Icon(Icons.close_rounded)),
                            ],
                          ),
                        ),
                      const SizedBox(height: 8),
                      const Text('Chek maxfiy saqlanadi va faqat admin ko‘ra oladi.', style: TextStyle(fontSize: 11.5, color: Colors.black54)),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            const _CheckoutStepHeader(number: '4', title: 'Buyurtma jami'),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _priceRow('Kitoblar', state.cartSubtotal),
                    const SizedBox(height: 8),
                    _priceRow('Yetkazib berish', deliveryFee),
                    const Divider(height: 24),
                    _priceRow('Jami', total, bold: true),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFFFF7E8), borderRadius: BorderRadius.circular(14)),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, size: 20, color: _orange),
                  SizedBox(width: 8),
                  Expanded(child: Text('Buyurtma yuborilganda ombor darhol kamaymaydi. Admin buyurtmani QABUL QILGANDA kitoblar ombordan avtomatik ayriladi.', style: TextStyle(fontSize: 12, height: 1.4, fontWeight: FontWeight.w600))),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: saving || state.cartLines.isEmpty ? null : () => _submit(state, deliveryFee),
                icon: saving
                    ? const SizedBox(width: 19, height: 19, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send_rounded),
                label: Text(saving ? 'Yuborilmoqda...' : 'Buyurtmani yuborish'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyAccount() async {
    await Clipboard.setData(const ClipboardData(text: AppState.bankAccount));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Karta raqami nusxalandi ✅')));
  }

  Future<void> _submit(AppState state, int deliveryFee) async {
    if (!formKey.currentState!.validate()) return;
    if (paymentDone && paymentProof == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('To‘lov qilgan bo‘lsangiz, chek skrinshotini tanlang.')));
      return;
    }

    setState(() => saving = true);
    try {
      final proof = paymentDone ? paymentProof : null;
      final orderId = await state.placeOrder(
        customerName: name.text,
        phone: phone.text,
        address: address.text,
        deliveryType: delivery,
        deliveryFee: deliveryFee,
        paymentProof: proof,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          icon: const Icon(Icons.check_circle_rounded, size: 58, color: _green),
          title: const Text('Buyurtma yuborildi'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Buyurtma raqami:\n$orderId', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              Text(
                proof != null
                    ? 'To‘lov cheki ham yuborildi. Admin tekshiradi va buyurtmani qabul qiladi.'
                    : 'Admin buyurtmani tekshiradi. To‘lovni amalga oshirgach, kerak bo‘lsa admin bilan bog‘lanishingiz mumkin.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 9),
              const Text('Qabul qilingandan keyin ombordagi qoldiq avtomatik yangilanadi.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.black54)),
            ],
          ),
          actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Tushunarli'))],
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Xatolik: $e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}

class _CheckoutStepHeader extends StatelessWidget {
  const _CheckoutStepHeader({required this.number, required this.title});
  final String number;
  final String title;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: _navy, shape: BoxShape.circle),
            child: Text(number, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 9),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        ],
      );
}'''
text = replace_between(text, "class CheckoutPage extends StatefulWidget {", "class _PaymentCard extends StatelessWidget {", checkout, "checkout page")

text = replace_once(
    text,
    "      'paid' => 'To‘landi',\n      'shipping' => 'Jo‘natildi',",
    "      'accepted' => 'Qabul qilindi',\n      'paid' => 'To‘landi',\n      'shipping' => 'Jo‘natildi',",
    "customer accepted status label",
)
text = replace_once(
    text,
    "      'paid' => Colors.blue,\n      'shipping' => _orange,",
    "      'accepted' => _green,\n      'paid' => Colors.blue,\n      'shipping' => _orange,",
    "customer accepted status color",
)
text = replace_once(
    text,
    "                      const Divider(height: 20),\n                      Row(children: [Text(DateFormat('yyyy.MM.dd HH:mm').format(order.createdAt), style: const TextStyle(color: Colors.black54, fontSize: 12)), const Spacer(), Text(won(order.total), style: const TextStyle(fontWeight: FontWeight.w900))]),",
    "                      if (order.hasPaymentProof) ...[\n                        const SizedBox(height: 4),\n                        const Row(children: [Icon(Icons.receipt_rounded, size: 16, color: _green), SizedBox(width: 5), Text('To‘lov cheki yuborilgan', style: TextStyle(color: _green, fontSize: 11.5, fontWeight: FontWeight.w800))]),\n                      ],\n                      const Divider(height: 20),\n                      Row(children: [Text(DateFormat('yyyy.MM.dd HH:mm').format(order.createdAt), style: const TextStyle(color: Colors.black54, fontSize: 12)), const Spacer(), Text(won(order.total), style: const TextStyle(fontWeight: FontWeight.w900))]),",
    "customer payment proof indicator",
)
p.write_text(text, encoding="utf-8")


# =========================
# ADMIN PANEL
# =========================
p = Path("lib/admin_ui.dart")
text = p.read_text(encoding="utf-8")

text = replace_once(
    text,
    "  Future<void> updateOrderStatus(String id, String status) async {\n    await client.rpc('admin_update_order_status', params: {",
    "  Future<String> paymentProofUrl(String path) async {\n    final response = await client.functions.invoke(\n      'payment-proof',\n      body: {'action': 'view', 'admin_code': secret, 'path': path},\n    );\n    final raw = response.data;\n    final data = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};\n    final url = (data['url'] ?? '').toString();\n    if (url.isEmpty) throw StateError((data['error'] ?? 'Chek ochilmadi.').toString());\n    return url;\n  }\n\n  Future<void> setStock(Book book, int value) async {\n    await saveBook(book.copyWith(stock: value < 0 ? 0 : value));\n  }\n\n  Future<void> updateOrderStatus(String id, String status) async {\n    await client.rpc('admin_update_order_status', params: {",
    "admin payment proof and stock methods",
)

dashboard = r'''class AdminDashboardPage extends StatefulWidget {
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
      _OverviewAdmin(api: api),
      _BooksAdmin(api: api),
      _InventoryAdmin(api: api),
      _OrdersAdmin(api: api),
      _DiscountAdmin(api: api),
    ];
    const railDestinations = [
      NavigationRailDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard_rounded), label: Text('Bosh sahifa')),
      NavigationRailDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book_rounded), label: Text('Kitoblar')),
      NavigationRailDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2_rounded), label: Text('Ombor')),
      NavigationRailDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long_rounded), label: Text('Buyurtmalar')),
      NavigationRailDestination(icon: Icon(Icons.percent_rounded), label: Text('Chegirma')),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 900;
        return Scaffold(
          appBar: AppBar(
            title: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                MuhajeerLogoBadge(size: 38, radius: 10, showShadow: false),
                SizedBox(width: 10),
                Text('Muhajeer Books • Admin'),
              ],
            ),
          ),
          body: desktop
              ? Row(
                  children: [
                    NavigationRail(
                      selectedIndex: tab,
                      onDestinationSelected: (v) => setState(() => tab = v),
                      labelType: NavigationRailLabelType.all,
                      groupAlignment: -.8,
                      destinations: railDestinations,
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: pages[tab]),
                  ],
                )
              : pages[tab],
          bottomNavigationBar: desktop
              ? null
              : NavigationBar(
                  selectedIndex: tab,
                  onDestinationSelected: (v) => setState(() => tab = v),
                  labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
                  destinations: const [
                    NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard_rounded), label: 'Bosh'),
                    NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book_rounded), label: 'Kitoblar'),
                    NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2_rounded), label: 'Ombor'),
                    NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long_rounded), label: 'Zakazlar'),
                    NavigationDestination(icon: Icon(Icons.percent_rounded), label: 'Chegirma'),
                  ],
                ),
        );
      },
    );
  }
}

class _OverviewData {
  const _OverviewData(this.books, this.orders);
  final List<Book> books;
  final List<ShopOrder> orders;
}

class _OverviewAdmin extends StatefulWidget {
  const _OverviewAdmin({required this.api});
  final _AdminApi api;

  @override
  State<_OverviewAdmin> createState() => _OverviewAdminState();
}

class _OverviewAdminState extends State<_OverviewAdmin> {
  late Future<_OverviewData> future;

  @override
  void initState() {
    super.initState();
    future = load();
  }

  Future<_OverviewData> load() async => _OverviewData(await widget.api.books(), await widget.api.orders());
  void reload() => setState(() => future = load());

  @override
  Widget build(BuildContext context) => FutureBuilder<_OverviewData>(
        future: future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return Center(child: Text('Xatolik: ${snap.error}'));
          final data = snap.data ?? const _OverviewData([], []);
          final books = data.books;
          final orders = data.orders;
          final now = DateTime.now();
          final todayOrders = orders.where((o) => o.createdAt.year == now.year && o.createdAt.month == now.month && o.createdAt.day == now.day).length;
          final newOrders = orders.where((o) => o.status == 'new').length;
          final proofOrders = orders.where((o) => o.status == 'new' && o.hasPaymentProof).length;
          final activeRevenue = orders.where((o) => ['accepted', 'paid', 'shipping', 'done'].contains(o.status)).fold<int>(0, (sum, o) => sum + o.total);
          final totalStock = books.fold<int>(0, (sum, b) => sum + b.stock);
          final retailValue = books.fold<int>(0, (sum, b) => sum + b.currentPrice * b.stock);
          final lowStock = books.where((b) => b.stock <= 2).toList()..sort((a, b) => a.stock.compareTo(b.stock));

          return RefreshIndicator(
            onRefresh: () async => reload(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(18),
              children: [
                Row(
                  children: [
                    const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Boshqaruv markazi', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)), SizedBox(height: 3), Text('Savdo, buyurtma va ombor holati bir joyda.', style: TextStyle(color: Colors.black54))])),
                    IconButton.filledTonal(onPressed: reload, icon: const Icon(Icons.refresh_rounded)),
                  ],
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _AdminStatCard(icon: Icons.new_releases_outlined, label: 'Yangi buyurtma', value: '$newOrders', accent: _orange),
                    _AdminStatCard(icon: Icons.today_outlined, label: 'Bugungi zakaz', value: '$todayOrders', accent: _navy),
                    _AdminStatCard(icon: Icons.receipt_outlined, label: 'Chek yuborilgan', value: '$proofOrders', accent: const Color(0xFF138A4B)),
                    _AdminStatCard(icon: Icons.inventory_2_outlined, label: 'Ombordagi dona', value: '$totalStock', accent: const Color(0xFF6B5DD3)),
                    _AdminStatCard(icon: Icons.payments_outlined, label: 'Qabul qilingan savdo', value: _won(activeRevenue), accent: const Color(0xFF138A4B)),
                    _AdminStatCard(icon: Icons.account_balance_wallet_outlined, label: 'Ombor retail qiymati', value: _won(retailValue), accent: _navy),
                  ],
                ),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [const Icon(Icons.warning_amber_rounded, color: _orange), const SizedBox(width: 8), const Expanded(child: Text('Kam qolgan kitoblar', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900))), Text('${lowStock.length} ta', style: const TextStyle(color: Colors.black54))]),
                        const SizedBox(height: 10),
                        if (lowStock.isEmpty)
                          const Text('Hamma kitoblarda qoldiq yaxshi ✅', style: TextStyle(color: Color(0xFF138A4B), fontWeight: FontWeight.w700))
                        else
                          ...lowStock.take(6).map((b) => ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: _AdminBookThumb(url: b.imageUrl),
                                title: Text(b.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                                trailing: Text('${b.stock} dona', style: TextStyle(fontWeight: FontWeight.w900, color: b.stock == 0 ? Colors.red : _orange)),
                              )),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
}

class _AdminStatCard extends StatelessWidget {
  const _AdminStatCard({required this.icon, required this.label, required this.value, required this.accent});
  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
        width: 210,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE6E8EC))),
        child: Row(
          children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: accent.withValues(alpha: .10), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: accent)),
            const SizedBox(width: 11),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)), const SizedBox(height: 2), Text(label, maxLines: 2, style: const TextStyle(fontSize: 11.5, color: Colors.black54, fontWeight: FontWeight.w600))])),
          ],
        ),
      );
}

class _InventoryAdmin extends StatefulWidget {
  const _InventoryAdmin({required this.api});
  final _AdminApi api;

  @override
  State<_InventoryAdmin> createState() => _InventoryAdminState();
}

class _InventoryAdminState extends State<_InventoryAdmin> {
  late Future<List<Book>> future;
  String query = '';
  final Set<String> busy = {};

  @override
  void initState() {
    super.initState();
    future = widget.api.books();
  }

  void reload() {
    setState(() => future = widget.api.books());
    context.read<AppState>().refreshBooks();
  }

  Future<void> change(Book book, int delta) async {
    if (busy.contains(book.id)) return;
    setState(() => busy.add(book.id));
    try {
      await widget.api.setStock(book, (book.stock + delta).clamp(0, 99999).toInt());
      if (mounted) reload();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ombor xatosi: $e')));
    } finally {
      if (mounted) setState(() => busy.remove(book.id));
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Book>>(
        future: future,
        builder: (context, snap) {
          final all = snap.data ?? const <Book>[];
          final q = query.trim().toLowerCase();
          final books = all.where((b) => q.isEmpty || b.title.toLowerCase().contains(q)).toList()..sort((a, b) => a.stock.compareTo(b.stock));
          final total = all.fold<int>(0, (s, b) => s + b.stock);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [const Expanded(child: Text('Ombor boshqaruvi', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900))), Chip(label: Text('$total dona'))]),
                    const SizedBox(height: 10),
                    TextField(onChanged: (v) => setState(() => query = v), decoration: const InputDecoration(hintText: 'Kitob nomi...', prefixIcon: Icon(Icons.search_rounded))),
                  ],
                ),
              ),
              if (snap.connectionState == ConnectionState.waiting)
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: books.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final b = books[i];
                      final isBusy = busy.contains(b.id);
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Row(
                            children: [
                              _AdminBookThumb(url: b.imageUrl),
                              const SizedBox(width: 12),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(b.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text('${_won(b.currentPrice)} • ${b.stock <= 2 ? 'Kam qolgan' : 'Qoldiq yaxshi'}', style: TextStyle(fontSize: 12, color: b.stock <= 2 ? _orange : const Color(0xFF138A4B))) ])),
                              if (isBusy)
                                const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                              else
                                Row(mainAxisSize: MainAxisSize.min, children: [
                                  IconButton.outlined(onPressed: () => change(b, -1), icon: const Icon(Icons.remove_rounded)),
                                  SizedBox(width: 50, child: Text('${b.stock}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
                                  IconButton.filledTonal(onPressed: () => change(b, 1), icon: const Icon(Icons.add_rounded)),
                                  const SizedBox(width: 4),
                                  PopupMenuButton<int>(
                                    tooltip: 'Tez qo‘shish',
                                    onSelected: (v) => change(b, v),
                                    itemBuilder: (_) => const [PopupMenuItem(value: 5, child: Text('+5 dona')), PopupMenuItem(value: 10, child: Text('+10 dona')), PopupMenuItem(value: 20, child: Text('+20 dona'))],
                                  ),
                                ]),
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
}'''
text = replace_between(text, "class AdminDashboardPage extends StatefulWidget {", "class _BooksAdmin extends StatefulWidget {", dashboard, "professional admin dashboard")

orders_admin = r'''class _OrdersAdmin extends StatefulWidget {
  const _OrdersAdmin({required this.api});
  final _AdminApi api;

  @override
  State<_OrdersAdmin> createState() => _OrdersAdminState();
}

class _OrdersAdminState extends State<_OrdersAdmin> {
  late Future<List<ShopOrder>> future;
  String filter = 'all';
  String query = '';
  final Set<String> busy = {};

  @override
  void initState() {
    super.initState();
    future = widget.api.orders();
  }

  void reload() => setState(() => future = widget.api.orders());

  Future<void> changeStatus(ShopOrder order, String status) async {
    if (busy.contains(order.id)) return;
    if (status == 'accepted') {
      final yes = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          icon: const Icon(Icons.inventory_2_rounded, color: Color(0xFF138A4B), size: 44),
          title: const Text('Buyurtmani qabul qilasizmi?'),
          content: const Text('Qabul qilinganda buyurtmadagi kitoblar ombordagi qoldiqdan avtomatik ayriladi.'),
          actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Yo‘q')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Qabul qilish'))],
        ),
      );
      if (yes != true) return;
    }
    if (status == 'cancelled') {
      final yes = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Buyurtmani bekor qilish'),
          content: Text(order.stockReserved ? 'Bu buyurtma ombordan ajratilgan. Bekor qilsangiz kitoblar omborga avtomatik qaytariladi.' : 'Buyurtma bekor qilinsinmi?'),
          actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Yo‘q')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Bekor qilish'))],
        ),
      );
      if (yes != true) return;
    }

    setState(() => busy.add(order.id));
    try {
      await widget.api.updateOrderStatus(order.id, status);
      await context.read<AppState>().refreshBooks();
      if (mounted) {
        reload();
        final message = status == 'accepted'
            ? 'Buyurtma qabul qilindi. Ombor avtomatik kamaydi ✅'
            : status == 'cancelled'
                ? 'Buyurtma bekor qilindi.'
                : 'Buyurtma holati yangilandi.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Xatolik: $e')));
    } finally {
      if (mounted) setState(() => busy.remove(order.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ShopOrder>>(
      future: future,
      builder: (context, snap) {
        final all = snap.data ?? const <ShopOrder>[];
        final q = query.trim().toLowerCase();
        final orders = all.where((o) {
          final matchStatus = filter == 'all' || o.status == filter;
          final matchQuery = q.isEmpty || o.customerName.toLowerCase().contains(q) || o.phone.toLowerCase().contains(q) || o.id.toLowerCase().contains(q);
          return matchStatus && matchQuery;
        }).toList();
        final newCount = all.where((o) => o.status == 'new').length;
        final proofCount = all.where((o) => o.status == 'new' && o.hasPaymentProof).length;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [const Expanded(child: Text('Buyurtmalar', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900))), Badge(isLabelVisible: newCount > 0, label: Text('$newCount'), child: IconButton.filledTonal(onPressed: reload, icon: const Icon(Icons.refresh_rounded)))]),
                  const SizedBox(height: 10),
                  Row(children: [Expanded(child: TextField(onChanged: (v) => setState(() => query = v), decoration: const InputDecoration(hintText: 'Mijoz, telefon yoki buyurtma ID...', prefixIcon: Icon(Icons.search_rounded)))), const SizedBox(width: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), decoration: BoxDecoration(color: proofCount > 0 ? const Color(0xFFEAF7EF) : Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE6E8EC))), child: Row(children: [const Icon(Icons.receipt_outlined, size: 18, color: Color(0xFF138A4B)), const SizedBox(width: 5), Text('$proofCount chek', style: const TextStyle(fontWeight: FontWeight.w800))]))]),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _OrderFilterChip(label: 'Barchasi', value: 'all', selected: filter, onTap: (v) => setState(() => filter = v)),
                        _OrderFilterChip(label: 'Yangi', value: 'new', selected: filter, onTap: (v) => setState(() => filter = v)),
                        _OrderFilterChip(label: 'Qabul qilingan', value: 'accepted', selected: filter, onTap: (v) => setState(() => filter = v)),
                        _OrderFilterChip(label: 'Jo‘natilgan', value: 'shipping', selected: filter, onTap: (v) => setState(() => filter = v)),
                        _OrderFilterChip(label: 'Yakunlangan', value: 'done', selected: filter, onTap: (v) => setState(() => filter = v)),
                        _OrderFilterChip(label: 'Bekor', value: 'cancelled', selected: filter, onTap: (v) => setState(() => filter = v)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (snap.connectionState == ConnectionState.waiting)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (snap.hasError)
              Expanded(child: Center(child: Text('Xatolik: ${snap.error}')))
            else if (orders.isEmpty)
              const Expanded(child: Center(child: Text('Bu bo‘limda buyurtma yo‘q')))
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: orders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _ProfessionalOrderCard(
                    order: orders[i],
                    api: widget.api,
                    loading: busy.contains(orders[i].id),
                    onStatus: (status) => changeStatus(orders[i], status),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _OrderFilterChip extends StatelessWidget {
  const _OrderFilterChip({required this.label, required this.value, required this.selected, required this.onTap});
  final String label;
  final String value;
  final String selected;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 7),
        child: ChoiceChip(label: Text(label), selected: selected == value, onSelected: (_) => onTap(value)),
      );
}

class _ProfessionalOrderCard extends StatelessWidget {
  const _ProfessionalOrderCard({required this.order, required this.api, required this.loading, required this.onStatus});
  final ShopOrder order;
  final _AdminApi api;
  final bool loading;
  final ValueChanged<String> onStatus;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: Container(width: 44, height: 44, decoration: BoxDecoration(color: _navy.withValues(alpha: .08), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.receipt_long_rounded, color: _navy)),
        title: Row(children: [Expanded(child: Text(order.customerName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900))), _AdminOrderStatusChip(status: order.status)]),
        subtitle: Padding(padding: const EdgeInsets.only(top: 4), child: Row(children: [Text(_won(order.total), style: const TextStyle(fontWeight: FontWeight.w800)), const Text(' • '), Expanded(child: Text(order.phone, maxLines: 1, overflow: TextOverflow.ellipsis)), if (order.hasPaymentProof) const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.receipt_rounded, size: 17, color: Color(0xFF138A4B)))])),
        children: [
          Row(children: [Expanded(child: Text('№ ${order.id}', style: const TextStyle(fontSize: 11, color: Colors.black45))), Text(DateFormat('yyyy.MM.dd HH:mm').format(order.createdAt), style: const TextStyle(fontSize: 11, color: Colors.black45))]),
          const SizedBox(height: 12),
          Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFF7F8FA), borderRadius: BorderRadius.circular(14)), child: Text('📱 ${order.phone}\n📍 ${order.address}\n🚚 ${order.deliveryType} • ${_won(order.deliveryFee)}', style: const TextStyle(height: 1.55))),
          const SizedBox(height: 12),
          ...order.items.map((item) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(children: [Expanded(child: Text('${item['title']} × ${item['quantity']}', style: const TextStyle(fontWeight: FontWeight.w700))), Text(_won((item['line_total'] as num?)?.toInt() ?? 0), style: const TextStyle(fontWeight: FontWeight.w800))]))),
          const Divider(height: 22),
          Row(children: [const Text('Jami', style: TextStyle(fontWeight: FontWeight.w800)), const Spacer(), Text(_won(order.total), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _navy))]),
          if (order.hasPaymentProof) ...[
            const SizedBox(height: 12),
            _PaymentProofPanel(api: api, path: order.paymentProofPath),
          ],
          const SizedBox(height: 14),
          if (loading)
            const Center(child: Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator()))
          else
            _OrderActions(order: order, onStatus: onStatus),
        ],
      ),
    );
  }
}

class _OrderActions extends StatelessWidget {
  const _OrderActions({required this.order, required this.onStatus});
  final ShopOrder order;
  final ValueChanged<String> onStatus;

  @override
  Widget build(BuildContext context) {
    if (order.status == 'cancelled' || order.status == 'done') return const SizedBox.shrink();
    String? primaryStatus;
    String? primaryLabel;
    IconData? primaryIcon;
    if (order.status == 'new') {
      primaryStatus = 'accepted';
      primaryLabel = 'Qabul qilish';
      primaryIcon = Icons.check_circle_rounded;
    } else if (order.status == 'accepted' || order.status == 'paid') {
      primaryStatus = 'shipping';
      primaryLabel = 'Jo‘natildi';
      primaryIcon = Icons.local_shipping_rounded;
    } else if (order.status == 'shipping') {
      primaryStatus = 'done';
      primaryLabel = 'Yakunlash';
      primaryIcon = Icons.task_alt_rounded;
    }

    return Row(
      children: [
        if (primaryStatus != null)
          Expanded(child: FilledButton.icon(onPressed: () => onStatus(primaryStatus!), icon: Icon(primaryIcon), label: Text(primaryLabel!))),
        if (primaryStatus != null) const SizedBox(width: 8),
        OutlinedButton.icon(onPressed: () => onStatus('cancelled'), icon: const Icon(Icons.close_rounded), label: const Text('Bekor')),
      ],
    );
  }
}

class _AdminOrderStatusChip extends StatelessWidget {
  const _AdminOrderStatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'accepted' => ('Qabul qilindi', const Color(0xFF138A4B)),
      'paid' => ('To‘landi', Colors.blue),
      'shipping' => ('Jo‘natildi', _orange),
      'done' => ('Yakunlandi', const Color(0xFF138A4B)),
      'cancelled' => ('Bekor', Colors.red),
      _ => ('Yangi', _navy),
    };
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: color.withValues(alpha: .10), borderRadius: BorderRadius.circular(100)), child: Text(label, style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w900)));
  }
}

class _PaymentProofPanel extends StatelessWidget {
  const _PaymentProofPanel({required this.api, required this.path});
  final _AdminApi api;
  final String path;

  Future<void> openProof(BuildContext context) async {
    showDialog<void>(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    try {
      final url = await api.paymentProofUrl(path);
      if (!context.mounted) return;
      Navigator.pop(context);
      await showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720, maxHeight: 820),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(title: const Text('To‘lov cheki', style: TextStyle(fontWeight: FontWeight.w900)), trailing: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded))),
                const Divider(height: 1),
                Flexible(child: InteractiveViewer(minScale: .5, maxScale: 4, child: Image.network(url, fit: BoxFit.contain))),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Chekni ochishda xatolik: $e')));
    }
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFFEAF7EF), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFBDE2C9))),
        child: Row(children: [const Icon(Icons.receipt_rounded, color: Color(0xFF138A4B)), const SizedBox(width: 9), const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('To‘lov cheki yuborilgan', style: TextStyle(fontWeight: FontWeight.w900)), Text('Chek maxfiy saqlanadi.', style: TextStyle(fontSize: 11, color: Colors.black54))])), FilledButton.tonalIcon(onPressed: () => openProof(context), icon: const Icon(Icons.visibility_outlined), label: const Text('Ko‘rish'))]),
      );
}'''
text = replace_between(text, "class _OrdersAdmin extends StatefulWidget {", "class _DiscountAdmin extends StatefulWidget {", orders_admin, "professional orders admin")
p.write_text(text, encoding="utf-8")


# =========================
# THEME POLISH
# =========================
p = Path("lib/main.dart")
text = p.read_text(encoding="utf-8")
text = replace_once(
    text,
    "          scaffoldBackgroundColor: const Color(0xFFF7F8FA),\n          inputDecorationTheme:",
    "          scaffoldBackgroundColor: const Color(0xFFF7F8FA),\n          appBarTheme: const AppBarTheme(\n            backgroundColor: Color(0xFFF7F8FA),\n            foregroundColor: Color(0xFF10213D),\n            surfaceTintColor: Colors.transparent,\n            elevation: 0,\n            scrolledUnderElevation: 0,\n            titleTextStyle: TextStyle(color: Color(0xFF10213D), fontSize: 20, fontWeight: FontWeight.w900),\n          ),\n          filledButtonTheme: FilledButtonThemeData(\n            style: FilledButton.styleFrom(\n              backgroundColor: const Color(0xFF10213D),\n              foregroundColor: Colors.white,\n              minimumSize: const Size(44, 48),\n              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),\n              textStyle: const TextStyle(fontWeight: FontWeight.w800),\n            ),\n          ),\n          navigationBarTheme: const NavigationBarThemeData(\n            backgroundColor: Colors.white,\n            indicatorColor: Color(0xFFFFE1C8),\n            elevation: 0,\n          ),\n          snackBarTheme: SnackBarThemeData(\n            behavior: SnackBarBehavior.floating,\n            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),\n          ),\n          inputDecorationTheme:",
    "theme polish",
)
p.write_text(text, encoding="utf-8")


# =========================
# REPO MIGRATION DOCUMENT
# =========================
migration = Path("supabase/migrations/20260906_professional_orders.sql")
migration.parent.mkdir(parents=True, exist_ok=True)
migration.write_text("""-- Applied to production on 2026-09-06.\n-- Professional order flow:\n-- 1) orders are validated on insert but stock is NOT reduced;\n-- 2) admin status 'accepted' atomically reserves/decrements stock;\n-- 3) cancellation restores stock only when it had been reserved;\n-- 4) payment_proof_path/payment_submitted_at store private receipt references;\n-- 5) payment-receipts is a private Storage bucket;\n-- 6) customer_order_statuses(uuid[]) exposes only status metadata for locally saved customer receipts.\n\n-- The live database migration was applied through Supabase before this source release.\n""", encoding="utf-8")

print("Professional upgrade patches applied.")
