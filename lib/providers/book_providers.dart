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

// 그룹핑 모드
enum GroupMode { none, author, finishedMonth }

class GroupModeNotifier extends Notifier<GroupMode> {
  @override
  GroupMode build() => GroupMode.none;
  void set(GroupMode mode) => state = mode;
}

final groupModeProvider =
    NotifierProvider<GroupModeNotifier, GroupMode>(GroupModeNotifier.new);

// 그룹핑된 책 목록
final groupedBooksProvider =
    FutureProvider<Map<String, List<Book>>>((ref) async {
  final books = await ref.watch(filteredBooksProvider.future);
  final groupMode = ref.watch(groupModeProvider);

  switch (groupMode) {
    case GroupMode.none:
      return {'': books};
    case GroupMode.author:
      final map = <String, List<Book>>{};
      for (final book in books) {
        final key = book.author.isNotEmpty ? book.author : '작가 미상';
        map.putIfAbsent(key, () => []).add(book);
      }
      // 가나다순 정렬
      return Map.fromEntries(
        map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
      );
    case GroupMode.finishedMonth:
      final map = <String, List<Book>>{};
      final fmt = DateFormat('yyyy년 M월');
      for (final book in books) {
        final key =
            book.finishedAt != null ? fmt.format(book.finishedAt!) : '미완독';
        map.putIfAbsent(key, () => []).add(book);
      }
      // 최신순 정렬 (미완독은 맨 뒤)
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
  ViewMode build() => ViewMode.gallery;
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
