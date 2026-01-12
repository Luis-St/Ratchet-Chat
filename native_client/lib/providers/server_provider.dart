import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/server_config.dart';
import '../data/repositories/server_repository.dart';
import 'service_providers.dart';

/// State for server configuration.
class ServerState {
  const ServerState({
    this.savedServer,
    this.currentServer,
    this.isLoading = false,
    this.error,
  });

  final ServerConfig? savedServer;
  final ServerConfig? currentServer;
  final bool isLoading;
  final String? error;

  /// Whether a server is available (saved or current).
  bool get hasServer => currentServer != null || savedServer != null;

  /// The active server (current takes precedence over saved).
  ServerConfig? get activeServer => currentServer ?? savedServer;

  ServerState copyWith({
    ServerConfig? savedServer,
    ServerConfig? currentServer,
    bool? isLoading,
    String? error,
    bool clearSaved = false,
    bool clearCurrent = false,
    bool clearError = false,
  }) {
    return ServerState(
      savedServer: clearSaved ? null : (savedServer ?? this.savedServer),
      currentServer: clearCurrent
          ? null
          : (currentServer ?? this.currentServer),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Notifier for managing server state.
class ServerNotifier extends Notifier<ServerState> {
  late final ServerRepository _serverRepository;
  late final dynamic _apiService;

  @override
  ServerState build() {
    _serverRepository = ref.watch(serverRepositoryProvider);
    _apiService = ref.watch(apiServiceProvider);
    _init();
    return const ServerState(isLoading: true);
  }

  Future<void> _init() async {
    try {
      final savedServer = await _serverRepository.getSavedServer();
      if (savedServer != null) {
        _apiService.setBaseUrl(savedServer.url);
      }
      state = ServerState(savedServer: savedServer);
    } catch (e) {
      state = ServerState(error: e.toString());
    }
  }

  /// Validates and sets the current server.
  Future<bool> validateAndSetServer(String url, {bool save = false}) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final result = await _serverRepository.validateServer(url);
      if (!result.isValid) {
        state = state.copyWith(
          isLoading: false,
          error: result.error ?? 'Invalid server',
        );
        return false;
      }

      final normalizedUrl = _serverRepository.normalizeUrl(url)!;
      final config = ServerConfig(
        url: normalizedUrl,
        name: result.serverName,
        isSaved: save,
      );

      if (save) {
        await _serverRepository.saveServer(config);
        state = state.copyWith(
          savedServer: config,
          currentServer: config,
          isLoading: false,
        );
      } else {
        state = state.copyWith(currentServer: config, isLoading: false);
      }

      _apiService.setBaseUrl(normalizedUrl);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Clears the saved server.
  Future<void> clearSavedServer() async {
    await _serverRepository.clearSavedServer();
    state = state.copyWith(clearSaved: true, clearCurrent: true);
  }

  /// Clears the current (unsaved) server.
  void clearCurrentServer() {
    state = state.copyWith(clearCurrent: true);
  }

  /// Clears any error.
  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

/// Provider for server state.
final serverProvider = NotifierProvider<ServerNotifier, ServerState>(
  ServerNotifier.new,
);
