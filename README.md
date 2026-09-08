# Muhajeer Books — professional Flutter kitob do‘koni

Bitta kod bazadan **Android + iOS + Web** uchun ishlaydigan Muhajeer Books ilovasi.

## Mijoz uchun

- Birinchi kirishda faqat **ism + telefon** kiritiladi
- Profil **bepul**: SMS va parol talab qilinmaydi
- Keyingi kirishlarda ma’lumot qayta so‘ralmaydi
- Kitoblar katalogi, qidiruv, kategoriyalar va saralash
- Tavsiya etilgan kitoblar, chegirma badge va eski/yangi narx
- Sevimlilar
- Savatcha, miqdorni `+ / −` o‘zgartirish va o‘chirish
- Koreya bo‘ylab 택배 — ₩4,000
- 4+ kitobda yetkazib berish bepul
- Yetkazib berish: 1–3 ish kuni
- Ism, telefon, to‘liq manzil va xona raqami bilan checkout
- Toss Bank rekvizitlari va to‘lov cheki yuklash
- Buyurtma tarixi va holatini kuzatish
- Katalog Supabase Realtime orqali yangilanadi

## Admin uchun

- Himoyalangan admin kirishi
- Professional dashboard
- Kitob qo‘shish / tahrirlash / o‘chirish
- Muqova rasmi yuklash
- Narx, tannarx, ombor, kategoriya, tavsif, muqova turi
- Tavsiya etilgan kitob va aktiv/yashirilgan holat
- Ombor nazorati va kam qolgan kitoblar
- Buyurtmalar va statuslar: yangi / qabul qilindi / to‘landi / jo‘natildi / yakunlandi / bekor
- To‘lov chekini maxfiy ko‘rish
- Chegirmalarni boshqarish
- **Mijozlar markazi**: jami mijozlar, bugun faol, 7 kunda faol, ilova qurilmalari, buyurtmalar va xarid summasi

## Mijozlar statistikasi

Mijozning ism va telefoni `customer_contacts` jadvalida telefon bo‘yicha yagona profil sifatida saqlanadi. Bir xil telefon qayta kirganda yangi mijoz yaratmaydi — mavjud profilning oxirgi faolligi yangilanadi. Buyurtma berilganda ham mijoz profili avtomatik sinxronlanadi.

To‘g‘ridan-to‘g‘ri jadvalga public access yopiq; mobil ilova faqat validatsiyalangan `customer_register_free` RPC orqali yozadi.

## Supabase

Production loyiha migratsiyalari `supabase/migrations/` ichida saqlanadi. Yangi muhitda migratsiyalarni tartib bilan qo‘llash kerak.

Ilova `SUPABASE_URL` va `SUPABASE_ANON_KEY` dart define’larini qo‘llab-quvvatlaydi. Repositorydagi frontend key faqat public/anon client uchun; `service_role` yoki boshqa server secret mobil ilovaga qo‘yilmasligi kerak.

## Android build

```bash
flutter create . --platforms=android,ios,web
flutter pub get
flutter analyze --no-fatal-warnings --no-fatal-infos
flutter test
flutter build appbundle --release
```

Google Play uchun `.aab` hosil bo‘ladi. Release signing alohida sozlanadi.

## iOS build

Mac + Xcode talab qilinadi:

```bash
flutter build ipa --release
```

App Store Connect uchun Apple Developer account, Bundle ID, signing va privacy ma’lumotlari kerak bo‘ladi.

## Xavfsizlik

- `service_role` key ilovaga qo‘yilmaydi
- Supabase RLS yoqilgan
- Buyurtma narxlari serverda qayta tekshiriladi
- To‘lov cheklari public bucket’da saqlanmaydi
- Admin va Telegram bot operatsiyalari alohida himoyalangan RPC oqimlaridan foydalanadi
