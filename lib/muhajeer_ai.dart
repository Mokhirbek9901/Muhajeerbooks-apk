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

  static Future<List<String>> search(String query,List<Book> books,{String mode='search'}) async {
    final r=await http.post(_uri('/api/ai-search'),
      headers:{'Content-Type':'application/json'},
      body:jsonEncode({'query':query,'mode':mode,'books':catalog(books)}),
    ).timeout(const Duration(seconds:90));
    if(r.statusCode!=200) return const [];
    return ((jsonDecode(r.body)['ids'] as List?)??const[]).map((e)=>e.toString()).toList();
  }
}
