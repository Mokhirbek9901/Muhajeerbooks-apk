from pathlib import Path


def replace_required(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        if new in text:
            return text
        raise SystemExit(f"Could not find expected {label} block")
    return text.replace(old, new, 1)


# Keep the original storefront layout. The customer/admin functionality stays,
# but the extra global owner strip introduced later is removed.
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


# Put the owner's name inside the original Muhajeer Books header instead of
# creating a separate bar above the old design.
store_path = Path("lib/store_ui.dart")
store = store_path.read_text(encoding="utf-8")
old_header_subtitle = """                    const SizedBox(height: 2),\n                    const Text(\n                      'Koreyadagi O’zbek kitobxonlari uchun',\n                      style: TextStyle(\n                        color: UzbekCustomerColors.textMuted,\n                        fontSize: 11.5,\n                        fontWeight: FontWeight.w700,\n                      ),\n                    ),"""
new_header_subtitle = """                    const SizedBox(height: 2),\n                    const Text(\n                      'Mohirbek Ismoilov',\n                      style: TextStyle(\n                        color: UzbekCustomerColors.navy,\n                        fontSize: 11.5,\n                        fontWeight: FontWeight.w900,\n                      ),\n                    ),\n                    const SizedBox(height: 1),\n                    const Text(\n                      'Koreyadagi O’zbek kitobxonlari uchun',\n                      style: TextStyle(\n                        color: UzbekCustomerColors.textMuted,\n                        fontSize: 10.8,\n                        fontWeight: FontWeight.w700,\n                      ),\n                    ),"""
store = replace_required(
    store,
    old_header_subtitle,
    new_header_subtitle,
    "store header subtitle",
)
store_path.write_text(store, encoding="utf-8")


# Keep the free first-entry flow, but brand it consistently with the old app.
auth_path = Path("lib/auth_gate.dart")
auth = auth_path.read_text(encoding="utf-8")
old_welcome = """                          MuhajeerLogoBadge(size: 88, radius: 24),\n                          SizedBox(height: 15),\n                          Text(\n                            'Muhajeer Books’ga\\nxush kelibsiz',"""
new_welcome = """                          MuhajeerLogoBadge(size: 88, radius: 24),\n                          SizedBox(height: 11),\n                          Text(\n                            'Mohirbek Ismoilov',\n                            textAlign: TextAlign.center,\n                            style: TextStyle(\n                              color: AppColors.gold,\n                              fontSize: 13,\n                              fontWeight: FontWeight.w900,\n                            ),\n                          ),\n                          SizedBox(height: 7),\n                          Text(\n                            'Muhajeer Books’ga\\nxush kelibsiz',"""
auth = replace_required(auth, old_welcome, new_welcome, "welcome branding")
auth_path.write_text(auth, encoding="utf-8")

print("Old storefront look restored; free profile/admin features preserved.")
