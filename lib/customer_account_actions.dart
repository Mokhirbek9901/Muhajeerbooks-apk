import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_state.dart';

Future<void> showCustomerHistoryHelp(BuildContext context) async {
  final state = context.read<AppState>();
  final note = TextEditingController();
  final send = await showDialog<bool>(context: context, builder: (dialog) =>
    AlertDialog(
      title: const Text('Avvalgi buyurtmalarni tiklash'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Eski tarix, manzil va to‘lovlar telefon raqamining o‘zi '
            'bilan ochilmaydi. Admin shaxsingizni va avvalgi buyurtmani '
            'tekshirgach, shu qurilmangizga kirishni tiklaydi.'),
          if (state.checkoutIdentityReady) TextField(controller: note,
            maxLength: 500, maxLines: 3, decoration: const InputDecoration(
              labelText: 'Eski buyurtma va bog‘lanish ma’lumoti',
              hintText: 'Buyurtma raqami, sanasi va siz bilan bog‘lanish yo‘li')),
          if (!state.checkoutIdentityReady) const Text(
            'Avval ism va telefoningizni saqlang, so‘ng shu tugmadan so‘rov yuboring.'),
        ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialog, false),
          child: const Text('Yopish')),
        TextButton(onPressed: () => launchUrl(
          Uri.parse('https://www.instagram.com/muhajeerbooks/'),
          mode: LaunchMode.externalApplication), child: const Text('Do‘konga yozish')),
        if (state.checkoutIdentityReady) FilledButton(
          onPressed: () => Navigator.pop(dialog, true),
          child: const Text('So‘rov yuborish')),
      ],
    ));
  final message = note.text.trim();
  note.dispose();
  if (send != true || !context.mounted) return;
  try {
    if (message.length < 10) throw StateError('Eski buyurtma haqida kamida 10 belgi yozing');
    await state.requestCustomerHistoryRecovery(message);
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('So‘rov yuborildi. Do‘kon shaxsingizni alohida tekshiradi.')));
  } catch (error) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$error')));
  }
}

Future<bool> confirmCustomerSignOut(BuildContext context) async =>
    await showDialog<bool>(context: context, builder: (dialog) => AlertDialog(
      title: const Text('Profildan chiqilsinmi?'),
      content: const Text('Bu qurilmadagi ism, telefon, manzil, savat va '
        'shaxsiy tarix tozalanadi. Buyurtmalar hamda to‘lov yozuvlari '
        'do‘konda saqlanadi. Eski tarixni qayta ochish uchun do‘konga '
        'murojaat qilish kerak bo‘ladi.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialog, false),
          child: const Text('Bekor qilish')),
        FilledButton(onPressed: () => Navigator.pop(dialog, true),
          child: const Text('Chiqish')),
      ],
    )) == true;

Future<void> showDeleteCustomerProfile(BuildContext context) async {
  final confirmed = await showDialog<bool>(context: context,
    builder: (dialog) => AlertDialog(
      title: const Text('Profilni o‘chirish'),
      content: const Text('Ushbu qurilmaning profilga kirishi bekor qilinadi. '
        'Ism, telefon, manzil va shaxsiy tarix shu qurilmadan tozalanadi. '
        'Yetkazish va moliyaviy hisob uchun zarur buyurtma hamda to‘lov '
        'yozuvlari do‘konda saqlanadi.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialog, false),
          child: const Text('Bekor qilish')),
        FilledButton(onPressed: () => Navigator.pop(dialog, true),
          child: const Text('Profilni o‘chirish')),
      ],
    ));
  if (confirmed != true || !context.mounted) return;
  try {
    await context.read<AppState>().deleteCustomerProfile();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profil o‘chirildi.')));
    Navigator.pop(context);
  } catch (error) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$error')));
  }
}
