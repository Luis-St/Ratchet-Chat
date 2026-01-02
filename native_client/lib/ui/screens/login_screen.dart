import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../providers/server_provider.dart';
import '../../routing/app_router.dart';

/// Registration method options.
enum RegistrationMethod {
  passkey,
  password2fa,
}

/// Screen for user login and registration.
class LoginScreen extends ConsumerStatefulWidget {
    const LoginScreen({super.key});

    @override
    ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with SingleTickerProviderStateMixin {
    final _formKey = GlobalKey<FormState>();
    final _usernameController = TextEditingController();
    // For login and passkey registration (single password)
    final _passwordController = TextEditingController();
    final _confirmPasswordController = TextEditingController();
    // For password+2FA registration (two passwords)
    final _accountPasswordController = TextEditingController();
    final _confirmAccountPasswordController = TextEditingController();
    final _masterPasswordController = TextEditingController();
    final _confirmMasterPasswordController = TextEditingController();
    late TabController _tabController;
    bool _savePassword = false;
    bool _obscurePassword = true;
    bool _obscureConfirmPassword = true;
    bool _obscureAccountPassword = true;
    bool _obscureConfirmAccountPassword = true;
    bool _obscureMasterPassword = true;
    bool _obscureConfirmMasterPassword = true;
    RegistrationMethod _registrationMethod = RegistrationMethod.passkey;

    bool get _isRegisterMode => _tabController.index == 1;
    bool get _isPasskeyRegistration => _registrationMethod == RegistrationMethod.passkey;
    bool get _isPassword2faRegistration => _isRegisterMode && !_isPasskeyRegistration;

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
        _accountPasswordController.dispose();
        _confirmAccountPasswordController.dispose();
        _masterPasswordController.dispose();
        _confirmMasterPasswordController.dispose();
        _tabController.dispose();
        super.dispose();
    }

    Future<void> _submit() async {
        if (!_formKey.currentState!.validate()) return;

        final authNotifier = ref.read(authProvider.notifier);

        if (_isRegisterMode) {
            if (_isPasskeyRegistration && authNotifier.isPasskeySupported) {
                // Passkey registration (single password = master password)
                await authNotifier.registerWithPasskey(
                    username: _usernameController.text.trim(),
                    password: _passwordController.text,
                    savePassword: _savePassword,
                );
            } else {
                // Password + 2FA registration (two passwords)
                await authNotifier.registerWithPassword(
                    username: _usernameController.text.trim(),
                    accountPassword: _accountPasswordController.text,
                    masterPassword: _masterPasswordController.text,
                    savePassword: _savePassword,
                );
            }
        } else {
            // Login (account password only, master password prompted separately)
            await authNotifier.login(
                username: _usernameController.text.trim(),
                password: _passwordController.text,
                savePassword: _savePassword,
            );
        }
    }

    Future<void> _loginWithPasskey() async {
        await ref.read(authProvider.notifier).loginWithPasskey();
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
        final authNotifier = ref.read(authProvider.notifier);
        final theme = Theme.of(context);
        final isLoading = authState.isLoading;
        final passkeySupported = authNotifier.isPasskeySupported;

        // If passkey not supported and in register mode, force password+2FA method
        if (_isRegisterMode && !passkeySupported && _registrationMethod == RegistrationMethod.passkey) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
                setState(() => _registrationMethod = RegistrationMethod.password2fa);
            });
        }

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

                                    // Registration method selector (only in Register mode when passkey is supported)
                                    if (_isRegisterMode && passkeySupported) ...[
                                        SegmentedButton<RegistrationMethod>(
                                            segments: const [
                                                ButtonSegment(
                                                    value: RegistrationMethod.passkey,
                                                    label: Text('Passkey'),
                                                    icon: Icon(Icons.fingerprint),
                                                ),
                                                ButtonSegment(
                                                    value: RegistrationMethod.password2fa,
                                                    label: Text('Password + 2FA'),
                                                    icon: Icon(Icons.security),
                                                ),
                                            ],
                                            selected: {_registrationMethod},
                                            onSelectionChanged: isLoading
                                                ? null
                                                : (Set<RegistrationMethod> selection) {
                                                    setState(() {
                                                        _registrationMethod = selection.first;
                                                    });
                                                    _formKey.currentState?.reset();
                                                    ref.read(authProvider.notifier).clearError();
                                                },
                                        ),
                                        const SizedBox(height: 24),
                                    ],

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

                                                // Password fields differ based on mode:
                                                // - Login: single password (account password)
                                                // - Passkey register: single password (master password)
                                                // - Password+2FA register: two passwords (account + master)

                                                if (_isPassword2faRegistration) ...[
                                                    // Password+2FA registration: Account Password
                                                    TextFormField(
                                                        controller: _accountPasswordController,
                                                        decoration: InputDecoration(
                                                            labelText: 'Account Password',
                                                            helperText: 'Used for server authentication',
                                                            prefixIcon: const Icon(Icons.lock_outline),
                                                            border: const OutlineInputBorder(),
                                                            suffixIcon: IconButton(
                                                                icon: Icon(
                                                                    _obscureAccountPassword
                                                                        ? Icons.visibility_outlined
                                                                        : Icons.visibility_off_outlined,
                                                                ),
                                                                onPressed: () {
                                                                    setState(() => _obscureAccountPassword = !_obscureAccountPassword);
                                                                },
                                                            ),
                                                        ),
                                                        obscureText: _obscureAccountPassword,
                                                        textInputAction: TextInputAction.next,
                                                        enabled: !isLoading,
                                                        validator: (value) {
                                                            if (value == null || value.isEmpty) {
                                                                return 'Please enter an account password';
                                                            }
                                                            if (value.length < 8) {
                                                                return 'Password must be at least 8 characters';
                                                            }
                                                            return null;
                                                        },
                                                    ),
                                                    const SizedBox(height: 16),
                                                    // Confirm Account Password
                                                    TextFormField(
                                                        controller: _confirmAccountPasswordController,
                                                        decoration: InputDecoration(
                                                            labelText: 'Confirm Account Password',
                                                            prefixIcon: const Icon(Icons.lock_outline),
                                                            border: const OutlineInputBorder(),
                                                            suffixIcon: IconButton(
                                                                icon: Icon(
                                                                    _obscureConfirmAccountPassword
                                                                        ? Icons.visibility_outlined
                                                                        : Icons.visibility_off_outlined,
                                                                ),
                                                                onPressed: () {
                                                                    setState(() => _obscureConfirmAccountPassword = !_obscureConfirmAccountPassword);
                                                                },
                                                            ),
                                                        ),
                                                        obscureText: _obscureConfirmAccountPassword,
                                                        textInputAction: TextInputAction.next,
                                                        enabled: !isLoading,
                                                        validator: (value) {
                                                            if (value == null || value.isEmpty) {
                                                                return 'Please confirm your account password';
                                                            }
                                                            if (value != _accountPasswordController.text) {
                                                                return 'Passwords do not match';
                                                            }
                                                            return null;
                                                        },
                                                    ),
                                                    const SizedBox(height: 24),
                                                    // Master Password
                                                    TextFormField(
                                                        controller: _masterPasswordController,
                                                        decoration: InputDecoration(
                                                            labelText: 'Master Password',
                                                            helperText: 'Used to encrypt your data locally',
                                                            prefixIcon: const Icon(Icons.key_outlined),
                                                            border: const OutlineInputBorder(),
                                                            suffixIcon: IconButton(
                                                                icon: Icon(
                                                                    _obscureMasterPassword
                                                                        ? Icons.visibility_outlined
                                                                        : Icons.visibility_off_outlined,
                                                                ),
                                                                onPressed: () {
                                                                    setState(() => _obscureMasterPassword = !_obscureMasterPassword);
                                                                },
                                                            ),
                                                        ),
                                                        obscureText: _obscureMasterPassword,
                                                        textInputAction: TextInputAction.next,
                                                        enabled: !isLoading,
                                                        validator: (value) {
                                                            if (value == null || value.isEmpty) {
                                                                return 'Please enter a master password';
                                                            }
                                                            if (value.length < 8) {
                                                                return 'Password must be at least 8 characters';
                                                            }
                                                            return null;
                                                        },
                                                    ),
                                                    const SizedBox(height: 16),
                                                    // Confirm Master Password
                                                    TextFormField(
                                                        controller: _confirmMasterPasswordController,
                                                        decoration: InputDecoration(
                                                            labelText: 'Confirm Master Password',
                                                            prefixIcon: const Icon(Icons.key_outlined),
                                                            border: const OutlineInputBorder(),
                                                            suffixIcon: IconButton(
                                                                icon: Icon(
                                                                    _obscureConfirmMasterPassword
                                                                        ? Icons.visibility_outlined
                                                                        : Icons.visibility_off_outlined,
                                                                ),
                                                                onPressed: () {
                                                                    setState(() => _obscureConfirmMasterPassword = !_obscureConfirmMasterPassword);
                                                                },
                                                            ),
                                                        ),
                                                        obscureText: _obscureConfirmMasterPassword,
                                                        textInputAction: TextInputAction.done,
                                                        enabled: !isLoading,
                                                        validator: (value) {
                                                            if (value == null || value.isEmpty) {
                                                                return 'Please confirm your master password';
                                                            }
                                                            if (value != _masterPasswordController.text) {
                                                                return 'Passwords do not match';
                                                            }
                                                            return null;
                                                        },
                                                        onFieldSubmitted: (_) => _submit(),
                                                    ),
                                                ] else ...[
                                                    // Login or Passkey registration: single password
                                                    TextFormField(
                                                        controller: _passwordController,
                                                        decoration: InputDecoration(
                                                            labelText: _isRegisterMode ? 'Master Password' : 'Password',
                                                            helperText: _isRegisterMode ? 'Used to encrypt your data locally' : null,
                                                            prefixIcon: Icon(_isRegisterMode ? Icons.key_outlined : Icons.lock_outline),
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

                                                    // Confirm password field (only for passkey registration)
                                                    if (_isRegisterMode) ...[
                                                        const SizedBox(height: 16),
                                                        TextFormField(
                                                            controller: _confirmPasswordController,
                                                            decoration: InputDecoration(
                                                                labelText: 'Confirm Master Password',
                                                                prefixIcon: const Icon(Icons.key_outlined),
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

                                                // Passkey login button (only in Login tab and on supported platforms)
                                                if (!_isRegisterMode && passkeySupported) ...[
                                                    const SizedBox(height: 24),
                                                    Row(
                                                        children: [
                                                            Expanded(child: Divider(color: theme.colorScheme.outline)),
                                                            Padding(
                                                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                                                child: Text(
                                                                    'or',
                                                                    style: TextStyle(
                                                                        color: theme.colorScheme.onSurfaceVariant,
                                                                    ),
                                                                ),
                                                            ),
                                                            Expanded(child: Divider(color: theme.colorScheme.outline)),
                                                        ],
                                                    ),
                                                    const SizedBox(height: 24),
                                                    OutlinedButton.icon(
                                                        onPressed: isLoading ? null : _loginWithPasskey,
                                                        icon: const Icon(Icons.fingerprint),
                                                        label: const Padding(
                                                            padding: EdgeInsets.all(12),
                                                            child: Text('Sign in with Passkey'),
                                                        ),
                                                    ),
                                                ],
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
