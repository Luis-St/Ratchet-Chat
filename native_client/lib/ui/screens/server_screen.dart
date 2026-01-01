import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/server_provider.dart';
import '../../routing/app_router.dart';

/// Screen for entering the server URL.
class ServerScreen extends ConsumerStatefulWidget {
    const ServerScreen({super.key, this.prefillUrl});

    /// Optional URL to prefill in the text field.
    final String? prefillUrl;

    @override
    ConsumerState<ServerScreen> createState() => _ServerScreenState();
}

class _ServerScreenState extends ConsumerState<ServerScreen> {
    final _formKey = GlobalKey<FormState>();
    final _urlController = TextEditingController();
    bool _saveServer = true;

    @override
    void initState() {
        super.initState();
        // Prefill URL if provided
        if (widget.prefillUrl != null && widget.prefillUrl!.isNotEmpty) {
            _urlController.text = widget.prefillUrl!;
        }
    }

    @override
    void dispose() {
        _urlController.dispose();
        super.dispose();
    }

    Future<void> _submit() async {
        if (!_formKey.currentState!.validate()) return;

        final success = await ref
            .read(serverProvider.notifier)
            .validateAndSetServer(_urlController.text.trim(), save: _saveServer);

        if (success && mounted) {
            context.go(AppRoutes.login);
        }
    }

    @override
    Widget build(BuildContext context) {
        final serverState = ref.watch(serverProvider);
        final theme = Theme.of(context);

        return Scaffold(
            body: SafeArea(
                child: Center(
                    child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 400),
                            child: Form(
                                key: _formKey,
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
                                        const SizedBox(height: 8),
                                        Text(
                                            'Enter your server address',
                                            style: theme.textTheme.bodyLarge?.copyWith(
                                                color: theme.colorScheme.onSurfaceVariant,
                                            ),
                                            textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 48),

                                        // Server URL field
                                        TextFormField(
                                            controller: _urlController,
                                            decoration: const InputDecoration(
                                                labelText: 'Server URL',
                                                hintText: 'chat.example.com',
                                                prefixIcon: Icon(Icons.dns_outlined),
                                                border: OutlineInputBorder(),
                                            ),
                                            keyboardType: TextInputType.url,
                                            textInputAction: TextInputAction.done,
                                            autocorrect: false,
                                            enabled: !serverState.isLoading,
                                            validator: (value) {
                                                if (value == null || value.trim().isEmpty) {
                                                    return 'Please enter a server URL';
                                                }
                                                return null;
                                            },
                                            onFieldSubmitted: (_) => _submit(),
                                        ),
                                        const SizedBox(height: 16),

                                        // Remember server checkbox
                                        CheckboxListTile(
                                            value: _saveServer,
                                            onChanged: serverState.isLoading
                                                ? null
                                                : (value) => setState(() => _saveServer = value!),
                                            title: const Text('Remember this server'),
                                            controlAffinity: ListTileControlAffinity.leading,
                                            contentPadding: EdgeInsets.zero,
                                        ),

                                        // Error message
                                        if (serverState.error != null) ...[
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
                                                                serverState.error!,
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

                                        // Continue button
                                        FilledButton(
                                            onPressed: serverState.isLoading ? null : _submit,
                                            child: Padding(
                                                padding: const EdgeInsets.all(12),
                                                child: serverState.isLoading
                                                    ? const SizedBox(
                                                        height: 24,
                                                        width: 24,
                                                        child: CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                        ),
                                                      )
                                                    : const Text('Continue'),
                                            ),
                                        ),
                                    ],
                                ),
                            ),
                        ),
                    ),
                ),
            ),
        );
    }
}
