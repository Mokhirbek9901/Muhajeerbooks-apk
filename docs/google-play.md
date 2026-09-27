# Google Play'ga chiqarish

## 1. Bir martalik sozlash: imzo paroli

1. GitHub → repozitoriy → **Settings → Secrets and variables → Actions → New repository secret**.
2. Name: `ANDROID_KEYSTORE_PASSWORD`
3. Secret: kamida 16 belgili, taxmin qilib bo'lmaydigan parol (harf + raqam). **Uni xavfsiz joyga yozib qo'ying** — yo'qolsa, yangi upload kalitini Play Console orqali tiklash kerak bo'ladi.

## 2. Imzolangan AAB olish

1. GitHub → **Actions → Google Play signed AAB → Run workflow** (branch: `main`).
2. Birinchi ishga tushishda upload kaliti yaratiladi, parol bilan shifrlanadi va `.github/signing/upload-keystore.jks.enc` ga saqlanadi. Keyingi safar xuddi shu kalit ishlatiladi.
3. Tugagach, run sahifasining pastidagi **Artifacts** bo'limidan `muhajeer-books-play-signed-aab-N` ni yuklab oling (ichida `app-release.aab`).

Har bir yangi versiya uchun shu workflow'ni qayta ishga tushiring — versiya raqami avtomatik oshadi.

## 3. Play Console'da ilova yaratish

1. **Create app** → nomi: `Muhajeer Books`, til: O'zbek, turi: App, bepul.
2. **App signing**: Google Play App Signing'ni yoqilgan holda qoldiring.
3. **Testing → Closed testing** → yangi track → yuqoridagi `app-release.aab` ni yuklang.
4. Kamida **12 ta tester** qo'shing (Gmail manzillari) va ular **14 kun** davomida ilovani o'rnatib turishi kerak. Shaxsiy hisoblar uchun bu Google talabi; shundan keyingina **Production**'ga ariza berish mumkin.

## 4. Store listing matnlari

**App name:** Muhajeer Books

**Short description (80 belgigacha):**
Koreyadagi o'zbeklar uchun kitob do'koni — 1–3 kunda yetkazib beramiz.

**Full description:**

Muhajeer Books — Janubiy Koreyada yashovchi o'zbek kitobxonlar uchun onlayn kitob do'koni.

📚 Keng tanlov
Badiiy adabiyot, diniy-ma'rifiy, tarix, psixologiya, bolalar adabiyoti, biznes va boshqa yo'nalishlardagi o'zbek tilidagi kitoblar.

🚚 Tez yetkazib berish
Koreya bo'ylab 택배 orqali 1–3 ish kunida. 4 va undan ortiq kitobga pochta bepul. 경산 (Gyeongsan)da o'zingiz olib ketishingiz ham mumkin.

🔎 Qulay qidiruv
Kitob nomi, muallif yoki mavzu bo'yicha qidiring. Kerakli kitob bo'lmasa — so'rov qoldiring, keltirib beramiz.

🔔 Xabarnomalar
Kutgan kitobingiz omborga kelganda va buyurtmangiz holati o'zgarganda xabar olasiz.

✅ Oddiy ro'yxatdan o'tish
Faqat ism va telefon raqami — parol va SMS kerak emas.

💳 Oson to'lov
Bank o'tkazmasi orqali to'lab, chekni ilovaga yuklaysiz.

Savollar uchun: Instagram @muhajeerbooks

**Category:** Books & Reference (yoki Shopping)

**Privacy policy URL:** https://muhajeer-books-live-production.up.railway.app/privacy

## 5. App content bo'limi

- **Privacy policy:** yuqoridagi havola.
- **Ads:** No, ilovada reklama yo'q.
- **App access:** "All functionality is available without special access" — mijoz qismi uchun login kerak emas (admin bo'limi faqat do'kon egasi uchun; kerak bo'lsa reviewer uchun izoh qoldiring).
- **Target audience:** 18+ (yoki 13+).
- **Data safety** (hammasi HTTPS orqali shifrlangan holda uzatiladi; ma'lumot sotilmaydi):
  - Personal info → **Name**, **Phone number**, **Address** — Collected, buyurtma va yetkazib berish uchun (App functionality), majburiy.
  - Photos → **Photos** (to'lov cheki) — Collected, App functionality, ixtiyoriy.
  - App activity → **Other user-generated content / In-app search history** (topilmagan qidiruvlar, kitob so'rovlari) — Collected, Analytics.
  - Device or other IDs → **Device or other IDs** (tasodifiy o'rnatish ID) — Collected, App functionality + Analytics.
  - Data shared: faqat yetkazib berish uchun ism/telefon/manzil pochta xizmatiga — "Shared" deb belgilang.
  - **Data deletion:** foydalanuvchi o'chirishni so'rashi mumkin → URL: https://muhajeer-books-live-production.up.railway.app/privacy#ochirish
- **Government apps / Financial features / Health:** No.

## 6. Grafik materiallar

- Ilova ikonkasi: 512×512 PNG.
- Feature graphic: 1024×500.
- Kamida 2 ta telefon skrinshoti (katalog, kitob sahifasi, savatcha, buyurtma).

## Eslatma

- Play versiyasi `PLAY_STORE_BUILD=true` bilan yig'iladi: ilova ichidagi "GitHub'dan yangi APK yuklab oling" oynasi unda chiqmaydi (Google Play qoidalari tashqi manbadan yangilanishni taqiqlaydi). Yangilanishlar faqat Play orqali keladi.
- GitHub'dagi APK o'rnatilgan telefonga Play versiyasini o'rnatish uchun avval eski ilovani o'chirish kerak (imzolari har xil).

## Avtomatik yuklash (har bir yangilanishda)

`main` ga `lib/`, `assets/` yoki `pubspec.yaml` o'zgarishi tushganda **Google Play signed AAB** workflow'i o'zi ishga tushadi, AAB yig'adi va `PLAY_SERVICE_ACCOUNT_JSON` secret bo'lsa, uni to'g'ridan-to'g'ri **Muhajeer Books Closed Test 1** trekiga yuklaydi.

Bir martalik sozlash:

1. https://console.cloud.google.com → yuqoridan loyiha tanlash → **New project** → nomi `muhajeer-play` → **Create**.
2. **APIs & Services → Library** → `Google Play Android Developer API` → **Enable**.
3. **IAM & Admin → Service Accounts → Create service account** → nomi `github-play` → **Create and continue** → **Done** (rol berish shart emas).
4. Yaratilgan service account → **Keys → Add key → Create new key → JSON** → fayl yuklanadi.
5. Play Console → **Пользователи и разрешения** → **Пригласить новых пользователей** → email: service account email'i (`github-play@...iam.gserviceaccount.com`) → **Разрешения для приложений**: Muhajeer Books → **Выпуск приложений в тестовые версии** (va kerak bo'lsa **рабочую версию**) → **Пригласить**.
6. GitHub → Settings → Secrets and variables → Actions → **New repository secret** → Name: `PLAY_SERVICE_ACCOUNT_JSON`, Secret: JSON faylning butun matni.

Production'ga o'tganda GitHub → Settings → Secrets and variables → Actions → **Variables** → `PLAY_TRACK` = `production`.
