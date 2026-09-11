from pathlib import Path

path = Path('lib/store_ui.dart')
text = path.read_text(encoding='utf-8')

if 'muhajeer_home_scroll_offset_v1' in text:
    print('iPhone scroll restore already applied.')
    raise SystemExit(0)

provider_import = "import 'package:provider/provider.dart';\n"
if "package:shared_preferences/shared_preferences.dart" not in text:
    if provider_import not in text:
        raise SystemExit('provider import marker not found')
    text = text.replace(
        provider_import,
        provider_import + "import 'package:shared_preferences/shared_preferences.dart';\n",
        1,
    )

old = """class _HomePageState extends State<HomePage> {
  String query = '';
  String category = 'Barchasi';
  String sort = 'new';

  @override
  Widget build(BuildContext context) {
"""

new = """class _HomePageState extends State<HomePage> {
  static const _homeScrollKey = 'muhajeer_home_scroll_offset_v1';

  String query = '';
  String category = 'Barchasi';
  String sort = 'new';

  final ScrollController _scrollController = ScrollController();
  Timer? _scrollSaveTimer;
  double? _pendingScrollOffset;
  int _restoreAttempts = 0;
  bool _restoringScroll = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_rememberScrollPosition);
    unawaited(_loadSavedScrollPosition());
  }

  void _rememberScrollPosition() {
    if (_restoringScroll || !_scrollController.hasClients) return;
    final offset = _scrollController.offset;
    _scrollSaveTimer?.cancel();
    _scrollSaveTimer = Timer(const Duration(milliseconds: 60), () {
      unawaited(_saveScrollPosition(offset));
    });
  }

  Future<void> _saveScrollPosition(double offset) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_homeScrollKey, offset < 0 ? 0 : offset);
    } catch (_) {
      // Scroll saqlash asosiy ilovani hech qachon to‘xtatmasin.
    }
  }

  Future<void> _loadSavedScrollPosition() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getDouble(_homeScrollKey) ?? 0;
      if (!mounted || saved <= 0) return;
      _pendingScrollOffset = saved;
      _restoreSavedScrollPosition();
    } catch (_) {
      // Xotira ishlamasa oddiy scroll davom etadi.
    }
  }

  void _restoreSavedScrollPosition() {
    if (!mounted || _pendingScrollOffset == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _pendingScrollOffset == null) return;
      if (!_scrollController.hasClients) {
        if (_restoreAttempts++ < 12) {
          Future<void>.delayed(
            const Duration(milliseconds: 120),
            _restoreSavedScrollPosition,
          );
        }
        return;
      }

      final target = _pendingScrollOffset!;
      final max = _scrollController.position.maxScrollExtent;
      if (max <= 0 && target > 0 && _restoreAttempts++ < 12) {
        Future<void>.delayed(
          const Duration(milliseconds: 120),
          _restoreSavedScrollPosition,
        );
        return;
      }

      _restoringScroll = true;
      _scrollController.jumpTo(target.clamp(0.0, max).toDouble());
      _restoringScroll = false;

      if (max + 2 >= target || _restoreAttempts++ >= 12) {
        _pendingScrollOffset = null;
      } else {
        Future<void>.delayed(
          const Duration(milliseconds: 120),
          _restoreSavedScrollPosition,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollSaveTimer?.cancel();
    if (_scrollController.hasClients) {
      unawaited(_saveScrollPosition(_scrollController.offset));
    }
    _scrollController
      ..removeListener(_rememberScrollPosition)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_pendingScrollOffset != null) {
      _restoreSavedScrollPosition();
    }
"""

if old not in text:
    raise SystemExit('HomePageState marker not found')
text = text.replace(old, new, 1)

old_scroll = """        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
"""
new_scroll = """        child: CustomScrollView(
          controller: _scrollController,
          key: const PageStorageKey<String>('muhajeer-home-scroll'),
          physics: const AlwaysScrollableScrollPhysics(),
"""
if old_scroll not in text:
    raise SystemExit('Home CustomScrollView marker not found')
text = text.replace(old_scroll, new_scroll, 1)

path.write_text(text, encoding='utf-8')
print('iPhone scroll restore patch applied.')
