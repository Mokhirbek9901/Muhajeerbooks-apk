part of 'admin_ui.dart';

/// Admin-only dialog for one already-active catalog preorder. No RPC is
/// called until the owner confirms the final date range and advance amount.
@visibleForTesting
DateTime? preorderActiveDate(
  String note,
  Map<String, dynamic>? managed, {
  required bool end,
}) {
  final saved = managed?[end ? 'end_date' : 'date']?.toString() ?? '';
  final managedDate = DateTime.tryParse(saved);
  if (managedDate != null) return DateUtils.dateOnly(managedDate);
  final dates = RegExp(r'\d{4}-\d{2}-\d{2}').allMatches(note).toList();
  if (dates.isEmpty) return null;
  final value = DateTime.tryParse(
    dates[end && dates.length > 1 ? 1 : 0].group(0) ?? '',
  );
  return value == null ? null : DateUtils.dateOnly(value);
}

Future<Map<String, dynamic>?> _showPreorderActiveEditor(
  BuildContext context,
  Book book,
  Map<String, dynamic>? managed,
) async {
  final today = DateUtils.dateOnly(DateTime.now());
  final latest = today.add(const Duration(days: 730));
  final originalStart = preorderActiveDate(
    book.preorderArrivalNote, managed, end: false);
  var start = originalStart ?? today.add(const Duration(days: 14));
  var until = preorderActiveDate(
    book.preorderArrivalNote, managed, end: true) ?? start;
  if (start.isBefore(today)) start = today;
  if (start.isAfter(latest)) start = latest;
  if (until.isBefore(start)) until = start;
  if (until.isAfter(latest)) until = latest;
  var amountText = '${book.preorderDepositMin >= 1000 ? book.preorderDepositMin : 5000}';
  String? validationError;

  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (dialog) => StatefulBuilder(
      builder: (dialog, redraw) => AlertDialog(
        title: Text('${book.title} • Tahrirlash'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Faqat shu kitobning kelish oralig‘i va yangi buyurtmalar '
                  'uchun avans miqdori o‘zgartiriladi. Oldingi avans va '
                  'mijoz buyurtmalari saqlanadi.',
                ),
                const SizedBox(height: 12),
                Text(
                  'Hozirgi kelish muddati: '
                  '${book.preorderArrivalNote.isEmpty ? 'Kiritilmagan' : book.preorderArrivalNote}',
                  style: const TextStyle(
                    fontSize: 12, color: AppColors.muted),
                ),
                if (originalStart == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'Eski sana boshqa formatda. Saqlashdan oldin '
                      'yangi sanalarni tekshiring.',
                      style: TextStyle(
                        color: AppColors.danger, fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 16),
                const Text(
                  'Taxminiy kelish oralig‘i',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('preorder_active_from'),
                        onPressed: () async {
                          final chosen = await showDatePicker(
                            context: dialog,
                            initialDate: start,
                            firstDate: today,
                            lastDate: latest,
                            helpText: 'Shu sanadan',
                          );
                          if (chosen != null && dialog.mounted) {
                            redraw(() {
                              start = DateUtils.dateOnly(chosen);
                              if (until.isBefore(start)) until = start;
                            });
                          }
                        },
                        icon: const Icon(
                          Icons.calendar_today_outlined, size: 16),
                        label: Text(
                          'Dan: ${DateFormat('MM.dd').format(start)}',
                          maxLines: 1,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('preorder_active_until'),
                        onPressed: () async {
                          final chosen = await showDatePicker(
                            context: dialog,
                            initialDate: until,
                            firstDate: start,
                            lastDate: latest,
                            helpText: 'Shu sanagacha',
                          );
                          if (chosen != null && dialog.mounted) {
                            redraw(() => until = DateUtils.dateOnly(chosen));
                          }
                        },
                        icon: const Icon(
                          Icons.event_available_outlined, size: 16),
                        label: Text(
                          'Gacha: ${DateFormat('MM.dd').format(until)}',
                          maxLines: 1,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  '${DateFormat('yyyy-MM-dd').format(start)} ~ '
                  '${DateFormat('yyyy-MM-dd').format(until)}',
                  style: const TextStyle(
                    fontSize: 12, color: AppColors.muted),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  key: const Key('preorder_active_deposit'),
                  initialValue: amountText,
                  keyboardType: TextInputType.number,
                  onChanged: (value) => amountText = value,
                  decoration: const InputDecoration(
                    labelText: 'Avans summasi (₩)',
                    prefixIcon: Icon(Icons.payments_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                if (validationError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      validationError!,
                      style: const TextStyle(
                        fontSize: 12, color: AppColors.danger),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Bekor qilish'),
          ),
          FilledButton.icon(
            key: const Key('preorder_active_save'),
            onPressed: () {
              final amount = int.tryParse(
                amountText.trim().replaceAll(',', ''));
              if (amount == null || amount < 1000 || amount > 1000000) {
                redraw(() => validationError =
                  'Avans ₩1,000–₩1,000,000 oralig‘ida bo‘lsin.');
                return;
              }
              Navigator.pop(dialog, {
                'id': book.id,
                'date': DateFormat('yyyy-MM-dd').format(start),
                'end_date': DateFormat('yyyy-MM-dd').format(until),
                'deposit': amount,
              });
            },
            icon: const Icon(Icons.save_outlined),
            label: const Text('Saqlash'),
          ),
        ],
      ),
    ),
  );
}
