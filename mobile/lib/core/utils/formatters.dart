import 'package:intl/intl.dart';

class Formatters {
  static final _currencyFormat = NumberFormat.currency(
    locale: 'fr_TG',
    symbol: 'FCFA',
    decimalDigits: 0,
  );

  static final _dateFormat = DateFormat('dd MMM yyyy', 'fr');
  static final _timeFormat = DateFormat('HH:mm', 'fr');
  static final _dateTimeFormat = DateFormat('dd MMM yyyy • HH:mm', 'fr');

  static String currency(double amount) => _currencyFormat.format(amount);

  static String date(DateTime dt) => _dateFormat.format(dt);

  static String time(DateTime dt) => _timeFormat.format(dt);

  static String dateTime(DateTime dt) => _dateTimeFormat.format(dt);

  static String relativeTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'À l\'instant';
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours} h';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays} j';
    return date(dt);
  }

  static String distance(double km) {
    if (km < 1) return '${(km * 1000).toStringAsFixed(0)} m';
    return '${km.toStringAsFixed(1)} km';
  }

  static String capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }

  static String vehiculeLabel(String type) {
    switch (type) {
      case 'moto':
        return 'Moto';
      case 'voiture':
        return 'Voiture';
      case 'minibus':
        return 'Minibus';
      case 'camion':
        return 'Camion';
      default:
        return capitalize(type);
    }
  }

  static String trajetStatutLabel(String statut) {
    switch (statut) {
      case 'ouvert':
        return 'Disponible';
      case 'en_cours':
        return 'En cours';
      case 'termine':
        return 'Terminé';
      case 'annule':
        return 'Annulé';
      default:
        return capitalize(statut);
    }
  }

  static String reservationStatutLabel(String statut) {
    switch (statut) {
      case 'en_attente':
        return 'En attente';
      case 'confirmee':
        return 'Confirmée';
      case 'declinee':
        return 'Déclinée';
      case 'terminee':
        return 'Terminée';
      default:
        return capitalize(statut);
    }
  }
}
