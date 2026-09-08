from pathlib import Path


def replace_required(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        if new in text:
            return text
        raise SystemExit(f"Could not find expected {label} block")
    return text.replace(old, new, 1)


# Keep the screenshot storefront: no extra global strip above the original header.
main_path = Path("lib/main.dart")
main = main_path.read_text(encoding="utf-8")
main = replace_required(
    main,
    """        builder: (context, child) => _ProfessionalAppFrame(\n          child: child ?? const SizedBox.shrink(),\n        ),""",
    """        builder: (context, child) => ColoredBox(\n          color: AppColors.background,\n          child: child ?? const SizedBox.shrink(),\n        ),""",
    "MaterialApp builder",
)
marker = "\nclass _ProfessionalAppFrame extends StatelessWidget"
if marker in main:
    main = main.split(marker, 1)[0].rstrip() + "\n"
main_path.write_text(main, encoding="utf-8")


# Restore the original home header shown in the screenshots.
store_path = Path("lib/store_ui.dart")
store = store_path.read_text(encoding="utf-8")
owner_header = """                    const SizedBox(height: 2),\n                    const Text(\n                      'Mohirbek Ismoilov',\n                      style: TextStyle(\n                        color: UzbekCustomerColors.navy,\n                        fontSize: 11.5,\n                        fontWeight: FontWeight.w900,\n                      ),\n                    ),\n                    const SizedBox(height: 1),\n                    const Text(\n                      'Koreyadagi O’zbek kitobxonlari uchun',\n                      style: TextStyle(\n                        color: UzbekCustomerColors.textMuted,\n                        fontSize: 10.8,\n                        fontWeight: FontWeight.w700,\n                      ),\n                    ),"""
original_header = """                    const SizedBox(height: 2),\n                    const Text(\n                      'Koreyadagi O’zbek kitobxonlari uchun',\n                      style: TextStyle(\n                        color: UzbekCustomerColors.textMuted,\n                        fontSize: 11.5,\n                        fontWeight: FontWeight.w700,\n                      ),\n                    ),"""
store = replace_required(store, owner_header, original_header, "original store header")
store_path.write_text(store, encoding="utf-8")


# First entry: name + phone only. Accept Uzbekistan and Korea mobile numbers.
auth_path = Path("lib/auth_gate.dart")
auth = auth_path.read_text(encoding="utf-8")

owner_welcome = """                          MuhajeerLogoBadge(size: 88, radius: 24),\n                          SizedBox(height: 11),\n                          Text(\n                            'Mohirbek Ismoilov',\n                            textAlign: TextAlign.center,\n                            style: TextStyle(\n                              color: AppColors.gold,\n                              fontSize: 13,\n                              fontWeight: FontWeight.w900,\n                            ),\n                          ),\n                          SizedBox(height: 7),\n                          Text(\n                            'Muhajeer Books’ga\\nxush kelibsiz',"""
plain_welcome = """                          MuhajeerLogoBadge(size: 88, radius: 24),\n                          SizedBox(height: 15),\n                          Text(\n                            'Muhajeer Books’ga\\nxush kelibsiz',"""
auth = replace_required(auth, owner_welcome, plain_welcome, "plain welcome")

old_saved_validator = """  bool _isValidSavedCustomer(Map<String, String> customer) {\n    final savedName = (customer['name'] ?? '').trim();\n    final savedPhone = (customer['phone'] ?? '').replaceAll(RegExp(r'\\D'), '');\n    return savedName.length >= 2 && savedPhone.length >= 9;\n  }"""
new_saved_validator = """  String? _normalizePhone(String raw) {\n    var digits = raw.replaceAll(RegExp(r'\\D'), '');\n    if (digits.startsWith('00')) digits = digits.substring(2);\n\n    // O‘zbekiston: +998 XX XXX XX XX, 998XXXXXXXXX yoki mahalliy 9 raqam.\n    if (digits.length == 12 && digits.startsWith('998')) {\n      return '+$digits';\n    }\n    if (digits.length == 9 && !digits.startsWith('0')) {\n      return '+998$digits';\n    }\n\n    // Koreya: 010-XXXX-XXXX yoki +82 10-XXXX-XXXX.\n    if (digits.length == 11 && digits.startsWith('010')) {\n      return '+82${digits.substring(1)}';\n    }\n    if (digits.length == 12 && digits.startsWith('8210')) {\n      return '+$digits';\n    }\n\n    return null;\n  }\n\n  bool _isValidSavedCustomer(Map<String, String> customer) {\n    final savedName = (customer['name'] ?? '').trim();\n    final savedPhone = (customer['phone'] ?? '').trim();\n    return savedName.length >= 2 && _normalizePhone(savedPhone) != null;\n  }"""
auth = replace_required(
    auth,
    old_saved_validator,
    new_saved_validator,
    "Uzbek/Korea saved phone validator",
)

old_continue_head = """    final fullName = name.text.trim().replaceAll(RegExp(r'\\s+'), ' ');\n    final phoneValue = phone.text.trim();\n    final digits = phoneValue.replaceAll(RegExp(r'\\D'), '');\n\n    if (fullName.length < 2) {\n      setState(() => error = 'Ismingizni kiriting.');\n      return;\n    }\n    if (digits.length < 9 || digits.length > 15) {\n      setState(() => error = 'Telefon raqamingizni to‘liq kiriting.');\n      return;\n    }"""
new_continue_head = """    final fullName = name.text.trim().replaceAll(RegExp(r'\\s+'), ' ');\n    final rawPhone = phone.text.trim();\n    final phoneValue = _normalizePhone(rawPhone);\n\n    if (fullName.length < 2) {\n      setState(() => error = 'Ismingizni kiriting.');\n      return;\n    }\n    if (phoneValue == null) {\n      setState(\n        () => error =\n            'O‘zbekiston (+998) yoki Koreya (010 / +82) telefon raqamini to‘liq kiriting.',\n      );\n      return;\n    }"""
auth = replace_required(auth, old_continue_head, new_continue_head, "phone normalization")

auth = auth.replace(
    "await state.setAuthenticatedCustomer(fullName, phoneValue);",
    "await state.setAuthenticatedCustomer(fullName, phoneValue);",
    1,
)

auth = replace_required(
    auth,
    """                                hintText: '010-1234-5678',\n                                prefixIcon: Icon(Icons.phone_iphone_rounded),\n                                helperText: 'Koreya raqamini 010 bilan yozishingiz mumkin.',""",
    """                                hintText: '+998 90 123 45 67 yoki 010-1234-5678',\n                                prefixIcon: Icon(Icons.phone_iphone_rounded),\n                                helperText:\n                                    'O‘zbekiston +998 va Koreya 010 / +82 raqamlari qabul qilinadi.',""",
    "phone input help",
)

auth_path.write_text(auth, encoding="utf-8")

print("Screenshot storefront restored; Uzbekistan/Korea name+phone entry enabled.")
