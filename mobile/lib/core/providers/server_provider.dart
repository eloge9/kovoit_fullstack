import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/api_constants.dart';
import '../network/dio_client.dart';
import '../services/server_discovery_service.dart';
import '../services/storage_service.dart';

enum ServerStatus {
  idle,        // État initial
  checking,    // Test de l'URL sauvegardée
  discovering, // Scan du réseau
  connected,   // Serveur trouvé et opérationnel
  notFound,    // Aucun serveur détecté
}

class ServerState {
  final ServerStatus status;
  final String? serverUrl;
  final String message;

  const ServerState({
    required this.status,
    this.serverUrl,
    this.message = '',
  });

  bool get isConnected => status == ServerStatus.connected;
  bool get isBusy =>
      status == ServerStatus.checking ||
      status == ServerStatus.discovering;

  ServerState copyWith({
    ServerStatus? status,
    String? serverUrl,
    String? message,
  }) =>
      ServerState(
        status: status ?? this.status,
        serverUrl: serverUrl ?? this.serverUrl,
        message: message ?? this.message,
      );
}

class ServerNotifier extends StateNotifier<ServerState> {
  final ServerDiscoveryService _discovery = ServerDiscoveryService();

  ServerNotifier()
      : super(const ServerState(status: ServerStatus.idle));

  // Appelé au démarrage depuis SplashScreen
  Future<void> initialize() async {
    state = const ServerState(
      status: ServerStatus.checking,
      message: 'Vérification du serveur...',
    );

    // 1. Toujours essayer l'URL sauvegardée manuellement en premier
    //    (permet de pointer vers un serveur local même en release)
    final saved = await StorageService.getServerUrl();
    if (saved != null) {
      final ok = await _discovery.ping(saved);
      if (ok) {
        _applyUrl(saved);
        return;
      }
    }

    // 2. En production (release), essayer l'URL de production
    if (kReleaseMode) {
      state = state.copyWith(message: 'Connexion au serveur de production...');
      final ok = await _discovery.ping(ApiConstants.productionUrl);
      if (ok) {
        _applyUrl(ApiConstants.productionUrl);
      } else {
        state = const ServerState(
          status: ServerStatus.notFound,
          message: 'Impossible de joindre le serveur. Vérifiez votre connexion.',
        );
      }
      return;
    }

    // 3. Debug : découverte automatique sur le réseau local
    state = const ServerState(
      status: ServerStatus.discovering,
      message: 'Recherche du serveur...',
    );

    final found = await _discovery.discover(
      onProgress: (msg) {
        if (mounted) {
          state = state.copyWith(
            status: ServerStatus.discovering,
            message: msg,
          );
        }
      },
    );

    if (found != null) {
      await StorageService.saveServerUrl(found);
      _applyUrl(found);
    } else {
      state = const ServerState(
        status: ServerStatus.notFound,
        message: 'Serveur introuvable sur le réseau local.',
      );
    }
  }

  // Définir une URL manuellement et la tester
  Future<bool> setManualUrl(String url) async {
    final cleaned = url.trim().replaceAll(RegExp(r'/$'), '');
    state = state.copyWith(
      status: ServerStatus.checking,
      message: 'Test de la connexion...',
    );

    final ok = await _discovery.ping(cleaned);
    if (ok) {
      await StorageService.saveServerUrl(cleaned);
      _applyUrl(cleaned);
      return true;
    } else {
      state = state.copyWith(
        status: ServerStatus.notFound,
        message: 'Impossible de joindre $cleaned',
      );
      return false;
    }
  }

  // Tester la connexion avec l'URL actuelle
  Future<bool> testConnection() async {
    final url = state.serverUrl;
    if (url == null) return false;
    state = state.copyWith(
      status: ServerStatus.checking,
      message: 'Test en cours...',
    );
    final ok = await _discovery.ping(url);
    if (ok) {
      state = state.copyWith(
        status: ServerStatus.connected,
        message: 'Connecté',
      );
    } else {
      state = state.copyWith(
        status: ServerStatus.notFound,
        message: 'Serveur inaccessible',
      );
    }
    return ok;
  }

  // Relancer la découverte automatique
  Future<void> rediscover() async {
    state = const ServerState(
      status: ServerStatus.discovering,
      message: 'Scan du réseau...',
    );

    final found = await _discovery.discover(
      onProgress: (msg) {
        if (mounted) state = state.copyWith(message: msg);
      },
    );

    if (found != null) {
      await StorageService.saveServerUrl(found);
      _applyUrl(found);
    } else {
      state = const ServerState(
        status: ServerStatus.notFound,
        message: 'Serveur introuvable.',
      );
    }
  }

  // Réinitialiser la configuration
  Future<void> reset() async {
    await StorageService.clearServerUrl();
    state = const ServerState(
      status: ServerStatus.idle,
      message: 'Configuration réinitialisée.',
    );
  }

  void _applyUrl(String url) {
    ApiConstants.updateServerUrl(url);
    DioClient.reset();
    state = ServerState(
      status: ServerStatus.connected,
      serverUrl: url,
      message: 'Connecté à $url',
    );
  }
}

final serverProvider =
    StateNotifierProvider<ServerNotifier, ServerState>((ref) {
  return ServerNotifier();
});
