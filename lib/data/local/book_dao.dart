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
    final maps = await db.query(
      'books',
      where: 'deleted = 0',
      orderBy: 'addedAt DESC',
    );
    return maps.map((map) => Book.fromMap(map)).toList();
  }

  Future<List<Book>> getBooksByStatus(ReadingStatus status) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'books',
      where: 'status = ? AND deleted = 0',
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
      where: 'isbn = ? AND deleted = 0',
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

  // ─── 동기화 관련 메서드 ───

  /// 미동기화 항목 조회 (synced = 0)
  Future<List<Book>> getUnsyncedBooks() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'books',
      where: 'synced = 0',
      orderBy: 'addedAt ASC',
    );
    return maps.map((map) => Book.fromMap(map)).toList();
  }

  /// 소프트 삭제된 항목 조회 (deleted = 1)
  Future<List<Book>> getDeletedBooks() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'books',
      where: 'deleted = 1',
      orderBy: 'addedAt ASC',
    );
    return maps.map((map) => Book.fromMap(map)).toList();
  }

  /// 소프트 삭제 (deleted 플래그 설정)
  Future<int> softDeleteBook(int id) async {
    final db = await _dbHelper.database;
    return await db.update(
      'books',
      {
        'deleted': 1,
        'synced': 0,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// supabase_id로 책 조회
  Future<Book?> getBookBySupabaseId(String supabaseId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'books',
      where: 'supabase_id = ?',
      whereArgs: [supabaseId],
    );
    if (maps.isEmpty) return null;
    return Book.fromMap(maps.first);
  }

  /// synced 플래그 업데이트
  Future<void> markAsSynced(int id, String supabaseId) async {
    final db = await _dbHelper.database;
    await db.update(
      'books',
      {
        'synced': 1,
        'supabase_id': supabaseId,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 동기화 완료 후 소프트 삭제된 항목 물리 삭제
  Future<void> purgeDeletedBooks() async {
    final db = await _dbHelper.database;
    await db.delete('books', where: 'deleted = 1 AND synced = 1');
  }

  /// 모든 항목 미동기화로 변경 (로그아웃 시)
  Future<void> markAllAsUnsynced() async {
    final db = await _dbHelper.database;
    await db.update('books', {
      'synced': 0,
      'supabase_id': null,
    });
  }

  /// 전체 책 목록 (삭제 포함, 동기화용)
  Future<List<Book>> getAllBooksIncludingDeleted() async {
    final db = await _dbHelper.database;
    final maps = await db.query('books', orderBy: 'addedAt DESC');
    return maps.map((map) => Book.fromMap(map)).toList();
  }
}
