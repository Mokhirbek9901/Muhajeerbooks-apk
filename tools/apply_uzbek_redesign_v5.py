from pathlib import Path
import re

path = Path('lib/store_ui.dart')
text = path.read_text(encoding='utf-8')
original = text


def replace_once(source: str, old: str, new: str, label: str) -> str:
    if old not in source:
        raise SystemExit(f'Missing expected block: {label}')
    return source.replace(old, new, 1)

# 1) Floating navigation becomes a deep Uzbek-tile navigation island.
nav_start = text.index('      bottomNavigationBar: Container(')
nav_end = text.index('\nclass CategoriesPage', nav_start)
nav = text[nav_start:nav_end]
nav = replace_once(
    nav,
    """      bottomNavigationBar: Container(\n        margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),\n        clipBehavior: Clip.antiAlias,\n        decoration: BoxDecoration(\n          gradient: const LinearGradient(\n            begin: Alignment.topLeft,\n            end: Alignment.bottomRight,\n            colors: [UzbekCustomerColors.surface, UzbekCustomerColors.ivory],\n          ),\n          borderRadius: BorderRadius.circular(26),\n          border: Border.all(color: UzbekCustomerColors.gold, width: 1.15),\n          boxShadow: const [\n            BoxShadow(\n              color: Color(0x26123C4A),\n              blurRadius: 28,\n              offset: Offset(0, 10),\n            ),\n          ],\n        ),\n        child: NavigationBar(\n          height: 72,\n          backgroundColor: Colors.transparent,\n          indicatorColor: UzbekCustomerColors.goldSoft,""",
    """      bottomNavigationBar: Container(\n        margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),\n        clipBehavior: Clip.antiAlias,\n        decoration: BoxDecoration(\n          gradient: const LinearGradient(\n            begin: Alignment.topLeft,\n            end: Alignment.bottomRight,\n            colors: [UzbekCustomerColors.navy, UzbekCustomerColors.tealDark],\n          ),\n          borderRadius: BorderRadius.circular(22),\n          border: Border.all(\n            color: UzbekCustomerColors.gold,\n            width: 1.05,\n          ),\n          boxShadow: const [\n            BoxShadow(\n              color: Color(0x33113D43),\n              blurRadius: 24,\n              offset: Offset(0, 9),\n            ),\n          ],\n        ),\n        child: NavigationBar(\n          height: 72,\n          backgroundColor: Colors.transparent,\n          indicatorColor: UzbekCustomerColors.gold,""",
    'bottom navigation shell',
)
nav = nav.replace('color: UzbekCustomerColors.goldDeep,', 'color: UzbekCustomerColors.navy,')
text = text[:nav_start] + nav + text[nav_end:]

# 2) Header becomes calmer and more compact while keeping all existing wording.
header_marker = 'class _StoreHeader extends StatelessWidget {'
header_start = text.index(header_marker)
header_end = text.index('\nclass _DeliveryPromoCard', header_start)
header = text[header_start:header_end]
header = replace_once(
    header,
    """    return Container(\n      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),\n      decoration: BoxDecoration(\n        gradient: const LinearGradient(\n          begin: Alignment.topLeft,\n          end: Alignment.bottomRight,\n          colors: [UzbekCustomerColors.surface, UzbekCustomerColors.ivory],\n        ),\n        borderRadius: BorderRadius.circular(26),\n        border: Border.all(color: UzbekCustomerColors.gold, width: 1.05),\n        boxShadow: const [\n          BoxShadow(\n            color: Color(0x15123C4A),\n            blurRadius: 20,\n            offset: Offset(0, 8),\n          ),\n        ],\n      ),""",
    """    return Container(\n      padding: const EdgeInsets.fromLTRB(14, 11, 10, 10),\n      decoration: BoxDecoration(\n        color: UzbekCustomerColors.surface,\n        borderRadius: BorderRadius.circular(20),\n        border: Border.all(color: UzbekCustomerColors.border),\n        boxShadow: const [\n          BoxShadow(\n            color: Color(0x10173F4A),\n            blurRadius: 16,\n            offset: Offset(0, 6),\n          ),\n        ],\n      ),""",
    'store header decoration',
)
text = text[:header_start] + header + text[header_end:]

# 3) Category strip uses shorter, wider touch targets and a clearer active state.
text = replace_once(
    text,
    """        SizedBox(\n          height: 88,""",
    """        SizedBox(\n          height: 78,""",
    'category strip height',
)
quick_start = text.index('class _QuickCategoryStrip')
quick_end = text.index('\nclass _TrustStrip', quick_start)
quick = text[quick_start:quick_end]
quick = quick.replace('                  width: 78,', '                  width: 86,', 1)
quick = quick.replace('                    vertical: 9,', '                    vertical: 7,', 1)
quick = quick.replace('                    borderRadius: BorderRadius.circular(20),', '                    borderRadius: BorderRadius.circular(17),', 1)
quick = quick.replace('                        size: 25,', '                        size: 23,', 1)
text = text[:quick_start] + quick + text[quick_end:]

# 4) Search filter becomes a strong one-tap action rather than another pale card.
search_pattern = re.compile(
    r"child: Container\(\n\s+height: 56,\n\s+width: 56,\n\s+decoration: BoxDecoration\(\n\s+color: UzbekCustomerColors\.surface,\n\s+borderRadius: BorderRadius\.circular\(18\),\n\s+border: Border\.all\(color: UzbekCustomerColors\.gold\),\n\s+boxShadow: const \[\n\s+BoxShadow\(\n\s+color: Color\(0x12123C4A\),\n\s+blurRadius: 14,\n\s+offset: Offset\(0, 5\),\n\s+\),\n\s+\],\n\s+\),\n\s+child: const Icon\(\n\s+Icons\.tune_rounded,\n\s+color: UzbekCustomerColors\.navy,\n\s+\),\n\s+\)",
    re.MULTILINE,
)
search_replacement = """child: Container(\n                        height: 56,\n                        width: 56,\n                        decoration: BoxDecoration(\n                          gradient: const LinearGradient(\n                            begin: Alignment.topLeft,\n                            end: Alignment.bottomRight,\n                            colors: [\n                              UzbekCustomerColors.navy,\n                              UzbekCustomerColors.tealDark,\n                            ],\n                          ),\n                          borderRadius: BorderRadius.circular(18),\n                          border: Border.all(color: UzbekCustomerColors.gold),\n                          boxShadow: const [\n                            BoxShadow(\n                              color: Color(0x22173F4A),\n                              blurRadius: 16,\n                              offset: Offset(0, 6),\n                            ),\n                          ],\n                        ),\n                        child: const Icon(\n                          Icons.tune_rounded,\n                          color: UzbekCustomerColors.goldSoft,\n                        ),\n                      )"""
text, count = search_pattern.subn(search_replacement, text, count=1)
if count != 1:
    raise SystemExit('Missing expected block: search filter')

# 5) Book cards become cleaner and denser so covers/prices are easier to scan.
book_start = text.index('class BookCard extends StatelessWidget {')
book_end = text.index('\nclass _BookCover extends StatelessWidget', book_start)
book = text[book_start:book_end]
book = replace_once(
    book,
    """    return Container(\n      decoration: BoxDecoration(\n        gradient: const LinearGradient(\n          begin: Alignment.topLeft,\n          end: Alignment.bottomRight,\n          colors: [UzbekCustomerColors.surface, UzbekCustomerColors.ivory],\n        ),\n        borderRadius: BorderRadius.circular(26),\n        border: Border.all(color: UzbekCustomerColors.border, width: 1.05),\n        boxShadow: const [\n          BoxShadow(\n            color: Color(0x1A123C4A),\n            blurRadius: 22,\n            offset: Offset(0, 9),\n          ),\n        ],\n      ),""",
    """    return Container(\n      decoration: BoxDecoration(\n        color: UzbekCustomerColors.surface,\n        borderRadius: BorderRadius.circular(18),\n        border: Border.all(color: UzbekCustomerColors.border),\n        boxShadow: const [\n          BoxShadow(\n            color: Color(0x12173F4A),\n            blurRadius: 16,\n            offset: Offset(0, 6),\n          ),\n        ],\n      ),""",
    'book card shell',
)
book = book.replace('borderRadius: BorderRadius.circular(100),', 'borderRadius: BorderRadius.circular(12),')
text = text[:book_start] + book + text[book_end:]

# 6) Slightly shorter cards improve browsing on phones without changing content.
text = text.replace(
    'childAspectRatio: width < 450 ? .57 : .62,',
    'childAspectRatio: width < 450 ? .60 : .66,',
    1,
)

if text == original:
    raise SystemExit('No UI changes were applied')

path.write_text(text, encoding='utf-8')
print('Applied Uzbek modern redesign v5 without changing customer-facing wording.')
