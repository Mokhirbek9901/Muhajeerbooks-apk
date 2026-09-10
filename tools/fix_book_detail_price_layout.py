from pathlib import Path

path = Path('lib/store_ui.dart')
source = path.read_text(encoding='utf-8')
class_pos = source.index('class BookDetailPage')
start = source.index('      bottomNavigationBar: SafeArea(\n', class_pos)
end_marker = '    );\n  }\n}\n\nclass _BookGallery'
end = source.index(end_marker, start)

replacement = r'''      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.border)),
            boxShadow: [
              BoxShadow(
                color: Color(0x120F172A),
                blurRadius: 20,
                offset: Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Narxi',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                  const SizedBox(width: 10),
                  if (b.isDiscounted) ...[
                    Text(
                      won(b.price),
                      maxLines: 1,
                      softWrap: false,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      won(b.currentPrice),
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              if (b.inStock)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      state.addToCart(b);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Savatchaga qo‘shildi ✅')),
                      );
                    },
                    icon: const Icon(Icons.shopping_bag_rounded),
                    label: const Text('Savatchaga qo‘shish'),
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () async {
                          final message = await state.toggleRestockNotification(b);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(message)),
                          );
                        },
                        icon: Icon(
                          state.isRestockSubscribed(b)
                              ? Icons.notifications_active_rounded
                              : Icons.notifications_none_rounded,
                        ),
                        label: Text(
                          state.isRestockSubscribed(b)
                              ? 'Xabar beramiz ✅'
                              : 'Kelganda xabar berish',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    if (b.legacyId != null) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _openTelegramRestock(context, b),
                          icon: const Icon(Icons.send_rounded),
                          label: const Text(
                            'Telegramda xabar olish',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
            ],
          ),
        ),
      ),
'''

path.write_text(source[:start] + replacement + source[end:], encoding='utf-8')
print('Book detail price/action layout fixed')
