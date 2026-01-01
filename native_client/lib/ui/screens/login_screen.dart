import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../providers/server_provider.dart';
import '../../routing/app_router.dart';

/// Screen for user login and registration.
class LoginScreen extends ConsumerStatefulWidget {
    const LoginScreen({super.key});

    @override
    ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with SingleTickerProviderStateMixin {
    final _formKey = GlobalKey<FormState>();
    final _usernameController = TextEditingController();
    final _passwordController = TextEditingController();
    final _confirmPasswordController = TextEditingController();
    late TabController _tabController;
    bool _savePassword = false;
    bool _obscurePassword = true;
    bool _obscureConfirmPassword = true;

    bool get _isRegisterMode => _tabController.index == 1;

    @override
    void initState() {
        super.initState();
        _tabController = TabController(length: 2, vsync: this);
        _tabController.addListener(() {
            if (!_tabController.indexIsChanging) {
                setState(() {});
                // Clear form when switching tabs
                _formKey.currentState?.reset();
                ref.read(authProvider.notifier).clearError();
            }
        });
    }

    @override
    void dispose() {
        _usernameController.dispose();
        _passwordController.dispose();
        _confirmPasswordController.dispose();
        _tabController.dispose();
        super.dispose();
    }

    Future<void> _submit() async {
        if (!_formKey.currentState!.validate()) return;

        if (_isRegisterMode) {
            await ref.read(authProvider.notifier).register(
                username: _usernameController.text.trim(),
                password: _passwordController.text,
                savePassword: _savePassword,
            );
        } else {
            await ref.read(authProvider.notifier).login(
                username: _usernameController.text.trim(),
                password: _passwordController.text,
                savePassword: _savePassword,
            );
        }
    }

    void _changeServer() {
        final currentUrl = ref.read(serverProvider).activeServer?.url;
        ref.read(serverProvider.notifier).clearSavedServer();
        if (currentUrl != null) {
            context.go('${AppRoutes.server}?prefill=${Uri.encodeComponent(currentUrl)}');
        } else {
            context.go(AppRoutes.server);
        }
    }

    @override
    Widget build(BuildContext context) {
        final authState = ref.watch(authProvider);
        final serverState = ref.watch(serverProvider);
        final theme = Theme.of(context);
        final isLoading = authState.isLoading;

        return Scaffold(
            body: SafeArea(
                child: Center(
                    child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 400),
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                    // Logo/Title
                                    Icon(
                                        Icons.chat_bubble_outline,
                                        size: 64,
                                        color: theme.colorScheme.primary,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                        'Ratchet Chat',
                                        style: theme.textTheme.headlineMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 24),

                                    // Server indicator
                                    if (serverState.activeServer != null) ...[
                                        Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 12,
                                            ),
                                            decoration: BoxDecoration(
                                                color: theme.colorScheme.surfaceContainerHighest,
                                                borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                                children: [
                                                    Icon(
                                                        Icons.dns_outlined,
                                                        size: 20,
                                                        color: theme.colorScheme.onSurfaceVariant,
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                        child: Text(
                                                            serverState.activeServer!.displayName,
                                                            style: theme.textTheme.bodyMedium?.copyWith(
                                                                color: theme.colorScheme.onSurfaceVariant,
                                                            ),
                                                        ),
                                                    ),
                                                    TextButton(
                                                        onPressed: isLoading ? null : _changeServer,
                                                        child: const Text('Change'),
                                                    ),
                                                ],
                                            ),
                                        ),
                                        const SizedBox(height: 24),
                                    ],

                                    // Tab bar for Login/Register
                                    Container(
                                        decoration: BoxDecoration(
                                            color: theme.colorScheme.surfaceContainerHighest,
                                            borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: TabBar(
                                            controller: _tabController,
                                            indicator: BoxDecoration(
                                                color: theme.colorScheme.primary,
                                                borderRadius: BorderRadius.circular(12),
                                            ),
                                            indicatorSize: TabBarIndicatorSize.tab,
                                            dividerColor: Colors.transparent,
                                            labelColor: theme.colorScheme.onPrimary,
                                            unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                                            tabs: const [
                                                Tab(text: 'Login'),
                                                Tab(text: 'Register'),
                                            ],
                                        ),
                                    ),
                                    const SizedBox(height: 24),

                                    // Form
                                    Form(
                                        key: _formKey,
                                        child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.stretch,
                                            children: [
                                                // Username field
                                                TextFormField(
                                                    controller: _usernameController,
                                                    decoration: const InputDecoration(
                                                        labelText: 'Username',
                                                        prefixIcon: Icon(Icons.person_outline),
                                                        border: OutlineInputBorder(),
                                                    ),
                                                    textInputAction: TextInputAction.next,
                                                    autocorrect: false,
                                                    enabled: !isLoading,
                                                    validator: (value) {
                                                        if (value == null || value.trim().isEmpty) {
                                                            return 'Please enter a username';
                                                        }
                                                        if (value.contains('@')) {
                                                            return 'Enter username without @domain';
                                                        }
                                                        if (_isRegisterMode && value.length < 3) {
                                                            return 'Username must be at least 3 characters';
                                                        }
                                                        return null;
                                                    },
                                                ),
                                                const SizedBox(height: 16),

                                                // Password field
                                                TextFormField(
                                                    controller: _passwordController,
                                                    decoration: InputDecoration(
                                                        labelText: 'Password',
                                                        prefixIcon: const Icon(Icons.lock_outline),
                                                        border: const OutlineInputBorder(),
                                                        suffixIcon: IconButton(
                                                            icon: Icon(
                                                                _obscurePassword
                                                                    ? Icons.visibility_outlined
                                                                    : Icons.visibility_off_outlined,
                                                            ),
                                                            onPressed: () {
                                                                setState(() => _obscurePassword = !_obscurePassword);
                                                            },
                                                        ),
                                                    ),
                                                    obscureText: _obscurePassword,
                                                    textInputAction: _isRegisterMode
                                                        ? TextInputAction.next
                                                        : TextInputAction.done,
                                                    enabled: !isLoading,
                                                    validator: (value) {
                                                        if (value == null || value.isEmpty) {
                                                            return 'Please enter a password';
                                                        }
                                                        if (_isRegisterMode && value.length < 8) {
                                                            return 'Password must be at least 8 characters';
                                                        }
                                                        return null;
                                                    },
                                                    onFieldSubmitted: _isRegisterMode ? null : (_) => _submit(),
                                                ),

                                                // Confirm password field (only for registration)
                                                if (_isRegisterMode) ...[
                                                    const SizedBox(height: 16),
                                                    TextFormField(
                                                        controller: _confirmPasswordController,
                                                        decoration: InputDecoration(
                                                            labelText: 'Confirm Password',
                                                            prefixIcon: const Icon(Icons.lock_outline),
                                                            border: const OutlineInputBorder(),
                                                            suffixIcon: IconButton(
                                                                icon: Icon(
                                                                    _obscureConfirmPassword
                                                                        ? Icons.visibility_outlined
                                                                        : Icons.visibility_off_outlined,
                                                                ),
                                                                onPressed: () {
                                                                    setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                                                                },
                                                            ),
                                                        ),
                                                        obscureText: _obscureConfirmPassword,
                                                        textInputAction: TextInputAction.done,
                                                        enabled: !isLoading,
                                                        validator: (value) {
                                                            if (value == null || value.isEmpty) {
                                                                return 'Please confirm your password';
                                                            }
                                                            if (value != _passwordController.text) {
                                                                return 'Passwords do not match';
                                                            }
                                                            return null;
                                                        },
                                                        onFieldSubmitted: (_) => _submit(),
                                                    ),
                                                ],

                                                const SizedBox(height: 16),

                                                // Remember password checkbox
                                                CheckboxListTile(
                                                    value: _savePassword,
                                                    onChanged: isLoading
                                                        ? null
                                                        : (value) => setState(() => _savePassword = value!),
                                                    title: const Text('Remember password on this device'),
                                                    controlAffinity: ListTileControlAffinity.leading,
                                                    contentPadding: EdgeInsets.zero,
                                                ),

                                                // Error message
                                                if (authState.error != null) ...[
                                                    const SizedBox(height: 16),
                                                    Container(
                                                        padding: const EdgeInsets.all(12),
                                                        decoration: BoxDecoration(
                                                            color: theme.colorScheme.errorContainer,
                                                            borderRadius: BorderRadius.circular(8),
                                                        ),
                                                        child: Row(
                                                            children: [
                                                                Icon(
                                                                    Icons.error_outline,
                                                                    color: theme.colorScheme.onErrorContainer,
                                                                ),
                                                                const SizedBox(width: 12),
                                                                Expanded(
                                                                    child: Text(
                                                                        authState.error!,
                                                                        style: TextStyle(
                                                                            color: theme.colorScheme.onErrorContainer,
                                                                        ),
                                                                    ),
                                                                ),
                                                            ],
                                                        ),
                                                    ),
                                                ],

                                                const SizedBox(height: 24),

                                                // Submit button
                                                FilledButton(
                                                    onPressed: isLoading ? null : _submit,
                                                    child: Padding(
                                                        padding: const EdgeInsets.all(12),
                                                        child: isLoading
                                                            ? const SizedBox(
                                                                height: 24,
                                                                width: 24,
                                                                child: CircularProgressIndicator(
                                                                    strokeWidth: 2,
                                                                ),
                                                              )
                                                            : Text(_isRegisterMode ? 'Register' : 'Login'),
                                                    ),
                                                ),
                                            ],
                                        ),
                                    ),
                                ],
                            ),
                        ),
                    ),
                ),
            ),
        );
    }
}
