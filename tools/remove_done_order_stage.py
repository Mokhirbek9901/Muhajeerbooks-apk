from pathlib import Path

p = Path('lib/admin_ui.dart')
s = p.read_text(encoding='utf-8')

replacements = {
    "['accepted', 'paid', 'shipping', 'done'].contains(o.status)": "['accepted', 'paid', 'shipping'].contains(o.status)",
    ".where((o) => o.status == 'done')": ".where((o) => o.status == 'shipping')",
    "final activeStatuses = {'accepted', 'paid', 'shipping', 'done'};": "final activeStatuses = {'accepted', 'paid', 'shipping'};",
    "          final doneOrders = orders.where((o) => o.status == 'done').length;\n": "",
    "              orders.isEmpty ? 0 : ((doneOrders / orders.length) * 100).round();": "              orders.isEmpty ? 0 : ((shippingOrders / orders.length) * 100).round();",
    "label: 'Yakunlangan savdo',": "label: 'Jo‘natilgan savdo',",
    "note: 'Yakunlangan buyurtmalar',": "note: 'Jo‘natilgan buyurtmalar',",
    """                          AppInfoPill(\n                            icon: Icons.task_alt_rounded,\n                            label: '$doneOrders yakunlangan',\n                            foreground: AppColors.navy,\n                            background: AppColors.surfaceSoft,\n                          ),\n""": "",
    "label: 'Yakunlangan buyurtmalar',": "label: 'Jo‘natilgan buyurtmalar',",
    """                        _OrderFilterChip(\n                          label: 'Yakunlangan',\n                          value: 'done',\n                          selected: filter,\n                          onTap: (v) => setState(() => filter = v),\n                        ),\n""": "",
    """    } else if (order.status == 'shipping') {\n      primaryStatus = 'done';\n      primaryLabel = 'Yakunlash';\n      primaryIcon = Icons.task_alt_rounded;\n    }\n""": "    }\n",
    """      'shipping' => (\n          'Jo‘natildi',\n          AppColors.orange,\n          const Color(0xFFFFF2E3),\n          const Color(0xFFFFD4A3),\n          Icons.local_shipping_rounded,\n        ),\n      'done' => (\n          'Yakunlandi',\n          AppColors.success,\n          AppColors.successSoft,\n          const Color(0xFFCDEAD7),\n          Icons.task_alt_rounded,\n        ),\n""": """      'shipping' => (\n          'Jo‘natildi',\n          AppColors.success,\n          AppColors.successSoft,\n          const Color(0xFFCDEAD7),\n          Icons.local_shipping_rounded,\n        ),\n      // Eski buildlardan qolgan 'done' yozuvlari bo‘lsa ham mijozga\n      // alohida bosqich ko‘rsatmaymiz: Jo‘natildi yakuniy holat.\n      'done' => (\n          'Jo‘natildi',\n          AppColors.success,\n          AppColors.successSoft,\n          const Color(0xFFCDEAD7),\n          Icons.local_shipping_rounded,\n        ),\n""",
    "'Ochiq buyurtmalar: ${stats['open_orders'] ?? 0} • Yakunlangan: ${stats['completed_orders'] ?? 0}'": "'Ochiq buyurtmalar: ${stats['open_orders'] ?? 0} • Jo‘natilgan: ${stats['completed_orders'] ?? 0}'",
}

missing = []
for old, new in replacements.items():
    if old not in s:
        missing.append(old[:90].replace('\n', ' '))
    else:
        s = s.replace(old, new)

if missing:
    raise SystemExit('Missing patterns: ' + ' | '.join(missing))

p.write_text(s, encoding='utf-8')
print('Removed Yakunlandi stage; Jo‘natildi is final and green.')
