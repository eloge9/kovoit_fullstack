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
      expediteurId: json['expediteur_id']?.toString() ?? json['expediteur']?.toString() ?? '',
      expediteurNom: json['expediteur_nom'] ?? '',
      expediteurPhoto: json['expediteur_photo'],
      destinataireId: json['destinataire_id']?.toString() ?? json['destinataire']?.toString() ?? '',
      contenu: json['contenu'] ?? '',
      lu: json['lu'] ?? false,
      timestamp: DateTime.parse(json['timestamp'] as String),
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

class ConversationModel {
  final String userId;
  final String userName;
  final String? userPhoto;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int unreadCount;

  const ConversationModel({
    required this.userId,
    required this.userName,
    this.userPhoto,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCount = 0,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      userId: json['user_id']?.toString() ?? json['id']?.toString() ?? '',
      userName: json['username'] ?? json['nom'] ?? '',
      userPhoto: json['photo_profile'] ?? json['photo'],
      lastMessage: json['dernier_message'],
      lastMessageTime: json['dernier_message_time'] != null
          ? DateTime.parse(json['dernier_message_time'] as String)
          : null,
      unreadCount: json['non_lus'] as int? ?? 0,
    );
  }
}
