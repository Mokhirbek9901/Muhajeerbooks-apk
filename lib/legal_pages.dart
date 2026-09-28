import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) => _LegalPage(
    title: 'Maxfiylik siyosati',
    children: const [
      Text('Oxirgi yangilanish: 2026-yil 28-sentabr.'),
      SizedBox(height: 16),
      Text('Muhajeer Books foydalanuvchilarning maxfiyligini hurmat qiladi. Ushbu sahifa ilova va web-xizmatdan foydalanganda qanday ma’lumotlar ishlatilishini tushuntiradi.'),
      _H('Yig‘ilishi mumkin bo‘lgan ma’lumotlar'),
      Text('Buyurtma va mijozga xizmat ko‘rsatish uchun ism, telefon raqami, yetkazib berish ma’lumotlari va buyurtma tafsilotlari; hisob yoki ilova ishlashiga oid texnik ma’lumotlar; qurilma turi, ilova platformasi va anonim foydalanish statistikasi qayd etilishi mumkin.'),
      _H('Ma’lumotlardan foydalanish'),
      Text('Ma’lumotlar buyurtmalarni bajarish, mijoz bilan bog‘lanish, yetkazib berishni tashkil qilish, ilovaning ishlashini yaxshilash, xavfsizlikni ta’minlash va foydalanuvchi ruxsat bergan hollarda muhim bildirishnomalarni yuborish uchun ishlatiladi.'),
      _H('Ruxsatlar'),
      Text('Ilova ayrim funksiyalar uchun kamera, rasmlar, biometrik autentifikatsiya yoki bildirishnoma ruxsatini so‘rashi mumkin. Bu ruxsatlar faqat tegishli funksiyani bajarish uchun ishlatiladi va qurilma sozlamalaridan boshqarilishi mumkin.'),
      _H('Saqlash va uchinchi tomon xizmatlari'),
      Text('Muhajeer Books xizmatni ishlatish uchun hosting, ma’lumotlar bazasi va boshqa texnik xizmat ko‘rsatuvchilardan foydalanishi mumkin. Ma’lumotlar faqat xizmat ko‘rsatish uchun zarur doirada qayta ishlanadi.'),
      _H('Ma’lumotlarni o‘chirish'),
      Text('Foydalanuvchi o‘ziga tegishli shaxsiy ma’lumotlarni ko‘rish, tuzatish yoki o‘chirish bo‘yicha Muhajeer Books yordam xizmatiga murojaat qilishi mumkin. Qonun yoki moliyaviy/buyurtma hisoboti talab qilgan ma’lumotlar zarur muddat davomida saqlanishi mumkin.'),
      _H('Bolalar maxfiyligi'),
      Text('Muhajeer Books bolalardan ataylab shaxsiy ma’lumot yig‘ishga mo‘ljallanmagan.'),
      _H('O‘zgarishlar'),
      Text('Ushbu siyosat xizmatdagi yoki qonunchilikdagi o‘zgarishlarga mos ravishda yangilanishi mumkin. Yangilangan sana shu sahifada ko‘rsatiladi.'),
      _H('Bog‘lanish'),
      Text('Maxfiylik yoki ma’lumotlarni o‘chirish bo‘yicha savollar uchun Muhajeer Books rasmiy yordam kanallari orqali murojaat qiling.'),
    ],
  );
}

class SupportPage extends StatelessWidget {
  const SupportPage({super.key});

  @override
  Widget build(BuildContext context) => _LegalPage(
    title: 'Muhajeer Books yordam markazi',
    children: const [
      Text('Ilova, buyurtma, to‘lov, yetkazib berish yoki hisob bilan bog‘liq muammo bo‘lsa, biz bilan bog‘lanishingiz mumkin.'),
      _H('Buyurtmalar'),
      Text('Buyurtma holati, kitob mavjudligi, yetkazib berish yoki buyurtmadagi xato bo‘yicha buyurtmada ishlatilgan ism va telefon raqamingiz bilan murojaat qiling.'),
      _H('Ilova bilan bog‘liq muammo'),
      Text('Muammo haqida yozganda iPhone/Android modeli, ilova versiyasi va imkon bo‘lsa xatolik skrinshotini yuboring. Bu muammoni tezroq aniqlashga yordam beradi.'),
      _H('Maxfiylik va ma’lumotlarni o‘chirish'),
      Text('Shaxsiy ma’lumotlaringizni ko‘rish, tuzatish yoki o‘chirish bo‘yicha ham yordam xizmatiga murojaat qilishingiz mumkin.'),
      _H('Rasmiy aloqa'),
      Text('Instagram: @muhajeerbooks\nTelegram: @muhajeerbooks_admin'),
    ],
  );
}

class _H extends StatelessWidget {
  const _H(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 22, bottom: 8),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
  );
}

class _LegalPage extends StatelessWidget {
  const _LegalPage({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: SafeArea(
      child: SelectionArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          children: children,
        ),
      ),
    ),
  );
}
