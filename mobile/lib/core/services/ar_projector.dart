import 'dart:math';
import 'package:flutter/material.dart';
import 'ar_sensor_service.dart';
import 'location_service.dart';

/// Résultat de la projection d'un point GPS vers l'écran.
class ArProjection {
  final Offset screenPos;
  final double distanceM;

  /// Facteur d'échelle perspective (1.0 = référence à [ArProjector.kRefDist] m).
  final double scale;

  /// Vrai si le point est visible dans le champ de la caméra (avec marge).
  final bool visible;

  /// Bearing absolu vers ce point (degrés, 0=Nord).
  final double bearing;

  const ArProjection({
    required this.screenPos,
    required this.distanceM,
    required this.scale,
    required this.visible,
    required this.bearing,
  });
}

/// Projette des coordonnées GPS dans l'espace écran en utilisant l'orientation
/// du téléphone (cap boussole + inclinaison accéléromètre).
///
/// Formules :
///   azimuth  = bearing − heading            (relatif, −180…+180)
///   screenX  = W/2 + tan(azimuth)  × focal
///   screenY  = H/2 − tan(elevation − pitch) × focal
///   scale    = refDist / distance           (perspective)
class ArProjector {
  /// Champ de vision horizontal de la caméra arrière (degrés, valeur typique).
  static const double kFovH = 65.0;

  /// Distance de référence pour scale = 1.0.
  static const double kRefDist = 25.0;

  /// Marge en pixels au-delà des bords pour considérer un point "visible".
  static const double kMargin = 80.0;

  static ArProjection? project({
    required double userLat,
    required double userLng,
    required double pointLat,
    required double pointLng,
    required double altitudeM, // 0 = niveau de la route
    required ArDeviceOrientation orientation,
    required Size screenSize,
  }) {
    final distM = LocationService.distanceKm(
          userLat, userLng, pointLat, pointLng) *
        1000;

    // Trop proche : évite division par zéro et artefacts
    if (distM < 1.0) return null;

    final bearing = LocationService.bearingTo(
        userLat, userLng, pointLat, pointLng);

    // Azimuth relatif au regard (−180…+180)
    final azDeg = _norm(bearing - orientation.heading);

    // Élévation vraie de l'objet (en degrés, 0 pour le sol à grande distance)
    final trueElevDeg = atan2(altitudeM, distM) * 180 / pi;

    // Élévation à l'écran après soustraction du pitch de la caméra
    // pitch > 0 → caméra pointe vers le ciel → objets au sol apparaissent plus bas
    final screenElevDeg = trueElevDeg - orientation.pitch;

    // Distance focale en pixels (écran / 2·tan(fov/2))
    final focalPx =
        screenSize.width / (2 * tan(kFovH * pi / 360));

    final x = screenSize.width  / 2 + tan(azDeg         * pi / 180) * focalPx;
    final y = screenSize.height / 2 - tan(screenElevDeg * pi / 180) * focalPx;

    final bool visible =
        x >= -kMargin &&
        x <= screenSize.width  + kMargin &&
        y >= -kMargin &&
        y <= screenSize.height + kMargin &&
        azDeg.abs() <= kFovH / 2 + 20;

    final scale = (kRefDist / distM.clamp(2.0, 300.0)).clamp(0.15, 3.5);

    return ArProjection(
      screenPos: Offset(x, y),
      distanceM: distM,
      scale:     scale,
      visible:   visible,
      bearing:   bearing,
    );
  }

  // Normalise un angle dans [−180, +180]
  static double _norm(double d) => ((d + 180) % 360) - 180;
}
