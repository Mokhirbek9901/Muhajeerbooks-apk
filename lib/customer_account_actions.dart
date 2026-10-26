import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';

Future<void> showPinRecovery(
  BuildContext context, {
  String name = '',
  String phone = '',
}) async {
  final n = TextEditingController(text: name),
      p = TextEditingController(text: phone),
      note = TextEditingController();
  final values = await showDialog<List<String>>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('PINni tiklash so‘rovi'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Admin shaxsingizni alohida tekshirgandan keyin PINni tiklaydi. Bog‘lanish uchun Instagram nomingizni va eski buyurtma raqamingizni yozing.',
            ),
            TextField(
              controller: n,
              decoration: const InputDecoration(labelText: 'To‘liq ism'),
            ),
            TextField(
              controller: p,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Telefon'),
            ),
            TextField(
              controller: note,
              maxLength: 500,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Bog‘lanish va tekshirish ma’lumoti',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Hozir emas'),
        ),
        FilledButton(
          onPressed: () {
            if (n.text.trim().length >= 2 && note.text.trim().length >= 10)
              Navigator.pop(ctx, [
                n.text.trim(),
                p.text.trim(),
                note.text.trim(),
              ]);
          },
          child: const Text('So‘rov yuborish'),
        ),
      ],
    ),
  );
  n.dispose();
  p.dispose();
  note.dispose();
  if (values == null || !context.mounted) return;
  try {
    await context.read<AppState>().recoverPin(values[0], values[1], values[2]);
    if (context.mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tiklash so‘rovi adminga saqlandi. Admin tekshiruvidan keyin bog‘lanadi.',
          ),
        ),
      );
  } catch (e) {
    if (context.mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
  }
}

Future<void> showDeleteCustomerProfile(BuildContext context) async {
  final pin = TextEditingController();
  final entered = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Akkauntni o‘chirish'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'PIN profili va barcha kirish sessiyalari o‘chiriladi. Yetkazish va moliyaviy hisob uchun zarur buyurtma yozuvlari saqlanadi. Ushbu qurilmadagi shaxsiy tarix va manzillar tozalanadi.',
          ),
          TextField(
            controller: pin,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 4,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Tasdiqlash uchun PIN',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Bekor qilish'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, pin.text),
          child: const Text('Akkauntni o‘chirish'),
        ),
      ],
    ),
  );
  pin.dispose();
  if (entered == null || !context.mounted) return;
  try {
    await context.read<AppState>().deleteCustomerProfile(entered);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN profili va sessiyalar o‘chirildi.')),
      );
      Navigator.pop(context);
    }
  } catch (e) {
    if (context.mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
  }
}
