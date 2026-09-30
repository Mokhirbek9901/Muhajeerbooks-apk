from pathlib import Path


PATH = Path('lib/finance_admin.dart')
MARKER = '// FINANCE_PERIOD_FILTERS_V2'


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f'Missing patch anchor: {label}')
    return text.replace(old, new, 1)


text = PATH.read_text(encoding='utf-8')
if MARKER in text:
    print('Finance period filters already applied.')
    raise SystemExit(0)

text = replace_once(
    text,
    "  String period = 'month';\n",
    "  String period = 'month';\n  String? customPeriodLabel;\n",
    'custom period state',
)

text = replace_once(
    text,
    """  static const periodLabels = <String, String>{
    'today': 'Bugun',
    'week': 'Shu hafta',
    'month': 'Shu oy',
    'all': 'Hammasi',
  };
""",
    """  static const periodLabels = <String, String>{
    'last_month': 'O‘tgan oy',
    'last_week': 'O‘tgan hafta',
    'yesterday': 'Kecha',
    'today': 'Bugun',
    'week': 'Shu hafta',
    'month': 'Shu oy',
  };

  static const _monthNames = <String>[
    'Yanvar',
    'Fevral',
    'Mart',
    'Aprel',
    'May',
    'Iyun',
    'Iyul',
    'Avgust',
    'Sentabr',
    'Oktabr',
    'Noyabr',
    'Dekabr',
  ];
""",
    'period labels',
)

category_block = """  static const categoryLabels = <String, String>{
    'postage': 'Pochta',
    'inventory_purchase': 'Yangi partiya kitoblar',
    'packaging': 'Qadoqlash',
    'ads': 'Reklama',
    'transport': 'Transport',
    'other': 'Boshqa',
  };
"""
helpers = r'''

  // FINANCE_PERIOD_FILTERS_V2
  String _twoDigits(int value) => value.toString().padLeft(2, '0');

  Future<void> _openPeriodFilter() async {
    final now = DateTime.now();
    var selectedYear = now.year;
    var selectedMonth = now.month;

    if (period.startsWith('range:')) {
      final parts = period.split(':');
      if (parts.length >= 3) {
        final parsed = DateTime.tryParse(parts[1]);
        if (parsed != null) {
          selectedYear = parsed.year;
          selectedMonth = parsed.month;
        }
      }
    }

    final selected = await showModalBottomSheet<Map<String, int>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  4,
                  20,
                  20 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Moliya davrini tanlang',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          tooltip: 'Yopish',
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: selectedYear,
                      decoration: const InputDecoration(
                        labelText: 'Yil',
                        prefixIcon: Icon(Icons.calendar_today_outlined),
                      ),
                      items: [
                        for (var year = now.year; year >= 2020; year--)
                          DropdownMenuItem<int>(
                            value: year,
                            child: Text('$year-yil'),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setSheetState(() => selectedYear = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: selectedMonth,
                      decoration: const InputDecoration(
                        labelText: 'Oy',
                        prefixIcon: Icon(Icons.calendar_month_outlined),
                      ),
                      items: [
                        for (var month = 1; month <= 12; month++)
                          DropdownMenuItem<int>(
                            value: month,
                            child: Text(_monthNames[month - 1]),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setSheetState(() => selectedMonth = value);
                        }
                      },
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.pop(
                          sheetContext,
                          <String, int>{
                            'year': selectedYear,
                            'month': selectedMonth,
                          },
                        ),
                        icon: const Icon(Icons.filter_alt_rounded),
                        label: const Text('Shu davrni ko‘rsatish'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted || selected == null) return;
    final year = selected['year']!;
    final month = selected['month']!;
    final lastDay = DateTime(year, month + 1, 0).day;
    final start = '$year-${_twoDigits(month)}-01';
    final end = '$year-${_twoDigits(month)}-${_twoDigits(lastDay)}';

    setState(() {
      period = 'range:$start:$end';
      customPeriodLabel = '$year ${_monthNames[month - 1]}';
    });
    await _load();
  }
'''
text = replace_once(text, category_block, category_block + helpers, 'filter helpers')

old_wrap = """          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: periodLabels.entries.map((entry) {
              return ChoiceChip(
                label: Text(entry.value),
                selected: period == entry.key,
                onSelected: (_) {
                  setState(() => period = entry.key);
                  unawaited(_load());
                },
              );
            }).toList(),
          ),
"""
new_wrap = """          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...periodLabels.entries.map((entry) {
                return ChoiceChip(
                  label: Text(entry.value),
                  selected: period == entry.key,
                  onSelected: (_) {
                    setState(() {
                      period = entry.key;
                      customPeriodLabel = null;
                    });
                    unawaited(_load());
                  },
                );
              }),
              FilterChip(
                avatar: const Icon(Icons.filter_alt_outlined, size: 18),
                label: Text(
                  customPeriodLabel == null
                      ? 'Filtr'
                      : 'Filtr: $customPeriodLabel',
                ),
                selected: customPeriodLabel != null,
                onSelected: (_) => unawaited(_openPeriodFilter()),
              ),
            ],
          ),
"""
text = replace_once(text, old_wrap, new_wrap, 'period chips')

PATH.write_text(text, encoding='utf-8')
print('Finance quick periods and year/month filter applied.')
