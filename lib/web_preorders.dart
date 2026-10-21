import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_state.dart';
import 'design_system.dart';
import 'push_notifications.dart';
import 'preview_features.dart';
import 'purchase_price_notice.dart';

part 'web_preorder_multi.dart';

// Enabled only for the explicitly requested iOS TestFlight preview.
bool get webPreordersAvailable => webPreviewFeaturesAvailable;

String webPreorderTime(dynamic value) {
  final time = DateTime.tryParse((value ?? '').toString());
  return time == null ? '—' : DateFormat('yyyy.MM.dd HH:mm').format(time.toLocal());
}

String webPreorderMoney(int amount) =>
    '₩${NumberFormat('#,###').format(amount)}';

class WebPreorderConfig {
  const WebPreorderConfig({
    this.enabled = false,
    this.arrival = '',
    this.deposit = 5000,
    this.batchQuantity = 0,
    this.revision = 1,
    this.bookId = '', this.bookTitle = '', this.bookImageUrl = '', this.termsToken = '',
    this.depositMax,

  });
  factory WebPreorderConfig.fromMap(Map<String, dynamic> data) =>
      WebPreorderConfig(
        bookId: (data['book_id'] ?? '').toString(),
        bookTitle: (data['book_title'] ?? '').toString(),
        bookImageUrl: (data['book_image_url'] ?? '').toString(),
        termsToken: (data['terms_token'] ?? '').toString(),
        depositMax: (data['deposit_max'] as num?)?.toInt(),
        enabled: data['enabled'] == true,
        arrival: (data['arrival_note'] ?? '').toString(),
        deposit: (data['deposit_amount'] as num?)?.toInt() ?? 5000,
        batchQuantity: (data['batch_quantity'] as num?)?.toInt() ?? 0,
        revision: (data['revision'] as num?)?.toInt() ?? 1,
      );
  final bool enabled;
  final String arrival, bookId, bookTitle, bookImageUrl, termsToken;
  final int? depositMax;
  final int deposit, batchQuantity, revision;
  bool get accepting => enabled && arrival.trim().isNotEmpty && deposit >= 5000;
  int get maximumDeposit => depositMax ?? deposit;
  int total(int quantity, [int? perBook]) => (perBook ?? deposit) * quantity;
}

class WebPreorderApi {
  Future<dynamic> call(
    String action, [
    Map<String, dynamic> params = const {},
  ]) async {
    final response = await Supabase.instance.client.functions
        .invoke('web-preorders', body: {'action': action, 'params': params})
        .timeout(const Duration(seconds: 40));
    final raw = response.data is String
        ? jsonDecode(response.data as String)
        : response.data;
    if (raw is! Map || raw['ok'] != true) {
      throw StateError(
        raw is Map
            ? '${raw['error'] ?? 'So‘rov bajarilmadi.'}'
            : 'Server javobi olinmadi.',
      );
    }
    return raw['data'];
  }

  Future<WebPreorderConfig> config() async => WebPreorderConfig.fromMap(
    Map<String, dynamic>.from(await call('config') as Map),
  );
  Future<WebPreorderConfig> bookConfig(String bookId) async => WebPreorderConfig.fromMap(
    Map<String, dynamic>.from(await call('book_config', {'book_id': bookId}) as Map),
  );
  Future<dynamic> admin(
    String secret,
    String action, [
    Map<String, dynamic> data = const {},
  ]) => call('admin', {
    'p_secret': secret,
    'p_action': action,
    'p_payload': data,
  });
  Future<String> upload(
    String id,
    String kind,
    Uint8List bytes,
    int revision, {String? bookId, String? termsToken}
  ) async {
    final data = await call('upload', {
      'id': id,
      'kind': kind,
      'data_base64': base64Encode(bytes),
      'revision': revision,
      if (bookId != null) 'book_id': bookId,
      if (termsToken != null) 'terms_token': termsToken,
    });
    return (data as Map)['path'].toString();
  }
}

class WebPreorderCatalogCard extends StatefulWidget {
  const WebPreorderCatalogCard({super.key, this.api});
  final WebPreorderApi? api;
  @override
  State<WebPreorderCatalogCard> createState() => _WebPreorderCatalogCardState();
}

class _WebPreorderCatalogCardState extends State<WebPreorderCatalogCard> {
  late final api = widget.api ?? WebPreorderApi();
  WebPreorderConfig? config;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    _load();
    timer = Timer.periodic(const Duration(seconds: 60), (_) => _load());
  }

  Future<void> _load() async {
    try {
      final c = await api.config();
      if (mounted) setState(() => config = c);
    } catch (_) {
      if (mounted) setState(() => config = null);
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Oldindan buyurtma',
    child: Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            settings: const RouteSettings(name: 'mb:web-preorder'),
            builder: (_) => WebPreorderPage(api: api),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: const Color(0xFF075E54),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD5B66A), width: 2),
                ),
                padding: const EdgeInsets.all(12),
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SizedBox(
                    width: 150,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_stories_rounded,
                          color: Color(0xFFF0D78B),
                          size: 38,
                        ),
                        SizedBox(height: 14),
                        Text(
                          'Oldindan\nbuyurtma',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                            height: 1.15,
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'MUHAJEER BOOKS',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFFF0D78B),
                            fontSize: 10,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 2, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Kitob so‘rovi',
                    maxLines: 1,
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    config?.accepting == true
                        ? 'Kelishi: ${config!.arrival}'
                        : 'Qabul hozircha yopiq',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                  if (config?.accepting == true) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Avans: ${webPreorderMoney(config!.deposit)} / dona',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class WebPreorderPage extends StatelessWidget {
  const WebPreorderPage({super.key, this.api, this.book, this.pickImage});
  final WebPreorderApi? api;
  final Book? book;
  final Future<Uint8List?> Function()? pickImage;
  @override
  Widget build(BuildContext context) => webPreordersAvailable && book == null
      ? WebMultiPreorderPage(api: api, pickImage: pickImage)
      : _WebSinglePreorderPage(api: api, book: book, pickImage: pickImage);
}

class _WebSinglePreorderPage extends StatefulWidget {
  const _WebSinglePreorderPage({this.api, this.book, this.pickImage});
  final WebPreorderApi? api;
  final Book? book;
  final Future<Uint8List?> Function()? pickImage;
  @override
  State<_WebSinglePreorderPage> createState() => _WebPreorderPageState();
}

class _WebPreorderPageState extends State<_WebSinglePreorderPage> {
  late final api = widget.api ?? WebPreorderApi();
  final form = GlobalKey<FormState>();
  final title = TextEditingController(),
      name = TextEditingController(),
      phone = TextEditingController(),
      advance = TextEditingController();
  late final String id;
  WebPreorderConfig? config;
  Uint8List? bookImage, proofImage;
  String? bookPath, proofPath, error;
  int quantity = 1;
  bool loading = true, payment = false, saving = false, picking = false;
  bool completed = false, allowPop = false, leaving = false;
  bool get busy => saving || picking || completed;
  late final String initialName, initialPhone;
  @override
  void initState() {
    super.initState();
    final bytes = List.generate(16, (_) => Random.secure().nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
    id =
        '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
    final saved = context.read<AppState>().savedCustomer;
    title.text = widget.book?.title ?? '';
    name.text = saved['name'] ?? '';
    phone.text = saved['phone'] ?? '';
    initialName = name.text;
    initialPhone = phone.text;
    _reload();
  }

  @override
  void dispose() {
    title.dispose();
    name.dispose();
    phone.dispose();
    advance.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final next = widget.book == null ? await api.config() : await api.bookConfig(widget.book!.id);
      if (mounted)
        setState(() {
          if (config?.revision != next.revision || config?.termsToken != next.termsToken) {
            payment = false;
            advance.text = '${next.deposit}';
          }
          if (next.bookTitle.isNotEmpty) title.text = next.bookTitle;
          config = next;
          error = null;
          loading = false;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          error = 'Shartlarni yuklab bo‘lmadi. Qayta urining.';
          config = null;
          loading = false;
          payment = false;
        });
    }
  }

  void _message(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _back() async {
    if (busy || leaving) return;
    if (payment) { setState(() => payment = false); return; }
    await _cancelRequest();
  }

  Future<void> _cancelRequest() async {
    if (busy || leaving) return;
    leaving = true;
    try {
      final dirty = payment || proofImage != null || bookImage != null || quantity != 1 ||
          name.text != initialName || phone.text != initialPhone ||
          (widget.book == null && title.text.isNotEmpty);
      if (dirty) {
        final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
          title: const Text('Buyurtmadan chiqasizmi?'),
          content: const Text('Yuborilmagan ma’lumotlar saqlanmaydi. Avans o‘tkazgan bo‘lsangiz, so‘rovni yuboring yoki administrator bilan bog‘laning.'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Davom etish')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Chiqish'))],
        ));
        if (confirmed != true || !mounted) return;
      }
      if (!mounted || !Navigator.of(context).canPop()) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      setState(() => allowPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) Navigator.pop(context); });
    } finally { leaving = false; }
  }

  void _removeImage(bool receipt) {
    if (busy) return;
    final image = receipt ? proofImage : bookImage;
    final path = receipt ? proofPath : bookPath;
    setState(() {
      if (receipt) { proofImage = null; proofPath = null; }
      else { bookImage = null; bookPath = null; }
    });
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(SnackBar(content: Text(receipt ? 'Chek olib tashlandi.' : 'Rasm olib tashlandi.'),
      action: SnackBarAction(label: 'Qaytarish', onPressed: () {
        if (!mounted || busy) return;
        setState(() {
          if (receipt) { proofImage = image; proofPath = path; }
          else { bookImage = image; bookPath = path; }
        });
      })));
  }

  Future<void> _pick(bool receipt) async {
    if (busy) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    setState(() => picking = true);
    try {
      Uint8List? bytes;
      if (widget.pickImage != null) {
        bytes = await widget.pickImage!();
      } else {
        final file = await ImagePicker().pickImage(source: ImageSource.gallery,
          maxWidth: 1200, maxHeight: 1600, imageQuality: 80);
        bytes = await file?.readAsBytes();
      }
      if (bytes == null || !mounted) return;
      if (bytes.length > 8 * 1024 * 1024) {
        if (mounted) _message('8 MB dan kichikroq rasm tanlang.');
        return;
      }
      var decoded = img.decodeImage(bytes);
      if (decoded == null) {
        if (mounted) _message('JPG, PNG yoki WebP rasm tanlang.');
        return;
      }
      decoded = img.bakeOrientation(decoded);
      if (decoded.width > 1200 || decoded.height > 1600) {
        decoded = img.copyResize(decoded, width: 1200, height: 1600, maintainAspect: true);
      }
      final encoded = Uint8List.fromList(img.encodeJpg(decoded, quality: 80));
      if (encoded.length > 2097152) {
        if (mounted) _message('Rasmni kichraytirib, qayta tanlang (2 MB).');
        return;
      }
      if (mounted)
        setState(() {
          if (receipt) {
            proofImage = encoded;
            proofPath = null;
          } else {
            bookImage = encoded;
            bookPath = null;
          }
        });
    } catch (_) {
      if (mounted) _message('Rasmni tanlab bo‘lmadi. Qayta urining.');
    } finally { if (mounted) setState(() => picking = false); }
  }

  bool _validateDetails() {
    // ListView may dispose offscreen FormFields; validate their controllers too.
    if (title.text.trim().length < 2 || title.text.trim().length > 160) {
      _message('Kitob nomini tekshiring.'); return false;
    }
    if (name.text.trim().length < 2 || name.text.trim().length > 80) {
      _message('Ismingizni kiriting.'); return false;
    }
    if (!RegExp(r'^010\d{8}$').hasMatch(phone.text.trim())) {
      _message('Telefon raqamini tekshiring.'); return false;
    }
    final amount = int.tryParse(advance.text);
    if (config == null || amount == null || amount < config!.deposit || amount > config!.maximumDeposit) {
      _message('Avans summasini tekshiring.'); return false;
    }
    return form.currentState?.validate() ?? false;
  }

  Future<bool> _checkCurrent() async {
    final old = config;
    await _reload();
    if (!mounted || config?.accepting != true) return false;
    if (old?.revision != config!.revision || old?.termsToken != config!.termsToken) {
      _message(
        'Kelish sanasi yoki avans yangilandi. Shartlarni qayta ko‘rib chiqing.',
      );
      return false;
    }
    return true;
  }

  Future<void> _continue() async {
    if (busy || !_validateDetails()) return;
    if (widget.book == null && bookImage == null) {
      _message('Kitob rasmini tanlang.');
      return;
    }
    setState(() => saving = true);
    try {
      if (await _checkCurrent() && mounted) setState(() => payment = true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _submit() async {
    if (busy || !_validateDetails()) return;
    if (proofImage == null) {
      _message('Avans to‘lovi chekini yuklang.');
      return;
    }
    setState(() => saving = true);
    try {
      if (!await _checkCurrent()) return;
      final c = config!;
      if (widget.book == null) bookPath ??= await api.upload(id, 'book', bookImage!, c.revision);
      proofPath ??= await api.upload(id, 'proof', proofImage!, c.revision,
        bookId: widget.book?.id, termsToken: widget.book == null ? null : c.termsToken);
      await api.call('submit', {
        'p_request': {
          'id': id,
          if (widget.book != null) 'book_id': widget.book!.id,
          'terms_token': c.termsToken,
          'customer_name': name.text.trim(),
          'phone': phone.text.trim(),
          'book_title': title.text.trim(),
          'quantity': quantity,
          'book_image_path': bookPath ?? '',
          'payment_proof_path': proofPath,
          'deposit_amount': c.total(quantity, int.tryParse(advance.text)),
          'revision': c.revision,
        },
      });
      if (!mounted) return;
      setState(() { completed = true; saving = false; });
      final state = context.read<AppState>();
      final samePhone = state.savedCustomerPhone == phone.text.trim();
      try {
        await state.setAuthenticatedCustomer(name.text.trim(), phone.text.trim(),
          verified: samePhone && state.customerVerified);
        unawaited(syncPushIdentity(phone.text.trim()));
        unawaited(state.refreshCustomerPushMessages());
      } catch (_) { /* The server already committed the request and inbox. */ }
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Oldindan buyurtma yuborildi'),
          content: Text(
            'Buyurtma: ${id.substring(0, 8)}\nAvans cheki administrator tomonidan tekshiriladi.\nTaxminiy kelishi: ${c.arrival}\nHolat o‘zgarganda “Bildirishnomalar” bo‘limiga xabar keladi.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tushunarli'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) _message(e.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = config;
    return PopScope(
      canPop: allowPop || completed,
      onPopInvokedWithResult: (didPop, result) { if (!didPop) _back(); },
      child: Scaffold(
      appBar: AppBar(title: const Text('Oldindan buyurtma'),
        leading: IconButton(tooltip: 'Orqaga', icon: const Icon(Icons.arrow_back), onPressed: busy ? null : _back)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : Form(
                  key: form,
                  child: ListView(
                    padding: const EdgeInsets.all(18),
                    children: [
                      AppSurface(
                        backgroundColor: const Color(0xFFE5F3ED),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Taxminiy kelish sanasi',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              c?.arrival.isNotEmpty == true
                                  ? c!.arrival
                                  : 'Hali belgilanmagan',
                              style: const TextStyle(
                                fontSize: 23,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            if (c != null && c.batchQuantity > 0)
                              Text('Partiyada keladi: ${c.batchQuantity} ta'),
                            const SizedBox(height: 8),
                            const Text(
                              'Kitobni shu muddatga qarab buyurtma qiling. Kelish sanasi taxminiy.',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (error != null || c?.accepting != true) ...[
                        Text(
                          error ?? 'Oldindan buyurtma qabuli hozircha yopiq. Avans yubormang.',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        OutlinedButton.icon(
                          onPressed: _reload,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Yangilash'),
                        ),
                      ] else ...[
                        if (iosTestFlightPreview) ...[
                          const PurchasePriceNotice(),
                          const SizedBox(height: 12),
                        ],
                        Text(
                          c!.maximumDeposit == c.deposit ? 'Avans: ${webPreorderMoney(c.deposit)} / dona' : 'Avans: ${webPreorderMoney(c.deposit)} – ${webPreorderMoney(c.maximumDeposit)} / dona',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Text(
                          'Yakuniy narx kitob kelganda aniqlanadi. Avans yakuniy to‘lovdan ayriladi.',
                        ),
                        const SizedBox(height: 18),
                        TextFormField(
                          controller: title,
                          readOnly: widget.book != null || payment || busy,
                          decoration: const InputDecoration(
                            labelText: 'Kitob nomi',
                          ),
                          maxLength: 160,
                          validator: (v) => (v ?? '').trim().length < 2
                              ? 'Kitob nomini kiriting'
                              : null,
                        ),
                        if (widget.book != null && c.bookImageUrl.isNotEmpty)
                          SizedBox(height: 160, child: Image.network(c.bookImageUrl, fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(Icons.menu_book_outlined))),
                        if (bookImage != null)
                          SizedBox(
                            height: 160,
                            child: Image.memory(
                              bookImage!,
                              fit: BoxFit.contain,
                            ),
                          ),
                        if (widget.book == null && !payment)
                          OutlinedButton.icon(
                            onPressed: busy ? null : () => _pick(false),
                            icon: const Icon(
                              Icons.add_photo_alternate_outlined,
                            ),
                            label: Text(
                              bookImage == null
                                  ? 'Kitob rasmini yuklash'
                                  : 'Rasmni almashtirish',
                            ),
                          ),
                        if (bookImage != null && !payment)
                          TextButton(onPressed: busy ? null : () => _removeImage(false), child: const Text('Rasmni bekor qilish')),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: name,
                          readOnly: payment || busy,
                          maxLength: 80,
                          decoration: const InputDecoration(
                            labelText: 'Ismingiz',
                          ),
                          validator: (v) => (v ?? '').trim().length < 2
                              ? 'Ismingizni kiriting'
                              : null,
                        ),
                        TextFormField(
                          controller: phone,
                          readOnly: payment || busy,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(11),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Telefon raqam',
                            hintText: '01012345678',
                          ),
                          validator: (v) =>
                              RegExp(r'^010\d{8}$').hasMatch(v ?? '')
                              ? null
                              : '010 bilan boshlanuvchi 11 ta raqam kiriting',
                        ),
                        const SizedBox(height: 12),
                        if (c.maximumDeposit > c.deposit) ...[
                          TextFormField(controller: advance, readOnly: payment || busy,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: const InputDecoration(labelText: 'Bir kitob uchun avans (₩)'),
                            onChanged: (_) => setState(() {}),
                            validator: (v) {
                              final n = int.tryParse(v ?? '') ?? 0;
                              return n < c.deposit || n > c.maximumDeposit ? '${webPreorderMoney(c.deposit)}–${webPreorderMoney(c.maximumDeposit)} oralig‘ida kiriting' : null;
                            }),
                          Wrap(spacing: 8, children: [
                            for (final value in {c.deposit, 5000, 10000, c.maximumDeposit}.where((v) => v >= c.deposit && v <= c.maximumDeposit))
                              ActionChip(label: Text(webPreorderMoney(value)), onPressed: payment || busy ? null : () => setState(() => advance.text = '$value')),
                          ]),
                        ],
                        Row(
                          children: [
                            const Expanded(child: Text('Miqdor')),
                            IconButton(
                              onPressed: quantity <= 1 || payment || busy
                                  ? null
                                  : () => setState(() => quantity--),
                              icon: const Icon(Icons.remove_circle_outline),
                            ),
                            Text(
                              '$quantity',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 20,
                              ),
                            ),
                            IconButton(
                              onPressed: quantity >= 20 || payment || busy
                                  ? null
                                  : () => setState(() => quantity++),
                              icon: const Icon(Icons.add_circle_outline),
                            ),
                          ],
                        ),
                        Text(
                          'Jami avans: ${webPreorderMoney(c.total(quantity, int.tryParse(advance.text)))}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                          ),
                        ),
                        const Text('Pochtaga +4 000 won qo‘shiladi. Hozir faqat avansni o‘tkazing.',
                          style: TextStyle(fontSize: 12, color: AppColors.muted)),
                        const SizedBox(height: 16),
                        if (!payment)
                          FilledButton(
                            onPressed: busy ? null : _continue,
                            child: Text(
                              saving
                                  ? 'Tekshirilmoqda…'
                                  : 'Shartlarni ko‘rdim — to‘lovga o‘tish',
                            ),
                          )
                        else ...[
                          AppSurface(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Bank o‘tkazmasi',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                  ),
                                ),
                                const Text(
                                  '${AppState.bankName}\n${AppState.bankOwner}',
                                ),
                                Row(
                                  children: [
                                    const Expanded(
                                      child: SelectableText(
                                        AppState.bankAccount,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Hisob raqamini nusxalash',
                                      icon: const Icon(Icons.copy),
                                      onPressed: () async {
                                        await Clipboard.setData(
                                          const ClipboardData(
                                            text: AppState.bankAccount,
                                          ),
                                        );
                                        if (mounted)
                                          _message('Hisob raqami nusxalandi');
                                      },
                                    ),
                                  ],
                                ),
                                Text(
                                  'O‘tkaziladigan summa: ${webPreorderMoney(c.total(quantity, int.tryParse(advance.text)))}',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (proofImage != null)
                            SizedBox(
                              height: 150,
                              child: Image.memory(
                                proofImage!,
                                fit: BoxFit.contain,
                              ),
                            ),
                          OutlinedButton.icon(
                            onPressed: busy ? null : () => _pick(true),
                            icon: const Icon(Icons.receipt_long_outlined),
                            label: Text(
                              proofImage == null
                                  ? 'Avans chekini yuklash'
                                  : 'Chekni almashtirish',
                            ),
                          ),
                          if (proofImage != null)
                            TextButton(onPressed: busy ? null : () => _removeImage(true), child: const Text('Chekni bekor qilish')),
                          FilledButton(
                            onPressed: busy ? null : _submit,
                            child: Text(
                              saving
                                  ? 'Yuborilmoqda…'
                                  : 'Avans yubordim — buyurtma berish',
                            ),
                          ),
                          TextButton(
                            onPressed: busy
                                ? null
                                : () => setState(() => payment = false),
                            child: const Text('Ma’lumotlarni tahrirlash'),
                          ),
                        ],
                        TextButton.icon(onPressed: busy ? null : _cancelRequest,
                          icon: const Icon(Icons.close), label: const Text('Buyurtmani bekor qilish')),
                        if (picking || saving) const LinearProgressIndicator(),
                      ],
                    ],
                  ),
                ),
        ),
      ),
    ));
  }
}

class WebPreorderAdminPage extends StatefulWidget {
  const WebPreorderAdminPage({super.key, required this.secret, this.api});
  final String secret;
  final WebPreorderApi? api;
  @override
  State<WebPreorderAdminPage> createState() => _WebPreorderAdminPageState();
}

class _WebPreorderAdminPageState extends State<WebPreorderAdminPage> {
  late final api = widget.api ?? WebPreorderApi();
  final form = GlobalKey<FormState>();
  final arrival = TextEditingController(),
      deposit = TextEditingController(),
      batch = TextEditingController();
  WebPreorderConfig? config;
  Future<dynamic>? requests;
  String? error;
  bool enabled = false, saving = false;
  final Set<String> statusSaving = {};
  String search = '', statusFilter = 'all';
  bool loadingMore = false, hasMore = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    arrival.dispose();
    deposit.dispose();
    batch.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final raw = await api.admin(widget.secret, 'settings');
      final c = WebPreorderConfig.fromMap(
        Map<String, dynamic>.from(raw as Map),
      );
      if (!mounted) return;
      setState(() {
        config = c;
        enabled = c.enabled;
        arrival.text = c.arrival;
        deposit.text = '${c.deposit}';
        batch.text = '${c.batchQuantity}';
        error = null;
        requests = api.admin(widget.secret, 'list');
        hasMore = true;
      });
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  Future<void> _save() async {
    if (saving) return;
    if (enabled && arrival.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Qabulni ochishdan oldin sanani kiriting')));
      return;
    }
    if (!form.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      await api.admin(widget.secret, 'save', {
        'enabled': enabled,
        'arrival_note': arrival.text.trim(),
        'deposit_amount': int.parse(deposit.text),
        'batch_quantity': int.parse(batch.text),
        'revision': config!.revision,
      });
      await _load();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Oldindan buyurtma sozlamalari saqlandi.'),
          ),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _date() async {
    final now = DateTime.now();
    final value = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 3),
    );
    if (value != null) arrival.text = DateFormat('yyyy.MM.dd').format(value);
  }

  Future<void> _status(Map row, String status) async {
    final id = '${row['id']}';
    if (statusSaving.contains(id)) return;
    var reason = '';
    final itemCount = (row['request_items'] as List?)?.length ?? 0;
    final needsReason = status == 'cancelled' || status == 'waiting';
    final key = GlobalKey<FormState>();
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(status == 'accepted' ? 'Avans chekini tasdiqlash' : status == 'arrived' ? 'Kitob keldimi?' : status == 'waiting' ? 'Qayta ko‘rib chiqish' : 'Buyurtmani bekor qilish'),
      content: Form(key: key, child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (itemCount > 1) Text('$itemCount turdagi kitobning barchasi uchun amal bajariladi.', style: const TextStyle(fontWeight: FontWeight.w800)),
        Text(status == 'accepted' ? 'Chek va bankdagi to‘lov mosligini tekshiring. Mijozga tasdiq xabari yuboriladi.' :
          status == 'cancelled' ? 'Mijozga sabab yoziladi. Avans bu tugma orqali avtomatik qaytarilmaydi.' : 'Mijozning bildirishnomalariga yangi holat yoziladi.'),
        const SizedBox(height: 12),
        TextFormField(onChanged: (v) => reason = v, maxLength: 500, maxLines: 3,
          decoration: InputDecoration(labelText: needsReason ? 'Sababi (majburiy)' : 'Mijozga izoh (ixtiyoriy)'),
          validator: (v) => needsReason && (v ?? '').trim().length < 3 ? 'Sababini yozing' : null),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Yopish')),
        FilledButton(onPressed: () { if (key.currentState!.validate()) Navigator.pop(ctx, true); }, child: const Text('Tasdiqlash'))],
    ));
    final note = reason.trim();
    if (confirmed != true || !mounted) return;
    setState(() => statusSaving.add(id));
    try {
      final result = await api.admin(widget.secret, 'status', {
        'id': id, 'status': status, 'version': row['status_version'] ?? 1, 'note': note,
      });
      if (result is! Map || result['status'] != status) throw StateError('Holat tasdiqlanmadi. Yangilab tekshiring.');
      var refreshFailed = false;
      try {
        final updated = await api.admin(widget.secret, 'list');
        if (!mounted) return;
        setState(() { requests = Future.value(updated); hasMore = (updated as List).length == 200; });
      } catch (_) {
        refreshFailed = true;
        if (!mounted) return;
        setState(() {
          row['status'] = status; row['status_version'] = result['version'] ?? (row['status_version'] as int? ?? 1) + 1;
          row['status_note'] = note; row['notification_state'] = 'pending';
        });
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
        (result['inbox_created'] == true ? 'Holat saqlandi. Mijozning bildirishnomalariga xabar yozildi.' : 'Holat saqlandi.') +
        (refreshFailed ? ' Ro‘yxatni qayta yuklang.' : ''))));
    } catch (e) {
      if (mounted) {
        setState(() { requests = api.admin(widget.secret, 'list'); });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => statusSaving.remove(id));
    }
  }

  Future<void> _more(List<Map> loaded) async {
    if (loadingMore) return;
    setState(() => loadingMore = true);
    try {
      final next = await api.admin(widget.secret, 'list', {'offset': loaded.length, 'limit': 200}) as List;
      if (!mounted) return;
      final merged = <String, Map>{for (final row in [...loaded, ...next.whereType<Map>()]) '${row['id']}': row};
      setState(() { requests = Future.value(merged.values.toList()); hasMore = next.length == 200; });
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Keyingi so‘rovlar yuklanmadi. Qayta urining.')));
    } finally { if (mounted) setState(() => loadingMore = false); }
  }

  void _view(String url) {
    if (url.isEmpty) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: SizedBox(
          width: 700,
          height: MediaQuery.sizeOf(ctx).height * .8,
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close),
                ),
              ),
              Expanded(
                child: InteractiveViewer(
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Text(
                      'Rasmni yangilash uchun ro‘yxatni qayta yuklang.',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Oldindan buyurtma • Sozlamalar'),
      actions: [
        IconButton(
          onPressed: saving ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: config == null
            ? Center(
                child: error == null
                    ? const CircularProgressIndicator()
                    : Text(error!),
              )
            : Form(
                key: form,
                child: ListView(
                  padding: const EdgeInsets.all(18),
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Oldindan buyurtma qabul qilish'),
                      subtitle: const Text(
                        'O‘chirilsa yangi buyurtma va rasm yuklash serverda ham to‘xtaydi.',
                      ),
                      value: enabled,
                      onChanged: saving
                          ? null
                          : (v) => setState(() => enabled = v),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: arrival,
                      maxLength: 200,
                      readOnly: saving,
                      decoration: InputDecoration(
                        labelText: 'Taxminiy kelish sanasi yoki muddati',
                        hintText: 'Masalan: 5-noyabr yoki 10–14 kun',
                        suffixIcon: IconButton(
                          onPressed: saving ? null : _date,
                          icon: const Icon(Icons.calendar_month_outlined),
                        ),
                        helperText: 'Mijoz bu ma’lumotni avans to‘lashdan oldin ko‘radi.',
                      ),
                      validator: (v) => enabled && (v ?? '').trim().isEmpty
                          ? 'Qabulni ochishdan oldin sanani kiriting'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: deposit,
                      readOnly: saving,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Bir kitob uchun avans (₩)',
                        helperText:
                            'Kamida ₩5 000; summani o‘zingiz belgilang.',
                      ),
                      validator: (v) {
                        final n = int.tryParse(v ?? '') ?? 0;
                        return n < 5000 || n > 10000000
                            ? '₩5 000–₩10 000 000 oralig‘ida kiriting'
                            : null;
                      },
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final amount in [5000, 10000])
                          ActionChip(
                            label: Text(webPreorderMoney(amount)),
                            onPressed: saving
                                ? null
                                : () => deposit.text = '$amount',
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: batch,
                      readOnly: saving,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Partiyada keladigan kitoblar soni',
                        helperText: '0 bo‘lsa son mijozga ko‘rsatilmaydi.',
                      ),
                      validator: (v) {
                        final n = int.tryParse(v ?? '') ?? -1;
                        return n < 0 || n > 100000 ? 'Sonni tekshiring' : null;
                      },
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: saving ? null : _save,
                      icon: const Icon(Icons.save_outlined),
                      label: Text(
                        saving ? 'Saqlanmoqda…' : 'Sozlamalarni saqlash',
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'Oldindan buyurtmalar',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                      ),
                    ),
                    const Text(
                      'Chekni bankdagi to‘lov bilan tekshiring. Bitta so‘rovdagi barcha kitoblar birgalikda boshqariladi.',
                    ),
                    const SizedBox(height: 12),
                    TextField(onChanged: (value) => setState(() => search = value.trim().toLowerCase()),
                      decoration: const InputDecoration(labelText: 'Kitob, mijoz yoki telefon bo‘yicha qidirish', prefixIcon: Icon(Icons.search))),
                    Wrap(spacing: 6, children: [
                      for (final entry in const {'all': 'Barchasi', 'waiting': 'Tekshirish kerak', 'accepted': 'Qabul qilindi', 'arrived': 'Keldi', 'cancelled': 'Bekor qilindi'}.entries)
                        ChoiceChip(label: Text(entry.value), selected: statusFilter == entry.key,
                          onSelected: (_) => setState(() => statusFilter = entry.key)),
                    ]),
                    const SizedBox(height: 12),
                    FutureBuilder<dynamic>(
                      future: requests,
                      builder: (ctx, snap) {
                        if (snap.hasError)
                          return OutlinedButton.icon(
                            onPressed: () => setState(() { requests = api.admin(widget.secret, 'list'); hasMore = true; }),
                            icon: const Icon(Icons.refresh), label: const Text('Buyurtmalar yuklanmadi. Qayta yuklash'));
                        if (!snap.hasData)
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        final loaded = (snap.data as List).whereType<Map>().toList();
                        final rows = loaded.where((r) => (statusFilter == 'all' || r['status'] == statusFilter) &&
                          (search.isEmpty || '${r['book_title']} ${r['request_items']} ${r['customer_name']} ${r['phone']}'.toLowerCase().contains(search))).toList();
                        if (rows.isEmpty)
                          return Column(children: [
                            const AppSurface(child: Text('Bu filtr bo‘yicha so‘rov topilmadi. Boshqa filtr yoki qidiruvni tanlang.')),
                            if (hasMore && loaded.length >= 200) OutlinedButton(
                              onPressed: loadingMore ? null : () => _more(loaded), child: const Text('Yana so‘rovlarni yuklash')),
                          ]);
                        const labels = {
                          'waiting': 'Chek tekshirilmoqda',
                          'accepted': 'Qabul qilindi',
                          'arrived': 'Keldi',
                          'cancelled': 'Bekor qilindi',
                        };
                        return Column(
                          children: rows
                              .map<Widget>(
                                (r) => Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: AppSurface(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${r['book_title']} • ${r['quantity']} dona',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        if ((r['request_items'] as List?)?.isNotEmpty == true)
                                          SizedBox(height: ((r['request_items'] as List).length * 88.0).clamp(88.0, 352.0).toDouble(),
                                            child: ListView.builder(primary: false,
                                              itemCount: (r['request_items'] as List).length,
                                              itemBuilder: (_, index) {
                                                final item = (r['request_items'] as List)[index];
                                                return Material(type: MaterialType.transparency, child: ListTile(contentPadding: EdgeInsets.zero,
                                                  leading: SizedBox(width: 48, height: 64, child: Image.network('${item['book_image_url'] ?? ''}', fit: BoxFit.contain,
                                                    errorBuilder: (_, __, ___) => const Icon(Icons.menu_book_outlined))),
                                                  title: Text('${item['book_title']}'), subtitle: Text('${item['quantity']} dona'),
                                                  trailing: const Icon(Icons.zoom_in),
                                                  onTap: () => _view('${item['book_image_url'] ?? ''}')));
                                              })),
                                        SelectableText(
                                          '${r['customer_name']}\n${r['phone']}',
                                        ),
                                        Text('Yuborilgan: ${webPreorderTime(r['created_at'])}'),
                                        Text(
                                          'Avans: ${webPreorderMoney((r['deposit_amount'] as num).toInt())}',
                                        ),
                                        Text(
                                          'Kelish muddati: ${r['arrival_note']}',
                                        ),
                                        Text(
                                          'Holat: ${labels[r['status']] ?? r['status']}',
                                        ),
                                        Text(
                                          'Buyurtma: ${r['id'].toString().substring(0, 8)}',
                                        ),
                                        if ((r['status_note'] ?? '').toString().isNotEmpty) Text('Izoh: ${r['status_note']}'),
                                        Text(r['notification_state'] == null ? 'Holat yangilanganda mijozga xabar beriladi.' :
                                          r['notification_state'] == 'sent' ? 'Mijoz xabari: ilovaga yozildi, web push yuborildi.' :
                                          r['notification_state'] == 'failed' ? 'Mijoz xabari: ilovaga yozildi. Push yetkazilmadi.' :
                                          r['notification_state'] == 'no_subscribers' ? 'Mijoz xabari: ilovaga yozildi. Push ruxsati yo‘q.' :
                                          'Mijoz xabari: ilovaga yozildi, push navbatda.'),
                                        if ((r['history'] as List?)?.isNotEmpty == true)
                                          ExpansionTile(title: const Text('Holat tarixi'), children: [
                                            for (final h in r['history'] as List)
                                              Material(type: MaterialType.transparency, child: ListTile(title: Text('${labels[h['status']] ?? h['status']}'),
                                                subtitle: Text('${h['message']}\n${webPreorderTime(h['created_at'])}'))),
                                          ]),

                                        Wrap(
                                          spacing: 8,
                                          children: [
                                            OutlinedButton.icon(
                                              onPressed: () => _view(
                                                '${r['book_image_url'] ?? ''}',
                                              ),
                                              icon: const Icon(
                                                Icons.menu_book_outlined,
                                              ),
                                              label: const Text('Kitob rasmi'),
                                            ),
                                            OutlinedButton.icon(
                                              onPressed: () => _view(
                                                '${r['payment_proof_url'] ?? ''}',
                                              ),
                                              icon: const Icon(
                                                Icons.receipt_outlined,
                                              ),
                                              label: const Text('Avans cheki'),
                                            ),
                                            for (final action in <String>[
                                              if (r['status'] == 'waiting') 'accepted',
                                              if (r['status'] == 'accepted') 'arrived',
                                              if (r['status'] != 'cancelled') 'cancelled',
                                              if (r['status'] == 'cancelled') 'waiting',
                                            ])
                                              OutlinedButton(
                                                onPressed: statusSaving.contains('${r['id']}') ? null : () => _status(r, action),
                                                child: Text(action == 'accepted' ? 'Qabul qilish' : action == 'arrived' ? ((r['request_items'] as List?)?.length != null && (r['request_items'] as List).length > 1 ? 'Barcha kitoblar keldi' : 'Kitob keldi') : action == 'waiting' ? 'Qayta ochish' : 'Bekor qilish'),
                                              ),
                                            if (statusSaving.contains('${r['id']}')) const Padding(
                                              padding: EdgeInsets.all(10), child: Text('Saqlanmoqda…')),

                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                              .toList()..addAll([
                                if (hasMore && loaded.length >= 200) OutlinedButton.icon(
                                  onPressed: loadingMore ? null : () => _more(loaded), icon: const Icon(Icons.expand_more),
                                  label: Text(loadingMore ? 'Yuklanmoqda…' : 'Yana so‘rovlarni yuklash')),
                              ]),
                        );
                      },
                    ),
                  ],
                ),
              ),
      ),
    ),
  );
}
