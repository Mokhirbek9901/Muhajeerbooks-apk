import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Missing prices are reported, never silently interpreted as known profit.
@visibleForTesting
bool profitLotHasMissingPrice(Map<String, dynamic> lot) {
  int n(dynamic value) => value is num
      ? value.round()
      : int.tryParse(value?.toString() ?? '') ?? 0;
  return n(lot['unit_cost']) <= 0 || n(lot['sale_price']) <= 0;
}

/// Forecast, not recognized profit from past transactions.
@visibleForTesting
int? profitLotForecast(int units, int? cost, int? sale) {
  if (units < 1 || cost == null || sale == null ||
      cost < 1 || sale < 1) return null;
  return (sale - cost) * units;
}

/// Edit only the selected purchase-lot unit cost and this book's current
/// catalog sale price. Past sales, stock, finance and other lots stay frozen.
Future<bool> showAdminProfitLotPriceEditor(
  BuildContext context, {
  required String secret,
  required Map<String, dynamic> lot,
}) async {
  int n(dynamic value) => value is num
      ? value.round()
      : int.tryParse(value?.toString() ?? '') ?? 0;
  String won(int value) =>
      '${value < 0 ? '−' : ''}₩${NumberFormat('#,###', 'en_US').format(value.abs())}';

  final lotId = n(lot['id']);
  final quantity = n(lot['quantity']);
  final oldCost = n(lot['unit_cost']);
  final oldSale = n(lot['sale_price']);
  if (secret.isEmpty || lotId < 1 || quantity < 1) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Narxlarni tahrirlash uchun partiya identifikatori topilmadi.')),
    );
    return false;
  }
  final costController = TextEditingController(
    text: oldCost > 0 ? oldCost.toString() : '',
  );
  final saleController = TextEditingController(
    text: oldSale > 0 ? oldSale.toString() : '',
  );
  try {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialog) => StatefulBuilder(
        builder: (dialog, redraw) {
          final cost = int.tryParse(costController.text.trim().replaceAll(',', ''));
          final sale = int.tryParse(saleController.text.trim().replaceAll(',', ''));
          final forecast = profitLotForecast(quantity, cost, sale);
          final isChanged = cost != oldCost || sale != oldSale;
          return _ProfitLotEditorForm(
            title: (lot['book_title'] ?? 'Kitob').toString(),
            quantity: quantity,
            oldCost: oldCost,
            oldSale: oldSale,
            costController: costController,
            saleController: saleController,
            forecast: forecast,
            isChanged: isChanged,
            lotId: lotId,
            secret: secret,
            won: won,
            onChanged: () => redraw(() {}),
            onSaved: () => Navigator.of(dialog).pop(true),
            onCancel: () => Navigator.of(dialog).pop(false),
          );
        },
      ),
    );
    return saved == true;
  } finally {
    costController.dispose();
    saleController.dispose();
  }
}

class _ProfitLotEditorForm extends StatefulWidget {
  const _ProfitLotEditorForm({
    required this.title,
    required this.quantity,
    required this.oldCost,
    required this.oldSale,
    required this.costController,
    required this.saleController,
    required this.forecast,
    required this.isChanged,
    required this.lotId,
    required this.secret,
    required this.won,
    required this.onChanged,
    required this.onSaved,
    required this.onCancel,
  });
  final String title;
  final int quantity,oldCost,oldSale,lotId;
  final TextEditingController costController,saleController;
  final int? forecast;
  final bool isChanged;
  final String secret;
  final String Function(int) won;
  final VoidCallback onChanged,onSaved,onCancel;
  @override
  State<_ProfitLotEditorForm> createState() => _ProfitLotEditorFormState();
}

class _ProfitLotEditorFormState extends State<_ProfitLotEditorForm> {
  bool saving = false;
  String? error;

  Future<void> _save() async {
    if (saving) return;
    final cost = int.tryParse(
      widget.costController.text.trim().replaceAll(',', ''));
    final sale = int.tryParse(
      widget.saleController.text.trim().replaceAll(',', ''));
    if (cost == null || sale == null || cost <= 0 || sale <= 0 ||
        cost > 100000000 || sale > 100000000) {
      setState(() => error = 'Ikkala narxni ham ₩1–₩100,000,000 oralig‘ida kiriting.');
      return;
    }
    if (cost == widget.oldCost && sale == widget.oldSale) {
      setState(() => error = 'Narxlar o‘zgarmagan.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final value = await Supabase.instance.client.rpc(
        'admin_profit_lot_price_review',
        params: {
          'p_secret': widget.secret,
          'p_lot_id': widget.lotId,
          'p_expected_unit_cost': widget.oldCost,
          'p_new_unit_cost': cost,
          'p_expected_sale_price': widget.oldSale,
          'p_new_sale_price': sale,
        },
      );
      if (value is! Map || value['saved'] != true) {
        throw StateError('Server narxlar saqlanganini tasdiqlamadi.');
      }
      if (mounted) widget.onSaved();
    } catch (e) {
      if (mounted) setState(() {
        error = 'Narxlar saqlanmadi: $e';
        saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Narxlarni tekshirish · ${widget.title}'),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Shu partiyada ${widget.quantity} dona. '
              'Tan narxi faqat shu partiyaga tegishli.',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            const Text(
              'Sotuv narxi esa katalogdagi joriy narx: uni o‘zgartirsangiz '
              'shu kitobning boshqa partiyalarida ham joriy narx yangilanadi. '
              'Eski sotuv summalari va tannarx yozuvlari o‘zgarmaydi.',
              style: TextStyle(color: Color(0xFF707C90),fontSize: 12,height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('profit_lot_cost_editor'),
              controller: widget.costController,
              enabled: !saving,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => widget.onChanged(),
              decoration: InputDecoration(
                labelText: 'Partiyadagi bir dona tan narxi (₩)',
                helperText: 'Hozir: ${widget.oldCost > 0 ? widget.won(widget.oldCost) : 'Kiritilmagan'}',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              key: const Key('profit_lot_sale_editor'),
              controller: widget.saleController,
              enabled: !saving,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => widget.onChanged(),
              decoration: InputDecoration(
                labelText: 'Katalogdagi joriy sotuv narxi (₩)',
                helperText: 'Hozir: ${widget.oldSale > 0 ? widget.won(widget.oldSale) : 'Kiritilmagan'}',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F8F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Yangi taxminiy foyda',
                    style: TextStyle(fontWeight: FontWeight.w800,fontSize: 13)),
                  const SizedBox(height: 6),
                  Text(widget.forecast == null
                    ? 'Ikkala narx kiritilganda hisoblanadi'
                    : '${widget.won(widget.forecast!)} · ${widget.quantity} dona',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                  if (widget.forecast != null)
                    Text('Bir donadan: ${widget.won((widget.forecast! ~/ widget.quantity))}',
                      style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Bu taxminiy foyda. Ilgari sotilgan, narxi qayd etilmagan '
              'kitoblarning haqiqiy tushumi avtomatik tiklanmaydi.',
              style: TextStyle(color: Color(0xFF707C90),fontSize: 11),
            ),
            if (error != null) Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(error!, style: const TextStyle(
                color: Color(0xFFBD3030),fontSize: 12)),
            ),
            if (saving) const LinearProgressIndicator(),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: saving ? null : widget.onCancel,
        child: const Text('Bekor qilish'),
      ),
      FilledButton.icon(
        key: const Key('profit_lot_price_save'),
        onPressed: saving || !widget.isChanged ? null : _save,
        icon: const Icon(Icons.save_outlined,size: 18),
        label: const Text('Narxlarni saqlash'),
      ),
    ],
  );
}
