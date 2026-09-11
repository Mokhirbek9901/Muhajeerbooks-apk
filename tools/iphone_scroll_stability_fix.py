from pathlib import Path
import re

path = Path('lib/store_ui.dart')
text = path.read_text(encoding='utf-8')
original = text

# Manual SharedPreferences scroll persistence caused repeated async writes and
# jumpTo restore loops on iPhone Safari. Normal Navigator.pop keeps HomePage
# mounted, so its ScrollController is already the correct source of truth.
text = text.replace("import 'package:shared_preferences/shared_preferences.dart';\n", '')

pattern = re.compile(
    r"class _HomePageState extends State<HomePage> \{\n"
    r"  static const _homeScrollKey = 'muhajeer_home_scroll_offset_v1';\n"
    r"(?P<body>.*?)"
    r"  @override\n  Widget build\(BuildContext context\) \{\n"
    r"    if \(_pendingScrollOffset != null\) \{\n"
    r"      _restoreSavedScrollPosition\(\);\n"
    r"    \}\n",
    re.S,
)

replacement = """class _HomePageState extends State<HomePage> {
  String query = '';
  String category = 'Barchasi';
  String sort = 'new';

  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
"""

text, count = pattern.subn(replacement, text, count=1)
if count != 1:
    raise SystemExit('HomePage scroll persistence block not found exactly once')

# Make PageStorage identity stable and explicit for normal Flutter restoration.
text = text.replace(
    "key: const PageStorageKey<String>('muhajeer-home-scroll'),",
    "key: const PageStorageKey<String>('muhajeer-home-scroll-v2'),",
    1,
)

if text == original:
    raise SystemExit('No storefront changes applied')

path.write_text(text, encoding='utf-8')

pubspec = Path('pubspec.yaml')
pub = pubspec.read_text(encoding='utf-8')
pub2, version_count = re.subn(
    r'^version:\s*[^\n]+$',
    'version: 2.5.5+12',
    pub,
    count=1,
    flags=re.M,
)
if version_count != 1:
    raise SystemExit('pubspec version not found')
pubspec.write_text(pub2, encoding='utf-8')
