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

    final updated = book.copyWith(
      status: status,
      finishedAt: status == ReadingStatus.finished ? DateTime.now() : null,
    );
    await _dao.updateBook(updated);
  }
}
