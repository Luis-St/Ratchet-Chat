import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/models/auth_state.dart';
import '../providers/auth_provider.dart';
import '../providers/server_provider.dart';
import '../ui/screens/home_screen.dart';
import '../ui/screens/lock_screen.dart';
import '../ui/screens/login_screen.dart';
import '../ui/screens/server_screen.dart';

/// Route paths.
class AppRoutes {
  AppRoutes._();

  static const server = '/server';
  static const login = '/login';
  static const lock = '/lock';
  static const home = '/';
}

/// Creates the app router with proper redirect logic.
GoRouter createAppRouter(WidgetRef ref) {
  return GoRouter(
    initialLocation: AppRoutes.home,
    debugLogDiagnostics: true,
    refreshListenable: _RouterRefreshStream(ref),
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final serverState = ref.read(serverProvider);

      final isLoading = authState.isLoading || serverState.isLoading;
      final isOnServerPage = state.matchedLocation == AppRoutes.server;
      final isOnLoginPage = state.matchedLocation == AppRoutes.login;
      final isOnLockPage = state.matchedLocation == AppRoutes.lock;
      final isOnHomePage = state.matchedLocation == AppRoutes.home;

      // Still loading, don't redirect
      if (isLoading) {
        return null;
      }

      // No server configured, go to server screen
      if (!serverState.hasServer) {
        return isOnServerPage ? null : AppRoutes.server;
      }

      // Handle auth states
      switch (authState.status) {
        case AuthStatus.loading:
          return null;

        case AuthStatus.guest:
          // Guest needs to login
          if (isOnLoginPage || isOnServerPage) return null;
          return AppRoutes.login;

        case AuthStatus.locked:
          // Locked needs to unlock
          if (isOnLockPage) return null;
          return AppRoutes.lock;

        case AuthStatus.authenticated:
          // Authenticated, go home unless already there
          if (isOnHomePage) return null;
          if (isOnServerPage || isOnLoginPage || isOnLockPage) {
            return AppRoutes.home;
          }
          return null;
      }
    },
    routes: [
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.server,
        name: 'server',
        builder: (context, state) {
          final prefillUrl = state.uri.queryParameters['prefill'];
          return ServerScreen(prefillUrl: prefillUrl);
        },
      ),
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.lock,
        name: 'lock',
        builder: (context, state) => const LockScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.matchedLocation}')),
    ),
  );
}

/// Listenable that triggers router refresh when auth or server state changes.
class _RouterRefreshStream extends ChangeNotifier {
  _RouterRefreshStream(this._ref) {
    _ref.listen(authProvider, (_, __) => notifyListeners());
    _ref.listen(serverProvider, (_, __) => notifyListeners());
  }

  final WidgetRef _ref;
}

/// Provider for the app router.
final appRouterProvider = Provider.family<GoRouter, WidgetRef>((
  ref,
  widgetRef,
) {
  return createAppRouter(widgetRef);
});
