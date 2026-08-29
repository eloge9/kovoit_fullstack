import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'route_step.dart';

/// Guidage vocal de navigation.
/// Deux modes :
///   1. Annonces à distance globale (pour la carte).
///   2. Annonces de manœuvres OSRM à 300 m / 100 m / 30 m (pour la RA).
class NavigationTtsService {
  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;
  bool _enabled = true;

  // Mode carte : distance globale
  double _lastDistGlobal = -1;

  // Mode RA : manœuvre OSRM
  String _lastStepId = '';
  double _lastAnnouncedDistForStep = double.infinity;

  Future<void> init() async {
    if (_initialized) return;
    try {
      await _tts.setLanguage('fr-FR');
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      _initialized = true;
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
    } catch (e) {
      debugPrint('[TTS] speak error: $e');
    }
  }

  // ── Annonces carte (distance globale) ────────────────────────────────────

  void announceIfNeeded({
    required double distanceKm,
    required int etaMinutes,
    required String destination,
  }) {
    if (!_enabled || !_initialized) return;

    if (distanceKm < 0.05) {
      if (_lastDistGlobal > 0.1) {
        speak('Vous êtes arrivé à $destination.');
        _lastDistGlobal = distanceKm;
      }
      return;
    }
    if (distanceKm < 0.2 && _lastDistGlobal > 0.3) {
      speak('Vous approchez de votre destination.');
      _lastDistGlobal = distanceKm;
      return;
    }

    final distM = (distanceKm * 1000).round();
    for (final d in const [500, 1000, 2000, 5000, 10000, 20000, 50000]) {
      if (distM <= d && (_lastDistGlobal * 1000) > d) {
        final label = d >= 1000
            ? '${d ~/ 1000} kilomètre${d >= 2000 ? 's' : ''}'
            : '$d mètres';
        speak('Distance restante : $label. Temps estimé : $etaMinutes minutes.');
        _lastDistGlobal = distanceKm;
        return;
      }
    }

    if (_lastDistGlobal < 0) {
      _lastDistGlobal = distanceKm;
      final distLabel = distanceKm >= 1
          ? '${distanceKm.toStringAsFixed(1)} kilomètres'
          : '${(distanceKm * 1000).round()} mètres';
      speak('Trajet démarré. Destination : $destination. '
          'Distance : $distLabel. Durée estimée : $etaMinutes minutes.');
    }
  }

  // ── Annonces de manœuvres RA (300 m / 100 m / 30 m) ─────────────────────

  /// Appeler à chaque mise à jour de position en mode RA.
  /// [step] : prochaine manœuvre OSRM.
  /// [distanceM] : mètres restants jusqu'à cette manœuvre.
  void announceManeuverIfNeeded({
    required RouteStep? step,
    required double distanceM,
  }) {
    if (!_enabled || !_initialized || step == null) return;
    if (distanceM.isInfinite || distanceM.isNaN) return;

    // Identifiant de l'étape pour détecter le changement
    final stepId = '${step.maneuver.name}_${step.location.latitude.toStringAsFixed(4)}_${step.location.longitude.toStringAsFixed(4)}';

    // Réinitialiser le suivi si l'étape a changé
    if (stepId != _lastStepId) {
      _lastStepId = stepId;
      _lastAnnouncedDistForStep = double.infinity;
    }

    // Arrivée
    if (step.isArrival && distanceM <= 30 && _lastAnnouncedDistForStep > 30) {
      speak(step.voiceText());
      _lastAnnouncedDistForStep = distanceM;
      return;
    }

    // 300 m
    if (distanceM <= 320 && distanceM > 200 && _lastAnnouncedDistForStep > 320) {
      speak(step.voiceText(remainingM: 300));
      _lastAnnouncedDistForStep = distanceM;
      return;
    }

    // 100 m
    if (distanceM <= 110 && distanceM > 60 && _lastAnnouncedDistForStep > 110) {
      speak(step.voiceText(remainingM: 100));
      _lastAnnouncedDistForStep = distanceM;
      return;
    }

    // 30 m — action imminente
    if (distanceM <= 35 && distanceM > 10 && _lastAnnouncedDistForStep > 35) {
      speak('${step.label}.');
      _lastAnnouncedDistForStep = distanceM;
      return;
    }

    _lastAnnouncedDistForStep = distanceM;
  }

  /// Réinitialise le suivi de manœuvre (nouveau trajet, recalcul, etc.).
  void resetManeuverTracking() {
    _lastStepId = '';
    _lastAnnouncedDistForStep = double.infinity;
  }

  Future<void> dispose() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
