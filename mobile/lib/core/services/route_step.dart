import 'package:latlong2/latlong.dart';

// ── Manœuvres OSRM ────────────────────────────────────────────────────────────

enum ManeuverType {
  depart,
  straight,
  slightLeft,
  slightRight,
  left,
  right,
  sharpLeft,
  sharpRight,
  uturn,
  roundabout,
  arrive,
}

// ── Étape de navigation ───────────────────────────────────────────────────────

class RouteStep {
  final double distanceM;
  final double durationS;
  final String streetName;
  final ManeuverType maneuver;
  final LatLng location;
  final double bearingBefore;
  final double bearingAfter;

  const RouteStep({
    required this.distanceM,
    required this.durationS,
    required this.streetName,
    required this.maneuver,
    required this.location,
    required this.bearingBefore,
    required this.bearingAfter,
  });

  factory RouteStep.fromJson(Map<String, dynamic> json) {
    final mv = json['maneuver'] as Map<String, dynamic>? ?? {};
    final type = mv['type'] as String? ?? 'continue';
    final modifier = mv['modifier'] as String?;
    final loc = mv['location'] as List<dynamic>? ?? [0.0, 0.0];
    return RouteStep(
      distanceM:     (json['distance'] as num?)?.toDouble() ?? 0,
      durationS:     (json['duration'] as num?)?.toDouble() ?? 0,
      streetName:    json['name'] as String? ?? '',
      maneuver:      _parseManeuver(type, modifier),
      location:      LatLng((loc[1] as num).toDouble(), (loc[0] as num).toDouble()),
      bearingBefore: (mv['bearing_before'] as num?)?.toDouble() ?? 0,
      bearingAfter:  (mv['bearing_after']  as num?)?.toDouble() ?? 0,
    );
  }

  static ManeuverType _parseManeuver(String type, String? modifier) {
    if (type == 'arrive')                          return ManeuverType.arrive;
    if (type == 'depart')                          return ManeuverType.depart;
    if (type == 'roundabout' || type == 'rotary') return ManeuverType.roundabout;
    return switch (modifier ?? 'straight') {
      'sharp left'   => ManeuverType.sharpLeft,
      'left'         => ManeuverType.left,
      'slight left'  => ManeuverType.slightLeft,
      'slight right' => ManeuverType.slightRight,
      'right'        => ManeuverType.right,
      'sharp right'  => ManeuverType.sharpRight,
      'uturn'        => ManeuverType.uturn,
      _              => ManeuverType.straight,
    };
  }

  // ── Affichage ─────────────────────────────────────────────────────────────

  String get icon => switch (maneuver) {
    ManeuverType.depart      => '⬆',
    ManeuverType.straight    => '⬆',
    ManeuverType.slightLeft  => '↖',
    ManeuverType.slightRight => '↗',
    ManeuverType.left        => '⬅',
    ManeuverType.right       => '➡',
    ManeuverType.sharpLeft   => '↩',
    ManeuverType.sharpRight  => '↪',
    ManeuverType.uturn       => '⤴',
    ManeuverType.roundabout  => '🔄',
    ManeuverType.arrive      => '🏁',
  };

  String get label => switch (maneuver) {
    ManeuverType.depart      => 'Démarrez',
    ManeuverType.straight    => 'Continuez tout droit',
    ManeuverType.slightLeft  => 'Prenez légèrement à gauche',
    ManeuverType.slightRight => 'Prenez légèrement à droite',
    ManeuverType.left        => 'Tournez à gauche',
    ManeuverType.right       => 'Tournez à droite',
    ManeuverType.sharpLeft   => 'Virage serré à gauche',
    ManeuverType.sharpRight  => 'Virage serré à droite',
    ManeuverType.uturn       => 'Faites demi-tour',
    ManeuverType.roundabout  => 'Prenez le rond-point',
    ManeuverType.arrive      => 'Vous êtes arrivé',
  };

  /// Texte TTS à prononcer, avec distance optionnelle.
  String voiceText({double? remainingM}) {
    if (isArrival) {
      return streetName.isNotEmpty
          ? 'Vous êtes arrivé à $streetName.'
          : 'Vous êtes arrivé à destination.';
    }
    final dist = remainingM ?? distanceM;
    final street = streetName.isNotEmpty ? ' sur $streetName' : '';
    if (dist < 10) return '$label$street.';
    final distStr = dist >= 1000
        ? '${(dist / 1000).toStringAsFixed(1)} kilomètre${dist >= 2000 ? 's' : ''}'
        : '${dist.round()} mètres';
    return 'Dans $distStr, $label$street.';
  }

  bool get isArrival   => maneuver == ManeuverType.arrive;
  bool get isDeparture => maneuver == ManeuverType.depart;
  bool get isStraight  => maneuver == ManeuverType.straight || maneuver == ManeuverType.depart;
}
