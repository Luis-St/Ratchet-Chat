import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../providers/contacts_provider.dart';
import '../../providers/server_provider.dart';
import '../widgets/contacts_sidebar.dart';

/// Main dashboard screen with responsive layout.
///
/// - Large screens (>600px): Collapsible sidebar + main content area
/// - Small screens (<600px): Full-screen contacts list with header
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _sidebarCollapsed = false;
  bool _contactsLoaded = false;

  @override
  void initState() {
    super.initState();
    // Load contacts after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeContacts();
    });
  }

  Future<void> _initializeContacts() async {
    if (_contactsLoaded) return;

    final authNotifier = ref.read(authProvider.notifier);
    final masterKey = authNotifier.masterKey;

    if (masterKey == null) return;

    // Set master key and load contacts
    ref.read(contactsProvider.notifier).setMasterKey(masterKey);
    await ref.read(contactsProvider.notifier).loadContacts();
    _contactsLoaded = true;
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final serverState = ref.watch(serverProvider);
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isLargeScreen = constraints.maxWidth > 600;

        if (isLargeScreen) {
          return _buildLargeScreenLayout(theme, authState, serverState);
        } else {
          return _buildSmallScreenLayout(theme, authState, serverState);
        }
      },
    );
  }

  Widget _buildLargeScreenLayout(
    ThemeData theme,
    authState,
    serverState,
  ) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _sidebarCollapsed ? 72 : 300,
            child: ContactsSidebar(
              collapsed: _sidebarCollapsed,
              onToggleCollapse: () {
                setState(() {
                  _sidebarCollapsed = !_sidebarCollapsed;
                });
              },
            ),
          ),
          // Divider
          VerticalDivider(width: 1, thickness: 1, color: theme.dividerColor),
          // Main content area
          Expanded(
            child: _buildMainContent(theme, authState, serverState),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallScreenLayout(
    ThemeData theme,
    authState,
    serverState,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
        actions: [
          _buildUserAvatar(theme, authState),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: const ContactsSidebar(
        collapsed: false,
        showHeader: false,
      ),
    );
  }

  Widget _buildMainContent(ThemeData theme, authState, serverState) {
    return Column(
      children: [
        // App bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              bottom: BorderSide(color: theme.dividerColor),
            ),
          ),
          child: Row(
            children: [
              const Spacer(),
              // Server info
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.dns_outlined,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      serverState.activeServer?.displayName ?? 'Unknown',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              _buildUserAvatar(theme, authState),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'Logout',
                onPressed: _handleLogout,
              ),
            ],
          ),
        ),
        // Content area
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // User info
                CircleAvatar(
                  radius: 48,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    (authState.username?.isNotEmpty == true
                            ? authState.username![0]
                            : '?')
                        .toUpperCase(),
                    style: theme.textTheme.headlineLarge?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Welcome, ${authState.username ?? 'User'}!',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (authState.handle != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    authState.handle!,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 48),
                Icon(
                  Icons.chat_bubble_outline,
                  size: 64,
                  color: theme.colorScheme.outlineVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  'Select a contact to start chatting',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserAvatar(ThemeData theme, authState) {
    return Tooltip(
      message: authState.handle ?? authState.username ?? 'User',
      child: CircleAvatar(
        radius: 16,
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Text(
          (authState.username?.isNotEmpty == true
                  ? authState.username![0]
                  : '?')
              .toUpperCase(),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogout() async {
    // Clear contacts before logout
    await ref.read(contactsProvider.notifier).clear();
    await ref.read(authProvider.notifier).logout();
  }
}
