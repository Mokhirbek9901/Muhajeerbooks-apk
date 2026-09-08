from pathlib import Path


def replace_all(text: str, old: str, new: str, label: str, minimum: int = 1) -> str:
    count = text.count(old)
    if count < minimum:
        raise SystemExit(f"Missing patch anchor for {label}: found {count}, need {minimum}")
    return text.replace(old, new)

# -------------------------
# Customer order UI
# -------------------------
store = Path('lib/store_ui.dart')
s = store.read_text(encoding='utf-8')

old_steps = """      'accepted' || 'paid' => 1,
      'shipping' => 2,
      'done' => 3,
      _ => 0,
    };
    const labels = ['Yuborildi', 'Qabul qilindi', 'Jo‘natildi', 'Yakunlandi'];
    const icons = [
      Icons.outbox_rounded,
      Icons.inventory_2_rounded,
      Icons.local_shipping_rounded,
      Icons.task_alt_rounded,
    ];"""
new_steps = """      'accepted' || 'paid' => 1,
      'shipping' || 'done' => 2,
      _ => 0,
    };
    const labels = ['Yuborildi', 'Qabul qilindi', 'Jo‘natildi'];
    const icons = [
      Icons.outbox_rounded,
      Icons.inventory_2_rounded,
      Icons.local_shipping_rounded,
    ];"""
s = replace_all(s, old_steps, new_steps, 'customer order timeline')

s = replace_all(
    s,
    "      'done' => 'Yakunlandi',",
    "      'done' => 'Jo‘natildi',",
    'legacy done label',
)

old_proof = """                    if (order.hasPaymentProof) ...[
                      const SizedBox(height: 8),
                      const AppInfoPill(
                        icon: Icons.receipt_rounded,
                        label: 'To‘lov cheki yuborilgan',
                        foreground: AppColors.success,
                        background: AppColors.successSoft,
                        border: Color(0xFFCDEAD7),
                      ),
                    ],"""
new_proof = old_proof + """
                    if (order.status == 'shipping' || order.status == 'done') ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.successSoft,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFCDEAD7)),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.local_shipping_rounded,
                              color: AppColors.success,
                              size: 20,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Buyurtma pochtaga topshirildi.\\n1–3 ish kunida yetkaziladi.',
                                style: TextStyle(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w800,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],"""
s = replace_all(s, old_proof, new_proof, 'shipping delivery note')

old_snackbar = """            SnackBar(
              content: Text(
                (notice['title'] ?? 'Buyurtma yangilandi').toString(),
              ),
              duration: const Duration(seconds: 4),
            ),"""
new_snackbar = """            SnackBar(
              content: Text(
                [
                  (notice['title'] ?? 'Buyurtma yangilandi').toString(),
                  (notice['message'] ?? '').toString(),
                ].where((value) => value.trim().isNotEmpty).join('\\n'),
              ),
              duration: const Duration(seconds: 5),
            ),"""
s = replace_all(s, old_snackbar, new_snackbar, 'customer notification snackbar')

store.write_text(s, encoding='utf-8')

# -------------------------
# Customer notification wording
# -------------------------
state = Path('lib/app_state.dart')
a = state.read_text(encoding='utf-8')
old_notice = """              'title': newStatus == 'accepted'
                  ? '✅ Buyurtmangiz qabul qilindi'
                  : '🚚 Buyurtmangiz jo‘natildi',
              'message': newStatus == 'accepted'
                  ? 'Buyurtmangiz tasdiqlandi va tayyorlanmoqda.'
                  : 'Buyurtmangiz jo‘natildi. Yetkazib berish 1–3 ish kuni.',"""
new_notice = """              'title': newStatus == 'accepted'
                  ? '✅ Buyurtmangiz qabul qilindi'
                  : '🚚 Buyurtmangiz pochtaga topshirildi',
              'message': newStatus == 'accepted'
                  ? 'Buyurtmangiz tasdiqlandi va tayyorlanmoqda.'
                  : 'Buyurtmangiz pochtaga topshirildi. 1–3 ish kunida yetkaziladi.',"""
a = replace_all(a, old_notice, new_notice, 'shipping notification wording')
state.write_text(a, encoding='utf-8')

print('Customer flow now ends at Jo‘natildi and shows postal delivery ETA.')
