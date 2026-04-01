import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../domain/model/book.dart';

class KakaoBookApi {
  static const String _baseUrl = 'https://dapi.kakao.com/v3/search/book';
  static const String _apiKey = '4a2f12c148a8fe9e10fa984dee8cf762';

  Future<List<Book>> searchBooks(String query, {int page = 1, int size = 20}) async {
    if (query.trim().isEmpty) return [];

    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'query': query,
      'page': page.toString(),
      'size': size.toString(),
    });

    final response = await http.get(
      uri,
      headers: {'Authorization': 'KakaoAK $_apiKey'},
    );

    if (response.statusCode != 200) {
      throw Exception('카카오 API 오류: \${response.statusCode}');
    }

    final data = json.decode(response.body);
    final documents = data['documents'] as List;

    return documents.map((doc) {
      final authors = (doc['authors'] as List).join(', ');
      final isbn = (doc['isbn'] as String).split(' ').last; // ISBN13 우선

      return Book(
        title: doc['title'] as String,
        author: authors,
        publisher: doc['publisher'] as String? ?? '',
        isbn: isbn,
        thumbnailUrl: doc['thumbnail'] as String? ?? '',
        description: doc['contents'] as String? ?? '',
        addedAt: DateTime.now(),
      );
    }).toList();
  }
}
