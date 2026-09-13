from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text(encoding="utf-8")
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"Expected exactly one match in {path}, found {count}: {old[:100]!r}")
    p.write_text(text.replace(old, new, 1), encoding="utf-8")


def replace_all(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text(encoding="utf-8")
    if old not in text:
        raise SystemExit(f"Expected at least one match in {path}: {old!r}")
    p.write_text(text.replace(old, new), encoding="utf-8")


# 1) Customer catalog: never request private cost_price and filter active books at SQL/API level.
replace_once(
    "lib/app_state.dart",
    """  Future<List<Book>> fetchBooks({bool includeInactive = false}) async {\n    final data = await client\n        .from('books')\n        .select()\n        .order('created_at', ascending: false);\n    return (data as List)\n        .map((e) => Book.fromMap(Map<String, dynamic>.from(e as Map)))\n        .where((b) => includeInactive || b.isActive)\n        .toList();\n  }\n""",
    """  static const String _storefrontBookColumns =\n      'id,legacy_id,title,author,publisher,category,description,price,stock,'\n      'discount_percent,image_url,image_urls,is_active,cover_type,recommended,'\n      'created_at';\n\n  Future<List<Book>> fetchBooks({bool includeInactive = false}) async {\n    final data = includeInactive\n        ? await client\n              .from('books')\n              .select(_storefrontBookColumns)\n              .order('created_at', ascending: false)\n        : await client\n              .from('books')\n              .select(_storefrontBookColumns)\n              .eq('is_active', true)\n              .order('created_at', ascending: false);\n    return (data as List)\n        .map((e) => Book.fromMap(Map<String, dynamic>.from(e as Map)))\n        .toList();\n  }\n""",
)

# Customer catalog updates use a light safe poll instead of a full-row realtime subscription.
replace_once(
    "lib/app_state.dart",
    """  RealtimeChannel? _booksChannel;\n  Timer? _booksRealtimeDebounce;\n  Timer? _booksFallbackTimer;\n""",
    """  Timer? _booksFallbackTimer;\n""",
)
replace_once(
    "lib/app_state.dart",
    """  void _startLiveBooksSync() {\n    if (_backend == null || _booksChannel != null) return;\n\n    _booksChannel = Supabase.instance.client\n        .channel('muhajeer-books-catalog-live')\n        .onPostgresChanges(\n          event: PostgresChangeEvent.all,\n          schema: 'public',\n          table: 'books',\n          callback: (_) {\n            _booksRealtimeDebounce?.cancel();\n            _booksRealtimeDebounce = Timer(\n              const Duration(milliseconds: 180),\n              _refreshBooksQuietly,\n            );\n          },\n        )\n        .subscribe();\n\n    // Realtime uzilib qolgan holat uchun yengil zaxira tekshiruv.\n    _booksFallbackTimer = Timer.periodic(const Duration(seconds: 60), (_) {\n      unawaited(_refreshBooksQuietly());\n      unawaited(_checkRestockNotificationsQuietly());\n    });\n  }\n""",
    """  void _startLiveBooksSync() {\n    if (_backend == null || _booksFallbackTimer != null) return;\n\n    // Mijoz roli tannarx (cost_price) ustunini o‘qimaydi. Katalogni faqat\n    // public ustunlar bilan muntazam yangilaymiz; checkout baribir buyurtma\n    // tugmasida live stockni serverdan qayta tekshiradi.\n    _booksFallbackTimer = Timer.periodic(const Duration(seconds: 20), (_) {\n      unawaited(_refreshBooksQuietly());\n      unawaited(_checkRestockNotificationsQuietly());\n    });\n  }\n""",
)
replace_once(
    "lib/app_state.dart",
    """  @override\n  void dispose() {\n    _booksRealtimeDebounce?.cancel();\n    _booksFallbackTimer?.cancel();\n    _orderStatusTimer?.cancel();\n    final channel = _booksChannel;\n    if (channel != null) {\n      unawaited(Supabase.instance.client.removeChannel(channel));\n    }\n    super.dispose();\n  }\n""",
    """  @override\n  void dispose() {\n    _booksFallbackTimer?.cancel();\n    _orderStatusTimer?.cancel();\n    super.dispose();\n  }\n""",
)

# 2) Admin dashboard: lazy-create tabs and reduce background refresh pressure.
replace_once(
    "lib/admin_ui.dart",
    """  final _salesKey = GlobalKey<_SalesAdminState>();\n  final _customersKey = GlobalKey<_CustomersAdminState>();\n\n  static const titles = [\n""",
    """  final _salesKey = GlobalKey<_SalesAdminState>();\n  final _customersKey = GlobalKey<_CustomersAdminState>();\n  final Set<int> _loadedTabs = <int>{0};\n\n  static const titles = [\n""",
)
replace_once(
    "lib/admin_ui.dart",
    """    _liveRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {\n""",
    """    _liveRefreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {\n""",
)
replace_once(
    "lib/admin_ui.dart",
    """  @override\n  void dispose() {\n    _liveRefreshTimer?.cancel();\n    super.dispose();\n  }\n\n  @override\n  Widget build(BuildContext context) {\n    final pages = [\n      _OverviewAdmin(key: _overviewKey, api: api),\n      _BooksAdmin(key: _booksKey, api: api),\n      _InventoryAdmin(key: _inventoryKey, api: api),\n      _OrdersAdmin(key: _ordersKey, api: api),\n      _SalesAdmin(key: _salesKey, api: api),\n      _CustomersAdmin(key: _customersKey, api: api),\n      FinanceAdminPage(secret: widget.secret),\n      _DiscountAdmin(api: api),\n    ];\n""",
    """  @override\n  void dispose() {\n    _liveRefreshTimer?.cancel();\n    super.dispose();\n  }\n\n  void _selectTab(int value) {\n    if (value == tab && _loadedTabs.contains(value)) return;\n    setState(() {\n      tab = value;\n      _loadedTabs.add(value);\n    });\n  }\n\n  @override\n  Widget build(BuildContext context) {\n    final pages = <Widget>[\n      _loadedTabs.contains(0)\n          ? _OverviewAdmin(key: _overviewKey, api: api)\n          : const SizedBox.shrink(),\n      _loadedTabs.contains(1)\n          ? _BooksAdmin(key: _booksKey, api: api)\n          : const SizedBox.shrink(),\n      _loadedTabs.contains(2)\n          ? _InventoryAdmin(key: _inventoryKey, api: api)\n          : const SizedBox.shrink(),\n      _loadedTabs.contains(3)\n          ? _OrdersAdmin(key: _ordersKey, api: api)\n          : const SizedBox.shrink(),\n      _loadedTabs.contains(4)\n          ? _SalesAdmin(key: _salesKey, api: api)\n          : const SizedBox.shrink(),\n      _loadedTabs.contains(5)\n          ? _CustomersAdmin(key: _customersKey, api: api)\n          : const SizedBox.shrink(),\n      _loadedTabs.contains(6)\n          ? FinanceAdminPage(secret: widget.secret)\n          : const SizedBox.shrink(),\n      _loadedTabs.contains(7)\n          ? _DiscountAdmin(api: api)\n          : const SizedBox.shrink(),\n    ];\n""",
)
replace_all(
    "lib/admin_ui.dart",
    "onDestinationSelected: (v) => setState(() => tab = v),",
    "onDestinationSelected: _selectTab,",
)
replace_all("lib/admin_ui.dart", "5 soniyalik", "15 soniyalik")
replace_all("lib/admin_ui.dart", "Har 5 soniyadagi", "Har 15 soniyadagi")

# 3) Share links now have a crawlable server-rendered preview route; old query links remain supported.
Path("lib/book_links.dart").write_text(
    """const bookShareOrigin = 'https://muhajeer-books-live-production.up.railway.app';\n\nUri bookShareLink(String id) =>\n    Uri.parse(bookShareOrigin).replace(path: '/share/$id');\n\nString? sharedBookId(Uri uri) {\n  String? id = uri.queryParameters['book'];\n  if ((id == null || id.isEmpty) &&\n      uri.pathSegments.length == 2 &&\n      uri.pathSegments.first == 'share') {\n    id = uri.pathSegments[1];\n  }\n  if (id == null ||\n      !RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')\n          .hasMatch(id)) return null;\n  return id.toLowerCase();\n}\n""",
    encoding="utf-8",
)

# 4) iOS home-screen icon aliases and dynamic share preview proxy.
replace_once(
    "web/index.html",
    '<link rel="apple-touch-icon" href="icons/Icon-192.png">',
    '<link rel="apple-touch-icon" sizes="180x180" href="/apple-touch-icon.png">',
)

nginx = Path("nginx.conf")
nginx_text = nginx.read_text(encoding="utf-8")
anchor = """  # Flutter web uchun Supabase same-origin proxy.\n"""
if anchor not in nginx_text:
    raise SystemExit("nginx insertion anchor not found")
insert = """  # Kitob ulashish havolasi uchun crawler-friendly Open Graph preview.\n  # Edge Function faqat public kitob maydonlarini qaytaradi va keyin ilovaga yo‘naltiradi.\n  location ~ ^/share/([0-9a-fA-F-]{36})$ {\n    rewrite ^/share/([0-9a-fA-F-]{36})$ /functions/v1/book-share-preview?id=$1 break;\n    proxy_pass https://rytfhjvhjxnbhgitowho.supabase.co;\n    proxy_http_version 1.1;\n    proxy_set_header Host rytfhjvhjxnbhgitowho.supabase.co;\n    proxy_ssl_server_name on;\n    proxy_ssl_name rytfhjvhjxnbhgitowho.supabase.co;\n    proxy_read_timeout 30s;\n    add_header X-Content-Type-Options \"nosniff\" always;\n    add_header X-Frame-Options \"DENY\" always;\n    add_header Referrer-Policy \"no-referrer\" always;\n    add_header Strict-Transport-Security \"max-age=31536000\" always;\n  }\n\n  # Safari avtomatik so‘raydigan standart icon nomlari 404 qaytarmasin.\n  location = /apple-touch-icon.png {\n    try_files /icons/Icon-192.png =404;\n    add_header Cache-Control \"public, max-age=604800, immutable\";\n    add_header X-Content-Type-Options \"nosniff\" always;\n  }\n\n  location = /apple-touch-icon-precomposed.png {\n    try_files /icons/Icon-192.png =404;\n    add_header Cache-Control \"public, max-age=604800, immutable\";\n    add_header X-Content-Type-Options \"nosniff\" always;\n  }\n\n"""
if "book-share-preview" in nginx_text:
    raise SystemExit("nginx share preview patch already present")
nginx.write_text(nginx_text.replace(anchor, insert + anchor, 1), encoding="utf-8")

# 5) Reproducible, faster web build: pin the known-good Flutter image and don't regenerate web/.
Path("Dockerfile").write_text(
    """FROM ghcr.io/cirruslabs/flutter:stable@sha256:46691e311715845de03a3ba4753a475476936805b29431b1f00f1816981033f8 AS build\nWORKDIR /app\nCOPY . .\nRUN flutter pub get\nRUN flutter build web --release\n\nFROM nginx:alpine\nCOPY nginx.conf /etc/nginx/conf.d/default.conf\nCOPY --from=build /app/build/web /usr/share/nginx/html\nEXPOSE 8080\nCMD [\"nginx\", \"-g\", \"daemon off;\"]\n""",
    encoding="utf-8",
)

# Sanity checks: private field must no longer appear in the public storefront select.
app_state = Path("lib/app_state.dart").read_text(encoding="utf-8")
fetch_block = app_state.split("Future<List<Book>> fetchBooks", 1)[1].split("Future<void> saveBook", 1)[0]
if "cost_price" in fetch_block or ".select()" in fetch_block:
    raise SystemExit("Unsafe storefront books query remains")

admin_ui = Path("lib/admin_ui.dart").read_text(encoding="utf-8")
if "Duration(seconds: 5)" in admin_ui:
    raise SystemExit("5-second admin polling remains")
if "onDestinationSelected: (v) => setState(() => tab = v)" in admin_ui:
    raise SystemExit("Eager tab selection remains")

print("Live storefront hardening patch applied successfully")
