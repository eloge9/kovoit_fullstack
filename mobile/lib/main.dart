import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/services/notification_service.dart';
import 'core/widgets/k_error_screen.dart';
import 'app.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Toute erreur de build (widget) affiche un écran KoVoit au lieu du
    // Red Screen of Death par défaut de Flutter.
    ErrorWidget.builder = (details) {
      FlutterError.presentError(details);
      return const KErrorScreen(kind: KErrorKind.unexpected);
    };

    // Erreurs du framework Flutter (build/layout/paint) — journalisées sans
    // jamais faire planter l'app pour l'utilisateur final.
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      if (kDebugMode) return;
      // TODO: brancher un service de crash-reporting (Sentry/Crashlytics) ici.
    };

    try {
      await initializeDateFormatting('fr_FR', null);
    } catch (_) {}
    try {
      await NotificationService.init();
    } catch (_) {}

    runApp(const ProviderScope(child: KoVoitApp()));
  }, (error, stack) {
    // Erreurs async non catchées (hors build Flutter) — jamais de crash visible.
    debugPrint('[runZonedGuarded] $error\n$stack');
    // TODO: brancher un service de crash-reporting (Sentry/Crashlytics) ici.
  });
}
