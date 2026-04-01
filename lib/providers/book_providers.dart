import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repository/book_repository.dart';
import '../data/repository/search_repository.dart';
import '../domain/model/book.dart';

// Repositories
final bookRepositoryProvider = Provider((ref) => BookRepository());
final searchRepositoryProvider = Provider((ref) => SearchRepository());

// 전체 책 목록
final booksProvider = FutureProvider<List<Book>>((ref) async {
  final repo = ref.read(bookRepositoryProvider);
  return repo.getAllBooks();
});

// 상태별 필터
class StatusFilterNotifier extends Notifier<ReadingStatus?> {
  @override
  ReadingStatus? build() => null;

  void set(ReadingStatus? status) => state = status;
}

final selectedStatusFilterProvider =
    NotifierProvider<StatusFilterNotifier, ReadingStatus?>(
        StatusFilterNotifier.new);

// 필터링된 책 목록
final filteredBooksProvider = FutureProvider<List<Book>>((ref) async {
  final repo = ref.read(bookRepositoryProvider);
  final filter = ref.watch(selectedStatusFilterProvider);

  if (filter == null) {
    return repo.getAllBooks();
  }
  return repo.getBooksByStatus(filter);
});

// 검색 쿼리
class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void set(String query) => state = query;
}

final searchQueryProvider =
    NotifierProvider<SearchQueryNotifier, String>(SearchQueryNotifier.new);

// 검색 결과
final searchResultsProvider = FutureProvider<List<Book>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.trim().isEmpty) return [];

  final repo = ref.read(searchRepositoryProvider);
  return repo.searchBooks(query);
});

// 책 상세
final bookDetailProvider = FutureProvider.family<Book?, int>((ref, id) async {
  final repo = ref.read(bookRepositoryProvider);
  return repo.getBookById(id);
});

// 갱신 트리거
class BooksRefreshNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void refresh() => state++;
}

final booksRefreshProvider =
    NotifierProvider<BooksRefreshNotifier, int>(BooksRefreshNotifier.new);
