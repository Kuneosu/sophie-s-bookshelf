import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repository/book_repository.dart';
import '../data/repository/search_repository.dart';
import '../domain/model/book.dart';
import 'package:intl/intl.dart';
import 'auth_providers.dart';

// Repositories
final bookRepositoryProvider = Provider((ref) {
  // 싱글턴으로 유지해야 동기화 상태가 일관됨
  return BookRepository();
});
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
  ref.watch(booksRefreshProvider);

  if (filter == null) {
    return repo.getAllBooks();
  }
  return repo.getBooksByStatus(filter);
});

// 정렬 모드
enum SortMode { status, title, author, date }

class SortModeNotifier extends Notifier<SortMode> {
  @override
  SortMode build() => SortMode.status;
  void set(SortMode mode) => state = mode;
}

final sortModeProvider =
    NotifierProvider<SortModeNotifier, SortMode>(SortModeNotifier.new);

// 상태 우선순위: 읽는중(1) > 읽고싶은(0) > 완독(2) > 중단(3)
int _statusPriority(ReadingStatus status) {
  switch (status) {
    case ReadingStatus.reading:
      return 0;
    case ReadingStatus.wantToRead:
      return 1;
    case ReadingStatus.finished:
      return 2;
    case ReadingStatus.dropped:
      return 3;
  }
}

// 정렬된 책 목록 (그룹핑 포함)
final groupedBooksProvider =
    FutureProvider<Map<String, List<Book>>>((ref) async {
  final books = await ref.watch(filteredBooksProvider.future);
  final sortMode = ref.watch(sortModeProvider);

  switch (sortMode) {
    case SortMode.status:
      // 상태별 그룹핑 + 우선순위 정렬
      final map = <String, List<Book>>{};
      final sorted = List<Book>.from(books)
        ..sort((a, b) {
          final cmp = _statusPriority(a.status).compareTo(_statusPriority(b.status));
          if (cmp != 0) return cmp;
          return b.addedAt.compareTo(a.addedAt);
        });
      for (final book in sorted) {
        final key = book.status.label;
        map.putIfAbsent(key, () => []).add(book);
      }
      return map;

    case SortMode.title:
      final sorted = List<Book>.from(books)
        ..sort((a, b) => a.title.compareTo(b.title));
      return {'': sorted};

    case SortMode.author:
      final map = <String, List<Book>>{};
      for (final book in books) {
        final key = book.author.isNotEmpty ? book.author : '작가 미상';
        map.putIfAbsent(key, () => []).add(book);
      }
      return Map.fromEntries(
        map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
      );

    case SortMode.date:
      final map = <String, List<Book>>{};
      final fmt = DateFormat('yyyy년 M월');
      for (final book in books) {
        final key =
            book.finishedAt != null ? fmt.format(book.finishedAt!) : '미완독';
        map.putIfAbsent(key, () => []).add(book);
      }
      return Map.fromEntries(
        map.entries.toList()
          ..sort((a, b) {
            if (a.key == '미완독') return 1;
            if (b.key == '미완독') return -1;
            return b.key.compareTo(a.key);
          }),
      );
  }
});

// 뷰 모드 (갤러리 / 리스트)
enum ViewMode { gallery, list }

class ViewModeNotifier extends Notifier<ViewMode> {
  @override
  ViewMode build() => ViewMode.list;
  void toggle() {
    state = state == ViewMode.gallery ? ViewMode.list : ViewMode.gallery;
  }
}

final viewModeProvider =
    NotifierProvider<ViewModeNotifier, ViewMode>(ViewModeNotifier.new);

// 검색
class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';
  void set(String query) => state = query;
}

final searchQueryProvider =
    NotifierProvider<SearchQueryNotifier, String>(SearchQueryNotifier.new);

final searchResultsProvider = FutureProvider<List<Book>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.trim().isEmpty) return [];
  final repo = ref.read(searchRepositoryProvider);
  return repo.searchBooks(query);
});

// 책 상세
final bookDetailProvider = FutureProvider.family<Book?, int>((ref, id) async {
  ref.watch(booksRefreshProvider);
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

// ─── 동기화 상태 ───

enum SyncStatus { idle, syncing, success, error }

class SyncNotifier extends Notifier<SyncStatus> {
  @override
  SyncStatus build() => SyncStatus.idle;

  Future<void> sync() async {
    final isLoggedIn = ref.read(isLoggedInProvider);
    if (!isLoggedIn) return;

    state = SyncStatus.syncing;
    try {
      final repo = ref.read(bookRepositoryProvider);
      await repo.syncAll();
      state = SyncStatus.success;

      // 책 목록 갱신
      ref.read(booksRefreshProvider.notifier).refresh();
      ref.invalidate(filteredBooksProvider);
      ref.invalidate(groupedBooksProvider);
      ref.invalidate(booksProvider);

      // 3초 후 idle로 복원
      await Future.delayed(const Duration(seconds: 3));
      if (state == SyncStatus.success) {
        state = SyncStatus.idle;
      }
    } catch (e) {
      state = SyncStatus.error;
    }
  }
}

final syncProvider =
    NotifierProvider<SyncNotifier, SyncStatus>(SyncNotifier.new);
