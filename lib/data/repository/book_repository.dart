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

  // ═══════════════════════════════════════
  //  CRUD — 로컬 저장 + 즉시 원격 동기화 (await)
  // ═══════════════════════════════════════

  /// 책 추가: 로컬 저장 → 원격 push (await)
  Future<int> addBook(Book book) async {
    final now = DateTime.now();
    final localBook = book.copyWith(synced: false, updatedAt: now);
    final localId = await _dao.insertBook(localBook);

    if (_isLoggedIn) {
      try {
        final supabaseId = await _remoteDao.insertBook(localBook);
        if (supabaseId != null) {
          await _dao.markAsSynced(localId, supabaseId);
        }
      } catch (e) {
        debugPrint('addBook remote sync failed: $e');
        // 로컬에는 저장됨, 다음 syncAll에서 재시도
      }
    }

    return localId;
  }

  /// 책 수정: 로컬 업데이트 → 원격 push (await)
  Future<void> updateBook(Book book) async {
    final updatedBook = book.copyWith(
      synced: false,
      updatedAt: DateTime.now(),
    );
    await _dao.updateBook(updatedBook);

    if (_isLoggedIn && updatedBook.supabaseId != null) {
      try {
        final success = await _remoteDao.updateBook(
          updatedBook.supabaseId!,
          updatedBook,
        );
        if (success && updatedBook.id != null) {
          await _dao.markAsSynced(updatedBook.id!, updatedBook.supabaseId!);
        }
      } catch (e) {
        debugPrint('updateBook remote sync failed: $e');
      }
    }
  }

  /// 책 삭제: 원격 삭제 (await) → 로컬 삭제
  Future<void> deleteBook(int id) async {
    final book = await _dao.getBookById(id);
    if (book == null) return;

    if (_isLoggedIn && book.supabaseId != null) {
      try {
        final success = await _remoteDao.deleteBook(book.supabaseId!);
        if (success) {
          await _dao.deleteBook(id);
        } else {
          // 원격 삭제 실패 → 소프트 삭제, 다음 syncAll에서 재시도
          await _dao.softDeleteBook(id);
        }
      } catch (e) {
        debugPrint('deleteBook remote error: $e');
        await _dao.softDeleteBook(id);
      }
    } else {
      // 원격에 없거나 로그인 안 됨 → 바로 물리 삭제
      await _dao.deleteBook(id);
    }
  }

  /// 상태 변경: 날짜 자동 설정 포함
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
    );
    await updateBook(updated); // updateBook이 동기화도 처리
  }

  Future<List<Book>> getAllBooks() => _dao.getAllBooks();

  Future<List<Book>> getBooksByStatus(ReadingStatus status) =>
      _dao.getBooksByStatus(status);

  Future<Book?> getBookById(int id) => _dao.getBookById(id);

  Future<bool> isBookExists(String isbn) => _dao.isBookExists(isbn);

  // ═══════════════════════════════════════
  //  전체 동기화 (앱 시작, 수동 새로고침)
  // ═══════════════════════════════════════

  Future<void> syncAll() async {
    if (!_isLoggedIn) return;

    try {
      // Phase 1: 로컬 → 원격 (실패했던 것들 재시도)
      await _pushPendingChanges();

      // Phase 2: 원격 → 로컬 (다른 기기 데이터 가져오기)
      await _pullRemoteChanges();

      // Phase 3: 소프트 삭제 정리
      await _dao.purgeDeletedBooks();

      debugPrint('syncAll 완료');
    } catch (e) {
      debugPrint('syncAll 에러: $e');
    }
  }

  /// 로컬에서 실패했던 변경사항 원격으로 push
  Future<void> _pushPendingChanges() async {
    // 1) 소프트 삭제된 항목 → 원격 삭제
    final deletedBooks = await _dao.getDeletedBooks();
    for (final book in deletedBooks) {
      if (book.supabaseId != null) {
        try {
          final success = await _remoteDao.deleteBook(book.supabaseId!);
          if (success && book.id != null) {
            await _dao.deleteBook(book.id!);
          }
        } catch (e) {
          debugPrint('push delete failed: $e');
        }
      } else if (book.id != null) {
        // 원격에 없던 책 → 바로 물리 삭제
        await _dao.deleteBook(book.id!);
      }
    }

    // 2) 미동기화 항목 → 원격 upsert
    final unsyncedBooks = await _dao.getUnsyncedBooks();
    for (final book in unsyncedBooks) {
      if (book.deleted) continue;

      try {
        if (book.supabaseId != null) {
          // 이미 원격에 있음 → 업데이트
          final success =
              await _remoteDao.updateBook(book.supabaseId!, book);
          if (success && book.id != null) {
            await _dao.markAsSynced(book.id!, book.supabaseId!);
          }
        } else {
          // 신규 → 원격 삽입
          final supabaseId = await _remoteDao.insertBook(book);
          if (supabaseId != null && book.id != null) {
            await _dao.markAsSynced(book.id!, supabaseId);
          }
        }
      } catch (e) {
        debugPrint('push upsert failed for "${book.title}": $e');
      }
    }
  }

  /// 원격 데이터를 로컬로 pull (다른 기기에서 추가/수정된 것)
  Future<void> _pullRemoteChanges() async {
    final remoteBooks = await _remoteDao.getAllBooks();
    final localBooks = await _dao.getAllBooks();

    // 로컬 ISBN → Book 매핑 (supabaseId 없는 것 대상)
    final localByIsbn = <String, Book>{};
    // 로컬 supabaseId → Book 매핑
    final localBySupabaseId = <String, Book>{};

    for (final local in localBooks) {
      if (local.supabaseId != null) {
        localBySupabaseId[local.supabaseId!] = local;
      }
      if (local.isbn.isNotEmpty && local.supabaseId == null) {
        localByIsbn[local.isbn] = local;
      }
    }

    // 원격 supabaseId 세트 (나중에 삭제 감지용)
    final remoteSupabaseIds = <String>{};

    for (final remote in remoteBooks) {
      if (remote.supabaseId == null) continue;
      remoteSupabaseIds.add(remote.supabaseId!);

      // 1) supabaseId로 매칭
      var local = localBySupabaseId[remote.supabaseId!];

      // 2) ISBN으로 매칭 (아직 supabaseId 미연결)
      if (local == null && remote.isbn.isNotEmpty) {
        local = localByIsbn[remote.isbn];
        if (local != null && local.id != null) {
          // ISBN 매칭 성공 → supabaseId 연결
          await _dao.markAsSynced(local.id!, remote.supabaseId!);
          localByIsbn.remove(remote.isbn);
        }
      }

      if (local == null) {
        // 로컬에 없음 → 신규 추가
        await _dao.insertBook(remote.copyWith(synced: true));
      } else {
        // 로컬에 있음 → 최신 데이터로 갱신 (로컬이 미동기화 상태면 스킵)
        if (local.synced) {
          final remoteUpdated = remote.updatedAt ?? DateTime(2000);
          final localUpdated = local.updatedAt ?? DateTime(2000);

          if (remoteUpdated.isAfter(localUpdated)) {
            final merged = remote.copyWith(id: local.id, synced: true);
            await _dao.updateBook(merged);
          }
        }
      }
    }

    // 원격에서 삭제된 책 감지: 로컬에 supabaseId 있는데 원격에 없으면 삭제
    for (final local in localBooks) {
      if (local.supabaseId != null &&
          local.synced &&
          !remoteSupabaseIds.contains(local.supabaseId!) &&
          local.id != null) {
        await _dao.deleteBook(local.id!);
        debugPrint('Remote deleted: "${local.title}"');
      }
    }
  }

  // ═══════════════════════════════════════
  //  JSON export/import
  // ═══════════════════════════════════════

  Future<String> exportToJson() async {
    final books = await _dao.getAllBooks();
    final jsonList = books.map((b) => b.toJson()).toList();
    return const JsonEncoder.withIndent('  ').convert({
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'books': jsonList,
    });
  }

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

    if (_isLoggedIn) {
      await syncAll();
    }

    return importedCount;
  }
}
