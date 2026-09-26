# Google Play uchun release

`Play Store Signed AAB` workflow imzolangan `app-release.aab` tayyorlaydi. Bu jarayon Google Play’ga avtomatik joylamaydi. Eski `Play Store Unsigned AAB` natijasi to‘g‘ridan-to‘g‘ri yuklash uchun tayyor emas.

## Bir marta sozlash

Mavjud upload key bo‘lsa, aynan o‘sha kalitdan foydalaning. Yangi kalitni har build uchun yaratmang. Kalit va parollarni GitHub kodiga yoki chatga yozmang.

GitHub → Settings → Secrets and variables → Actions bo‘limiga quyidagilar kiritiladi:

| Secret | Qiymat |
| --- | --- |
| ANDROID_UPLOAD_KEYSTORE_BASE64 | Mavjud upload keystore faylining base64 ko‘rinishi |
| ANDROID_UPLOAD_STORE_PASSWORD | Keystore paroli |
| ANDROID_UPLOAD_KEY_PASSWORD | Upload key paroli |
| ANDROID_UPLOAD_KEY_ALIAS | Kalit aliasi |

Kalit hali yaratilmagan bo‘lsa, egasining kompyuterida interaktiv tarzda yaratiladi:

```bash
keytool -genkeypair -v -keystore upload-keystore.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Kalitni va parollarni xavfsiz joyda zaxiralang. Base64 — shifrlash emas.

## Yig‘ish va yuklash

1. `pubspec.yaml` dagi `version` ning `+` dan keyingi soni Play Console’dagi oldingi yuklashlardan katta bo‘lishi kerak. Hozir kodda `2.4.0+6`; bu raqam Console bilan hali tekshirilmagan.
2. GitHub → Actions → **Play Store Signed AAB** → Run workflow.
3. Workflow tekshiruv, test, release build va imzoni tekshirishdan o‘tadi. Biror bosqich xato bo‘lsa, tayyor AAB artifact chiqarilmaydi.
4. Muvaffaqiyatli natijadan `muhajeer-books-play-signed-aab` arxivini yuklab, ichidagi `app-release.aab` faylini oling.
5. Play Console’da avval internal testing release’ga yuklang va telefonda katalog, savat, buyurtma, admin kirishini tekshiring.

Paket nomi: `com.muhajeerbooks.app`. Target/compile SDK: mavjud loyihadagi kabi 36. Backend konfiguratsiyasi `lib/main.dart` dagi mavjud konfiguratsiyadan olinadi.

## Hali yakunlanishi kerak

- Upload key secretlari borligi va haqiqiy imzolangan build muvaffaqiyati.
- Play Console’dagi shaxs/telefon tasdiqlash holati.
- Maxfiylik siyosatining ochiq URL’i, Data safety javoblari va akkaunt o‘chirish talablari — haqiqiy ilova xatti-harakatiga muvofiq tekshirish.
- Store tavsifi, skrinshotlar, kontakt ma’lumotlari va kontent reytingi.
- Haqiqiy qurilmada sinov va Console ko‘rsatgan nashrga chiqish talablari.

Ushbu ro‘yxat tugamaguncha ilova “Google Play’ga to‘liq tayyor” deb hisoblanmaydi.

Rasmiy qo‘llanma: https://docs.flutter.dev/deployment/android
