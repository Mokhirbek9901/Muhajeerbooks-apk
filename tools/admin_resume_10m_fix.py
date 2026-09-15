from pathlib import Path

CATALOG = Path('lib/catalog_resume.dart')
FAST = Path('lib/fast_store_shell.dart')
ADMIN = Path('lib/admin_ui.dart')


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if new in text:
        return text
    if old not in text:
        raise SystemExit(f'{label}: marker not found')
    return text.replace(old, new, 1)


catalog = CATALOG.read_text(encoding='utf-8')
fast = FAST.read_text(encoding='utf-8')
admin = ADMIN.read_text(encoding='utf-8')

# Admin panel ochiq paytda storefront'ning 1 daqiqalik mijoz timeouti
# navigatorni bosh sahifaga chiqarib yubormasin.
catalog = replace_once(
    catalog,
    """  DateTime? _awayAt;
  late SharedPreferences _prefs;
""",
    """  DateTime? _awayAt;
  bool _adminPanelActive = false;
  bool get adminPanelActive => _adminPanelActive;
  void setAdminPanelActive(bool value) => _adminPanelActive = value;
  late SharedPreferences _prefs;
""",
    'catalog admin-active flag',
)

fast = replace_once(
    fast,
    """  void _resetAfterAbsence() {
    if (!mounted) return;

    // 1+ daqiqa tashqarida qolinsa, ichki detail/checkout route'larini yopib,
""",
    """  void _resetAfterAbsence() {
    if (!mounted) return;
    // Admin panel o'zining alohida 10 daqiqalik resume qoidasi bilan boshqariladi.
    // Storefront timeouti admin route'larini hech qachon pop qilmasin.
    if (CatalogResume.instance.adminPanelActive) return;

    // 1+ daqiqa tashqarida qolinsa, ichki detail/checkout route'larini yopib,
""",
    'storefront must not reset active admin',
)

admin = replace_once(
    admin,
    """import 'finance_admin.dart';

const _navy = Color(0xFF10213D);
""",
    """import 'finance_admin.dart';
import 'catalog_resume.dart';

const _navy = Color(0xFF10213D);
""",
    'admin import catalog resume',
)

admin = replace_once(
    admin,
    """    api = _AdminApi(widget.secret);
    WidgetsBinding.instance.addObserver(this);
    _liveRefreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
""",
    """    api = _AdminApi(widget.secret);
    WidgetsBinding.instance.addObserver(this);
    CatalogResume.instance.setAdminPanelActive(true);
    _liveRefreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
""",
    'admin mark active',
)

admin = replace_once(
    admin,
    """  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _liveRefreshTimer?.cancel();
    super.dispose();
  }
""",
    """  void dispose() {
    CatalogResume.instance.setAdminPanelActive(false);
    WidgetsBinding.instance.removeObserver(this);
    _liveRefreshTimer?.cancel();
    super.dispose();
  }
""",
    'admin mark inactive',
)

old_resume = """    if (mounted) {
      setState(() {
        tab = 0;
        _loadedTabs.add(0);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).popUntil((route) => route.isFirst);
      });
    }
"""
new_resume = """    if (mounted) {
      // 10 daqiqagacha aynan turgan admin joyi saqlanadi. Faqat 10 daqiqadan
      // oshgandagina adminning o'z bosh paneliga qaytamiz; storefrontga emas.
      final dashboardRoute = ModalRoute.of(context);
      setState(() {
        tab = 0;
        _loadedTabs.add(0);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || dashboardRoute == null) return;
        Navigator.of(context).popUntil((route) => identical(route, dashboardRoute));
      });
    }
"""
admin = replace_once(admin, old_resume, new_resume, 'admin ten-minute reset target')

CATALOG.write_text(catalog, encoding='utf-8')
FAST.write_text(fast, encoding='utf-8')
ADMIN.write_text(admin, encoding='utf-8')
print('Admin resume behavior fixed: keep exact place for 10 minutes, then admin home.')
