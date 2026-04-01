import '../../domain/model/book.dart';
import '../remote/kakao_book_api.dart';

class SearchRepository {
  final KakaoBookApi _kakaoApi = KakaoBookApi();

  Future<List<Book>> searchBooks(String query, {int page = 1}) {
    return _kakaoApi.searchBooks(query, page: page);
  }
}
