part of 'web_preorders.dart';

class _RequestedBook {
  final title = TextEditingController();
  Uint8List? image;
  String? path;
  int quantity = 1;
}

/// A single receipt covers every named book in this web request.
class WebMultiPreorderPage extends StatefulWidget {
  const WebMultiPreorderPage({super.key, this.api, this.pickImage});
  final WebPreorderApi? api;
  final Future<Uint8List?> Function()? pickImage;
  @override
  State<WebMultiPreorderPage> createState() => _WebMultiPreorderPageState();
}

class _WebMultiPreorderPageState extends State<WebMultiPreorderPage> {
  late final api = widget.api ?? WebPreorderApi();
  final form = GlobalKey<FormState>();
  final name = TextEditingController(), phone = TextEditingController();
  final books = <_RequestedBook>[_RequestedBook()];
  late final String id;
  WebPreorderConfig? config;
  Uint8List? proof;
  String? proofPath, error;
  bool loading = true, saving = false, payment = false, picking = false, completed = false;
  int get quantity => books.fold(0, (sum, b) => sum + b.quantity);
  int get total => (config?.deposit ?? 0) * quantity;

  @override
  void initState() {
    super.initState();
    final bytes = List.generate(16, (_) => Random.secure().nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
    id = '${hex.substring(0,8)}-${hex.substring(8,12)}-${hex.substring(12,16)}-${hex.substring(16,20)}-${hex.substring(20)}';
    final saved = context.read<AppState>().savedCustomer;
    name.text = saved['name'] ?? '';
    phone.text = saved['phone'] ?? '';
    _reload();
  }

  @override
  void dispose() {
    name.dispose(); phone.dispose();
    for (final b in books) { b.title.dispose(); }
    super.dispose();
  }

  void message(String value) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> _reload() async {
    try {
      final next = await api.config();
      if (!mounted) return;
      setState(() { config = next; loading = false; error = null; });
    } catch (_) {
      if (mounted) setState(() { loading = false; error = 'Shartlarni yuklab bo‘lmadi. Qayta urining.'; });
    }
  }

  Future<bool> currentTerms() async {
    final old = config;
    try {
      final next = await api.config();
      if (!mounted) return false;
      if (!next.accepting || old?.revision != next.revision || old?.deposit != next.deposit || old?.arrival != next.arrival) {
        setState(() { config = next; payment = false; });
        message('Qabul shartlari o‘zgardi. Sana va avansni qayta tekshiring.');
        return false;
      }
      return true;
    } catch (_) { message('Shartlarni tekshirib bo‘lmadi. Qayta urining.'); return false; }
  }

  Future<void> pick([_RequestedBook? book]) async {
    if (picking || saving) return;
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
      if (bytes.length > 8 * 1024 * 1024) { message('8 MB dan kichikroq rasm tanlang.'); return; }
      var decoded = img.decodeImage(bytes);
      if (decoded == null) { message('JPG, PNG yoki WebP rasm tanlang.'); return; }
      decoded = img.bakeOrientation(decoded);
      if (decoded.width > 1200 || decoded.height > 1600) {
        decoded = img.copyResize(decoded, width: 1200, height: 1600, maintainAspect: true);
      }
      final encoded = Uint8List.fromList(img.encodeJpg(decoded, quality: 80));
      if (encoded.length > 2097152) { message('Rasmni kichraytirib qayta tanlang (2 MB).'); return; }
      setState(() {
        if (book == null) { proof = encoded; proofPath = null; }
        else { book.image = encoded; book.path = null; }
      });
    } catch (_) { message('Rasm tanlanmadi. Qayta urining.'); }
    finally { if (mounted) setState(() => picking = false); }
  }

  bool validateDetails() {
    // ListView disposes fields outside the viewport. Validate every controller,
    // including names above the scroll position, before showing bank details.
    final invalid = books.indexWhere((b) => b.title.text.trim().length < 2);
    if (invalid >= 0) { message('${invalid + 1}-kitob nomini kiriting.'); return false; }
    if (name.text.trim().length < 2) { message('Ismingizni kiriting.'); return false; }
    if (!RegExp(r'^010\d{8}$').hasMatch(phone.text)) { message('Telefon raqamini tekshiring.'); return false; }
    return form.currentState!.validate();
  }

  Future<void> next() async {
    if (saving || picking || completed || !validateDetails()) return;
    final missing = books.indexWhere((b) => b.image == null);
    if (missing >= 0) { message('${missing + 1}-kitob rasmini tanlang.'); return; }
    setState(() => saving = true);
    try { if (await currentTerms() && mounted) setState(() => payment = true); }
    finally { if (mounted) setState(() => saving = false); }
  }

  Future<void> submit() async {
    if (saving || picking || completed || !validateDetails()) return;
    if (proof == null) { message('Jami avans uchun to‘lov chekini yuklang.'); return; }
    setState(() => saving = true);
    try {
      if (!await currentTerms()) return;
      final c = config!;
      for (final book in books) {
        book.path ??= await api.upload(id, 'book', book.image!, c.revision);
      }
      proofPath ??= await api.upload(id, 'proof', proof!, c.revision);
      await api.call('submit_multi', {'p_request': {
        'id': id, 'customer_name': name.text.trim(), 'phone': phone.text.trim(),
        'revision': c.revision, 'deposit_amount': total, 'payment_proof_path': proofPath,
        'items': [for (final b in books) {'book_title': b.title.text.trim(), 'book_image_path': b.path, 'quantity': b.quantity}],
      }});
      if (!mounted) return;
      setState(() { completed = true; saving = false; });
      // The server has committed the order; failure to refresh local identity
      // must never offer another payment or silently lose this success.
      final state = context.read<AppState>();
      try {
        await state.setAuthenticatedCustomer(name.text.trim(), phone.text.trim(),
          verified: state.customerVerified && state.savedCustomerPhone == phone.text.trim());
        unawaited(syncPushIdentity(phone.text.trim()));
        unawaited(state.refreshCustomerPushMessages());
      } catch (_) { /* The durable server inbox still contains the receipt. */ }
      if (!mounted) return;
      await showDialog<void>(context: context, barrierDismissible: false, builder: (ctx) => AlertDialog(
        title: const Text('Oldindan buyurtma yuborildi'),
        content: Text('${books.length} turdagi kitob • $quantity dona\nJami avans: ${webPreorderMoney(total)}\nTaxminiy kelishi: ${c.arrival}\nBuyurtma: ${id.substring(0,8)}\n\nAdministrator chekni tekshiradi. Qabul qilish, bekor qilish va kitoblar kelishi haqida Bildirishnomalar bo‘limiga xabar keladi.'),
        actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tushunarli'))],
      ));
      if (mounted) Navigator.pop(context);
    } catch (e) { message(e.toString().replaceFirst('Bad state: ', '')); }
    finally { if (mounted) setState(() => saving = false); }
  }

  Widget bookCard(_RequestedBook book, int index) => AppSurface(
    key: ObjectKey(book),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [Expanded(child: Text('${index + 1}-kitob', style: const TextStyle(fontWeight: FontWeight.w900))),
        if (books.length > 1 && !payment) IconButton(tooltip: 'Kitobni olib tashlash',
          onPressed: saving || picking ? null : () {
            setState(() => books.remove(book));
            WidgetsBinding.instance.addPostFrameCallback((_) => book.title.dispose());
          }, icon: const Icon(Icons.delete_outline))]),
      TextFormField(controller: book.title, readOnly: payment || saving,
        maxLength: 160, decoration: InputDecoration(labelText: '${index + 1}-kitob nomi'),
        validator: (v) => (v ?? '').trim().length < 2 ? 'Kitob nomini kiriting' : null),
      if (book.image != null) SizedBox(height: 140, child: Image.memory(book.image!, fit: BoxFit.contain)),
      if (!payment) OutlinedButton.icon(onPressed: saving || picking ? null : () => pick(book),
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: Text(book.image == null ? 'Kitob rasmini yuklash' : 'Rasmni almashtirish')),
      Row(children: [const Expanded(child: Text('Dona')),
        IconButton(onPressed: payment || saving || book.quantity == 1 ? null : () => setState(() => book.quantity--), icon: const Icon(Icons.remove_circle_outline)),
        Text('${book.quantity}', style: const TextStyle(fontWeight: FontWeight.w900)),
        IconButton(onPressed: payment || saving || book.quantity >= 20 ? null : () => setState(() => book.quantity++), icon: const Icon(Icons.add_circle_outline))]),
      Text('Avans: ${webPreorderMoney((config?.deposit ?? 0) * book.quantity)}'),
    ]),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Oldindan buyurtma')),
    body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 680),
      child: loading ? const Center(child: CircularProgressIndicator()) : Form(key: form,
        child: ListView(padding: const EdgeInsets.all(18), children: [
          AppSurface(backgroundColor: const Color(0xFFE5F3ED), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Taxminiy kelish sanasi', style: TextStyle(fontWeight: FontWeight.w800)),
            Text(config?.arrival.isNotEmpty == true ? config!.arrival : 'Hali belgilanmagan', style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
            const Text('Sana taxminiy. Kitoblarni shu muddatga qarab buyurtma qiling.'),
          ])),
          const SizedBox(height: 14),
          if (error != null || config?.accepting != true) ...[
            Text(error ?? 'Oldindan buyurtma qabuli hozircha yopiq. Avans yubormang.'),
            OutlinedButton.icon(onPressed: _reload, icon: const Icon(Icons.refresh), label: const Text('Yangilash')),
          ] else ...[
            Text('Avans: ${webPreorderMoney(config!.deposit)} / dona', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const Text('Har bir kitobning nomi va rasmini alohida kiriting. Yana kitob qo‘shishingiz mumkin. Avans yakuniy summadan ayriladi.'),
            const SizedBox(height: 12),
            for (var i = 0; i < books.length; i++) Padding(padding: const EdgeInsets.only(bottom: 12), child: bookCard(books[i], i)),
            if (!payment) OutlinedButton.icon(onPressed: saving || picking ? null : () => setState(() => books.add(_RequestedBook())),
              icon: const Icon(Icons.add), label: const Text('Yana kitob qo‘shish')),
            TextFormField(controller: name, readOnly: payment || saving, maxLength: 80,
              decoration: const InputDecoration(labelText: 'Ismingiz'), validator: (v) => (v ?? '').trim().length < 2 ? 'Ismingizni kiriting' : null),
            TextFormField(controller: phone, readOnly: payment || saving, keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(11)],
              decoration: const InputDecoration(labelText: 'Telefon raqam', hintText: '01012345678'),
              validator: (v) => RegExp(r'^010\d{8}$').hasMatch(v ?? '') ? null : '010 bilan boshlanuvchi 11 ta raqam kiriting'),
            Text('${books.length} turdagi kitob • $quantity dona'),
            Text('Jami avans: ${webPreorderMoney(total)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const Text('Pochtaga +4 000 won qo‘shiladi. Hozir faqat avansni o‘tkazing.', style: TextStyle(fontSize: 12, color: AppColors.muted)),
            const SizedBox(height: 16),
            if (!payment) FilledButton(onPressed: saving || picking ? null : next,
              child: Text(saving ? 'Tekshirilmoqda…' : 'Shartlarni ko‘rdim — to‘lovga o‘tish'))
            else ...[
              AppSurface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Bank o‘tkazmasi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const Text('${AppState.bankName}\n${AppState.bankOwner}'),
                Row(children: [const Expanded(child: SelectableText(AppState.bankAccount)),
                  IconButton(tooltip: 'Hisob raqamini nusxalash', onPressed: () async {
                    await Clipboard.setData(const ClipboardData(text: AppState.bankAccount)); message('Hisob raqami nusxalandi');
                  }, icon: const Icon(Icons.copy))]),
                Text('O‘tkaziladigan summa: ${webPreorderMoney(total)}', style: const TextStyle(fontWeight: FontWeight.w900)),
              ])),
              if (proof != null) SizedBox(height: 150, child: Image.memory(proof!, fit: BoxFit.contain)),
              OutlinedButton.icon(onPressed: saving || picking ? null : () => pick(), icon: const Icon(Icons.receipt_long_outlined),
                label: Text(proof == null ? 'Avans chekini yuklash' : 'Chekni almashtirish')),
              FilledButton(onPressed: saving || picking || completed ? null : submit,
                child: Text(saving ? 'Yuborilmoqda…' : 'Avans yubordim — buyurtma berish')),
              TextButton(onPressed: saving ? null : () => setState(() => payment = false), child: const Text('Ma’lumotlarni tahrirlash')),
            ],
            if (saving || picking) const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator()),
          ],
        ]),
      ),
    )),
  );
}
