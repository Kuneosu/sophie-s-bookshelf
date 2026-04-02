import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../domain/model/book.dart';
import '../local/book_dao.dart';
import '../remote/supabase_book_dao.dart';
import '../remote/supabase_service.dart';

class BookRepository {
  final BookDao _dao = BookDao();
  final SupabaseBookDao _remoteDao = SupabaseBookDao();
  final SupabaseService _authService = SupabaseService();

  bool get _isLoggedIn => _authService.isLoggedIn;

  // ─── 기존 CRUD (로컬 우선, 동기화 트리거) ───

  Future<int> addBook(Book book) async {
    final now = DateTime.now();
    final localBook = book.copyWith(
      synced: false,
      updatedAt: now,
    );
    final id = await _dao.insertBook(localBook);

    // 로그인 상태면 원격 동기화 시도
    if (_isLoggedIn) {
      _syncSingleInsert(id, localBook);
    }

    return id;
  }

  Future<List<Book>> getAllBooks() => _dao.getAllBooks();

  Future<List<Book>> getBooksByStatus(ReadingStatus status) =>
      _dao.getBooksByStatus(status);

  Future<Book?> getBookById(int id) => _dao.getBookById(id);

  Future<void> updateBook(Book book) async {
    final updatedBook = book.copyWith(
      synced: false,
      updatedAt: DateTime.now(),
    );
    await _dao.updateBook(updatedBook);

    if (_isLoggedIn) {
      _syncSingleUpdate(updatedBook);
    }
  }

  Future<void> deleteBook(int id) async {
    final book = await _dao.getBookById(id);
    if (book == null) return;

    if (_isLoggedIn && book.supabaseId != null) {
      // 소프트 삭제 → 동기화 후 물리 삭제
      await _dao.softDeleteBook(id);
      _syncSingleDelete(book);
    } else {
      // 로그인 안 된 상태면 바로 물리 삭제
      await _dao.deleteBook(id);
    }
  }

  Future<bool> isBookExists(String isbn) => _dao.isBookExists(isbn);

  Future<void> updateStatus(int id, ReadingStatus status) async {
    final book = await _dao.getBookById(id);
    if (book == null) return;

    final now = DateTime.now();
    final updated = book.copyWith(
      status: status,
      startedAt:
          status == ReadingStatus.reading ? (book.startedAt ?? now) : null,
      finishedAt: status == ReadingStatus.finished ? now : null,
      clearStartedAt: status == ReadingStatus.wantToRead,
      clearFinishedAt: status != ReadingStatus.finished,
      synced: false,
      updatedAt: now,
    );
    await _dao.updateBook(updated);

    if (_isLoggedIn) {
      _syncSingleUpdate(updated);
    }
  }

  // ─── 동기화 로직 ───

  /// 전체 동기화 (앱 시작 시, 수동 동기화 시)
  Future<void> syncAll() async {
    if (!_isLoggedIn) return;

    try {
      // 1. 로컬 → 원격: 미동기화 항목 업로드
      await _pushLocalChanges();

      // 2. 원격 → 로컬: 원격 데이터 가져오기
      await _pullRemoteChanges();

      // 3. 소프트 삭제된 항목 정리
      await _dao.purgeDeletedBooks();

      debugPrint('BookRepository: syncAll 완료');
    } catch (e) {
      debugPrint('BookRepository: syncAll 에러: $e');
    }
  }

  /// 로컬 미동기화 항목을 원격에 푸시
  Future<void> _pushLocalChanges() async {
    // 삭제된 항목 원격 삭제
    final deletedBooks = await _dao.getDeletedBooks();
    for (final book in deletedBooks) {
      if (book.supabaseId != null) {
        final success = await _remoteDao.deleteBook(book.supabaseId!);
        if (success && book.id != null) {
          await _dao.deleteBook(book.id!); // 물리 삭제
        }
      } else if (book.id != null) {
        await _dao.deleteBook(book.id!); // 원격에 없으니 바로 삭제
      }
    }

    // 미동기화 항목 업로드
    final unsyncedBooks = await _dao.getUnsyncedBooks();
    for (final book in unsyncedBooks) {
      if (book.deleted) continue; // 이미 처리됨

      if (book.supabaseId != null) {
        // 이미 원격에 있음 → 업데이트
        final success =
            await _remoteDao.updateBook(book.supabaseId!, book);
        if (success && book.id != null) {
          await _dao.markAsSynced(book.id!, book.supabaseId!);
        }
      } else {
        // 신규 → 삽입
        final supabaseId = await _remoteDao.insertBook(book);
        if (supabaseId != null && book.id != null) {
          await _dao.markAsSynced(book.id!, supabaseId);
        }
      }
    }
  }

  /// 원격 데이터를 로컬로 풀
  Future<void> _pullRemoteChanges() async {
    final remoteBooks = await _remoteDao.getAllBooks();

    for (final remoteBook in remoteBooks) {
      if (remoteBook.supabaseId == null) continue;

      final localBook =
          await _dao.getBookBySupabaseId(remoteBook.supabaseId!);

      if (localBook == null) {
        // 로컬에 없음 → 추가
        final newBook = remoteBook.copyWith(synced: true);
        await _dao.insertBook(newBook);
      } else {
        // 로컬에 있음 → updated_at 비교
        final remoteUpdated = remoteBook.updatedAt ?? DateTime(2000);
        final localUpdated = localBook.updatedAt ?? DateTime(2000);

        if (remoteUpdated.isAfter(localUpdated) && localBook.synced) {
          // 원격이 더 최신이고, 로컬이 이미 동기화된 상태면 → 원격 데이터로 덮어쓰기
          final merged = remoteBook.copyWith(
            id: localBook.id,
            synced: true,
          );
          await _dao.updateBook(merged);
        }
        // 로컬이 미동기화 상태면 로컬이 우선 → pushLocalChanges에서 처리
      }
    }
  }

  // ─── 단건 동기화 (백그라운드) ───

  Future<void> _syncSingleInsert(int localId, Book book) async {
    try {
      final supabaseId = await _remoteDao.insertBook(book);
      if (supabaseId != null) {
        await _dao.markAsSynced(localId, supabaseId);
      }
    } catch (e) {
      debugPrint('syncSingleInsert error: $e');
    }
  }

  Future<void> _syncSingleUpdate(Book book) async {
    try {
      if (book.supabaseId != null) {
        final success = await _remoteDao.updateBook(book.supabaseId!, book);
        if (success && book.id != null) {
          await _dao.markAsSynced(book.id!, book.supabaseId!);
        }
      }
    } catch (e) {
      debugPrint('syncSingleUpdate error: $e');
    }
  }

  Future<void> _syncSingleDelete(Book book) async {
    try {
      if (book.supabaseId != null) {
        final success = await _remoteDao.deleteBook(book.supabaseId!);
        if (success && book.id != null) {
          await _dao.deleteBook(book.id!); // 물리 삭제
        }
      }
    } catch (e) {
      debugPrint('syncSingleDelete error: $e');
    }
  }

  // ─── JSON export/import (기존 유지) ───

  /// JSON export
  Future<String> exportToJson() async {
    final books = await _dao.getAllBooks();
    final jsonList = books.map((b) => b.toJson()).toList();
    return const JsonEncoder.withIndent('  ').convert({
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'books': jsonList,
    });
  }

  /// JSON import (기존 데이터 유지 + 병합, 또는 덮어쓰기)
  Future<int> importFromJson(String jsonString, {bool replace = false}) async {
    final data = jsonDecode(jsonString) as Map<String, dynamic>;
    final booksList = data['books'] as List;
    final books = booksList
        .map((b) => Book.fromJson(b as Map<String, dynamic>))
        .toList();

    if (replace) {
      await _dao.deleteAll();
    }

    int importedCount = 0;
    for (final book in books) {
      // ISBN이 있으면 중복 체크
      if (!replace &&
          book.isbn.isNotEmpty &&
          await _dao.isBookExists(book.isbn)) {
        continue;
      }
      final importedBook = book.copyWith(
        synced: false,
        updatedAt: DateTime.now(),
      );
      await _dao.insertBook(importedBook);
      importedCount++;
    }

    // 로그인 상태면 동기화
    if (_isLoggedIn) {
      syncAll();
    }

    return importedCount;
  }
}
