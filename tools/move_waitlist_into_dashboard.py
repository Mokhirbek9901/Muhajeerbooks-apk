from pathlib import Path

path = Path('lib/admin_ui.dart')
text = path.read_text(encoding='utf-8')
original = text

replacements = [
    (
        "  final _restockKey = GlobalKey<_RestockAdminState>();\n",
        "",
    ),
    (
        "    'Kutayotganlar',\n",
        "",
    ),
    (
        "    Icons.notifications_active_rounded,\n",
        "",
    ),
    (
        "        case 6:\n          unawaited(_restockKey.currentState?.reloadQuietly());\n",
        "",
    ),
    (
        "      _RestockAdmin(key: _restockKey, api: api),\n",
        "",
    ),
    (
        "      NavigationRailDestination(\n        icon: Icon(Icons.notifications_none_rounded),\n        selectedIcon: Icon(Icons.notifications_active_rounded),\n        label: Text('Kutayotganlar'),\n      ),\n",
        "",
    ),
]

for old, new in replacements:
    if old not in text:
        raise SystemExit(f'Expected block not found:\n{old}')
    text = text.replace(old, new, 1)

anchor = """            const SizedBox(height: 18),
            LayoutBuilder(
"""
insert = """            const SizedBox(height: 18),
            InkWell(
              borderRadius: BorderRadius.circular(AppRadii.large),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      appBar: AppBar(
                        title: const Text('Kutayotganlar'),
                      ),
                      body: _RestockAdmin(api: widget.api),
                    ),
                  ),
                );
              },
              child: AppSurface(
                backgroundColor: AppColors.surfaceSoft,
                shadow: true,
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(
                        Icons.notifications_active_rounded,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(width: 13),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kutayotganlar',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Sotuvga qaytishini kutish so‘rovlarini ko‘rish',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.navy,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
"""

if anchor not in text:
    raise SystemExit('Overview insertion anchor not found')
text = text.replace(anchor, insert, 1)

if text == original:
    raise SystemExit('No changes made')

path.write_text(text, encoding='utf-8')
print('Moved Kutayotganlar into Boshqaruv markazi and removed standalone navigation tab.')
