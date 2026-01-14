import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/models/auth_state.dart';
import '../providers/auth_provider.dart';
import '../providers/server_provider.dart';
import '../ui/screens/chat_screen.dart';
import '../ui/screens/dashboard_screen.dart';
import '../ui/screens/lock_screen.dart';
import '../ui/screens/login_screen.dart';
import '../ui/screens/master_password_screen.dart';
import '../ui/screens/recovery_codes_screen.dart';
import '../ui/screens/server_screen.dart';
import '../ui/screens/totp_setup_screen.dart';
import '../ui/screens/two_factor_screen.dart';

/// Route paths.
class AppRoutes {
  AppRoutes._();

  static const server = '/server';
  static const login = '/login';
  static const lock = '/lock';
  static const twoFactor = '/2fa';
  static const masterPassword = '/master-password';
  static const totpSetup = '/totp-setup';
  static const recoveryCodes = '/recovery-codes';
  static const home = '/';
  static const chat = '/chat/:handle';

  /// Creates a chat route path for a specific handle.
  static String chatPath(String handle) => '/chat/${Uri.encodeComponent(handle)}';
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
      final isOn2faPage = state.matchedLocation == AppRoutes.twoFactor;
      final isOnMasterPasswordPage = state.matchedLocation == AppRoutes.masterPassword;
      final isOnTotpSetupPage = state.matchedLocation == AppRoutes.totpSetup;
      final isOnRecoveryCodesPage = state.matchedLocation == AppRoutes.recoveryCodes;
      final isOnHomePage = state.matchedLocation == AppRoutes.home;
      final isOnChatPage = state.matchedLocation.startsWith('/chat/');

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
          // Locked needs to unlock (existing session, password not saved)
          if (isOnLockPage) return null;
          return AppRoutes.lock;

        case AuthStatus.awaiting2fa:
          // Waiting for 2FA verification
          if (isOn2faPage) return null;
          return AppRoutes.twoFactor;

        case AuthStatus.awaitingMasterPassword:
          // Waiting for master password to decrypt keys
          if (isOnMasterPasswordPage) return null;
          return AppRoutes.masterPassword;

        case AuthStatus.awaitingTotpSetup:
          // Waiting for TOTP setup during registration
          if (isOnTotpSetupPage) return null;
          return AppRoutes.totpSetup;

        case AuthStatus.awaitingRecoveryCodesAck:
          // Waiting for user to acknowledge recovery codes
          if (isOnRecoveryCodesPage) return null;
          return AppRoutes.recoveryCodes;

        case AuthStatus.authenticated:
          // Authenticated, allow home or chat pages
          if (isOnHomePage || isOnChatPage) return null;
          if (isOnServerPage || isOnLoginPage || isOnLockPage ||
              isOn2faPage || isOnMasterPasswordPage ||
              isOnTotpSetupPage || isOnRecoveryCodesPage) {
            return AppRoutes.home;
          }
          return null;
      }
    },
    routes: [
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        builder: (context, state) => const DashboardScreen(),
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
      GoRoute(
        path: AppRoutes.twoFactor,
        name: '2fa',
        builder: (context, state) => const TwoFactorScreen(),
      ),
      GoRoute(
        path: AppRoutes.masterPassword,
        name: 'masterPassword',
        builder: (context, state) => const MasterPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.totpSetup,
        name: 'totpSetup',
        builder: (context, state) => const TotpSetupScreen(),
      ),
      GoRoute(
        path: AppRoutes.recoveryCodes,
        name: 'recoveryCodes',
        builder: (context, state) => const RecoveryCodesScreen(),
      ),
      GoRoute(
        path: AppRoutes.chat,
        name: 'chat',
        builder: (context, state) {
          final handle = Uri.decodeComponent(state.pathParameters['handle'] ?? '');
          return ChatScreen(peerHandle: handle);
        },
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
