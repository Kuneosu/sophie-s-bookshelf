import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;
import '../data/remote/supabase_service.dart';

// ─── SupabaseService Provider ───
final supabaseServiceProvider = Provider((ref) => SupabaseService());

// ─── 인증 상태 ───

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final supa.User? user;
  final String? errorMessage;
  final bool isLoading;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.errorMessage,
    this.isLoading = false,
  });

  AuthState copyWith({
    AuthStatus? status,
    supa.User? user,
    String? errorMessage,
    bool? isLoading,
    bool clearError = false,
    bool clearUser = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: clearUser ? null : (user ?? this.user),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  late final SupabaseService _service;

  @override
  AuthState build() {
    _service = ref.read(supabaseServiceProvider);

    // 현재 세션 확인
    final user = _service.currentUser;
    if (user != null) {
      return AuthState(
        status: AuthStatus.authenticated,
        user: user,
      );
    }

    // 인증 상태 변경 리스닝
    _listenToAuthChanges();

    return const AuthState(status: AuthStatus.unauthenticated);
  }

  void _listenToAuthChanges() {
    _service.authStateChanges.listen((data) {
      final event = data.event;
      final session = data.session;

      switch (event) {
        case supa.AuthChangeEvent.signedIn:
        case supa.AuthChangeEvent.tokenRefreshed:
          state = AuthState(
            status: AuthStatus.authenticated,
            user: session?.user,
          );
          break;
        case supa.AuthChangeEvent.signedOut:
          state = const AuthState(
            status: AuthStatus.unauthenticated,
          );
          break;
        default:
          break;
      }
    });
  }

  /// 이메일/비밀번호 로그인
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final response = await _service.signIn(
        email: email,
        password: password,
      );

      if (response.user != null) {
        state = AuthState(
          status: AuthStatus.authenticated,
          user: response.user,
        );
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: '로그인에 실패했습니다.',
        );
        return false;
      }
    } on supa.AuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _mapAuthError(e.message),
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '알 수 없는 오류가 발생했습니다.',
      );
      return false;
    }
  }

  /// 이메일/비밀번호 회원가입
  Future<bool> signUp({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final response = await _service.signUp(
        email: email,
        password: password,
      );

      if (response.user != null) {
        state = AuthState(
          status: AuthStatus.authenticated,
          user: response.user,
        );
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: '회원가입에 실패했습니다.',
        );
        return false;
      }
    } on supa.AuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _mapAuthError(e.message),
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '알 수 없는 오류가 발생했습니다.',
      );
      return false;
    }
  }

  /// 로그아웃
  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);
    try {
      await _service.signOut();
      state = const AuthState(status: AuthStatus.unauthenticated);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '로그아웃에 실패했습니다.',
      );
    }
  }

  /// 에러 클리어
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  String _mapAuthError(String message) {
    if (message.contains('Invalid login credentials')) {
      return '이메일 또는 비밀번호가 올바르지 않습니다.';
    }
    if (message.contains('Email not confirmed')) {
      return '이메일 인증이 필요합니다. 메일함을 확인해주세요.';
    }
    if (message.contains('User already registered')) {
      return '이미 가입된 이메일입니다.';
    }
    if (message.contains('Password should be')) {
      return '비밀번호는 6자 이상이어야 합니다.';
    }
    if (message.contains('Unable to validate email')) {
      return '유효한 이메일 주소를 입력해주세요.';
    }
    return message;
  }
}

final authProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

// ─── 편의 providers ───

/// 로그인 여부
final isLoggedInProvider = Provider<bool>((ref) {
  final auth = ref.watch(authProvider);
  return auth.status == AuthStatus.authenticated;
});

/// 현재 유저 이메일
final currentUserEmailProvider = Provider<String?>((ref) {
  final auth = ref.watch(authProvider);
  return auth.user?.email;
});
