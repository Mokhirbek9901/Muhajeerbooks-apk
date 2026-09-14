from pathlib import Path

store_path = Path('lib/store_ui.dart')
state_path = Path('lib/app_state.dart')
store = store_path.read_text(encoding='utf-8')
state = state_path.read_text(encoding='utf-8')

# 1) Checkout total must react to delivery choice.
old = """    final deliveryFee = state.cartCount >= 4 ? 0 : AppState.deliveryFee;\n    final total = state.cartSubtotal + deliveryFee;\n"""
new = """    final isGyeongsanPickup = delivery == '경산 직접수령';\n    final deliveryFee = isGyeongsanPickup\n        ? 0\n        : (state.cartCount >= 4 ? 0 : AppState.deliveryFee);\n    final total = state.cartSubtotal + deliveryFee;\n"""
if old not in store:
    raise SystemExit('checkout delivery fee block not found')
store = store.replace(old, new, 1)

# 2) Address is required only for parcel delivery.
old = """                      decoration: const InputDecoration(\n                        labelText: 'Manzil',\n                        alignLabelWithHint: true,\n                        helperMaxLines: 3,\n                        helperText: 'Manzil va xona raqamini to‘liq yozing.\\nMasalan: 경상북도 경산시 계양로 37길 7-3, 808호',\n                        prefixIcon: Icon(Icons.location_on_outlined),\n                      ),\n                      validator: (v) => v == null || v.trim().length < 8\n                          ? 'To‘liq manzilni kiriting'\n                          : null,\n"""
new = """                      decoration: InputDecoration(\n                        labelText: isGyeongsanPickup\n                            ? 'Manzil (ixtiyoriy)'\n                            : 'Manzil',\n                        alignLabelWithHint: true,\n                        helperMaxLines: 3,\n                        helperText: isGyeongsanPickup\n                            ? '경산da o‘zingiz olib ketsangiz, to‘liq manzil kiritish shart emas.'\n                            : 'Manzil va xona raqamini to‘liq yozing.\\nMasalan: 경상북도 경산시 계양로 37길 7-3, 808호',\n                        prefixIcon: const Icon(Icons.location_on_outlined),\n                      ),\n                      validator: (v) => isGyeongsanPickup\n                          ? null\n                          : (v == null || v.trim().length < 8\n                                ? 'To‘liq manzilni kiriting'\n                                : null),\n"""
if old not in store:
    raise SystemExit('address block not found')
store = store.replace(old, new, 1)

# 3) Add Gyeongsan self-pickup option under the default Korea-wide parcel option.
old = """                  RadioListTile<String>(\n                    value: '택배',\n                    groupValue: delivery,\n                    onChanged: (v) => setState(() => delivery = v!),\n                    title: const Text(\n                      'Koreya bo‘ylab 택배',\n                      style: TextStyle(fontWeight: FontWeight.w800),\n                    ),\n                    subtitle: Text(\n                      state.cartCount >= 4\n                          ? '4+ kitob — BEPUL • 1–3 ish kuni'\n                          : '₩4,000 • 1–3 ish kuni',\n                    ),\n                  ),\n"""
new = """                  RadioListTile<String>(\n                    value: '택배',\n                    groupValue: delivery,\n                    onChanged: (v) => setState(() => delivery = v!),\n                    title: const Text(\n                      'Koreya bo‘ylab pochta (택배)',\n                      style: TextStyle(fontWeight: FontWeight.w800),\n                    ),\n                    subtitle: Text(\n                      state.cartCount >= 4\n                          ? '4+ kitob — BEPUL • 1–3 ish kuni'\n                          : '₩4,000 • 1–3 ish kuni',\n                    ),\n                  ),\n                  const Divider(height: 1),\n                  RadioListTile<String>(\n                    value: '경산 직접수령',\n                    groupValue: delivery,\n                    onChanged: (v) => setState(() => delivery = v!),\n                    title: const Text(\n                      '경산 (Gyeongsan) — o‘zim olib ketaman',\n                      style: TextStyle(fontWeight: FontWeight.w800),\n                    ),\n                    subtitle: const Text('BEPUL • Pochta puli olinmaydi'),\n                    secondary: const Icon(Icons.storefront_outlined),\n                  ),\n"""
if old not in store:
    raise SystemExit('delivery option block not found')
store = store.replace(old, new, 1)

# 4) Preserve a meaningful address value for pickup orders when customer leaves it blank.
old = """        address: address.text,\n        deliveryType: delivery,\n"""
new = """        address: isGyeongsanPickupAddress(address.text, delivery),\n        deliveryType: delivery,\n"""
if old not in store:
    raise SystemExit('submit address block not found')
store = store.replace(old, new, 1)

# Local helper keeps submit logic easy to audit.
anchor = """bool _isSupportedCustomerPhone(String raw) {\n  final digits = raw.replaceAll(RegExp(r'\\D'), '');\n  return digits.length == 11 && digits.startsWith('010');\n}\n"""
replacement = anchor + """\nString isGyeongsanPickupAddress(String rawAddress, String deliveryType) {\n  final value = rawAddress.trim();\n  if (deliveryType == '경산 직접수령' && value.isEmpty) {\n    return '경산 직접수령';\n  }\n  return value;\n}\n"""
if anchor not in store:
    raise SystemExit('phone helper anchor not found')
store = store.replace(anchor, replacement, 1)

# 5) AppState is the final client-side safety gate: pickup is always zero delivery fee.
old = """    final subtotal = cartSubtotal;\n    final safeDeliveryFee = cartCount >= 4 ? 0 : AppState.deliveryFee;\n    final total = subtotal + safeDeliveryFee;\n"""
new = """    final subtotal = cartSubtotal;\n    final isGyeongsanPickup = deliveryType == '경산 직접수령';\n    final safeDeliveryFee = isGyeongsanPickup\n        ? 0\n        : (cartCount >= 4 ? 0 : AppState.deliveryFee);\n    final total = subtotal + safeDeliveryFee;\n"""
if old not in state:
    raise SystemExit('AppState safe delivery fee block not found')
state = state.replace(old, new, 1)

store_path.write_text(store, encoding='utf-8')
state_path.write_text(state, encoding='utf-8')
print('Gyeongsan pickup patch applied safely.')
