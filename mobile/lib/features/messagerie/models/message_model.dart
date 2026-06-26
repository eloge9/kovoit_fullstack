class MessageModel {
  final int id;
  final String expediteurId;
  final String expediteurNom;
  final String? expediteurPhoto;
  final String destinataireId;
  final String contenu;
  final bool lu;
  final DateTime timestamp;

  const MessageModel({
    required this.id,
    required this.expediteurId,
    required this.expediteurNom,
    this.expediteurPhoto,
    required this.destinataireId,
    required this.contenu,
    this.lu = false,
    required this.timestamp,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] as int,
      // Django returns 'auteur_id' and 'username'; support legacy field names too
      expediteurId: json['auteur_id']?.toString() ??
          json['expediteur_id']?.toString() ??
          json['expediteur']?.toString() ??
          '',
      expediteurNom: json['username'] as String? ??
          json['expediteur_nom'] as String? ??
          '',
      expediteurPhoto: json['expediteur_photo'] as String?,
      // Django does not return a destinataire field at message level
      destinataireId: json['destinataire_id']?.toString() ??
          json['destinataire']?.toString() ??
          '',
      contenu: json['contenu'] as String? ?? '',
      lu: json['lu'] as bool? ?? false,
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  MessageModel copyWith({bool? lu}) {
    return MessageModel(
      id: id,
      expediteurId: expediteurId,
      expediteurNom: expediteurNom,
      expediteurPhoto: expediteurPhoto,
      destinataireId: destinataireId,
      contenu: contenu,
      lu: lu ?? this.lu,
      timestamp: timestamp,
    );
  }
}

// Django response shape for a conversation:
// {
//   "id": <int conv_id>,
//   "interlocuteurs": [{"id": "uuid", "nom": "...", "username": "...", "photo_profil": "..."}],
//   "dernier_message": {"contenu": "...", "timestamp": "...", ...} | null,
//   "non_lus": <int>,
//   "updated_at": "..."
// }
class ConversationModel {
  final int convId;       // conversation ID (Django pk)
  final String userId;    // interlocutor's user UUID (for WebSocket)
  final String userName;
  final String? userPhoto;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int unreadCount;

  const ConversationModel({
    required this.convId,
    required this.userId,
    required this.userName,
    this.userPhoto,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCount = 0,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    final interlocuteurs = json['interlocuteurs'] as List?;
    final first = (interlocuteurs != null && interlocuteurs.isNotEmpty)
        ? interlocuteurs.first as Map<String, dynamic>
        : null;

    final _dernierMsgRaw = json['dernier_message'];
    final dernierMsg = _dernierMsgRaw is Map<String, dynamic> ? _dernierMsgRaw : null;

    return ConversationModel(
      convId: json['id'] as int,
      userId: first?['id']?.toString() ?? '',
      userName: first?['nom']?.toString() ??
          first?['username']?.toString() ??
          '',
      userPhoto: first?['photo_profil']?.toString(),
      lastMessage: dernierMsg?['contenu'] as String?,
      lastMessageTime: dernierMsg?['timestamp'] != null
          ? DateTime.parse(dernierMsg!['timestamp'] as String)
          : null,
      unreadCount: json['non_lus'] as int? ?? 0,
    );
  }
}
