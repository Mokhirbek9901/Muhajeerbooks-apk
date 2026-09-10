from pathlib import Path

path = Path('lib/admin_ui.dart')
text = path.read_text(encoding='utf-8')

replacements = [
    (
        "import 'design_system.dart';\n",
        "import 'design_system.dart';\nimport 'finance_admin.dart';\n",
    ),
    (
        "    'Sotilgan kitoblar',\n    'Mijozlar',\n    'Chegirmalar',\n",
        "    'Sotilgan kitoblar',\n    'Mijozlar',\n    'Moliya',\n    'Chegirmalar',\n",
    ),
    (
        "    Icons.sell_rounded,\n    Icons.people_alt_rounded,\n    Icons.percent_rounded,\n",
        "    Icons.sell_rounded,\n    Icons.people_alt_rounded,\n    Icons.account_balance_wallet_rounded,\n    Icons.percent_rounded,\n",
    ),
    (
        "      _SalesAdmin(key: _salesKey, api: api),\n      _CustomersAdmin(key: _customersKey, api: api),\n      _DiscountAdmin(api: api),\n",
        "      _SalesAdmin(key: _salesKey, api: api),\n      _CustomersAdmin(key: _customersKey, api: api),\n      FinanceAdminPage(secret: widget.secret),\n      _DiscountAdmin(api: api),\n",
    ),
    (
        "      NavigationRailDestination(\n        icon: Icon(Icons.people_alt_outlined),\n        selectedIcon: Icon(Icons.people_alt_rounded),\n        label: Text('Mijozlar'),\n      ),\n      NavigationRailDestination(\n        icon: Icon(Icons.percent_rounded),\n        label: Text('Chegirma'),\n      ),\n",
        "      NavigationRailDestination(\n        icon: Icon(Icons.people_alt_outlined),\n        selectedIcon: Icon(Icons.people_alt_rounded),\n        label: Text('Mijozlar'),\n      ),\n      NavigationRailDestination(\n        icon: Icon(Icons.account_balance_wallet_outlined),\n        selectedIcon: Icon(Icons.account_balance_wallet_rounded),\n        label: Text('Moliya'),\n      ),\n      NavigationRailDestination(\n        icon: Icon(Icons.percent_rounded),\n        label: Text('Chegirma'),\n      ),\n",
    ),
]

for old, new in replacements:
    if new in text:
        continue
    if old not in text:
        raise SystemExit(f'Expected admin_ui snippet not found: {old[:80]!r}')
    text = text.replace(old, new, 1)

path.write_text(text, encoding='utf-8')
print('Finance admin tab patched')
