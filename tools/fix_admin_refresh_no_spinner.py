from pathlib import Path

path = Path("lib/admin_ui.dart")
text = path.read_text(encoding="utf-8")

old = """            if (snap.connectionState == ConnectionState.waiting)\n              const Expanded(child: Center(child: CircularProgressIndicator()))\n            else if (snap.hasError)"""
new = """            // Avtomatik 5 soniyalik refresh paytida eski ma'lumotni ekranda\n            // qoldiramiz. Katta loading faqat sahifa birinchi marta ochilganda chiqadi.\n            if (snap.connectionState == ConnectionState.waiting &&\n                snap.data == null)\n              const Expanded(child: Center(child: CircularProgressIndicator()))\n            else if (snap.hasError)"""

count = text.count(old)
if count < 2:
    raise SystemExit(f"Expected at least 2 refresh spinners, found {count}")
text = text.replace(old, new)

# Timerning 5 soniyalik yangilanishi qoladi, lekin UI endi mavjud ma'lumotni
# loading ekraniga almashtirmaydi. Overview/Customers allaqachon shu usulda.
path.write_text(text, encoding="utf-8")
print(f"Updated {count} FutureBuilder loading guards")
