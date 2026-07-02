import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import '../constants/api_constants.dart';

class ServerDiscoveryService {
  static const Duration _timeout = Duration(milliseconds: 500);
  static const int _batchSize = 60;

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

  /// Détecte les sous-réseaux IPv4 actifs du téléphone via dart:io.
  /// Ex : téléphone sur 192.168.43.105 → retourne ['192.168.43']
  Future<List<String>> _deviceSubnets() async {
    final subnets = <String>[];
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final parts = addr.address.split('.');
          if (parts.length == 4 && parts[0] != '127') {
            final subnet = '${parts[0]}.${parts[1]}.${parts[2]}';
            if (!subnets.contains(subnet)) subnets.add(subnet);
          }
        }
      }
    } catch (_) {}
    return subnets;
  }

  Future<String?> discover({void Function(String message)? onProgress}) async {
    onProgress?.call('Détection du réseau...');

    // Récupérer les vrais sous-réseaux du téléphone
    final deviceSubnets = await _deviceSubnets();

    // Phase 1 : IPs prioritaires sur les sous-réseaux détectés
    onProgress?.call('Recherche rapide...');
    final quickUrls = <String>[];
    for (final subnet in deviceSubnets) {
      // Tester les IPs les plus communes en premier : .1 .2 .100 .101 .50
      for (final host in [1, 2, 100, 101, 50, 10, 254]) {
        quickUrls.add('http://$subnet.$host:${ApiConstants.port}');
      }
    }
    // Candidats hardcodés en fallback (émulateur Android, etc.)
    for (final ip in ApiConstants.quickCandidates) {
      final url = 'http://$ip:${ApiConstants.port}';
      if (!quickUrls.contains(url)) quickUrls.add(url);
    }

    // Test rapide en parallèle
    final found = await _pingBatch(quickUrls);
    if (found != null) return found;

    // Phase 2 : scan complet des sous-réseaux du téléphone
    final subnetsToScan = deviceSubnets.isNotEmpty
        ? deviceSubnets
        : ApiConstants.scanSubnets;

    onProgress?.call('Scan du réseau (${subnetsToScan.join(", ")})...');
    return await _scanFull(subnetsToScan, onProgress);
  }

  /// Teste toutes les URLs en parallèle, retourne la première qui répond.
  Future<String?> _pingBatch(List<String> urls) async {
    if (urls.isEmpty) return null;
    final completer = Completer<String?>();
    int done = 0;
    for (final url in urls) {
      ping(url).then((ok) {
        if (completer.isCompleted) return;
        if (ok) {
          completer.complete(url);
        } else {
          done++;
          if (done >= urls.length) completer.complete(null);
        }
      });
    }
    return completer.future;
  }

  Future<String?> _scanFull(
    List<String> subnets,
    void Function(String)? onProgress,
  ) async {
    final candidates = <String>[];
    for (final subnet in subnets) {
      for (int i = 1; i <= 254; i++) {
        candidates.add('http://$subnet.$i:${ApiConstants.port}');
      }
    }

    for (int i = 0; i < candidates.length; i += _batchSize) {
      final batch = candidates.sublist(i, min(i + _batchSize, candidates.length));
      final found = await _pingBatch(batch);
      if (found != null) return found;
    }
    return null;
  }
}
