from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"Patch target not found: {label}")
    if text.count(old) != 1:
        raise SystemExit(f"Patch target is not unique: {label} ({text.count(old)})")
    return text.replace(old, new, 1)


admin_path = Path("lib/admin_ui.dart")
admin = admin_path.read_text(encoding="utf-8")

admin = replace_once(
    admin,
    """class _BooksAdminState extends State<_BooksAdmin> {\n  String query = '';\n  late Future<List<Book>> future;\n""",
    """class _BooksAdminState extends State<_BooksAdmin> {\n  String query = '';\n  String filter = 'all';\n  late Future<List<Book>> future;\n\n  bool _matchesFilter(Book book) {\n    switch (filter) {\n      case 'missing_image':\n        return book.galleryImages.isEmpty;\n      case 'missing_cost':\n        return book.costPrice <= 0;\n      case 'active':\n        return book.isActive;\n      case 'hidden':\n        return !book.isActive;\n      default:\n        return true;\n    }\n  }\n""",
    "books filter state",
)

admin = replace_once(
    admin,
    """        final books = all\n            .where(\n              (b) =>\n                  q.isEmpty ||\n                  b.title.toLowerCase().contains(q) ||\n                  b.author.toLowerCase().contains(q),\n            )\n            .toList();\n        final totalStock = all.fold<int>(0, (s, b) => s + b.stock);\n""",
    """        final books = all\n            .where(\n              (b) =>\n                  _matchesFilter(b) &&\n                  (q.isEmpty ||\n                      b.title.toLowerCase().contains(q) ||\n                      b.author.toLowerCase().contains(q)),\n            )\n            .toList();\n        final totalStock = all.fold<int>(0, (s, b) => s + b.stock);\n        final missingImages = all.where((b) => b.galleryImages.isEmpty).length;\n        final missingCost = all.where((b) => b.costPrice <= 0).length;\n        final activeBooks = all.where((b) => b.isActive).length;\n        final hiddenBooks = all.where((b) => !b.isActive).length;\n""",
    "books visible list",
)

admin = replace_once(
    admin,
    """                    children: [\n                      _MiniStat(label: 'Kitob', value: '${all.length}'),\n                      _MiniStat(label: 'Ombor', value: '$totalStock dona'),\n                      _MiniStat(\n                        label: 'Rasmli',\n                        value:\n                            '${all.where((b) => b.imageUrl.isNotEmpty).length}',\n                      ),\n                      _MiniStat(\n                        label: 'Kam qolgan',\n                        value: '${all.where((b) => b.stock <= 2).length}',\n                      ),\n                    ],\n""",
    """                    children: [\n                      _MiniStat(\n                        label: 'Kitob',\n                        value: '${all.length}',\n                        selected: filter == 'all',\n                        onTap: () => setState(() => filter = 'all'),\n                      ),\n                      _MiniStat(label: 'Ombor', value: '$totalStock dona'),\n                      _MiniStat(\n                        label: 'Rasm yuklanmagan',\n                        value: '$missingImages',\n                        selected: filter == 'missing_image',\n                        onTap: () => setState(() => filter = 'missing_image'),\n                      ),\n                      _MiniStat(\n                        label: 'Tan narxi kiritilmagan',\n                        value: '$missingCost',\n                        selected: filter == 'missing_cost',\n                        onTap: () => setState(() => filter = 'missing_cost'),\n                      ),\n                      _MiniStat(\n                        label: 'Sotuvda ko‘rsatilgan',\n                        value: '$activeBooks',\n                        selected: filter == 'active',\n                        onTap: () => setState(() => filter = 'active'),\n                      ),\n                      _MiniStat(\n                        label: 'Sotuvda ko‘rsatilmagan',\n                        value: '$hiddenBooks',\n                        selected: filter == 'hidden',\n                        onTap: () => setState(() => filter = 'hidden'),\n                      ),\n                    ],\n""",
    "books stat filters",
)

admin = replace_once(
    admin,
    """            else\n              Expanded(\n                child: ListView.separated(\n                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),\n                  itemCount: books.length,\n""",
    """            else if (books.isEmpty)\n              const Expanded(\n                child: Center(\n                  child: Text(\n                    'Bu bo‘limda kitob topilmadi.',\n                    style: TextStyle(color: AppColors.muted),\n                  ),\n                ),\n              )\n            else\n              Expanded(\n                child: ListView.separated(\n                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),\n                  itemCount: books.length,\n""",
    "empty filtered state",
)

admin = replace_once(
    admin,
    """class _MiniStat extends StatelessWidget {\n  const _MiniStat({required this.label, required this.value});\n  final String label;\n  final String value;\n\n  @override\n  Widget build(BuildContext context) => Container(\n        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),\n        decoration: BoxDecoration(\n          color: Colors.white,\n          borderRadius: BorderRadius.circular(14),\n          border: Border.all(color: const Color(0xFFE7E9ED)),\n        ),\n        child: Text(\n          '$label: $value',\n          style: const TextStyle(fontWeight: FontWeight.w800),\n        ),\n      );\n}\n""",
    """class _MiniStat extends StatelessWidget {\n  const _MiniStat({\n    required this.label,\n    required this.value,\n    this.onTap,\n    this.selected = false,\n  });\n  final String label;\n  final String value;\n  final VoidCallback? onTap;\n  final bool selected;\n\n  @override\n  Widget build(BuildContext context) {\n    final child = AnimatedContainer(\n      duration: const Duration(milliseconds: 160),\n      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),\n      decoration: BoxDecoration(\n        color: selected ? AppColors.navy : Colors.white,\n        borderRadius: BorderRadius.circular(14),\n        border: Border.all(\n          color: selected ? AppColors.navy : const Color(0xFFE7E9ED),\n        ),\n      ),\n      child: Text(\n        '$label: $value',\n        style: TextStyle(\n          fontWeight: FontWeight.w800,\n          color: selected ? Colors.white : null,\n        ),\n      ),\n    );\n    if (onTap == null) return child;\n    return Material(\n      color: Colors.transparent,\n      child: InkWell(\n        borderRadius: BorderRadius.circular(14),\n        onTap: onTap,\n        child: child,\n      ),\n    );\n  }\n}\n""",
    "mini stat tappable",
)

admin_path.write_text(admin, encoding="utf-8")

store_path = Path("lib/store_ui.dart")
store = store_path.read_text(encoding="utf-8")
store = replace_once(
    store,
    """    final file = await picker.pickImage(\n      source: ImageSource.gallery,\n      imageQuality: 88,\n      maxWidth: 1800,\n    );\n""",
    """    // To‘lov skrinshotini tanlash paytida avtomatik yengillashtiramiz.\n    // Matn o‘qiladigan darajada qoladi, lekin odatiy telefon skrinshotlari\n    // 7 MB yuklash limitidan ancha past bo‘lib qoladi.\n    final file = await picker.pickImage(\n      source: ImageSource.gallery,\n      imageQuality: 76,\n      maxWidth: 1440,\n      maxHeight: 2400,\n    );\n""",
    "payment proof compression",
)
store_path.write_text(store, encoding="utf-8")

print("Admin catalog filters and payment proof compression patch applied.")
