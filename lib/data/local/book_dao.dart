import 'database_helper.dart';
import '../../domain/model/book.dart';

class BookDao {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<int> insertBook(Book book) async {
    final db = await _dbHelper.database;
    return await db.insert('books', book.toMap());
  }

  Future<List<Book>> getAllBooks() async {
    final db = await _dbHelper.database;
    final maps = await db.query('books', orderBy: 'addedAt DESC');
    return maps.map((map) => Book.fromMap(map)).toList();
  }

  Future<List<Book>> getBooksByStatus(ReadingStatus status) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'books',
      where: 'status = ?',
      whereArgs: [status.index],
      orderBy: 'addedAt DESC',
    );
    return maps.map((map) => Book.fromMap(map)).toList();
  }

  Future<Book?> getBookById(int id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'books',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Book.fromMap(maps.first);
  }

  Future<int> updateBook(Book book) async {
    final db = await _dbHelper.database;
    return await db.update(
      'books',
      book.toMap(),
      where: 'id = ?',
      whereArgs: [book.id],
    );
  }

  Future<int> deleteBook(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'books',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<bool> isBookExists(String isbn) async {
    if (isbn.isEmpty) return false;
    final db = await _dbHelper.database;
    final result = await db.query(
      'books',
      where: 'isbn = ?',
      whereArgs: [isbn],
    );
    return result.isNotEmpty;
  }

  /// 전체 삭제 (import 시 사용)
  Future<void> deleteAll() async {
    final db = await _dbHelper.database;
    await db.delete('books');
  }

  /// 배치 삽입 (import 시 사용)
  Future<void> insertAll(List<Book> books) async {
    final db = await _dbHelper.database;
    final batch = db.batch();
    for (final book in books) {
      batch.insert('books', book.toMap());
    }
    await batch.commit(noResult: true);
  }
}
