import 'dart:async';
import 'package:multicast_dns/multicast_dns.dart';

/// Découverte automatique du backend Kovoit via mDNS (Bonjour/Zeroconf).
/// Le backend publie "Kovoit._http._tcp.local." — on écoute ce service
/// et on reconstruit l'URL http://IP:port en moins de 5 secondes.
class MdnsDiscoveryService {
  static const String _serviceType = '_http._tcp';
  static const String _targetName = 'Kovoit';
  static const Duration _timeout = Duration(seconds: 5);

  Future<String?> discoverBackend() async {
    final client = MDnsClient();
    try {
      await client.start();

      String? foundIp;
      int? foundPort;

      final ptrStream = client
          .lookup<PtrResourceRecord>(
            ResourceRecordQuery.serverPointer(_serviceType),
          )
          .timeout(_timeout, onTimeout: (_) {});

      await for (final ptr in ptrStream) {
        if (!ptr.domainName.contains(_targetName)) continue;

        // Récupère le port via SRV
        final srvStream = client
            .lookup<SrvResourceRecord>(
              ResourceRecordQuery.service(ptr.domainName),
            )
            .timeout(_timeout, onTimeout: (_) {});

        await for (final srv in srvStream) {
          foundPort = srv.port;

          // Récupère l'IP via A record
          final ipStream = client
              .lookup<IPAddressResourceRecord>(
                ResourceRecordQuery.addressIPv4(srv.target),
              )
              .timeout(_timeout, onTimeout: (_) {});

          await for (final ip in ipStream) {
            foundIp = ip.address.address;
            break;
          }
          break;
        }

        if (foundIp != null && foundPort != null) break;
      }

      if (foundIp != null && foundPort != null) {
        return 'http://$foundIp:$foundPort';
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      client.stop();
    }
  }
}
