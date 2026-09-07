from pathlib import Path

p = Path('lib/admin_ui.dart')
s = p.read_text(encoding='utf-8')

s = s.replace(
"  final _ordersKey = GlobalKey<_OrdersAdminState>();\n",
"  final _ordersKey = GlobalKey<_OrdersAdminState>();\n  final _customersKey = GlobalKey<_CustomersAdminState>();\n",
1,
)

s = s.replace(
"        case 3:\n          _ordersKey.currentState?.reload();\n      }\n",
"        case 3:\n          _ordersKey.currentState?.reload();\n        case 4:\n          _customersKey.currentState?.reload();\n      }\n",
1,
)

s = s.replace(
"      _OrdersAdmin(key: _ordersKey, api: api),\n      _DiscountAdmin(api: api),\n",
"      _OrdersAdmin(key: _ordersKey, api: api),\n      _CustomersAdmin(key: _customersKey, api: api),\n      _DiscountAdmin(api: api),\n",
1,
)

s = s.replace(
"      NavigationRailDestination(\n        icon: Icon(Icons.percent_rounded),\n        label: Text('Chegirma'),\n      ),\n",
"      NavigationRailDestination(\n        icon: Icon(Icons.people_alt_outlined),\n        selectedIcon: Icon(Icons.people_alt_rounded),\n        label: Text('Mijozlar'),\n      ),\n      NavigationRailDestination(\n        icon: Icon(Icons.percent_rounded),\n        label: Text('Chegirma'),\n      ),\n",
1,
)

s = s.replace(
"class _CustomersAdmin extends StatefulWidget {\n  const _CustomersAdmin({required this.api});\n",
"class _CustomersAdmin extends StatefulWidget {\n  const _CustomersAdmin({super.key, required this.api});\n",
1,
)

needle = "class _CustomersAdminState extends State<_CustomersAdmin> {\n  late Future<(Map<String, dynamic>, List<Map<String, dynamic>>)> future;\n  String query = '';\n"
replacement = "class _CustomersAdminState extends State<_CustomersAdmin> {\n  late Future<(Map<String, dynamic>, List<Map<String, dynamic>>)> future;\n  String query = '';\n\n  void reload() {\n    if (!mounted) return;\n    _reload();\n    setState(() {});\n  }\n"
if needle not in s:
    raise SystemExit('Customers state anchor not found')
s = s.replace(needle, replacement, 1)

p.write_text(s, encoding='utf-8')
print('Admin customer navigation fixed')
