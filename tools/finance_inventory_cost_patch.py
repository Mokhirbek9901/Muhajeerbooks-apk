from pathlib import Path

path = Path('lib/finance_admin.dart')
text = path.read_text(encoding='utf-8')

old = "  List<Map<String, dynamic>> expenses = <Map<String, dynamic>>[];\n"
new = old + "  int inventoryStockCost = 0;\n"
if old not in text:
    raise SystemExit('state marker not found')
text = text.replace(old, new, 1)

old = """        client.rpc(\n          'admin_finance_expenses',\n          params: {'p_secret': widget.secret, 'p_limit': 100},\n        ),\n      ]);\n      if (!mounted) return;\n      final rawReport = result[0];\n      final rawExpenses = result[1];\n      setState(() {\n"""
new = """        client.rpc(\n          'admin_finance_expenses',\n          params: {'p_secret': widget.secret, 'p_limit': 100},\n        ),\n        client.rpc(\n          'admin_list_books',\n          params: {'p_secret': widget.secret},\n        ),\n      ]);\n      if (!mounted) return;\n      final rawReport = result[0];\n      final rawExpenses = result[1];\n      final rawBooks = result[2];\n      var stockCost = 0;\n      if (rawBooks is List) {\n        for (final row in rawBooks.whereType<Map>()) {\n          final stock = (row['stock'] as num?)?.round() ?? 0;\n          final costPrice = (row['cost_price'] as num?)?.round() ?? 0;\n          if (stock > 0 && costPrice > 0) {\n            stockCost += stock * costPrice;\n          }\n        }\n      }\n      setState(() {\n"""
if old not in text:
    raise SystemExit('load marker not found')
text = text.replace(old, new, 1)

old = """        expenses = rawExpenses is List\n            ? rawExpenses\n                .whereType<Map>()\n                .map((e) => Map<String, dynamic>.from(e))\n                .toList()\n            : <Map<String, dynamic>>[];\n        loading = false;\n"""
new = """        expenses = rawExpenses is List\n            ? rawExpenses\n                .whereType<Map>()\n                .map((e) => Map<String, dynamic>.from(e))\n                .toList()\n            : <Map<String, dynamic>>[];\n        inventoryStockCost = stockCost;\n        loading = false;\n"""
if old not in text:
    raise SystemExit('setState marker not found')
text = text.replace(old, new, 1)

old = """                  _FinanceCard(\n                    title: 'Boshqa chiqimlar',\n                    value: _financeWon(_int('other_expenses')),\n                    subtitle: 'Qadoqlash, reklama, transport va boshqa',\n                    icon: Icons.receipt_long_outlined,\n                  ),\n                  _FinanceCard(\n                    title: resultTitle,\n"""
new = """                  _FinanceCard(\n                    title: 'Boshqa chiqimlar',\n                    value: _financeWon(_int('other_expenses')),\n                    subtitle: 'Qadoqlash, reklama, transport va boshqa',\n                    icon: Icons.receipt_long_outlined,\n                  ),\n                  _FinanceCard(\n                    title: 'Ombor tan narxi',\n                    value: _financeWon(inventoryStockCost),\n                    subtitle: 'Hozir omborda bor kitoblarning jami tannarxi',\n                    icon: Icons.inventory_2_outlined,\n                  ),\n                  _FinanceCard(\n                    title: resultTitle,\n"""
if old not in text:
    raise SystemExit('card marker not found')
text = text.replace(old, new, 1)

path.write_text(text, encoding='utf-8')
print('finance inventory cost card patched')
