part of 'admin_ui.dart';

/// A supplier order is deliberately separate from customer orders, holds,
/// deposits and inventory. Editing this object can never mutate a preorder.
class _SupplierLine {
  _SupplierLine({
    required this.key, required this.sourceRef, required this.title,
    required this.publisher, required this.imageUrl, required this.requested,
    required this.quantity, this.selected = true,
  });
  final String key;
  final String sourceRef;
  String title;
  String publisher;
  String imageUrl;
  int requested;
  int quantity;
  bool selected;

  Map<String, dynamic> toJson() => {
    'item_key': key, 'source_ref': sourceRef, 'title': title,
    'publisher': publisher, 'image_url': imageUrl,
    'requested': requested, 'quantity': quantity, 'selected': selected,
  };

  factory _SupplierLine.fromJson(Map<String, dynamic> row) => _SupplierLine(
    key: (row['item_key'] ?? '').toString(),
    sourceRef: (row['source_ref'] ?? '').toString(),
    title: (row['title'] ?? 'Kitob').toString(),
    publisher: (row['publisher'] ?? '').toString(),
    imageUrl: (row['image_url'] ?? '').toString(),
    requested: (row['requested'] as num?)?.toInt() ?? 0,
    quantity: (row['quantity'] as num?)?.toInt() ?? 0,
    selected: row['selected'] != false,
  );
}

@visibleForTesting
List<Map<String, dynamic>> supplierSourceRows(
  List<Map<String, dynamic>> orders,
) {
  final grouped = <String, Map<String, dynamic>>{};
  for (final order in orders) {
    if ('${order['status'] ?? ''}' == 'cancelled') continue;
    final web = order['_origin'] == 'web';
    final items = web && order['request_items'] is List &&
            (order['request_items'] as List).isNotEmpty
        ? (order['request_items'] as List)
        : <dynamic>[order];
    for (var i = 0; i < items.length; i++) {
      if (items[i] is! Map) continue;
      final x = Map<String, dynamic>.from(items[i] as Map);
      final name = (web
          ? (x['book_title'] ?? order['book_title'])
          : order['title'])?.toString().trim() ?? '';
      if (name.isEmpty) continue;
      final publisher = (x['_publisher'] ?? order['_publisher'] ?? '')
          .toString().trim();
      final bookId = (x['book_id'] ?? order['book_id'] ?? '').toString();
      // Publisher keeps editions separate even with identical short titles.
      final key = bookId.isNotEmpty
          ? 'catalog:$bookId'
          : 'title:${name.toLowerCase()}|${publisher.toLowerCase()}';
      final qty = (x['quantity'] as num?)?.toInt() ??
          (order['quantity'] as num?)?.toInt() ?? 1;
      final cover = (x['book_image_url'] ??
          order['_cover_image_url'] ?? '').toString();
      final sourceRef = '${web ? 'web' : 'native'}:${order['id']}:$i';
      final existing = grouped[key];
      if (existing == null) {
        grouped[key] = {
          'item_key': key, 'source_ref': sourceRef, 'title': name,
          'publisher': publisher, 'image_url': cover,
          'requested': qty < 0 ? 0 : qty,
          'quantity': qty < 0 ? 0 : qty, 'selected': true,
        };
      } else {
        final extra = qty < 0 ? 0 : qty;
        existing['requested'] = (existing['requested'] as int) + extra;
        existing['quantity'] = (existing['quantity'] as int) + extra;
        if ((existing['image_url'] as String).isEmpty && cover.isNotEmpty) {
          existing['image_url'] = cover;
        }
      }
    }
  }
  return grouped.values.toList()
    ..sort((a, b) => (a['title'] as String).compareTo(b['title'] as String));
}

class _PreorderSupplierPage extends StatefulWidget {
  const _PreorderSupplierPage({required this.api, required this.orders});
  final _AdminApi api;
  final List<Map<String, dynamic>> orders;
  @override
  State<_PreorderSupplierPage> createState() => _PreorderSupplierPageState();
}

class _PreorderSupplierPageState extends State<_PreorderSupplierPage> {
  late List<_SupplierLine> lines;
  final nameController = TextEditingController();
  final searchController = TextEditingController();
  List<Map<String, dynamic>> drafts = [];
  String? draftId;
  bool loading = true;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    lines = supplierSourceRows(widget.orders)
        .map((row) => _SupplierLine.fromJson(row)).toList();
    nameController.text = 'O‘zbekistonga kitob buyurtmasi';
    _loadDrafts();
  }

  @override
  void dispose() {
    nameController.dispose();
    searchController.dispose();
    super.dispose();
  }

  Future<dynamic> _rpc(String action, [Map<String, dynamic> payload = const {}]) =>
      widget.api._rpc('admin_preorder_supplier', params: {
        'p_secret': widget.api.secret,
        'p_action': action, 'p_payload': payload,
      });

  Future<void> _loadDrafts() async {
    try {
      final result = Map<String, dynamic>.from(await _rpc('list') as Map);
      if (!mounted) return;
      setState(() {
        drafts = (result['drafts'] as List? ?? [])
            .whereType<Map>().map((x) => Map<String, dynamic>.from(x)).toList();
        loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
        _message('Ro‘yxatlar yuklanmadi: $e');
      }
    }
  }

  void _message(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  void _newDraft() {
    setState(() {
      draftId = null;
      nameController.text = 'O‘zbekistonga kitob buyurtmasi';
      lines = supplierSourceRows(widget.orders)
          .map((row) => _SupplierLine.fromJson(row)).toList();
    });
  }

  void _openDraft(Map<String, dynamic> draft) {
    final fresh = {
      for (final row in supplierSourceRows(widget.orders))
        (row['source_ref'] ?? '').toString(): (row['image_url'] ?? '').toString()
    };
    final restored = <_SupplierLine>[];
    for (final raw in draft['lines'] as List? ?? const []) {
      if (raw is! Map) continue;
      final line = _SupplierLine.fromJson(Map<String, dynamic>.from(raw));
      // A private signed cover URL may have expired since the draft was
      // saved. Replace it with a newly resolved URL for this session.
      if ((fresh[line.sourceRef] ?? '').startsWith('https://')) {
        line.imageUrl = fresh[line.sourceRef]!;
      }
      restored.add(line);
    }
    setState(() {
      draftId = (draft['id'] ?? '').toString();
      nameController.text = (draft['name'] ?? '').toString();
      lines = restored;
    });
  }

  Future<bool> _confirm(String title, String body, String label) async {
    return await showDialog<bool>(context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Bekor qilish')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
            child: Text(label)),
        ],
      )) ?? false;
  }

  Future<void> _save() async {
    if (busy) return;
    final title = nameController.text.trim();
    if (title.isEmpty) { _message('Ro‘yxat nomini kiriting.'); return; }
    setState(() => busy = true);
    try {
      final result = Map<String, dynamic>.from(await _rpc('save_draft', {
        if (draftId != null) 'id': draftId,
        'name': title, 'lines': lines.map((x) => x.toJson()).toList(),
      }) as Map);
      if (!mounted) return;
      setState(() => draftId = (result['id'] ?? '').toString());
      await _loadDrafts();
      _message('Ro‘yxat xavfsiz saqlandi. Mijoz zakaslari o‘zgarmadi.');
    } catch (e) { _message('Saqlashda xato: $e'); }
    finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> _deleteDraft() async {
    if (draftId == null || busy) return;
    if (!await _confirm('Saqlangan ro‘yxatni o‘chirish',
      'Faqat ushbu ta’minot ro‘yxati o‘chiriladi. '
      'Mijoz buyurtmalari, avanslar va ombor o‘zgarmaydi.',
      'Ro‘yxatni o‘chirish')) return;
    setState(() => busy = true);
    try {
      await _rpc('delete_draft', {'id': draftId});
      if (!mounted) return;
      _newDraft();
      await _loadDrafts();
      _message('Faqat ta’minot ro‘yxati o‘chirildi.');
    } catch (e) { _message('O‘chirilmadi: $e'); }
    finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> _clearLines() async {
    if (!await _confirm('Barcha tanlanganlarni tozalash',
      'Shu ro‘yxatdagi kitob qatorlari tozalanadi. '
      'Mijozlarning asl zakazlari o‘chirilmaydi. '
      'Saqlashni bossangiz ushbu bo‘sh ro‘yxat saqlanadi.',
      'Tozalash')) return;
    if (mounted) setState(() => lines.clear());
  }

  Future<void> _editLine(_SupplierLine line) async {
    final title = TextEditingController(text: line.title);
    final publisher = TextEditingController(text: line.publisher);
    final result = await showDialog<bool>(
      context: context, builder: (ctx) => AlertDialog(
        title: const Text('Jo‘natma kitobini tahrirlash'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: title, maxLength: 240,
            decoration: const InputDecoration(labelText: 'Kitob nomi')),
          TextField(controller: publisher, maxLength: 160,
            decoration: const InputDecoration(labelText: 'Nashriyot')),
          const Text('Bu faqat ta’minot ro‘yxatini o‘zgartiradi. '
            'Asl oldindan zakaz nomini alohida tahrirlash mumkin.',
            style: TextStyle(fontSize: 12)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Bekor')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Saqlash')),
        ],
      ));
    if (mounted && result == true && title.text.trim().isNotEmpty) {
      setState(() {
        line.title = title.text.trim();
        line.publisher = publisher.text.trim();
      });
    }
    title.dispose();
    publisher.dispose();
  }

  Future<void> _addLine() async {
    final title = TextEditingController();
    final publisher = TextEditingController();
    final quantity = TextEditingController(text: '1');
    final result = await showDialog<bool>(context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Qo‘shimcha kitob qo‘shish'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: title, decoration:
            const InputDecoration(labelText: 'Kitob nomi')),
          TextField(controller: publisher, decoration:
            const InputDecoration(labelText: 'Nashriyot')),
          TextField(controller: quantity, keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Olinadigan miqdor')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Bekor')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Qo‘shish')),
        ],
      ));
    final count = int.tryParse(quantity.text) ?? 0;
    if (mounted && result == true) {
      if (title.text.trim().isEmpty || count < 1 || count > 10000) {
        _message('Kitob nomi va to‘g‘ri miqdorni kiriting.');
      } else {
        setState(() => lines.add(_SupplierLine(
          key: 'manual:${DateTime.now().microsecondsSinceEpoch}',
          sourceRef: '', title: title.text.trim(),
          publisher: publisher.text.trim(), imageUrl: '',
          requested: 0, quantity: count,
        )));
      }
    }
    title.dispose(); publisher.dispose(); quantity.dispose();
  }

  List<_SupplierLine> get selected =>
      lines.where((line) => line.selected && line.quantity > 0).toList();

  int get total => selected.fold(0, (a, b) => a + b.quantity);

  String _textExport() {
    final out = StringBuffer('MUHAJEER BOOKS | O‘ZBEKISTONGA BUYURTMA\n');
    out.writeln(nameController.text.trim());
    out.writeln('------------------------------------------------');
    for (var i = 0; i < selected.length; i++) {
      final line = selected[i];
      out.writeln('${i + 1}. ${line.title} — ${line.quantity} dona');
      if (line.publisher.isNotEmpty) {
        out.writeln('   Nashriyot: ${line.publisher}');
      }
    }
    out.writeln('------------------------------------------------');
    out.writeln('JAMI: $total dona, ${selected.length} nom.');
    return out.toString();
  }

  Future<void> _shareData(List<int> bytes, String type, String suffix) async {
    final id = DateTime.now().millisecondsSinceEpoch;
    await SharePlus.instance.share(ShareParams(
      files: [XFile.fromData(Uint8List.fromList(bytes), mimeType: type)],
      fileNameOverrides: ['Muhajeer_kitoblar_$id.$suffix'],
      title: nameController.text.trim(),
    ));
  }

  Future<void> _export(String format) async {
    if (busy) return;
    if (selected.isEmpty) {
      _message('Avval kamida bitta kitob tanlang va miqdorini belgilang.');
      return;
    }
    setState(() => busy = true);
    try {
      if (format == 'text') {
        await SharePlus.instance.share(ShareParams(text: _textExport()));
      } else if (format == 'copy') {
        await Clipboard.setData(ClipboardData(text: _textExport()));
        _message('Kitoblar ro‘yxati nusxalandi.');
      } else if (format == 'xlsx') {
        final excel = xl.Excel.createExcel();
        final sheet = excel['Kitoblar'];
        sheet.appendRow([
          xl.TextCellValue('№'), xl.TextCellValue('Kitob'),
          xl.TextCellValue('Nashriyot'), xl.TextCellValue('Mijoz zakazi'),
          xl.TextCellValue('Do‘kondan olinadi'),
        ]);
        for (var i = 0; i < selected.length; i++) {
          final item = selected[i];
          sheet.appendRow([
            xl.IntCellValue(i + 1), xl.TextCellValue(item.title),
            xl.TextCellValue(item.publisher), xl.IntCellValue(item.requested),
            xl.IntCellValue(item.quantity),
          ]);
        }
        sheet.appendRow([
          xl.TextCellValue('JAMI'), xl.TextCellValue(''),
          xl.TextCellValue(''),
          xl.IntCellValue(selected.fold(0, (a,b)=>a+b.requested)),
          xl.IntCellValue(total),
        ]);
        excel.delete('Sheet1');
        final output = excel.encode();
        if (output == null) throw StateError('Excel tayyorlanmadi');
        await _shareData(output,
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          'xlsx');
      } else {
        final pages = await _renderPages();
        if (format == 'pdf') {
          final pdf = pw.Document(compress: true);
          for (final png in pages) {
            pdf.addPage(pw.Page(pageFormat: PdfPageFormat.a4,
              margin: pw.EdgeInsets.zero,
              build: (_) => pw.Center(child: pw.Image(
                pw.MemoryImage(png),fit:pw.BoxFit.contain)),
            ));
          }
          await _shareData(await pdf.save(), 'application/pdf', 'pdf');
        } else {
          final jpg = format == 'jpg';
          final files = <XFile>[];
          final names = <String>[];
          final id = DateTime.now().millisecondsSinceEpoch;
          for (var i = 0; i < pages.length; i++) {
            final encoded = jpg
                ? img.encodeJpg(img.decodePng(pages[i])!, quality: 90)
                : pages[i];
            files.add(XFile.fromData(Uint8List.fromList(encoded),
              mimeType:jpg?'image/jpeg':'image/png'));
            names.add('Muhajeer_kitoblar_${id}_${i + 1}.${jpg?'jpg':'png'}');
          }
          await SharePlus.instance.share(ShareParams(
            files: files, fileNameOverrides: names,
            title: nameController.text.trim(),
          ));
        }
      }
    } catch (e) {
      _message('Faylni tayyorlashda xato: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _drawText(Canvas canvas, String text, Offset point,
      double width, {double size=25, FontWeight weight=FontWeight.w500,
      Color color=const Color(0xFF1D3937), int lines=2}) {
    final painter = TextPainter(
      text: TextSpan(text:text, style:TextStyle(
        fontSize:size, fontWeight:weight, color:color)),
      textDirection: ui.TextDirection.ltr,
      maxLines:lines, ellipsis:'…',
    )..layout(maxWidth:width);
    painter.paint(canvas, point);
  }

  Future<ui.Image?> _cover(String url) async {
    if (!url.startsWith('https://')) return null;
    try {
      final response = await http.get(Uri.parse(url))
        .timeout(const Duration(seconds: 7));
      if (response.statusCode != 200 ||
          response.bodyBytes.lengthInBytes > 4000000) return null;
      final codec = await ui.instantiateImageCodec(response.bodyBytes);
      final frame = await codec.getNextFrame();
      codec.dispose();
      return frame.image;
    } catch (_) { return null; }
  }

  /// A4-friendly 1000x1400 pages; covers and Uzbek text rendered by Flutter
  /// itself, avoiding missing PDF font glyphs. Seven books per page prevents
  /// iOS canvas texture-size overflows for even very long supplier lists.
  Future<List<Uint8List>> _renderPages() async {
    final chosen = selected;
    final pages = <Uint8List>[];
    const width=1000.0;
    const height=1400.0;
    final count = (chosen.length / 7).ceil();
    for (var page=0; page<count; page++) {
      final slice = chosen.skip(page*7).take(7).toList();
      final recorder=ui.PictureRecorder();
      final canvas=Canvas(recorder);
      canvas.drawRect(const Rect.fromLTWH(0,0,width,height),
        Paint()..color=const Color(0xFFF8F6EF));
      canvas.drawRect(const Rect.fromLTWH(0,0,width,145),
        Paint()..color=const Color(0xFF075F5A));
      _drawText(canvas,'MUHAJEER BOOKS',const Offset(44,24),900,
        size:40,weight:FontWeight.w900,color:Colors.white);
      _drawText(canvas,nameController.text.trim(),const Offset(44,81),900,
        size:24,color:Colors.white);
      final totalRequested = chosen.fold<int>(0,(a,b)=>a+b.requested);
      _drawText(canvas,
        '${chosen.length} nom  •  Jami $total dona  •  Mijoz zakazi $totalRequested dona',
        const Offset(44,167),930,size:24,weight:FontWeight.w700);
      var y=215.0;
      for (var i=0; i<slice.length; i++) {
        final line=slice[i];
        canvas.drawRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(35,y,930,146),const Radius.circular(14)),
          Paint()..color=Colors.white);
        final cover=await _cover(line.imageUrl);
        if (cover!=null) {
          canvas.drawImageRect(cover,
            Rect.fromLTWH(0,0,cover.width.toDouble(),cover.height.toDouble()),
            Rect.fromLTWH(48,y+9,96,126),Paint()..filterQuality=FilterQuality.high);
          cover.dispose();
        } else {
          canvas.drawRect(Rect.fromLTWH(48,y+9,96,126),
            Paint()..color=const Color(0xFFE7F0ED));
          _drawText(canvas,'KITOB',Offset(56,y+61),83,size:18);
        }
        _drawText(canvas,'${page*7+i+1}. ${line.title}',
          Offset(165,y+14),630,size:27,weight:FontWeight.w800);
        _drawText(canvas,
          line.publisher.isEmpty?'Nashriyot ko‘rsatilmagan':line.publisher,
          Offset(165,y+79),630,size:20,color:const Color(0xFF72817C));
        _drawText(canvas,'${line.quantity} dona',
          Offset(816,y+54),133,size:22,weight:FontWeight.w900,
          color:const Color(0xFF075F5A),lines:1);
        y+=155;
      }
      canvas.drawRect(const Rect.fromLTWH(0,1345,1000,55),
        Paint()..color=const Color(0xFFE6ECE8));
      _drawText(canvas,'Faqat do‘konga buyurtma ro‘yxati • Mijoz ma’lumotlari yo‘q',
        const Offset(38,1354),830,size:19);
      _drawText(canvas,'${page+1}/$count',const Offset(920,1354),64,size:18);
      final picture=recorder.endRecording();
      final bitmap=await picture.toImage(width.toInt(),height.toInt());
      picture.dispose();
      final byteData=await bitmap.toByteData(format:ui.ImageByteFormat.png);
      bitmap.dispose();
      if (byteData == null) throw StateError('Rasm yaratilmadi');
      pages.add(byteData.buffer.asUint8List());
    }
    return pages;
  }

  @override
  Widget build(BuildContext context) {
    final query=searchController.text.toLowerCase().trim();
    final visible=lines.where((l) => l.title.toLowerCase().contains(query) ||
      l.publisher.toLowerCase().contains(query)).toList();
    return Scaffold(
      appBar:AppBar(title:const Text('O‘zbekistonga zakaz ro‘yxati'),
        actions:[IconButton(tooltip:'Yangi ro‘yxat',
          onPressed:busy?null:_newDraft,icon:const Icon(Icons.note_add_outlined))]),
      body:loading ? const Center(child:CircularProgressIndicator()) :
      Column(children:[
        Expanded(child:ListView(padding:const EdgeInsets.all(14),children:[
          TextField(controller:nameController, maxLength:160,
            decoration:const InputDecoration(
              labelText:'Jo‘natma ro‘yxati nomi',prefixIcon:Icon(Icons.edit_note))),
          ExpansionTile(title:Text('Saqlangan ro‘yxatlar (${drafts.length})'),
            subtitle:const Text('Qayta ochish, tahrirlash va eksport qilish'),
            children:[
              for(final draft in drafts)
                ListTile(
                  title:Text((draft['name']??'Ro‘yxat').toString()),
                  subtitle:Text((draft['updated_at']??'').toString()),
                  selected:draftId==draft['id'],
                  trailing:const Icon(Icons.chevron_right),
                  onTap:busy?null:()=>_openDraft(draft),
                ),
            ],
          ),
          const SizedBox(height:8),
          Wrap(spacing:6,runSpacing:6,children:[
            FilledButton.tonalIcon(onPressed:busy?null:()=>setState(() {
              for(final l in lines){l.selected=true;}
            }),icon:const Icon(Icons.check_box_outlined),
              label:const Text('Barchasini tanlash')),
            OutlinedButton.icon(onPressed:busy?null:()=>setState(() {
              for(final l in lines){l.selected=false;}
            }),icon:const Icon(Icons.deselect),
              label:const Text('Tanlovni olib tashlash')),
            OutlinedButton.icon(onPressed:busy?null:_addLine,
              icon:const Icon(Icons.add),label:const Text('Kitob qo‘shish')),
          ]),
          const SizedBox(height:10),
          TextField(controller:searchController,
            onChanged:(_)=>setState(() {}),
            decoration:const InputDecoration(prefixIcon:Icon(Icons.search),
              labelText:'Kitob qidirish')),
          const SizedBox(height:10),
          if(lines.isEmpty)
            const Card(child:Padding(padding:EdgeInsets.all(20),
              child:Text('Ro‘yxat bo‘sh. Buyurtmalardan yangi ro‘yxat yarating yoki kitob qo‘shing.'))),
          for(final line in visible)
            Card(color:Colors.white,
              margin:const EdgeInsets.only(bottom:7),
              child:Padding(padding:const EdgeInsets.all(8),child:Column(children:[
                Row(children:[
                  Checkbox(value:line.selected,
                    onChanged:busy?null:(v)=>setState(()=>line.selected=v==true)),
                  _PreorderBookCover(url:line.imageUrl,width:48,height:62),
                  const SizedBox(width:9),
                  Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,
                    children:[
                      Text(line.title,style:const TextStyle(fontWeight:FontWeight.w800)),
                      Text(line.publisher.isEmpty?'Nashriyot ko‘rsatilmagan':
                        line.publisher,style:const TextStyle(fontSize:11)),
                      Text('Mijoz zakazi: ${line.requested} dona',
                        style:const TextStyle(fontSize:11,color:AppColors.muted)),
                    ])),
                  IconButton(tooltip:'Nom / nashriyotni tahrirlash',
                    icon:const Icon(Icons.edit_outlined),onPressed:busy?null:()=>_editLine(line)),
                  IconButton(tooltip:'Qatorni ro‘yxatdan olib tashlash',
                    icon:const Icon(Icons.close),
                    onPressed:busy?null:()=>setState(()=>lines.remove(line))),
                ]),
                Row(mainAxisAlignment:MainAxisAlignment.end,children:[
                  const Text('Olinadi: '),
                  IconButton(tooltip:'Kamaytirish',onPressed:busy?null:()=>setState((){
                    if(line.quantity>0)line.quantity--;
                  }),icon:const Icon(Icons.remove_circle_outline)),
                  SizedBox(width:80,child:TextFormField(
                    key:ValueKey(line.key),initialValue:'${line.quantity}',
                    keyboardType:TextInputType.number,
                    textAlign:TextAlign.center,
                    decoration:const InputDecoration(isDense:true),
                    onChanged:(x){final n=int.tryParse(x);if(n!=null&&n>=0&&n<=10000){
                      setState(()=>line.quantity=n);
                    }},
                  )),
                  IconButton(tooltip:'Ko‘paytirish',onPressed:busy?null:()=>setState((){
                    if(line.quantity<10000)line.quantity++;
                  }),icon:const Icon(Icons.add_circle_outline)),
                ]),
              ]))),
          const SizedBox(height:10),
          Text('${selected.length} nom • $total dona',style:const TextStyle(
            fontSize:19,fontWeight:FontWeight.w900,color:AppColors.navy)),
          const Text('Mijozlarning asl zakaslari, avanslari va ombori o‘zgarmaydi.',
            style:TextStyle(fontSize:12,color:AppColors.muted)),
          const SizedBox(height:10),
          Wrap(spacing:8,runSpacing:8,children:[
            FilledButton.icon(onPressed:busy?null:_save,
              icon:const Icon(Icons.save_outlined),label:const Text('Ro‘yxatni saqlash')),
            OutlinedButton.icon(onPressed:busy?null:_clearLines,
              icon:const Icon(Icons.delete_sweep_outlined),label:const Text('Hammasini tozalash')),
            if(draftId!=null)
              OutlinedButton.icon(onPressed:busy?null:_deleteDraft,
                icon:const Icon(Icons.delete_outline),
                label:const Text('Saqlangan ro‘yxatni o‘chirish')),
          ]),
          const Divider(height:28),
          const Text('Do‘konga yuborish formati',
            style:TextStyle(fontWeight:FontWeight.w900,fontSize:16)),
          const SizedBox(height:8),
          Wrap(spacing:8,runSpacing:8,children:[
            for(final option in const [
              ('pdf','PDF',Icons.picture_as_pdf_outlined),
              ('png','PNG rasm',Icons.image_outlined),
              ('jpg','JPG rasm',Icons.photo_outlined),
              ('xlsx','Excel',Icons.table_chart_outlined),
              ('text','Matn yuborish',Icons.send_outlined),
              ('copy','Nusxalash',Icons.copy_all_outlined),
            ])
              OutlinedButton.icon(onPressed:busy?null:()=>_export(option.$1),
                icon:Icon(option.$3),label:Text(option.$2)),
          ]),
          const SizedBox(height:12),
          const Text('Uzun ro‘yxatlarda rasm bir necha sahifaga bo‘linadi. '
            'PDF ko‘p sahifali. Eksportda mijoz ismi, telefon raqami '
            'va avans summasi chiqmaydi.',
            style:TextStyle(fontSize:12,color:AppColors.muted)),
        ])),
        if(busy)const LinearProgressIndicator(),
      ]),
    );
  }
}
