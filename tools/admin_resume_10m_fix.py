from pathlib import Path

CATALOG = Path('lib/catalog_resume.dart')
ADMIN = Path('lib/admin_ui.dart')
NAV = Path('lib/navigation_sync.dart')
MAIN = Path('lib/main.dart')
SESSION = Path('lib/admin_resume_session.dart')


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if new in text:
        return text
    if old not in text:
        raise SystemExit(f'{label}: marker not found')
    return text.replace(old, new, 1)


catalog = CATALOG.read_text(encoding='utf-8')
admin = ADMIN.read_text(encoding='utf-8')
nav = NAV.read_text(encoding='utf-8')
main = MAIN.read_text(encoding='utf-8')

# 1) Storefrontning 1 daqiqalik timeouti admin ochiq paytda umuman ishlamasin.
catalog = replace_once(
    catalog,
    """      if (leftAt != null && expired(leftAt, _now())) {
        // Notify synchronously so a pending scroll restore cannot win the race.
""",
    """      if (leftAt != null &&
          expired(leftAt, _now()) &&
          !_adminPanelActive) {
        // Notify synchronously so a pending scroll restore cannot win the race.
""",
    'catalog admin timeout isolation',
)

# 2) iPhone/Safari backgrounddan qaytganda paydo bo‘lishi mumkin bo‘lgan
#    popstate admin route'ini tasodifan yopib yubormasin.
nav = replace_once(
    nav,
    """import 'browser_history.dart';
""",
    """import 'browser_history.dart';
import 'catalog_resume.dart';
""",
    'navigation import catalog resume',
)
nav = replace_once(
    nav,
    """      _subscription = browserPopEvents.listen((_) async {
        if (_popInFlight) return;
        final navigator = widget.navigatorKey.currentState;
""",
    """      _subscription = browserPopEvents.listen((_) async {
        if (_popInFlight) return;
        if (CatalogResume.instance.adminPanelActive) {
          // iOS web-app resume ba'zan popstate yuboradi. Admin ochiq bo'lsa
          // buni back deb qabul qilmaymiz va guardni qayta tiklaymiz.
          scheduleMicrotask(restoreBrowserHistoryGuard);
          return;
        }
        final navigator = widget.navigatorKey.currentState;
""",
    'ignore accidental browser pop while admin active',
)

# 3) 10 daqiqalik admin resume holatini secure storage + prefsda saqlaymiz.
SESSION.write_text(
    """import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminResumeSnapshot {
  const AdminResumeSnapshot({required this.secret, required this.tab});

  final String secret;
  final int tab;
}

class AdminResumeSession {
  AdminResumeSession._();

  static const timeout = Duration(minutes: 10);
  static const _secretKey = 'muhajeer_admin_resume_secret_v2';
  static const _activeKey = 'muhajeer_admin_resume_active_v2';
  static const _seenAtKey = 'muhajeer_admin_resume_seen_at_v2';
  static const _tabKey = 'muhajeer_admin_resume_tab_v2';
  static const FlutterSecureStorage _secure = FlutterSecureStorage();

  static Future<void> start(String secret, {required int tab}) async {
    final value = secret.trim();
    if (value.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      _secure.write(key: _secretKey, value: value),
      prefs.setBool(_activeKey, true),
      prefs.setInt(_seenAtKey, DateTime.now().millisecondsSinceEpoch),
      prefs.setInt(_tabKey, tab.clamp(0, 7)),
    ]);
  }

  static Future<void> touch({required int tab}) async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_activeKey) ?? false)) return;
    await Future.wait([
      prefs.setInt(_seenAtKey, DateTime.now().millisecondsSinceEpoch),
      prefs.setInt(_tabKey, tab.clamp(0, 7)),
    ]);
  }

  static Future<AdminResumeSnapshot?> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool(_activeKey) ?? false)) return null;

      final seenAt = prefs.getInt(_seenAtKey);
      if (seenAt == null) {
        await clear();
        return null;
      }
      final lastSeen = DateTime.fromMillisecondsSinceEpoch(seenAt);
      final age = DateTime.now().difference(lastSeen);
      if (age.isNegative || age > timeout) {
        await clear();
        return null;
      }

      final secret = (await _secure.read(key: _secretKey) ?? '').trim();
      if (secret.isEmpty) {
        await clear();
        return null;
      }
      final tab = (prefs.getInt(_tabKey) ?? 0).clamp(0, 7);
      return AdminResumeSnapshot(secret: secret, tab: tab);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        _secure.delete(key: _secretKey),
        prefs.remove(_activeKey),
        prefs.remove(_seenAtKey),
        prefs.remove(_tabKey),
      ]);
    } catch (_) {
      // Resume cache ishlamasa adminning o'zi ishlashda davom etadi.
    }
  }
}
""",
    encoding='utf-8',
)

# 4) Admin dashboard joriy tabni saqlaydi va lifecycle holatini 10 daqiqagacha
#    qayta tiklash uchun yozib boradi.
admin = replace_once(
    admin,
    """import 'catalog_resume.dart';

const _navy = Color(0xFF10213D);
""",
    """import 'catalog_resume.dart';
import 'admin_resume_session.dart';

const _navy = Color(0xFF10213D);
""",
    'admin import resume session',
)
admin = replace_once(
    admin,
    """class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key, required this.secret});
  final String secret;
""",
    """class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({
    super.key,
    required this.secret,
    this.initialTab = 0,
  });
  final String secret;
  final int initialTab;
""",
    'admin initial tab constructor',
)
admin = replace_once(
    admin,
    """class _AdminDashboardPageState extends State<AdminDashboardPage> with WidgetsBindingObserver {
  int tab = 0;
""",
    """class _AdminDashboardPageState extends State<AdminDashboardPage> with WidgetsBindingObserver {
  late int tab;
""",
    'admin late tab',
)
admin = replace_once(
    admin,
    """  DateTime? _awayAt;
  static const _resumeTimeout = Duration(minutes: 10);
""",
    """  DateTime? _awayAt;
  AppLifecycleState _lastLifecycleState = AppLifecycleState.resumed;
  static const _resumeTimeout = Duration(minutes: 10);
""",
    'admin lifecycle state tracking',
)
admin = replace_once(
    admin,
    """  void initState() {
    super.initState();
    api = _AdminApi(widget.secret);
    WidgetsBinding.instance.addObserver(this);
    CatalogResume.instance.setAdminPanelActive(true);
    _liveRefreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
""",
    """  void initState() {
    super.initState();
    tab = widget.initialTab.clamp(0, titles.length - 1);
    _loadedTabs.add(tab);
    api = _AdminApi(widget.secret);
    WidgetsBinding.instance.addObserver(this);
    CatalogResume.instance.setAdminPanelActive(true);
    unawaited(AdminResumeSession.start(widget.secret, tab: tab));
    _liveRefreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      unawaited(AdminResumeSession.touch(tab: tab));
""",
    'admin persist session on init',
)
admin = replace_once(
    admin,
    """  void dispose() {
    CatalogResume.instance.setAdminPanelActive(false);
    WidgetsBinding.instance.removeObserver(this);
    _liveRefreshTimer?.cancel();
    super.dispose();
  }
""",
    """  void dispose() {
    CatalogResume.instance.setAdminPanelActive(false);
    if (_lastLifecycleState == AppLifecycleState.resumed) {
      // Foydalanuvchi adminni ataylab yopsa keyingi refreshda qayta ochilmasin.
      unawaited(AdminResumeSession.clear());
    }
    WidgetsBinding.instance.removeObserver(this);
    _liveRefreshTimer?.cancel();
    super.dispose();
  }
""",
    'admin clear intentional exit only',
)
admin = replace_once(
    admin,
    """  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _awayAt ??= DateTime.now();
      return;
    }
    if (state != AppLifecycleState.resumed) return;

    final leftAt = _awayAt;
    _awayAt = null;
    if (leftAt == null || DateTime.now().difference(leftAt) <= _resumeTimeout) {
      return;
    }
""",
    """  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lastLifecycleState = state;
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _awayAt ??= DateTime.now();
      unawaited(AdminResumeSession.touch(tab: tab));
      return;
    }
    if (state != AppLifecycleState.resumed) return;

    final leftAt = _awayAt;
    _awayAt = null;
    if (leftAt == null || DateTime.now().difference(leftAt) <= _resumeTimeout) {
      unawaited(AdminResumeSession.touch(tab: tab));
      return;
    }
""",
    'admin lifecycle persist',
)
admin = replace_once(
    admin,
    """      setState(() {
        tab = 0;
        _loadedTabs.add(0);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
""",
    """      setState(() {
        tab = 0;
        _loadedTabs.add(0);
      });
      unawaited(AdminResumeSession.touch(tab: 0));
      WidgetsBinding.instance.addPostFrameCallback((_) {
""",
    'admin reset session tab after 10m',
)
admin = replace_once(
    admin,
    """    setState(() {
      tab = value;
      _loadedTabs.add(value);
    });
  }
""",
    """    setState(() {
      tab = value;
      _loadedTabs.add(value);
    });
    unawaited(AdminResumeSession.touch(tab: value));
  }
""",
    'admin persist selected tab',
)

# 5) To'liq web-view reload bo'lsa ham 10 daqiqa ichida admin route qayta ochiladi.
main = replace_once(
    main,
    """import 'admin_ui.dart';
import 'app_state.dart';
""",
    """import 'admin_ui.dart';
import 'admin_resume_session.dart';
import 'app_state.dart';
""",
    'main import admin resume session',
)
main = replace_once(
    main,
    """              : (backendConfigured
                    ? const CustomerAuthGate()
                    : const FastStoreShell()),
""",
    """              : _AdminResumeBootstrap(
                  child: backendConfigured
                      ? const CustomerAuthGate()
                      : const FastStoreShell(),
                ),
""",
    'main wrap storefront with admin resume bootstrap',
)
if 'class _AdminResumeBootstrap extends StatefulWidget' not in main:
    main += """

class _AdminResumeBootstrap extends StatefulWidget {
  const _AdminResumeBootstrap({required this.child});

  final Widget child;

  @override
  State<_AdminResumeBootstrap> createState() => _AdminResumeBootstrapState();
}

class _AdminResumeBootstrapState extends State<_AdminResumeBootstrap> {
  bool _restoreStarted = false;

  @override
  void initState() {
    super.initState();
    unawaited(_restoreAdminIfNeeded());
  }

  Future<void> _restoreAdminIfNeeded() async {
    if (_restoreStarted) return;
    _restoreStarted = true;
    final snapshot = await AdminResumeSession.restore();
    if (!mounted || snapshot == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: 'mb:admin-resume'),
          builder: (_) => AdminDashboardPage(
            secret: snapshot.secret,
            initialTab: snapshot.tab,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
"""

CATALOG.write_text(catalog, encoding='utf-8')
ADMIN.write_text(admin, encoding='utf-8')
NAV.write_text(nav, encoding='utf-8')
MAIN.write_text(main, encoding='utf-8')
print('Robust admin 10-minute resume applied, including iPhone web reload/popstate protection.')
