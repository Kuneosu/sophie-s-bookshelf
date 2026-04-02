import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_providers.dart';
import '../ui/auth/login_screen.dart';
import '../ui/auth/signup_screen.dart';
import '../ui/home/home_screen.dart';
import '../ui/search/search_screen.dart';
import '../ui/detail/detail_screen.dart';
import '../ui/settings/settings_screen.dart';

/// GoRouter provider (인증 상태에 따라 리다이렉트)
final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isLoggedIn = authState.status == AuthStatus.authenticated;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/signup';

      // 로그인 안 된 상태에서 인증 라우트가 아니면 → 로그인으로
      if (!isLoggedIn && !isAuthRoute) {
        return '/login';
      }

      // 로그인 된 상태에서 인증 라우트면 → 홈으로
      if (isLoggedIn && isAuthRoute) {
        return '/';
      }

      return null;
    },
    routes: [
      // 인증 라우트
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: LoginScreen(
            onSignUpTap: () => context.go('/signup'),
            onLoginSuccess: () => context.go('/'),
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      ),
      GoRoute(
        path: '/signup',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: SignUpScreen(
            onLoginTap: () => context.go('/login'),
            onSignUpSuccess: () => context.go('/'),
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      ),

      // 기존 라우트
      GoRoute(
        path: '/',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: HomeScreen(
            onBookTap: (id) => context.push('/detail/$id'),
            onSearchTap: () => context.push('/search'),
            onSettingsTap: () => context.push('/settings'),
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      ),
      GoRoute(
        path: '/search',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: SearchScreen(
            onBack: () => context.pop(),
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.1),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: FadeTransition(opacity: animation, child: child),
          ),
        ),
      ),
      GoRoute(
        path: '/detail/:id',
        pageBuilder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return CustomTransitionPage(
            key: state.pageKey,
            child: DetailScreen(
              bookId: id,
              onBack: () => context.pop(),
            ),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) =>
                    SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            ),
          );
        },
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: SettingsScreen(
            onBack: () => context.pop(),
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          ),
        ),
      ),
    ],
  );
});
