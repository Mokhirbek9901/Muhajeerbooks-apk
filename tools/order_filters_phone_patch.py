from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected 1 match, found {count}')
    return text.replace(old, new, 1)


admin_path = Path('lib/admin_ui.dart')
admin = admin_path.read_text(encoding='utf-8')

admin = replace_once(
    admin,
    """        final q = query.trim().toLowerCase();
        final orders = all.where((o) {
          final matchStatus = filter == 'all' || o.status == filter;
""",
    """        final q = query.trim().toLowerCase();
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final yesterday = today.subtract(const Duration(days: 1));
        final orders = all.where((o) {
          final created = o.createdAt.toLocal();
          final orderDay = DateTime(created.year, created.month, created.day);
          final matchStatus = switch (filter) {
            'all' => o.status != 'cancelled',
            'today' => o.status != 'cancelled' && orderDay == today,
            'yesterday' => o.status != 'cancelled' && orderDay == yesterday,
            _ => o.status == filter,
          };
""",
    'order filtering logic',
)

admin = replace_once(
    admin,
    """                        _OrderFilterChip(
                          label: 'Barchasi',
                          value: 'all',
                          selected: filter,
                          onTap: (v) => setState(() => filter = v),
                        ),
                        _OrderFilterChip(
                          label: 'Yangi',
""",
    """                        _OrderFilterChip(
                          label: 'Barchasi',
                          value: 'all',
                          selected: filter,
                          onTap: (v) => setState(() => filter = v),
                        ),
                        _OrderFilterChip(
                          label: 'Bugun',
                          value: 'today',
                          selected: filter,
                          onTap: (v) => setState(() => filter = v),
                        ),
                        _OrderFilterChip(
                          label: 'Kecha',
                          value: 'yesterday',
                          selected: filter,
                          onTap: (v) => setState(() => filter = v),
                        ),
                        _OrderFilterChip(
                          label: 'Yangi',
""",
    'today/yesterday order chips',
)

admin_path.write_text(admin, encoding='utf-8')

store_path = Path('lib/store_ui.dart')
store = store_path.read_text(encoding='utf-8')

store = replace_once(
    store,
    """bool _isSupportedCustomerPhone(String raw) {
  var digits = raw.replaceAll(RegExp(r'\\D'), '');
  if (digits.startsWith('00')) digits = digits.substring(2);

  // O‘zbekiston: +998 XX XXX XX XX, 998XXXXXXXXX yoki mahalliy 9 raqam.
  if (digits.length == 12 && digits.startsWith('998')) return true;
  if (digits.length == 9 && !digits.startsWith('0')) return true;

  // Koreya: 010-XXXX-XXXX yoki +82 10-XXXX-XXXX.
  if (digits.length == 11 && digits.startsWith('010')) return true;
  if (digits.length == 12 && digits.startsWith('8210')) return true;
  return false;
}
""",
    """bool _isSupportedCustomerPhone(String raw) {
  final digits = raw.replaceAll(RegExp(r'\\D'), '');
  return digits.length == 11 && digits.startsWith('010');
}
""",
    'Korean-only phone validator',
)

store = replace_once(
    store,
    """    name = TextEditingController(text: saved['name'] ?? '');
    phone = TextEditingController(text: saved['phone'] ?? '');
    address = TextEditingController(text: saved['address'] ?? '');
""",
    """    name = TextEditingController(text: saved['name'] ?? '');
    final savedPhone = (saved['phone'] ?? '').replaceAll(RegExp(r'\\D'), '');
    phone = TextEditingController(
      text: _isSupportedCustomerPhone(savedPhone) ? savedPhone : '',
    );
    address = TextEditingController(text: saved['address'] ?? '');
""",
    'saved checkout phone normalization',
)

store = replace_once(
    store,
    """                      controller: phone,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Telefon raqam',
                        hintText: '+998 90 123 45 67 yoki 010-1234-5678',
                        helperText: 'O‘zbekiston +998 va Koreya 010 / +82 raqamlari qabul qilinadi.',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: (v) => !_isSupportedCustomerPhone(v ?? '')
                          ? 'O‘zbekiston (+998) yoki Koreya (010 / +82) raqamini to‘liq kiriting'
                          : null,
""",
    """                      controller: phone,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      inputFormatters: const [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(11),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Telefon raqam',
                        hintText: '01024338600',
                        helperText: 'Koreya raqamini 010 bilan 11 ta raqamda kiriting.',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: (v) => !_isSupportedCustomerPhone(v ?? '')
                          ? 'Koreya 010 raqamini to‘liq kiriting. Masalan: 01024338600'
                          : null,
""",
    'checkout phone field',
)

store_path.write_text(store, encoding='utf-8')
print('Order filters and Korean phone checkout updated')
