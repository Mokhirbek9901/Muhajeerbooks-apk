# Mijoz kirishi va admin boshqaruvi

Profil banneri doimo “Mohirbek Ismoilov” deb ko‘rsatiladi. Mijozning ismi va tasdiqlangan telefoni alohida hisob kartasida turadi.

Birinchi kirish: ism → telefon → SMS-kod. Parol yoki familiya talab qilinmaydi. Koreya mahalliy 010 raqami +82 formatiga aylantiriladi; boshqa davlat raqami + bilan kiritiladi. Kodni qayta yuborish uchun 60 soniya kutish, raqamni almashtirish va xatodan keyin qayta urinish bor. Saqlangan tasdiqlangan sessiya qayta kirishda tiklanadi. Profil serverdan olinmaguncha do‘kon ochilmaydi.

Admin kirishi ro‘yxatdan o‘tish oynasi va profil tugmasidan ochiladi, amaldagi serverdagi admin kodi bilan tekshiriladi. Panelda tezkor kitob qo‘shish, buyurtmalar, ombor, mijozlar va chegirmalarga o‘tish, qo‘lda yangilash, avtoyangilashni to‘xtatish/yoqish va paneldan chiqish bor. Kitobni o‘chirish xatosi foydalanuvchiga bildiriladi.

## SMS uchun qolgan ulanish

2026-09-08 tekshiruvda Supabase Auth `/settings` javobida `external.phone=false` edi. Haqiqiy SMS jo‘natish hali tekshirilmadi. `rytfhjvhjxnbhgitowho` loyihasida Auth → Providers → Phone ichida SMS provayderining hisobini ulash va telefon orqali kirishni yoqish kerak. Provayder parollarini repoga yoki chatga joylamang; Supabase sozlamalariga kiriting.

Yangi kodda `REQUIRE_PHONE_AUTH` odatda true. Shuning uchun SMS provayderi ulanmasdan production’ga chiqarmang: mijozlar kirish bosqichidan o‘ta olmaydi. Ilovada OTP tekshiruvini chetlab o‘tuvchi soxta tasdiqlash yo‘q.

Nashrdan oldin haqiqiy telefonda birinchi kirish, noto‘g‘ri kod, qayta yuborish, ilovani qayta ochish, profil, checkout, hisobdan chiqish va boshqa mijoz bilan kirish sinovlari kerak.

Rasmiy qo‘llanmalar:
- https://supabase.com/docs/guides/auth/phone-login
- https://supabase.com/docs/reference/dart/auth-signinwithotp

Tasdiqlangan mijoz buyurtma tarixini serverdan o‘z user ID’si bo‘yicha oladi. Oldingi, akkauntga bog‘lanmagan buyurtmalar yangi hisobga avtomatik biriktirilmaydi. Bu o‘zgarish hamma mavjud kamchiliklar tugaganini anglatmaydi.

## Tekshiruv natijalari

GitHub Flutter CI’da tahlil xatosiz tugadi, 6 ta test o‘tdi (770935e commit). Mavjud lint ogohlantirishlari qolgan. Haqiqiy SMS va qurilmadagi to‘liq xarid sinovi hali bajarilmagan.

2026-09-08 kuni `protect_customer_profile_role` migratsiyasi amaldagi bazaga qo‘llandi. Mijozlar o‘z `role` maydonini o‘zgartira olishi aniqlandi va yopildi. Ismni tahrirlash huquqi saqlandi; sessiyani ro‘yxatga olish faqat autentifikatsiyadan o‘tgan foydalanuvchiga qoldirildi:

```sql
revoke update on table public.profiles from public, anon, authenticated;
grant update (full_name) on table public.profiles to authenticated;
revoke execute on function public.customer_register_session(text) from public, anon;
grant execute on function public.customer_register_session(text) to authenticated;
```

Tekshiruv: customer_can_change_role=false, customer_can_edit_name=true, anon_can_register=false, customer_can_register=true. Admin amallari amaldagi admin RPC tekshiruvi orqali ishlaydi.

Qolgan SECURITY DEFINER ogohlantirishlari amaldagi admin/bot RPC arxitekturasiga tegishli; bu ish ularning barchasi bartaraf etilganini anglatmaydi. Qo‘llanma: https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable
