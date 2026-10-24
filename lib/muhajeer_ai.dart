import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'app_state.dart';

class MuhajeerAi {
  static Uri _uri(String path) => kIsWeb
      ? Uri.base.resolve(path)
      : Uri.parse('https://muhajeer-books-live-production.up.railway.app' + path);
  static List<Map<String,dynamic>> catalog(List<Book> books) => books.map((b)=> {
    'id':b.id,'title':b.title,'author':b.author,'category':b.category,
    'description':b.description,'price':b.currentPrice,'stock':b.stock,
  }).toList();

  static Future<String> ask({
    required String mode,
    required String query,
    required List<Book> books,
    List<Map<String,String>> history=const [],
  }) async {
    final r=await http.post(_uri('/api/ai-assistant'),
      headers:{'Content-Type':'application/json'},
      body:jsonEncode({'mode':mode,'query':query,'books':catalog(books),'history':history.take(10).toList()}),
    ).timeout(const Duration(seconds:90));
    if(r.statusCode!=200) throw StateError('AI vaqtincha ishlamayapti');
    return (jsonDecode(r.body)['text']??'').toString();
  }

// Search is catalog-only: doing it on the device/web client avoids waiting
  // for Railway and avoids silently dropping books after the first 500.
  static String _normalized(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r"[‘’ʻʼ´\u0060]"), "'")
      .replaceAll("o'", "o")
      .replaceAll("g'", "g")
      .replaceAll(RegExp(r"[^a-z0-9а-яёқғҳў]+"), ' ')
      .replaceAll(RegExp(r"\s+"), ' ')
      .trim();

  static const _ignore = <String>{
    'kitob', 'kitobi', 'kitoblar', 'bormi', 'narxi', 'qancha', 'necha',
    'sotuvda', 'mavjud', 'haqida', 'kerak', 'menga', 'bor', 'yoq',
    'qil', 'qiling', 'iltimos', 'qaysi', 'nima', 'uchun', 'bilan',
    'ham', 'shu', 'bir', 'eng', 'dan', 'ning', 'top', 'topib', 'ber',
    'tavsiya', 'tavsiyalar', 'oqish', 'oqishga',
  };

  static List<String> _words(String value) =>
      _normalized(value).split(' ').where((w) => w.length > 1).toList();

  static int _editDistance(String a, String b) {
    if (a == b) return 0;
    var previous = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final current = List<int>.filled(b.length + 1, 0);
      current[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        final deletion = previous[j] + 1;
        final insertion = current[j - 1] + 1;
        final substitution = previous[j - 1] + cost;
        current[j] = [deletion, insertion, substitution].reduce(
          (best, x) => x < best ? x : best,
        );
      }
      previous = current;
    }
    return previous[b.length];
  }

  static double _wordScore(String queryWord, String catalogWord) {
    if (queryWord == catalogWord) return 1;
    if (queryWord.length >= 3 && catalogWord.startsWith(queryWord)) {
      return 0.8;
    }
    if (queryWord.length < 4 || catalogWord.length < 4 ||
        (queryWord.length - catalogWord.length).abs() > 2) {
      return 0;
    }
    final distance = _editDistance(queryWord, catalogWord);
    if (distance == 1) return 0.70;
    if (queryWord.length >= 7 && distance == 2) return 0.55;
    return 0;
  }

  static double _bestWordScore(String needle, List<String> words) {
    var best = 0.0;
    for (final word in words) {
      final candidate = _wordScore(needle, word);
      if (candidate > best) best = candidate;
      if (best == 1) break;
    }
    return best;
  }

  /// Works with the entire already-loaded catalogue, even without network.
  /// Only ids are returned, so the UI still uses current local prices/stock.
  static List<String> localSearch(
    String query,
    List<Book> books, {
    String mode = 'search',
  }) {
    final normalizedQuery = _normalized(query);
    final queryWords = _words(query).where((w) => !_ignore.contains(w)).toList();
    if (normalizedQuery.isEmpty || queryWords.isEmpty) return const [];

    final ranked = <MapEntry<Book, double>>[];
    for (final book in books) {
      if (!book.isActive || book.id.isEmpty || book.title.trim().isEmpty) {
        continue;
      }
      final title = _normalized(book.title);
      final author = _normalized(book.author);
      final titleWords = _words(book.title);
      final authorWords = _words(book.author);
      final categoryWords = _words(book.category);
      final descriptionWords = _words(book.description);

      var score = 0.0;
      if (title == normalizedQuery) {
        score += 40;
      } else if (title.contains(normalizedQuery)) {
        score += 25;
      } else if (normalizedQuery.contains(title) && title.length >= 4) {
        score += 12;
      }
      if (author.isNotEmpty && author.contains(normalizedQuery)) score += 12;

      for (final word in queryWords) {
        final titleScore = _bestWordScore(word, titleWords);
        final authorScore = _bestWordScore(word, authorWords);
        final categoryScore = _bestWordScore(word, categoryWords);
        final descriptionScore = _bestWordScore(word, descriptionWords);
        if (titleScore > 0) {
          score += 8 * titleScore;
        } else if (authorScore > 0) {
          score += 5 * authorScore;
        } else if (categoryScore > 0) {
          score += 4 * categoryScore;
        } else if (descriptionScore > 0) {
          score += 1.5 * descriptionScore;
        }
      }
      if (score > 0) ranked.add(MapEntry(book, score));
    }

    ranked.sort((a, b) {
      final relevance = b.value.compareTo(a.value);
      if (relevance != 0) return relevance;
      return b.key.stock.compareTo(a.key.stock);
    });

    if (mode == 'similar' && ranked.isNotEmpty) {
      final target = ranked.first.key;
      final category = _normalized(target.category);
      final titleWords = _words(target.title).toSet();
      final alternatives = <MapEntry<Book, double>>[];
      for (final book in books) {
        if (!book.isActive || book.id == target.id || book.stock <= 0) continue;
        var score = category.isNotEmpty &&
                _normalized(book.category) == category ? 10.0 : 0.0;
        for (final word in _words(book.title)) {
          if (word.length > 2 && titleWords.contains(word)) score += 2;
        }
        final description = _normalized(book.description);
        for (final word in _words(target.description).take(20)) {
          if (word.length > 4 && description.contains(word)) score += 0.2;
        }
        if (score > 0) alternatives.add(MapEntry(book, score));
      }
      alternatives.sort((a, b) => b.value.compareTo(a.value));
      if (alternatives.isNotEmpty) {
        return alternatives.take(16).map((e) => e.key.id).toList();
      }
    }
    return ranked.take(16).map((e) => e.key.id).toList();
  }

  static Future<List<String>> search(
    String query,
    List<Book> books, {
    String mode = 'search',
  }) async => localSearch(query, books, mode: mode);
}
