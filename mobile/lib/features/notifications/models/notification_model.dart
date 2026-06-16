import 'package:flutter/material.dart';

class NotificationModel {
  final String type;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final bool isRead;

  const NotificationModel({
    required this.type,
    required this.data,
    required this.timestamp,
    this.isRead = false,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    final type = json['type']?.toString() ?? 'info';
    return NotificationModel(
      type: type,
      data: data,
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now(),
      isRead: json['isRead'] as bool? ?? false,
    );
  }

  NotificationModel copyWith({bool? isRead}) => NotificationModel(
    type: type,
    data: data,
    timestamp: timestamp,
    isRead: isRead ?? this.isRead,
  );

  String get titre {
    switch (type) {
      case 'nouvelle_reservation':
        return 'Nouvelle réservation';
      case 'reservation_confirmee':
        return 'Réservation confirmée ✅';
      case 'reservation_refusee':
        return 'Réservation refusée';
      case 'paiement_recu':
        return 'Paiement reçu 💰';
      case 'paiement_mobile_money_confirme':
        return 'Paiement Mobile Money confirmé';
      case 'trajet_demarre':
        return 'Trajet démarré 🚗';
      case 'trajet_termine':
        return 'Trajet terminé ✅';
      case 'conducteur_proche':
        return 'Conducteur à proximité 📍';
      case 'nouveau_message':
        return 'Nouveau message 💬';
      case 'documents_valides':
        return 'Documents validés ✅';
      case 'documents_refuses':
        return 'Documents refusés';
      case 'annulation_trajet':
        return 'Trajet annulé';
      default:
        return 'Notification KoVoit';
    }
  }

  String get message {
    final nom = data['nom']?.toString()
        ?? data['username']?.toString()
        ?? data['conducteur_nom']?.toString()
        ?? data['passager_nom']?.toString()
        ?? '';
    final montant = data['montant']?.toString() ?? '';
    final depart = data['depart']?.toString() ?? '';
    final destination = data['destination']?.toString() ?? '';
    final contenu = data['contenu']?.toString() ?? '';

    switch (type) {
      case 'nouvelle_reservation':
        return nom.isNotEmpty ? '$nom souhaite rejoindre votre trajet.' : 'Nouvelle demande de réservation.';
      case 'reservation_confirmee':
        return nom.isNotEmpty ? '$nom a accepté votre réservation.' : 'Votre réservation a été acceptée.';
      case 'reservation_refusee':
        return nom.isNotEmpty ? '$nom n\'a pas pu accepter votre réservation.' : 'Votre réservation a été refusée.';
      case 'paiement_recu':
        return montant.isNotEmpty ? 'Vous avez reçu $montant FCFA.' : 'Paiement reçu pour votre trajet.';
      case 'paiement_mobile_money_confirme':
        return 'Votre paiement Mobile Money a été confirmé.';
      case 'trajet_demarre':
        return (depart.isNotEmpty && destination.isNotEmpty)
            ? 'Votre trajet $depart → $destination est en cours.'
            : 'Votre trajet a démarré.';
      case 'trajet_termine':
        return destination.isNotEmpty
            ? 'Vous êtes arrivé à $destination.'
            : 'Votre trajet est terminé.';
      case 'conducteur_proche':
        return 'Votre conducteur est à proximité de votre arrêt.';
      case 'nouveau_message':
        return contenu.isNotEmpty ? contenu : (nom.isNotEmpty ? 'Message de $nom' : 'Vous avez un nouveau message.');
      case 'documents_valides':
        return 'Vos documents ont été validés. Votre compte conducteur est actif.';
      case 'documents_refuses':
        return 'Vos documents ont été refusés. Veuillez les soumettre à nouveau.';
      case 'annulation_trajet':
        return 'Un trajet a été annulé.';
      default:
        return data['message']?.toString() ?? 'Vous avez une nouvelle notification.';
    }
  }

  IconData get icone {
    switch (type) {
      case 'nouvelle_reservation':
        return Icons.confirmation_number_outlined;
      case 'reservation_confirmee':
        return Icons.check_circle_outline;
      case 'reservation_refusee':
        return Icons.cancel_outlined;
      case 'paiement_recu':
      case 'paiement_mobile_money_confirme':
        return Icons.account_balance_wallet_outlined;
      case 'trajet_demarre':
        return Icons.directions_car_outlined;
      case 'trajet_termine':
        return Icons.flag_outlined;
      case 'conducteur_proche':
        return Icons.location_on_outlined;
      case 'nouveau_message':
        return Icons.chat_bubble_outline;
      case 'documents_valides':
        return Icons.verified_outlined;
      case 'documents_refuses':
        return Icons.error_outline;
      case 'annulation_trajet':
        return Icons.cancel_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color get couleur {
    switch (type) {
      case 'reservation_confirmee':
      case 'paiement_recu':
      case 'paiement_mobile_money_confirme':
      case 'trajet_termine':
      case 'documents_valides':
        return const Color(0xFF13201F); // successContent
      case 'reservation_refusee':
      case 'documents_refuses':
      case 'annulation_trajet':
        return const Color(0xFFD97A72); // error
      case 'trajet_demarre':
      case 'conducteur_proche':
      case 'nouvelle_reservation':
        return const Color(0xFF1D6EEF); // primary
      case 'nouveau_message':
        return const Color(0xFF4B3BAB); // secondary
      default:
        return const Color(0xFF8896AA); // baseContentMid
    }
  }
}
