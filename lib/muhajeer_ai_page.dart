import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'muhajeer_ai.dart';

class MuhajeerAiPage extends StatefulWidget {
  const MuhajeerAiPage({super.key});

  @override
  State<MuhajeerAiPage> createState() => _MuhajeerAiPageState();
}

class _MuhajeerAiPageState extends State<MuhajeerAiPage> {
  final q = TextEditingController();
  final scroll = ScrollController();
  bool busy = false;
  String mode = 'advisor';

  final List<Map<String, String>> messages = [
    {
      'role': 'assistant',
      'text':
          'Assalomu alaykum! 🙂 Kitob nomini xato yozsangiz ham topishga harakat qilaman. Mavzu, narx yoki kayfiyatingizni aytsangiz, hozir omborda bor kitoblardan tavsiya qilaman.'
    },
  ];

  final modes = const {
    'advisor': 'Kitob maslahatchi',
    'search': 'Aqlli qidiruv',
    'similar': 'O‘xshash kitoblar',
    'marketing': 'Reklama matni',
  };

  Future<void> run() async {
    final text = q.text.trim();
    if (text.isEmpty || busy) return;
    final history = messages
        .map((e) => {'role': e['role'] ?? '', 'text': e['text'] ?? ''})
        .toList();
    setState(() {
      busy = true;
      messages.add({'role': 'user', 'text': text});
      q.clear();
    });
    _toBottom();

    try {
      final books = context.read<AppState>().books;
      String answer;
      if (mode == 'search' || mode == 'similar') {
        final ids = await MuhajeerAi.search(text, books, mode: mode);
        final matches = ids
            .map((id) => books.where((b) => b.id == id).firstOrNull)
            .whereType<Book>()
            .toList();
        answer = matches.isEmpty
            ? 'Mos kitob topilmadi. Boshqacharoq yozib ko‘ring.'
            : matches
                .take(8)
                .map((b) =>
                    '• ${b.title} — ₩${b.currentPrice} — ${b.stock > 0 ? "omborda ${b.stock} dona" : "hozircha mavjud emas"}')
                .join('\n');
      } else {
        answer = await MuhajeerAi.ask(
          mode: mode,
          query: text,
          books: books,
          history: history,
        );
      }
      if (mounted) {
        setState(() => messages.add({'role': 'assistant', 'text': answer}));
      }
    } catch (_) {
      if (mounted) {
        setState(() => messages.add({
              'role': 'assistant',
              'text':
                  'Yordamchi vaqtincha javob bera olmadi. Qayta urinib ko‘ring.'
            }));
      }
    } finally {
      if (mounted) setState(() => busy = false);
      _toBottom();
    }
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scroll.hasClients) return;
      scroll.animateTo(
        scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    q.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Muhajeer AI')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
              child: DropdownButtonFormField<String>(
                value: mode,
                items: modes.entries
                    .map((e) =>
                        DropdownMenuItem(value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: busy
                    ? null
                    : (v) => setState(() => mode = v ?? mode),
                decoration: const InputDecoration(
                  labelText: 'Bepul yordamchi rejimi',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                itemCount: messages.length,
                itemBuilder: (_, i) {
                  final m = messages[i];
                  final mine = m['role'] == 'user';
                  return Align(
                    alignment:
                        mine ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 620),
                      margin: const EdgeInsets.only(bottom: 9),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 13, vertical: 11),
                      decoration: BoxDecoration(
                        color: mine
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(context).colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: SelectableText(
                        m['text'] ?? '',
                        style: const TextStyle(fontSize: 15, height: 1.45),
                      ),
                    ),
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: q,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.newline,
                        decoration: InputDecoration(
                          hintText: mode == 'similar'
                              ? 'Masalan: Binafsha shulasi'
                              : 'Masalan: 20 minggacha diniy kitob tavsiya qil',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: busy ? null : run,
                      icon: busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}
