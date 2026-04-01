import 'dart:convert';
import '../../domain/model/book.dart';
import '../local/book_dao.dart';

class BookRepository {
  final BookDao _dao = BookDao();

  Future<int> addBook(Book book) => _dao.insertBook(book);

  Future<List<Book>> getAllBooks() => _dao.getAllBooks();

  Future<List<Book>> getBooksByStatus(ReadingStatus status) =>
      _dao.getBooksByStatus(status);

  Future<Book?> getBookById(int id) => _dao.getBookById(id);

  Future<void> updateBook(Book book) => _dao.updateBook(book);

  Future<void> deleteBook(int id) => _dao.deleteBook(id);

  Future<bool> isBookExists(String isbn) => _dao.isBookExists(isbn);

  Future<void> updateStatus(int id, ReadingStatus status) async {
    final book = await _dao.getBookById(id);
    if (book == null) return;

    final now = DateTime.now();
    final updated = book.copyWith(
      status: status,
      startedAt: status == ReadingStatus.reading ? (book.startedAt ?? now) : null,
      finishedAt: status == ReadingStatus.finished ? now : null,
      clearStartedAt: status == ReadingStatus.wantToRead,
      clearFinishedAt: status != ReadingStatus.finished,
    );
    await _dao.updateBook(updated);
  }

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
      if (!replace && book.isbn.isNotEmpty && await _dao.isBookExists(book.isbn)) {
        continue;
      }
      await _dao.insertBook(book);
      importedCount++;
    }
    return importedCount;
  }
}
