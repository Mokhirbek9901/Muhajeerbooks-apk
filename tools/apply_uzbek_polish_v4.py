from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected exactly 1 match, found {count}")
    return text.replace(old, new, 1)


def patch_design_system() -> None:
    path = ROOT / "lib" / "design_system.dart"
    text = path.read_text(encoding="utf-8")

    replacements = [
        ("static const navy = Color(0xFF10213D);", "static const navy = Color(0xFF082F49);", "navy"),
        ("static const navy2 = Color(0xFF19345B);", "static const navy2 = Color(0xFF0C4A6E);", "navy2"),
        ("static const orange = Color(0xFFFF8A00);", "static const orange = Color(0xFFB7791F);", "orange"),
        ("static const gold = Color(0xFFFFC928);", "static const gold = Color(0xFFD9A441);", "gold"),
        ("static const background = Color(0xFFF5F7FA);", "static const background = Color(0xFFF4EBDD);", "background"),
        ("static const surface = Colors.white;", "static const surface = Color(0xFFFFFCF6);", "surface"),
        ("static const surfaceSoft = Color(0xFFF8FAFC);", "static const surfaceSoft = Color(0xFFFFF7E7);", "surfaceSoft"),
        ("static const border = Color(0xFFE5E9F0);", "static const border = Color(0xFFD8C3A3);", "border"),
        ("static const text = Color(0xFF142033);", "static const text = Color(0xFF20353D);", "text"),
        ("static const muted = Color(0xFF667085);", "static const muted = Color(0xFF74695D);", "muted"),
        ("static const success = Color(0xFF16834A);", "static const success = Color(0xFF2E7D5B);", "success"),
        ("static const successSoft = Color(0xFFEAF7EF);", "static const successSoft = Color(0xFFE8F3EA);", "successSoft"),
        ("static const warning = Color(0xFFB96B00);", "static const warning = Color(0xFFA66416);", "warning"),
        ("static const warningSoft = Color(0xFFFFF5DF);", "static const warningSoft = Color(0xFFFFF1D4);", "warningSoft"),
        ("static const danger = Color(0xFFD73A49);", "static const danger = Color(0xFFB85042);", "danger"),
        ("static const dangerSoft = Color(0xFFFFECEE);", "static const dangerSoft = Color(0xFFFBEAE6);", "dangerSoft"),
        ("static const info = Color(0xFF246BCE);", "static const info = Color(0xFF0F766E);", "info"),
        ("static const infoSoft = Color(0xFFEBF3FF);", "static const infoSoft = Color(0xFFE7F3EF);", "infoSoft"),
        ("static const small = 12.0;", "static const small = 14.0;", "radius small"),
        ("static const medium = 16.0;", "static const medium = 18.0;", "radius medium"),
        ("static const large = 22.0;", "static const large = 24.0;", "radius large"),
        ("static const xl = 28.0;", "static const xl = 30.0;", "radius xl"),
    ]
    for old, new, label in replacements:
        text = replace_once(text, old, new, label)

    text = replace_once(
        text,
        """      cardTheme: CardThemeData(\n        color: Colors.white,\n        surfaceTintColor: Colors.transparent,""",
        """      cardTheme: CardThemeData(\n        color: AppColors.surface,\n        surfaceTintColor: Colors.transparent,""",
        "card surface",
    )
    text = replace_once(
        text,
        """      inputDecorationTheme: InputDecorationTheme(\n        filled: true,\n        fillColor: Colors.white,""",
        """      inputDecorationTheme: InputDecorationTheme(\n        filled: true,\n        fillColor: AppColors.surface,""",
        "input surface",
    )
    text = replace_once(
        text,
        """      navigationBarTheme: NavigationBarThemeData(\n        height: 70,\n        backgroundColor: Colors.white,\n        surfaceTintColor: Colors.transparent,\n        indicatorColor: const Color(0xFFFFE8CF),""",
        """      navigationBarTheme: NavigationBarThemeData(\n        height: 72,\n        backgroundColor: AppColors.surface,\n        surfaceTintColor: Colors.transparent,\n        indicatorColor: const Color(0xFFF8E7BE),""",
        "navigation theme",
    )
    text = replace_once(
        text,
        """      navigationRailTheme: const NavigationRailThemeData(\n        backgroundColor: Colors.white,\n        indicatorColor: Color(0xFFFFE8CF),""",
        """      navigationRailTheme: const NavigationRailThemeData(\n        backgroundColor: AppColors.surface,\n        indicatorColor: Color(0xFFF8E7BE),""",
        "rail theme",
    )
    text = replace_once(
        text,
        """      chipTheme: ChipThemeData(\n        backgroundColor: Colors.white,\n        selectedColor: const Color(0xFFFFE8CF),""",
        """      chipTheme: ChipThemeData(\n        backgroundColor: AppColors.surface,\n        selectedColor: const Color(0xFFF8E7BE),""",
        "chip theme",
    )
    text = replace_once(
        text,
        """      dialogTheme: DialogThemeData(\n        backgroundColor: Colors.white,""",
        """      dialogTheme: DialogThemeData(\n        backgroundColor: AppColors.surface,""",
        "dialog surface",
    )
    text = replace_once(
        text,
        """      bottomSheetTheme: const BottomSheetThemeData(\n        backgroundColor: Colors.white,""",
        """      bottomSheetTheme: const BottomSheetThemeData(\n        backgroundColor: AppColors.surface,""",
        "bottom sheet surface",
    )
    text = replace_once(
        text,
        """      progressIndicatorTheme: const ProgressIndicatorThemeData(\n        color: AppColors.orange,""",
        """      progressIndicatorTheme: const ProgressIndicatorThemeData(\n        color: AppColors.navy2,""",
        "progress color",
    )
    text = replace_once(
        text,
        """    this.backgroundColor = Colors.white,""",
        """    this.backgroundColor = AppColors.surface,""",
        "AppSurface default",
    )

    path.write_text(text, encoding="utf-8")


def patch_store_ui() -> None:
    path = ROOT / "lib" / "store_ui.dart"
    text = path.read_text(encoding="utf-8")

    old_nav = """      bottomNavigationBar: Container(\n        decoration: const BoxDecoration(\n          color: Colors.white,\n          border: Border(top: BorderSide(color: UzbekCustomerColors.border)),\n          boxShadow: [\n            BoxShadow(\n              color: Color(0x140B2942),\n              blurRadius: 20,\n              offset: Offset(0, -5),\n            ),\n          ],\n        ),\n        child: NavigationBar(\n          height: 70,\n          backgroundColor: Colors.white,"""
    new_nav = """      bottomNavigationBar: Container(\n        margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),\n        clipBehavior: Clip.antiAlias,\n        decoration: BoxDecoration(\n          gradient: const LinearGradient(\n            begin: Alignment.topLeft,\n            end: Alignment.bottomRight,\n            colors: [\n              UzbekCustomerColors.surface,\n              UzbekCustomerColors.ivory,\n            ],\n          ),\n          borderRadius: BorderRadius.circular(26),\n          border: Border.all(color: UzbekCustomerColors.gold, width: 1.15),\n          boxShadow: const [\n            BoxShadow(\n              color: Color(0x26123C4A),\n              blurRadius: 28,\n              offset: Offset(0, 10),\n            ),\n          ],\n        ),\n        child: NavigationBar(\n          height: 72,\n          backgroundColor: Colors.transparent,"""
    text = replace_once(text, old_nav, new_nav, "floating bottom navigation")

    old_header = """      decoration: BoxDecoration(\n        color: UzbekCustomerColors.surface,\n        borderRadius: BorderRadius.circular(22),\n        border: Border.all(color: UzbekCustomerColors.border),\n      ),\n      child: Column("""
    new_header = """      decoration: BoxDecoration(\n        gradient: const LinearGradient(\n          begin: Alignment.topLeft,\n          end: Alignment.bottomRight,\n          colors: [UzbekCustomerColors.surface, UzbekCustomerColors.ivory],\n        ),\n        borderRadius: BorderRadius.circular(26),\n        border: Border.all(color: UzbekCustomerColors.gold, width: 1.05),\n        boxShadow: const [\n          BoxShadow(\n            color: Color(0x15123C4A),\n            blurRadius: 20,\n            offset: Offset(0, 8),\n          ),\n        ],\n      ),\n      child: Column("""
    text = replace_once(text, old_header, new_header, "store header")

    old_category = """                  decoration: BoxDecoration(\n                    color: active ? UzbekCustomerColors.goldSoft : Colors.white,\n                    borderRadius: BorderRadius.circular(18),\n                    border: Border.all(\n                      color: active\n                          ? UzbekCustomerColors.goldDeep\n                          : UzbekCustomerColors.border,\n                    ),"""
    new_category = """                  decoration: BoxDecoration(\n                    gradient: active\n                        ? const LinearGradient(\n                            begin: Alignment.topLeft,\n                            end: Alignment.bottomRight,\n                            colors: [\n                              UzbekCustomerColors.navy,\n                              UzbekCustomerColors.tealDark,\n                            ],\n                          )\n                        : const LinearGradient(\n                            begin: Alignment.topLeft,\n                            end: Alignment.bottomRight,\n                            colors: [\n                              UzbekCustomerColors.surface,\n                              UzbekCustomerColors.ivory,\n                            ],\n                          ),\n                    borderRadius: BorderRadius.circular(20),\n                    border: Border.all(\n                      color: active\n                          ? UzbekCustomerColors.gold\n                          : UzbekCustomerColors.border,\n                    ),"""
    text = replace_once(text, old_category, new_category, "category card")
    text = replace_once(
        text,
        """                        color: active\n                            ? UzbekCustomerColors.goldDeep\n                            : UzbekCustomerColors.teal,""",
        """                        color: active\n                            ? UzbekCustomerColors.gold\n                            : UzbekCustomerColors.teal,""",
        "category icon",
    )
    text = replace_once(
        text,
        """                          color: UzbekCustomerColors.navy,\n                          fontSize: 10.5,""",
        """                          color: active\n                              ? Colors.white\n                              : UzbekCustomerColors.navy,\n                          fontSize: 10.5,""",
        "category label",
    )

    old_book = """      decoration: BoxDecoration(\n        color: Colors.white,\n        borderRadius: BorderRadius.circular(22),\n        border: Border.all(color: UzbekCustomerColors.border),\n        boxShadow: const [\n          BoxShadow(\n            color: Color(0x100F4C5C),\n            blurRadius: 18,\n            offset: Offset(0, 7),\n          ),\n        ],\n      ),"""
    new_book = """      decoration: BoxDecoration(\n        gradient: const LinearGradient(\n          begin: Alignment.topLeft,\n          end: Alignment.bottomRight,\n          colors: [UzbekCustomerColors.surface, UzbekCustomerColors.ivory],\n        ),\n        borderRadius: BorderRadius.circular(26),\n        border: Border.all(color: UzbekCustomerColors.border, width: 1.05),\n        boxShadow: const [\n          BoxShadow(\n            color: Color(0x1A123C4A),\n            blurRadius: 22,\n            offset: Offset(0, 9),\n          ),\n        ],\n      ),"""
    text = replace_once(text, old_book, new_book, "book card")

    old_sort = """                        decoration: BoxDecoration(\n                          color: Colors.white,\n                          borderRadius: BorderRadius.circular(16),\n                          border: Border.all(color: const Color(0xFFE6E8EC)),\n                        ),\n                        child: const Icon(Icons.tune_rounded),"""
    new_sort = """                        decoration: BoxDecoration(\n                          color: UzbekCustomerColors.surface,\n                          borderRadius: BorderRadius.circular(18),\n                          border: Border.all(color: UzbekCustomerColors.gold),\n                          boxShadow: const [\n                            BoxShadow(\n                              color: Color(0x12123C4A),\n                              blurRadius: 14,\n                              offset: Offset(0, 5),\n                            ),\n                          ],\n                        ),\n                        child: const Icon(\n                          Icons.tune_rounded,\n                          color: UzbekCustomerColors.navy,\n                        ),"""
    text = replace_once(text, old_sort, new_sort, "sort button")

    path.write_text(text, encoding="utf-8")


def main() -> None:
    patch_design_system()
    patch_store_ui()


if __name__ == "__main__":
    main()
