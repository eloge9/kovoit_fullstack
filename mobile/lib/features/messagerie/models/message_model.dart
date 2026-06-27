import '../../../core/constants/api_constants.dart';

// ── ReplyInfo ─────────────────────────────────────────────────────────────────

class ReplyInfo {
  final int id;
  final String contenu;
  final String username;
  final String messageType;

  const ReplyInfo({
    required this.id,
    required this.contenu,
    required this.username,
    required this.messageType,
  });

  factory ReplyInfo.fromJson(Map<String, dynamic> j) => ReplyInfo(
    id:          j['id'] as int,
    contenu:     j['contenu']?.toString() ?? '',
    username:    j['username']?.toString() ?? '',
    messageType: j['message_type']?.toString() ?? 'text',
  );
}

// ── ReactionGroup ─────────────────────────────────────────────────────────────

class ReactionGroup {
  final int count;
  final bool moi;

  const ReactionGroup({required this.count, required this.moi});

  factory ReactionGroup.fromJson(Map<String, dynamic> j) => ReactionGroup(
    count: j['count'] as int? ?? 0,
    moi:   j['moi']   as bool? ?? false,
  );
}

// ── MessageModel ──────────────────────────────────────────────────────────────

class MessageModel {
  final int id;

  // Champs de base
  final String expediteurId;
  final String expediteurNom;
  final String? expediteurPhoto;
  final String destinataireId;
  final String contenu;
  final bool lu;                 // legacy — remplacé par isRead
  final DateTime timestamp;

  // Nouveaux champs
  final bool deleted;            // message supprimé pour tout le monde
  final String messageType;      // 'text' | 'audio' | 'image'
  final String? audioUrl;        // URL absolue du fichier audio
  final int? audioDuration;      // durée en secondes
  final bool isEdited;
  final DateTime? editedAt;
  final ReplyInfo? replyTo;
  final Map<String, ReactionGroup> reactions;
  final bool isRead;             // vu par l'interlocuteur (✓✓ bleu)

  const MessageModel({
    required this.id,
    required this.expediteurId,
    required this.expediteurNom,
    this.expediteurPhoto,
    required this.destinataireId,
    required this.contenu,
    this.lu = false,
    required this.timestamp,
    this.deleted = false,
    this.messageType = 'text',
    this.audioUrl,
    this.audioDuration,
    this.isEdited = false,
    this.editedAt,
    this.replyTo,
    this.reactions = const {},
    this.isRead = false,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    // Réactions : { "👍": {"count": 2, "moi": true}, … }
    final rawReactions = json['reactions'];
    final Map<String, ReactionGroup> reactions = {};
    if (rawReactions is Map) {
      rawReactions.forEach((key, val) {
        if (val is Map<String, dynamic>) {
          reactions[key.toString()] = ReactionGroup.fromJson(val);
        }
      });
    }

    // reply_to
    final rawReply = json['reply_to'];
    final replyTo = (rawReply is Map<String, dynamic>) ? ReplyInfo.fromJson(rawReply) : null;

    return MessageModel(
      id:             json['id'] as int,
      expediteurId:   json['auteur_id']?.toString() ??
                      json['expediteur_id']?.toString() ??
                      json['expediteur']?.toString() ?? '',
      expediteurNom:  json['username']?.toString() ??
                      json['expediteur_nom']?.toString() ?? '',
      expediteurPhoto: json['expediteur_photo']?.toString(),
      destinataireId: json['destinataire_id']?.toString() ??
                      json['destinataire']?.toString() ?? '',
      contenu:        json['contenu']?.toString() ?? '',
      lu:             json['lu'] as bool? ?? false,
      timestamp:      DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now(),
      deleted:        json['deleted'] as bool? ?? false,
      messageType:    json['message_type']?.toString() ?? 'text',
      audioUrl:       json['audio_url'] != null
                        ? ApiConstants.buildMediaUrl(json['audio_url'].toString())
                        : null,
      audioDuration:  json['audio_duration'] as int?,
      isEdited:       json['is_edited'] as bool? ?? false,
      editedAt:       json['edited_at'] != null
                        ? DateTime.tryParse(json['edited_at'].toString())
                        : null,
      replyTo:        replyTo,
      reactions:      reactions,
      isRead:         json['is_read'] as bool? ?? false,
    );
  }

  MessageModel copyWith({
    bool? lu,
    bool? deleted,
    String? contenu,
    bool? isEdited,
    DateTime? editedAt,
    Map<String, ReactionGroup>? reactions,
    bool? isRead,
  }) {
    return MessageModel(
      id:             id,
      expediteurId:   expediteurId,
      expediteurNom:  expediteurNom,
      expediteurPhoto: expediteurPhoto,
      destinataireId: destinataireId,
      contenu:        contenu ?? this.contenu,
      lu:             lu ?? this.lu,
      timestamp:      timestamp,
      deleted:        deleted ?? this.deleted,
      messageType:    messageType,
      audioUrl:       audioUrl,
      audioDuration:  audioDuration,
      isEdited:       isEdited ?? this.isEdited,
      editedAt:       editedAt ?? this.editedAt,
      replyTo:        replyTo,
      reactions:      reactions ?? this.reactions,
      isRead:         isRead ?? this.isRead,
    );
  }

  bool get peutEtreModifie {
    final diff = DateTime.now().difference(timestamp);
    return !deleted && diff.inMinutes < 15;
  }
}

// ── ConversationModel ─────────────────────────────────────────────────────────

class ConversationModel {
  final int convId;
  final String userId;      // premier interlocuteur (pour conv privée)
  final String userName;    // nom affiché (titre pour groupe, nom pour privé)
  final String? userPhoto;
  final String? lastMessage;
  final String? lastMessageAuthor; // Pour les groupes : "Fabrice: ..."
  final DateTime? lastMessageTime;
  final int unreadCount;
  final String statut;       // 'ouverte' | 'lecture_seule' | 'fermee'
  final String type;         // 'private' | 'trajet'
  final String? titre;       // Titre du groupe (ex: "Cotonou → Abomey")
  final int participantsCount;
  final bool isGroupe;

  const ConversationModel({
    required this.convId,
    required this.userId,
    required this.userName,
    this.userPhoto,
    this.lastMessage,
    this.lastMessageAuthor,
    this.lastMessageTime,
    this.unreadCount = 0,
    this.statut = 'ouverte',
    this.type = 'private',
    this.titre,
    this.participantsCount = 2,
    this.isGroupe = false,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    final isGroupe = json['is_groupe'] as bool? ?? false;
    final type     = json['type']?.toString() ?? 'private';
    final titre    = json['titre']?.toString();

    final interlocuteurs = json['interlocuteurs'] as List?;
    final first = (interlocuteurs != null && interlocuteurs.isNotEmpty)
        ? interlocuteurs.first as Map<String, dynamic>
        : null;

    final dernierMsgRaw = json['dernier_message'];
    final dernierMsg = dernierMsgRaw is Map<String, dynamic> ? dernierMsgRaw : null;

    // Nom affiché : titre pour groupe, nom de l'interlocuteur pour privé
    final displayName = isGroupe
        ? (titre ?? 'Groupe trajet')
        : (first?['nom']?.toString() ?? first?['username']?.toString() ?? '');

    // Dernier message : pour les groupes on préfixe avec le nom de l'auteur
    String? lastMsgContent = dernierMsg?['contenu'] as String?;
    String? lastMsgAuthor;
    if (isGroupe && dernierMsg != null) {
      final moi = dernierMsg['moi'] as bool? ?? false;
      lastMsgAuthor = moi ? 'Vous' : (dernierMsg['username']?.toString());
    }

    return ConversationModel(
      convId:              json['id'] as int,
      userId:              first?['id']?.toString() ?? '',
      userName:            displayName,
      userPhoto:           isGroupe ? null : first?['photo_profil']?.toString(),
      lastMessage:         lastMsgContent,
      lastMessageAuthor:   lastMsgAuthor,
      lastMessageTime:     dernierMsg?['timestamp'] != null
                               ? DateTime.tryParse(dernierMsg!['timestamp'] as String)
                               : null,
      unreadCount:         json['non_lus'] as int? ?? 0,
      statut:              json['statut']?.toString() ?? 'ouverte',
      type:                type,
      titre:               titre,
      participantsCount:   json['participants_count'] as int? ?? 2,
      isGroupe:            isGroupe,
    );
  }
}
