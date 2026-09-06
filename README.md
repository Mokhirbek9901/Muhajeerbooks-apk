# Muhajeer Books — Flutter do‘kon ilovasi

Bitta kod bazadan **Android + iOS + Web** uchun ishlaydigan kitob do‘koni.

## Tayyor funksiyalar

### Mijoz uchun
- Kitoblar katalogi
- Qidiruv va kategoriyalar
- Kitob tafsilotlari
- Chegirma badge va eski/yangi narx
- Sevimlilar
- Savatcha, +/− miqdor va o‘chirish
- Koreya bo‘ylab 택배 (₩4,000) yoki Gyeongsan ichida bepul yetkazish
- Ism, telefon, to‘liq manzil/xona raqami bilan buyurtma
- Buyurtma Supabase bazasiga yoziladi

### Admin uchun
- Email/parol bilan admin kirish
- Dashboard: kitoblar, ombor, kam qolganlar, chegirmalar
- Kitob qo‘shish / tahrirlash / o‘chirish
- Narx, ombor, kategoriya, tavsif, aktiv holat
- Muqovani galereyadan Supabase Storage’ga yuklash
- Har kitobga alohida chegirma
- Barcha kitoblarga bir xil chegirma berish va bekor qilish
- Buyurtmalar ro‘yxati va status: yangi / to‘landi / jo‘natildi / yakunlandi / bekor
- Buyurtmada ombor avtomatik kamayadi; bekor qilinsa qaytadi

## 1. Flutter platform fayllarini yaratish

Repo ildizida:

```bash
flutter create . --platforms=android,ios,web
flutter pub get
```

Bu mavjud `lib/` kodini o‘chirmaydi, faqat Android/iOS/Web uchun native papkalarni yaratadi.

## 2. Supabase sozlash

1. Supabase’da yangi project yarating.
2. `supabase/schema.sql` faylini SQL Editor’da ishga tushiring.
3. Authentication -> Users orqali admin email/parol yarating.
4. `schema.sql` oxiridagi `update public.profiles ...` so‘rovini emailingiz bilan bajarib admin qiling.
5. Project Settings -> API’dan **Project URL** va **anon public key** oling.

## 3. Ilovani ishga tushirish

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

URL/key berilmasa ilova **demo rejim**da ochiladi. Demo rejimda katalog va admin UI’ni tekshirish mumkin, ammo ma’lumotlar serverda saqlanmaydi.

## 4. Android build

```bash
flutter build appbundle --release \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

Google Play uchun `.aab` hosil bo‘ladi. Release signing key alohida sozlanadi.

## 5. iOS build

Mac + Xcode kerak:

```bash
flutter build ipa --release \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

App Store Connect uchun Apple Developer account, Bundle ID, signing va privacy ma’lumotlari kerak bo‘ladi.

## Xavfsizlik

- Supabase `anon` key maxfiy server paroli emas va mobil app ichida ishlatilishi mumkin.
- `service_role` key’ni ilovaga **hech qachon** qo‘ymang.
- Admin huquqi `profiles.role = admin` va RLS policy orqali tekshiriladi.

## Keyingi tavsiya etiladigan bosqichlar

- To‘lov cheki / bank o‘tkazmasi workflow
- Push notification
- Mijoz akkaunti va buyurtma tarixi
- Telegram bot bilan bitta ombor bazasini ulash
- App icon, splash screen, privacy policy va store screenshots
