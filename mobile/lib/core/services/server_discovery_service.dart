import 'dart:async';
import 'dart:math';
import 'package:dio/dio.dart';
import '../constants/api_constants.dart';

class ServerDiscoveryService {
  static const Duration _timeout = Duration(milliseconds: 800);
  static const int _batchSize = 40;

  // Teste si une URL est bien le backend KoVoit
  Future<bool> ping(String serverUrl) async {
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: _timeout,
        receiveTimeout: _timeout,
        validateStatus: (s) => s != null && s < 500,
      ));
      final resp = await dio.get('$serverUrl${ApiConstants.pingPath}');
      if (resp.statusCode != 200) return false;
      final data = resp.data;
      return data is Map &&
          data['status'] == 'ok' &&
          data['service'] == 'backend';
    } catch (_) {
      return false;
    }
  }

  // Découverte automatique avec progression
  Future<String?> discover({void Function(String message)? onProgress}) async {
    // Phase 1 : IPs prioritaires (émulateur, gateway communs)
    onProgress?.call('Recherche du serveur...');
    for (final ip in ApiConstants.quickCandidates) {
      final url = 'http://$ip:${ApiConstants.port}';
      if (await ping(url)) return url;
    }

    // Phase 2 : Scan des plages .1-50 sur tous les sous-réseaux
    onProgress?.call('Scan du réseau local...');
    final result2 = await _scanRange(1, 50, onProgress);
    if (result2 != null) return result2;

    // Phase 3 : Scan étendu .51-254
    onProgress?.call('Scan étendu en cours...');
    return await _scanRange(51, 254, onProgress);
  }

  Future<String?> _scanRange(
    int start,
    int end,
    void Function(String)? onProgress,
  ) async {
    final candidates = <String>[];
    for (final subnet in ApiConstants.scanSubnets) {
      for (int i = start; i <= end; i++) {
        candidates.add('http://$subnet.$i:${ApiConstants.port}');
      }
    }

    for (int i = 0; i < candidates.length; i += _batchSize) {
      final batch =
          candidates.sublist(i, min(i + _batchSize, candidates.length));

      final completer = Completer<String?>();
      int done = 0;

      for (final url in batch) {
        ping(url).then((ok) {
          if (completer.isCompleted) return;
          if (ok) {
            completer.complete(url);
          } else {
            done++;
            if (done >= batch.length) completer.complete(null);
          }
        });
      }

      final found = await completer.future;
      if (found != null) return found;
    }
    return null;
  }
}
