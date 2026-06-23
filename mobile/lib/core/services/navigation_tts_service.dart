import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Service de guidage vocal pour la navigation (côté conducteur).
/// Annonce automatiquement la distance restante et l'heure d'arrivée.
class NavigationTtsService {
  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;
  bool _enabled = true;
  double _lastAnnouncedDist = -1;

  Future<void> init() async {
    if (_initialized) return;
    try {
      await _tts.setLanguage('fr-FR');
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      _initialized = true;
      debugPrint('[TTS] initialisé');
    } catch (e) {
      debugPrint('[TTS] init error: $e');
    }
  }

  bool get isEnabled => _enabled;

  void toggle() => _enabled = !_enabled;

  Future<void> speak(String text) async {
    if (!_enabled || !_initialized) return;
    try {
      await _tts.stop();
      await _tts.speak(text);
      debugPrint('[TTS] "$text"');
    } catch (e) {
      debugPrint('[TTS] speak error: $e');
    }
  }

  /// Annonce automatique basée sur la distance et l'ETA.
  /// Appeler à chaque mise à jour de position.
  void announceIfNeeded({
    required double distanceKm,
    required int etaMinutes,
    required String destination,
  }) {
    if (!_enabled || !_initialized) return;

    // Annonce d'arrivée imminente
    if (distanceKm < 0.2 && _lastAnnouncedDist > 0.3) {
      speak('Vous approchez de votre destination.');
      _lastAnnouncedDist = distanceKm;
      return;
    }

    if (distanceKm < 0.05) {
      speak('Vous êtes arrivé à $destination.');
      _lastAnnouncedDist = distanceKm;
      return;
    }

    // Annonces à des distances clés
    final distM = (distanceKm * 1000).round();
    final keyDistances = [500, 1000, 2000, 5000, 10000, 20000, 50000];
    for (final d in keyDistances) {
      if (distM <= d && (_lastAnnouncedDist * 1000) > d) {
        final label = d >= 1000
            ? '${d ~/ 1000} kilomètre${d >= 2000 ? 's' : ''}'
            : '$d mètres';
        speak('Distance restante : $label. Temps estimé : $etaMinutes minutes.');
        _lastAnnouncedDist = distanceKm;
        return;
      }
    }

    // Annonce initiale
    if (_lastAnnouncedDist < 0) {
      _lastAnnouncedDist = distanceKm;
      final distLabel = distanceKm >= 1
          ? '${distanceKm.toStringAsFixed(1)} kilomètres'
          : '${(distanceKm * 1000).round()} mètres';
      speak('Trajet démarré. Destination : $destination. '
          'Distance : $distLabel. Durée estimée : $etaMinutes minutes.');
    }
  }

  Future<void> dispose() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
