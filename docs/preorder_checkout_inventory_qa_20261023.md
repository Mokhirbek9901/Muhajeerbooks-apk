# Oldindan zakaz — iOS TestFlight QA

## Admin oqimi
- Kutilmoqda → Qabul qilingan: admin avans chekini tekshiradi.
- Omborga yangi partiya qo‘shilganda oldindan qabul qilingan nusxalar band qilinadi. Kitoblar.stock faqat erkin sotiladigan qoldiq. Masalan 3 ta keldi, 2 ta band, 1 ta erkin.
- Kitob keldi: admin dona yakuniy narxi, pochta va majburiy izohni kiritadi. Kitoblar hali band qilinmagan bo‘lsa server amalni rad etadi.
- Jami = dona narxi × son + qo‘shimcha kitoblar + pochta − bir marta avans. 4+ kitobda bepul yetkazish (amal qilayotgan chegirma istisnosi saqlanadi).
- Mijoz qolgan to‘lov chekini yuklaganidan keyin admin chekni ko‘rib tasdiqlaydi.
- Bekor qilish: sabab + alohida «Rostdan bekor qilasizmi?»; zaxira qaytadi, avans avtomatik qaytmaydi.

## Mijoz oqimi
- Native preorder uchun 1–20 nusxa, jami avans nusxa soniga mutanosib.
- Profil → Oldindan zakazlarim: yakuniy summa, avans, admin izohi va qolgan to‘lov.
- Mavjud kitoblardan qo‘shish va bir nusxadan olib tashlash; har biri serverda zaxiraga olinadi.
- Avans aynan bir marta ayriladi; 4+ kitobda pochta qoidasi saqlanadi.
- Chek yuborilgach qo‘shimcha savat bloklanadi.
- Ilova ichida Kitob keldi hamda To‘lov tasdiqlandi bildirishnomalari.

## Xavfsizlik va tekshiruv
- Rollback orqali 3 keldi, 2 band, 1 erkin simulyatsiyasi tekshirildi.
- Rollback orqali qo‘shimcha kitob kiritish, chiqarish, avans kreditlari, 4+ bepul pochta tekshirildi.
- Bekor qilinganda band kitob o‘sha bekor qilingan zakazga qayta yozilib qolmasligi tekshirildi.
- Admin amallari serverda maxfiy kod bilan himoyalangan; privileged RPC'lar anon/authenticated uchun ochiq emas.
- Haqiqiy Yusufning qizi zakazi 1 dona qabul qilingan, ombor 0, avans ₩10 000 holatida qoldi.

## Hali qo‘shimcha tekshiruv zarur
- Oxirgi iOS TestFlight buildi haqiqiy iPhone’da.
- Push qurilma ekraniga kelishi: jonli Railway APNs dispatcher hali chiqarilmagan. In-app xabar bor.
- Preorder to‘lovlarini asosiy Moliya/sotuvlar statistikasiga avtomatik o‘tkazish bu ish hajmiga kirmagan; alohida xavfsiz migratsiya kerak.
- Oldindan buyurtma uchun yangi to‘lov va avtomatik stock-hold aynan native ilova buyurtmalariga tegishli; web oldindan zakazlarning eski holat boshqaruvi o‘zgarmagan.
- App Store, Play Market va Railway nashri amalga oshirilmagan.

## Yangi partiyani adminning o‘zidan kiritish
- Oldindan zakaz kartasi → "Yangi partiya qo‘shish" tugmasini bosing; kelgan miqdorni (1–2000) kiriting.
- Bu qiymat mavjud books.stock ni almashtirmaydi, unga atomik ravishda qo‘shiladi.
- BEFORE UPDATE trigger avval qabul qilingan zakazlar uchun yetarli nusxani bandlaydi, qolgan miqdorgina erkin sotuvda ko‘rinadi.
- Shu misolda ombor boshida 0, qabul qilingan 2 ta, yangi partiya 3 ta → band2, ochiq1.
- Tizim o‘zgarishlarni bir tranzaksiyada qiladi va yakuniy mavjud/band miqdorlarini adminga ko‘rsatadi.
- SQL rollback sinovi: mavjud 1 ta va qo‘shimcha 2 ta kiritilganda accepted2 band, erkin1; haqiqiy stock qaytarilgan.
- Himoyalangan admin_preorder_receive_batch RPC faqat service_role va tasdiqlangan admin kodi orqali ishlaydi.
