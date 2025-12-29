// Ratchet Chat - Native Flutter Client
// A federated, end-to-end encrypted messaging app using post-quantum cryptography.

import 'package:flutter/material.dart';

import 'src/ui/ui.dart';

void main() {
  runApp(const RatchetChatApp());
}

/// Main application widget.
class RatchetChatApp extends StatefulWidget {
  const RatchetChatApp({super.key});

  @override
  State<RatchetChatApp> createState() => _RatchetChatAppState();
}

class _RatchetChatAppState extends State<RatchetChatApp> {
  AppThemeMode _themeMode = AppThemeMode.system;
  _AppScreen _currentScreen = _AppScreen.splash;
  bool _isAuthenticated = false;

  ThemeMode get _flutterThemeMode {
    switch (_themeMode) {
      case AppThemeMode.system:
        return ThemeMode.system;
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ratchet Chat',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _flutterThemeMode,
      debugShowCheckedModeBanner: false,
      home: _buildCurrentScreen(),
    );
  }

  Widget _buildCurrentScreen() {
    switch (_currentScreen) {
      case _AppScreen.splash:
        return SplashScreen(
          onInitComplete: _handleSplashComplete,
        );
      case _AppScreen.login:
        return LoginScreen(
          onLogin: _handleLogin,
          onPasskeyLogin: _handlePasskeyLogin,
          onRegisterTap: () => _navigateTo(_AppScreen.register),
        );
      case _AppScreen.register:
        return RegisterScreen(
          onRegister: _handleRegister,
          onLoginTap: () => _navigateTo(_AppScreen.login),
        );
      case _AppScreen.conversations:
        return ConversationsScreen(
          conversations: _getDemoConversations(),
          onConversationTap: (conv) => _navigateTo(_AppScreen.chat),
          onNewChatTap: () {
            // TODO: Implement new chat
          },
          onSettingsTap: () => _navigateTo(_AppScreen.settings),
        );
      case _AppScreen.chat:
        return ChatScreen(
          participantHandle: 'demo@example.com',
          participantName: 'Demo User',
          isOnline: true,
          messages: _getDemoMessages(),
          onSendMessage: _handleSendMessage,
          onBackTap: () => _navigateTo(_AppScreen.conversations),
          onCallTap: () {
            // TODO: Implement call
          },
          onVideoCallTap: () {
            // TODO: Implement video call
          },
        );
      case _AppScreen.settings:
        return SettingsScreen(
          userHandle: 'user@example.com',
          userName: 'Current User',
          themeMode: _themeMode,
          onThemeModeChanged: (mode) {
            setState(() {
              _themeMode = mode;
            });
          },
          onLogout: _handleLogout,
          onBackTap: () => _navigateTo(_AppScreen.conversations),
        );
    }
  }

  void _navigateTo(_AppScreen screen) {
    setState(() {
      _currentScreen = screen;
    });
  }

  void _handleSplashComplete() {
    setState(() {
      _currentScreen = _isAuthenticated ? _AppScreen.conversations : _AppScreen.login;
    });
  }

  Future<bool> _handleLogin(String handle, String password) async {
    // TODO: Implement actual OPAQUE login
    await Future.delayed(const Duration(seconds: 1));

    // Demo: accept any login
    setState(() {
      _isAuthenticated = true;
      _currentScreen = _AppScreen.conversations;
    });
    return true;
  }

  Future<bool> _handlePasskeyLogin() async {
    // TODO: Implement passkey login
    await Future.delayed(const Duration(seconds: 1));
    return false;
  }

  Future<bool> _handleRegister(String handle, String password) async {
    // TODO: Implement actual OPAQUE registration
    await Future.delayed(const Duration(seconds: 1));

    // Demo: accept any registration
    setState(() {
      _isAuthenticated = true;
      _currentScreen = _AppScreen.conversations;
    });
    return true;
  }

  Future<bool> _handleSendMessage(String content) async {
    // TODO: Implement actual message sending
    await Future.delayed(const Duration(milliseconds: 500));
    return true;
  }

  void _handleLogout() {
    setState(() {
      _isAuthenticated = false;
      _currentScreen = _AppScreen.login;
    });
  }

  // Demo data for testing UI
  List<ConversationItem> _getDemoConversations() {
    return [
      ConversationItem(
        id: '1',
        participantHandle: 'alice@example.com',
        displayName: 'Alice',
        lastMessage: 'Hey, how are you?',
        lastMessageTime: DateTime.now().subtract(const Duration(minutes: 5)),
        unreadCount: 2,
        isOnline: true,
      ),
      ConversationItem(
        id: '2',
        participantHandle: 'bob@example.com',
        displayName: 'Bob',
        lastMessage: 'See you tomorrow!',
        lastMessageTime: DateTime.now().subtract(const Duration(hours: 2)),
        isOnline: false,
      ),
      ConversationItem(
        id: '3',
        participantHandle: 'carol@example.com',
        displayName: 'Carol',
        lastMessage: 'Thanks for the update',
        lastMessageTime: DateTime.now().subtract(const Duration(days: 1)),
        isOnline: true,
      ),
    ];
  }

  List<MessageItem> _getDemoMessages() {
    final now = DateTime.now();
    return [
      MessageItem(
        id: '1',
        content: 'Hey there!',
        timestamp: now.subtract(const Duration(minutes: 10)),
        isOutgoing: false,
        status: MessageDisplayStatus.read,
      ),
      MessageItem(
        id: '2',
        content: 'Hi! How are you?',
        timestamp: now.subtract(const Duration(minutes: 9)),
        isOutgoing: true,
        status: MessageDisplayStatus.read,
      ),
      MessageItem(
        id: '3',
        content: 'I\'m doing great, thanks for asking! How about you?',
        timestamp: now.subtract(const Duration(minutes: 8)),
        isOutgoing: false,
        status: MessageDisplayStatus.read,
      ),
      MessageItem(
        id: '4',
        content: 'Pretty good! Working on the new chat app.',
        timestamp: now.subtract(const Duration(minutes: 5)),
        isOutgoing: true,
        status: MessageDisplayStatus.delivered,
      ),
    ];
  }
}

enum _AppScreen {
  splash,
  login,
  register,
  conversations,
  chat,
  settings,
}
