// Settings screen for app configuration.

import 'package:flutter/material.dart';

import '../theme/theme.dart';
import '../widgets/widgets.dart';

/// Theme mode options.
enum AppThemeMode {
  system,
  light,
  dark,
}

class SettingsScreen extends StatelessWidget {
  final String? userHandle;
  final String? userName;
  final AppThemeMode themeMode;
  final bool notificationsEnabled;
  final bool soundEnabled;
  final void Function(AppThemeMode)? onThemeModeChanged;
  final void Function(bool)? onNotificationsChanged;
  final void Function(bool)? onSoundChanged;
  final VoidCallback? onRegisterPasskey;
  final VoidCallback? onExportKeys;
  final VoidCallback? onLogout;
  final VoidCallback? onBackTap;

  const SettingsScreen({
    super.key,
    this.userHandle,
    this.userName,
    this.themeMode = AppThemeMode.system,
    this.notificationsEnabled = true,
    this.soundEnabled = true,
    this.onThemeModeChanged,
    this.onNotificationsChanged,
    this.onSoundChanged,
    this.onRegisterPasskey,
    this.onExportKeys,
    this.onLogout,
    this.onBackTap,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onBackTap ?? () => Navigator.of(context).pop(),
        ),
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // Profile section
          _buildProfileSection(context),
          const Divider(height: 1),

          // Appearance section
          _buildSectionHeader(context, 'Appearance'),
          _buildThemeTile(context),
          const Divider(height: 1),

          // Notifications section
          _buildSectionHeader(context, 'Notifications'),
          _buildSwitchTile(
            context,
            title: 'Push Notifications',
            subtitle: 'Receive notifications for new messages',
            value: notificationsEnabled,
            onChanged: onNotificationsChanged,
            icon: Icons.notifications_outlined,
          ),
          _buildSwitchTile(
            context,
            title: 'Sound',
            subtitle: 'Play sound for notifications',
            value: soundEnabled,
            onChanged: onSoundChanged,
            icon: Icons.volume_up_outlined,
          ),
          const Divider(height: 1),

          // Security section
          _buildSectionHeader(context, 'Security'),
          _buildActionTile(
            context,
            title: 'Register Passkey',
            subtitle: 'Add biometric login',
            icon: Icons.fingerprint,
            onTap: onRegisterPasskey,
          ),
          _buildActionTile(
            context,
            title: 'Export Keys',
            subtitle: 'Backup your encryption keys',
            icon: Icons.key_outlined,
            onTap: onExportKeys,
          ),
          const Divider(height: 1),

          // About section
          _buildSectionHeader(context, 'About'),
          _buildInfoTile(
            context,
            title: 'Version',
            value: '1.0.0',
            icon: Icons.info_outlined,
          ),
          _buildActionTile(
            context,
            title: 'Privacy Policy',
            icon: Icons.privacy_tip_outlined,
            onTap: () {
              // TODO: Open privacy policy
            },
          ),
          _buildActionTile(
            context,
            title: 'Terms of Service',
            icon: Icons.description_outlined,
            onTap: () {
              // TODO: Open terms
            },
          ),
          const Divider(height: 1),

          // Logout
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              onPressed: onLogout,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
              ),
              icon: const Icon(Icons.logout),
              label: const Text('Sign Out'),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildProfileSection(BuildContext context) {
    final name = userName ?? userHandle ?? 'User';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Avatar(name: name, size: 64),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (userName != null)
                  Text(
                    userName!,
                    style: AppTypography.headingSmall,
                  ),
                if (userHandle != null)
                  Text(
                    userHandle!,
                    style: AppTypography.bodyMedium.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () {
              // TODO: Edit profile
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: AppTypography.labelSmall.copyWith(
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildThemeTile(BuildContext context) {
    String themeText;
    switch (themeMode) {
      case AppThemeMode.system:
        themeText = 'System';
        break;
      case AppThemeMode.light:
        themeText = 'Light';
        break;
      case AppThemeMode.dark:
        themeText = 'Dark';
        break;
    }

    return ListTile(
      leading: Icon(
        Icons.palette_outlined,
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
      ),
      title: const Text('Theme'),
      subtitle: Text(themeText),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        showModalBottomSheet(
          context: context,
          builder: (context) => _ThemeSelector(
            currentMode: themeMode,
            onSelected: (mode) {
              Navigator.pop(context);
              onThemeModeChanged?.call(mode);
            },
          ),
        );
      },
    );
  }

  Widget _buildSwitchTile(
    BuildContext context, {
    required String title,
    String? subtitle,
    required bool value,
    required void Function(bool)? onChanged,
    required IconData icon,
  }) {
    return SwitchListTile(
      secondary: Icon(
        icon,
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
      ),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required String title,
    String? subtitle,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
      ),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Widget _buildInfoTile(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
      ),
      title: Text(title),
      trailing: Text(
        value,
        style: AppTypography.bodyMedium.copyWith(
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
        ),
      ),
    );
  }
}

class _ThemeSelector extends StatelessWidget {
  final AppThemeMode currentMode;
  final void Function(AppThemeMode) onSelected;

  const _ThemeSelector({
    required this.currentMode,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Choose Theme',
              style: AppTypography.headingSmall,
            ),
          ),
          const Divider(height: 1),
          _buildOption(context, AppThemeMode.system, 'System', Icons.settings_suggest_outlined),
          _buildOption(context, AppThemeMode.light, 'Light', Icons.light_mode_outlined),
          _buildOption(context, AppThemeMode.dark, 'Dark', Icons.dark_mode_outlined),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildOption(
    BuildContext context,
    AppThemeMode mode,
    String label,
    IconData icon,
  ) {
    final isSelected = currentMode == mode;

    return ListTile(
      leading: Icon(
        icon,
        color: isSelected
            ? AppColors.primary
            : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? AppColors.primary : null,
          fontWeight: isSelected ? FontWeight.w600 : null,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check, color: AppColors.primary)
          : null,
      onTap: () => onSelected(mode),
    );
  }
}
