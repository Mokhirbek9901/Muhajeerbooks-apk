from pathlib import Path

path = Path('lib/store_ui.dart')
text = path.read_text(encoding='utf-8')


def replace_once(old: str, new: str, label: str) -> None:
    global text
    if new in text:
        return
    if old not in text:
        raise SystemExit(f'{label}: marker not found')
    text = text.replace(old, new, 1)


# SharedPreferences/localStorage yozuvi scrollning o'zida ishlamasin.
# Pozitsiya RAM'da har frame saqlanadi, diskka faqat scroll to'xtaganda yoziladi.
replace_once(
    """  Timer? _saveTimer;
  double? _pendingRestore;
""",
    """  double? _pendingRestore;
""",
    'remove scroll timer field',
)
replace_once(
    """    _saveTimer?.cancel();
    _pendingRestore = null;
""",
    """    _pendingRestore = null;
""",
    'remove reset timer work',
)
replace_once(
    """    _scrollMemory[storageKey] = value;
    if (_saveTimer != null) return;
    _saveTimer = Timer(const Duration(milliseconds: 900), () {
      _saveTimer = null;
      final latest = _scrollMemory[storageKey] ?? value;
      unawaited(_write(latest));
    });
  }

  Future<void> _write(double value) async {
""",
    """    _scrollMemory[storageKey] = value;
  }

  void _persistWhenIdle() {
    if (_disposed || !hasClients) return;
    if (positions.any((p) => p.isScrollingNotifier.value)) return;
    final latest = _scrollMemory[storageKey];
    if (latest != null) unawaited(_write(latest));
  }

  Future<void> _write(double value) async {
""",
    'persist scroll only when idle',
)
replace_once(
    """  void attach(ScrollPosition position) {
    super.attach(position);
    _scheduleRestore();
  }

  void _scheduleRestore() {
""",
    """  void attach(ScrollPosition position) {
    super.attach(position);
    position.isScrollingNotifier.addListener(_persistWhenIdle);
    _scheduleRestore();
  }

  @override
  void detach(ScrollPosition position) {
    position.isScrollingNotifier.removeListener(_persistWhenIdle);
    super.detach(position);
  }

  void _scheduleRestore() {
""",
    'scroll activity listener',
)
replace_once(
    """    _disposed = true;
    _saveTimer?.cancel();
    if (hasClients) {
""",
    """    _disposed = true;
    if (hasClients) {
""",
    'dispose without scroll timer',
)

# Retina/iPhone ekranlarda 300px katalog rasmi xira ko'rinadi.
# 480px ikki ustunli kartalar uchun tiniqroq, lekin original/full-size rasmni
# dekod qilmaydi; shu sabab scroll optimizatsiyasi saqlanadi.
text = text.replace('cacheWidth: 360,', 'cacheWidth: 480,')
text = text.replace('cacheWidth: 300,', 'cacheWidth: 480,')
text = text.replace('filterQuality: FilterQuality.low,', 'filterQuality: FilterQuality.medium,')

# Stateless kitob kartalari keepAlive talab qilmaydi; bu uzun katalogda xotira va
# element boshqaruvi xarajatini kamaytiradi.
replace_once(
    """                      delegate: SliverChildBuilderDelegate(
                        (context, i) => BookCard(book: books[i]),
                        childCount: books.length,
                      ),
""",
    """                      delegate: SliverChildBuilderDelegate(
                        (context, i) => BookCard(book: books[i]),
                        childCount: books.length,
                        addAutomaticKeepAlives: false,
                        addRepaintBoundaries: true,
                      ),
""",
    'home grid delegate tuning',
)
replace_once(
    """  Widget build(BuildContext context) => GridView.builder(
    controller: _controller,
    key: PageStorageKey<String>('grid:${widget.storageKey}'),
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
    itemCount: widget.books.length,
""",
    """  Widget build(BuildContext context) => GridView.builder(
    controller: _controller,
    key: PageStorageKey<String>('grid:${widget.storageKey}'),
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
    addAutomaticKeepAlives: false,
    addRepaintBoundaries: true,
    itemCount: widget.books.length,
""",
    'browse grid keepalive tuning',
)

# Katta hero statik painter bo'lgani uchun alohida repaint boundaryda ushlanadi.
replace_once(
    """              sliver: SliverToBoxAdapter(child: _DeliveryPromoCard()),
""",
    """              sliver: SliverToBoxAdapter(
                child: RepaintBoundary(child: _DeliveryPromoCard()),
              ),
""",
    'hero repaint boundary',
)

path.write_text(text, encoding='utf-8')
print('Strong scroll-jank fix applied with sharper catalog covers.')
