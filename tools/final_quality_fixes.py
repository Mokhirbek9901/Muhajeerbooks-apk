from pathlib import Path


def replace_required(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        if new in text:
            return text
        raise SystemExit(f"Could not find {label}")
    return text.replace(old, new, 1)


# ---------- app_state.dart ----------
p = Path("lib/app_state.dart")
s = p.read_text(encoding="utf-8")

old_logout = """  Future<void> signOutCustomer() async {
    try {
      if (backendConfigured) {
        await Supabase.instance.client.auth.signOut();
      }
    } catch (_) {
      // Local logout must still work even if the network is unavailable.
    }
    savedCustomer = const {'name': '', 'phone': '', 'address': ''};
    customerVerified = false;
    await _local.clearCustomer();
    notifyListeners();
  }
"""
new_logout = """  Future<void> signOutCustomer() async {
    // Profil lokal qurilmada saqlanadi. Uni tarmoq javobini kutmasdan darhol
    // tozalaymiz, shuning uchun tugma internet sust bo‘lsa ham ishlaydi.
    savedCustomer = const {'name': '', 'phone': '', 'address': ''};
    customerVerified = false;
    await _local.clearCustomer();
    notifyListeners();

    if (backendConfigured) {
      unawaited(
        Supabase.instance.client.auth.signOut().catchError((_) {}),
      );
    }
  }
"""
s = replace_required(s, old_logout, new_logout, "local-first profile clear")
p.write_text(s, encoding="utf-8")


# ---------- store_ui.dart ----------
p = Path("lib/store_ui.dart")
s = p.read_text(encoding="utf-8")

phone_helper_anchor = """final _money = NumberFormat('#,###', 'en_US');
String won(int value) => '₩${_money.format(value)}';
"""
phone_helper_new = """final _money = NumberFormat('#,###', 'en_US');
String won(int value) => '₩${_money.format(value)}';

bool _isSupportedCustomerPhone(String raw) {
  var digits = raw.replaceAll(RegExp(r'\\D'), '');
  if (digits.startsWith('00')) digits = digits.substring(2);

  // O‘zbekiston: +998 XX XXX XX XX, 998XXXXXXXXX yoki mahalliy 9 raqam.
  if (digits.length == 12 && digits.startsWith('998')) return true;
  if (digits.length == 9 && !digits.startsWith('0')) return true;

  // Koreya: 010-XXXX-XXXX yoki +82 10-XXXX-XXXX.
  if (digits.length == 11 && digits.startsWith('010')) return true;
  if (digits.length == 12 && digits.startsWith('8210')) return true;
  return false;
}
"""
s = replace_required(s, phone_helper_anchor, phone_helper_new, "UZ/KR phone helper")

old_phone = """                    TextFormField(
                      controller: phone,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Telefon raqam',
                        hintText: '010-1234-5678',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: (v) =>
                          v == null ||
                              v.replaceAll(RegExp(r'\\D'), '').length < 7
                          ? 'Telefon raqamni to‘liq kiriting'
                          : null,
                    ),
"""
new_phone = """                    TextFormField(
                      controller: phone,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Telefon raqam',
                        hintText: '+998 90 123 45 67 yoki 010-1234-5678',
                        helperText:
                            'O‘zbekiston +998 va Koreya 010 / +82 raqamlari qabul qilinadi.',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: (v) => !_isSupportedCustomerPhone(v ?? '')
                          ? 'O‘zbekiston (+998) yoki Koreya (010 / +82) raqamini to‘liq kiriting'
                          : null,
                    ),
"""
s = replace_required(s, old_phone, new_phone, "checkout phone validation")

old_logout_ui = """          IconButton(
            tooltip: 'Hisobdan chiqish',
            onPressed: () async {
              final shouldLogout = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('Hisobdan chiqish'),
                  content: const Text(
                    'Haqiqatan ham hisobdan chiqmoqchimisiz?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Yo‘q'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('Chiqish'),
                    ),
                  ],
                ),
              );
              if (shouldLogout != true || !context.mounted) return;
              await context.read<AppState>().signOutCustomer();
            },
            icon: const Icon(Icons.logout_rounded),
          ),
"""
new_logout_ui = """          IconButton(
            tooltip: 'Profil ma’lumotlarini tozalash',
            onPressed: () async {
              final shouldClear = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('Profil ma’lumotlarini tozalash'),
                  content: const Text(
                    'Saqlangan ism, telefon va manzil shu qurilmadan o‘chiriladi. Do‘kondan foydalanishda davom etasiz.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Bekor qilish'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('Tozalash'),
                    ),
                  ],
                ),
              );
              if (shouldClear != true || !context.mounted) return;
              await context.read<AppState>().signOutCustomer();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Profil ma’lumotlari tozalandi.')),
              );
            },
            icon: const Icon(Icons.person_remove_alt_1_outlined),
          ),
"""
s = replace_required(s, old_logout_ui, new_logout_ui, "profile clear wording")

p.write_text(s, encoding="utf-8")
print("Final customer UX quality fixes applied.")
