import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  /// Supabase 초기화 (main.dart에서 호출)
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: 'https://jqbehvvsxhazphawqzco.supabase.co',
      anonKey: 'sb_publishable_lDboRD6fA_vTpzcMJOq4rg_bApX1NAI',
    );
  }

  // ─── 인증 ───

  /// 현재 유저
  User? get currentUser => client.auth.currentUser;

  /// 현재 유저 ID
  String? get currentUserId => client.auth.currentUser?.id;

  /// 로그인 상태
  bool get isLoggedIn => client.auth.currentUser != null;

  /// 인증 상태 스트림
  Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  /// 이메일/비밀번호 회원가입
  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    return await client.auth.signUp(
      email: email,
      password: password,
    );
  }

  /// 이메일/비밀번호 로그인
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// 로그아웃
  Future<void> signOut() async {
    await client.auth.signOut();
  }

  /// 세션 복원 확인
  Session? get currentSession => client.auth.currentSession;

  /// 비밀번호 재설정 이메일 발송
  Future<void> resetPassword(String email) async {
    await client.auth.resetPasswordForEmail(email);
  }
}
