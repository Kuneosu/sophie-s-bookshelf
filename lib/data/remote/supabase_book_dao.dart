import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/model/book.dart';
import 'supabase_service.dart';

class SupabaseBookDao {
  final SupabaseClient _client = SupabaseService.client;
  static const String _table = 'books';

  String? get _userId => _client.auth.currentUser?.id;

  /// 전체 책 목록 조회 (현재 유저)
  Future<List<Book>> getAllBooks() async {
    if (_userId == null) return [];

    try {
      final response = await _client
          .from(_table)
          .select()
          .eq('user_id', _userId!)
          .order('added_at', ascending: false);

      return (response as List)
          .map((row) => Book.fromSupabase(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('SupabaseBookDao.getAllBooks error: $e');
      return [];
    }
  }

  /// 책 추가 → 생성된 row의 id 반환
  Future<String?> insertBook(Book book) async {
    if (_userId == null) return null;

    try {
      final data = book.toSupabaseMap();
      data['user_id'] = _userId;

      final response =
          await _client.from(_table).insert(data).select('id').single();

      return response['id']?.toString();
    } catch (e) {
      debugPrint('SupabaseBookDao.insertBook error: $e');
      return null;
    }
  }

  /// 책 수정 (supabase id 기준)
  Future<bool> updateBook(String supabaseId, Book book) async {
    if (_userId == null) return false;

    try {
      await _client
          .from(_table)
          .update(book.toSupabaseMap())
          .eq('id', int.parse(supabaseId))
          .eq('user_id', _userId!);
      return true;
    } catch (e) {
      debugPrint('SupabaseBookDao.updateBook error: $e');
      return false;
    }
  }

  /// 책 삭제 (supabase id 기준)
  Future<bool> deleteBook(String supabaseId) async {
    if (_userId == null) return false;

    try {
      await _client
          .from(_table)
          .delete()
          .eq('id', int.parse(supabaseId))
          .eq('user_id', _userId!);
      return true;
    } catch (e) {
      debugPrint('SupabaseBookDao.deleteBook error: $e');
      return false;
    }
  }

  /// 특정 책 조회
  Future<Book?> getBookById(String supabaseId) async {
    if (_userId == null) return null;

    try {
      final response = await _client
          .from(_table)
          .select()
          .eq('id', int.parse(supabaseId))
          .eq('user_id', _userId!)
          .maybeSingle();

      if (response == null) return null;
      return Book.fromSupabase(response);
    } catch (e) {
      debugPrint('SupabaseBookDao.getBookById error: $e');
      return null;
    }
  }

  /// updated_at 이후 변경된 책 조회
  Future<List<Book>> getBooksUpdatedAfter(DateTime since) async {
    if (_userId == null) return [];

    try {
      final response = await _client
          .from(_table)
          .select()
          .eq('user_id', _userId!)
          .gte('updated_at', since.toUtc().toIso8601String())
          .order('updated_at', ascending: true);

      return (response as List)
          .map((row) => Book.fromSupabase(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('SupabaseBookDao.getBooksUpdatedAfter error: $e');
      return [];
    }
  }
}
