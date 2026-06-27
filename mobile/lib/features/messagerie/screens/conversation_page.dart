import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/k_avatar.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/message_model.dart';
import '../repositories/messagerie_repository.dart';

const _kEmojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

// ── Utilitaires ───────────────────────────────────────────────────────────────

String _fmtDuration(int? sec) {
  if (sec == null || sec == 0) return '0:00';
  final m = sec ~/ 60;
  final s = sec % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

// ── Widget lecteur audio ──────────────────────────────────────────────────────

class _AudioPlayer extends StatefulWidget {
  final String url;
  final int? duration;
  final bool isMine;
  const _AudioPlayer({required this.url, this.duration, required this.isMine});

  @override
  State<_AudioPlayer> createState() => _AudioPlayerState();
}

class _AudioPlayerState extends State<_AudioPlayer> {
  final _player = AudioPlayer();
  bool _playing = false;
  int _current = 0;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _total = widget.duration ?? 0;
    _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _playing = s == PlayerState.playing);
    });
    _player.onPositionChanged.listen((d) {
      if (mounted) setState(() => _current = d.inSeconds);
    });
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _total = d.inSeconds);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() { _playing = false; _current = 0; });
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
    } else {
      await _player.play(UrlSource(widget.url));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ratio = _total > 0 ? _current / _total : 0.0;
    final trackColor = widget.isMine
        ? Colors.white.withOpacity(0.25)
        : KColors.base300;
    final fillColor = widget.isMine ? Colors.white : KColors.primary;
    final textColor = widget.isMine
        ? Colors.white.withOpacity(0.7)
        : KColors.baseContentMid;

    return SizedBox(
      width: 200,
      child: Row(children: [
        GestureDetector(
          onTap: _toggle,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: widget.isMine
                  ? Colors.white.withOpacity(0.2)
                  : KColors.primary.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: widget.isMine ? Colors.white : KColors.primary,
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ratio.toDouble(),
                  backgroundColor: trackColor,
                  valueColor: AlwaysStoppedAnimation<Color>(fillColor),
                  minHeight: 4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _fmtDuration(_playing ? _current : _total),
                style: KTextStyles.caption.copyWith(color: textColor, fontSize: 10),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Icon(Icons.mic_rounded, size: 14,
            color: widget.isMine ? Colors.white54 : KColors.baseContentLow),
      ]),
    );
  }
}

// ── Page principale ───────────────────────────────────────────────────────────

class ConversationPage extends ConsumerStatefulWidget {
  final int convId;
  final String userName;
  final String? userId;
  final String statut;
  final bool isGroupe;

  const ConversationPage({
    super.key,
    required this.convId,
    required this.userName,
    this.userId,
    this.statut = 'ouverte',
    this.isGroupe = false,
  });

  @override
  ConsumerState<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends ConsumerState<ConversationPage> {
  final _messageCtrl = TextEditingController();
  final _scrollCtrl  = ScrollController();
  final _repo        = MessagerieRepository();

  List<MessageModel> _messages = [];
  bool _isLoading    = true;
  bool _enLigne      = false;
  bool _isTyping     = false;
  String _typingUsername = '';
  Timer? _typingTimer;
  Timer? _typingThrottle;

  // WebSocket
  WebSocketChannel? _wsChannel;
  bool _wsConnected = false;
  Timer? _reconnectTimer;

  // Composition
  MessageModel? _replyTo;
  MessageModel? _editingMsg;

  // Audio enregistrement
  final _recorder   = AudioRecorder();
  bool _recording   = false;
  bool _sendingAudio = false;
  int _recordElapsed = 0;
  Timer? _recordTimer;
  String? _recordPath;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _connectWs();
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    _typingTimer?.cancel();
    _typingThrottle?.cancel();
    _recordTimer?.cancel();
    _reconnectTimer?.cancel();
    _wsChannel?.sink.close();
    _recorder.dispose();
    super.dispose();
  }

  // ── Chargement ─────────────────────────────────────────────────────────────

  Future<void> _loadMessages() async {
    try {
      final msgs = await _repo.getMessages(widget.convId);
      if (mounted) {
        setState(() { _messages = msgs; _isLoading = false; });
        _scrollToBottom();
        _wsSend({'type': 'lire'});
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── WebSocket ──────────────────────────────────────────────────────────────

  Future<void> _connectWs() async {
    final token = await StorageService.getAccessToken();
    if (token == null || widget.convId == 0 || !mounted) return;
    try {
      final uri = Uri.parse(
        '${ApiConstants.wsBaseUrl}/conv/${widget.convId}/?token=$token',
      );
      _wsChannel = WebSocketChannel.connect(uri);
      setState(() => _wsConnected = true);

      _wsChannel!.stream.listen(
        _handleWsMessage,
        onError: (_) => _scheduleReconnect(),
        onDone: () => _scheduleReconnect(),
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (!mounted) return;
    setState(() { _wsConnected = false; _wsChannel = null; });
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), _connectWs);
  }

  void _wsSend(Map<String, dynamic> payload) {
    if (_wsChannel != null && _wsConnected) {
      try { _wsChannel!.sink.add(jsonEncode(payload)); } catch (_) {}
    }
  }

  void _handleWsMessage(dynamic raw) {
    if (!mounted) return;
    try {
      final data = jsonDecode(raw as String) as Map<String, dynamic>;
      final type = data['type'] as String?;

      switch (type) {
        case 'message':
          final msg = MessageModel.fromJson(data);
          setState(() {
            if (!_messages.any((m) => m.id == msg.id)) _messages.add(msg);
          });
          _scrollToBottom();
          if (msg.expediteurId == widget.userId) {
            NotificationService.nouveauMessage(
              widget.userName,
              msg.messageType == 'audio' ? '🎵 Message vocal' : msg.contenu,
            );
          }
          _wsSend({'type': 'lire'});

        case 'message_edited':
          final msgId  = data['message_id'] as int;
          final contenu = data['contenu'] as String? ?? '';
          final editedAt = data['edited_at'] as String?;
          setState(() {
            _messages = _messages.map((m) => m.id == msgId
              ? m.copyWith(
                  contenu: contenu,
                  isEdited: true,
                  editedAt: editedAt != null ? DateTime.tryParse(editedAt) : null,
                )
              : m,
            ).toList();
          });

        case 'message_deleted':
          final msgId   = data['message_id'] as int;
          final pourTous = data['pour_tous'] as bool? ?? false;
          if (pourTous) {
            setState(() {
              _messages = _messages.map((m) =>
                m.id == msgId ? m.copyWith(deleted: true) : m,
              ).toList();
            });
          } else {
            setState(() => _messages.removeWhere((m) => m.id == msgId));
          }

        case 'reaction':
          final msgId  = data['message_id'] as int;
          final emoji  = data['emoji'] as String;
          final userId = data['user_id'] as String?;
          final action = data['action'] as String?;
          _applyReaction(msgId, emoji, userId ?? '', action ?? 'add');

        case 'typing':
          final senderId = data['user_id'] as String?;
          if (senderId != ref.read(currentUserProvider)?.id) {
            setState(() {
              _isTyping = true;
              _typingUsername = data['username'] as String? ?? widget.userName;
            });
            _typingTimer?.cancel();
            _typingTimer = Timer(const Duration(seconds: 3), () {
              if (mounted) setState(() { _isTyping = false; _typingUsername = ''; });
            });
          }

        case 'lu':
          final luBy = data['user_id'] as String?;
          final myId = ref.read(currentUserProvider)?.id ?? '';
          if (luBy != null && luBy != myId) {
            setState(() {
              _messages = _messages.map((m) =>
                m.expediteurId == myId ? m.copyWith(isRead: true) : m,
              ).toList();
            });
          }

        case 'user_online':
          final uid = data['user_id'] as String?;
          if (uid == widget.userId) {
            setState(() => _enLigne = data['online'] as bool? ?? false);
          }
      }
    } catch (_) {}
  }

  void _applyReaction(
      int msgId, String emoji, String userId, String action) {
    final currentId = ref.read(currentUserProvider)?.id ?? '';
    setState(() {
      _messages = _messages.map((m) {
        if (m.id != msgId) return m;
        final reactions = Map<String, ReactionGroup>.from(m.reactions);
        if (action == 'remove') {
          if (reactions.containsKey(emoji)) {
            final prev = reactions[emoji]!;
            final newCount = prev.count - 1;
            if (newCount <= 0) {
              reactions.remove(emoji);
            } else {
              reactions[emoji] = ReactionGroup(
                count: newCount,
                moi: userId == currentId ? false : prev.moi,
              );
            }
          }
        } else {
          final prev = reactions[emoji];
          reactions[emoji] = ReactionGroup(
            count: (prev?.count ?? 0) + 1,
            moi: userId == currentId ? true : (prev?.moi ?? false),
          );
        }
        return m.copyWith(reactions: reactions);
      }).toList();
    });
  }

  // ── Scroll ──────────────────────────────────────────────────────────────────

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Envoi texte ────────────────────────────────────────────────────────────

  Future<void> _sendMessage() async {
    if (widget.statut != 'ouverte') return;
    final text = _messageCtrl.text.trim();

    // Mode édition
    if (_editingMsg != null) {
      if (text.isEmpty) return;
      final msgId = _editingMsg!.id;
      final contenu = text;
      _messageCtrl.clear();
      setState(() => _editingMsg = null);
      _wsSend({'type': 'edit_message', 'message_id': msgId, 'contenu': contenu});
      return;
    }

    if (text.isEmpty) return;
    _messageCtrl.clear();
    final replyToId = _replyTo?.id;
    setState(() => _replyTo = null);

    if (_wsConnected) {
      _wsSend({
        'type': 'message',
        'contenu': text,
        if (replyToId != null) 'reply_to_id': replyToId,
      });
    } else {
      try {
        final msg = await _repo.envoyerMessage(
          widget.convId, text, replyToId: replyToId,
        );
        if (mounted) {
          setState(() {
            if (!_messages.any((m) => m.id == msg.id)) _messages.add(msg);
          });
          _scrollToBottom();
        }
      } catch (e) {
        _showError('Erreur d\'envoi');
      }
    }
  }

  // ── Audio enregistrement ───────────────────────────────────────────────────

  Future<void> _startRecording() async {
    final perm = await Permission.microphone.request();
    if (!perm.isGranted) {
      _showError('Permission microphone refusée');
      return;
    }
    final dir  = await getTemporaryDirectory();
    final path = '${dir.path}/msg_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
    setState(() {
      _recording    = true;
      _recordPath   = path;
      _recordElapsed = 0;
    });
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _recordElapsed++);
    });
  }

  Future<void> _stopAndSendAudio() async {
    // Garde contre le double appel (onLongPressEnd + bouton Envoyer)
    if (!_recording || _sendingAudio) return;

    _recordTimer?.cancel();
    final path = await _recorder.stop();
    setState(() { _recording = false; });
    if (path == null || !mounted) return;
    setState(() => _sendingAudio = true);
    try {
      final msg = await _repo.envoyerAudio(
        widget.convId, path, _recordElapsed,
      );
      if (mounted) {
        setState(() {
          // Déduplication : le WS peut avoir déjà ajouté le message
          if (!_messages.any((m) => m.id == msg.id)) {
            _messages.add(msg);
          }
        });
        _scrollToBottom();
      }
    } catch (_) {
      _showError('Impossible d\'envoyer l\'audio');
    } finally {
      if (mounted) setState(() => _sendingAudio = false);
      try { File(path).deleteSync(); } catch (_) {}
    }
  }

  Future<void> _cancelRecording() async {
    _recordTimer?.cancel();
    await _recorder.stop();
    if (mounted) setState(() { _recording = false; _recordPath = null; });
    if (_recordPath != null) {
      try { File(_recordPath!).deleteSync(); } catch (_) {}
    }
  }

  // ── Réactions ─────────────────────────────────────────────────────────────

  Future<void> _react(MessageModel msg, String emoji) async {
    Navigator.of(context).pop();
    final currentId = ref.read(currentUserProvider)?.id ?? '';
    if (_wsConnected) {
      _wsSend({'type': 'react', 'message_id': msg.id, 'emoji': emoji});
    } else {
      try {
        final r = await _repo.reagirMessage(msg.id, emoji);
        _applyReaction(
          r['message_id'] as int,
          r['emoji'] as String,
          currentId,
          r['action'] as String,
        );
      } catch (_) {}
    }
  }

  // ── Suppression ────────────────────────────────────────────────────────────

  Future<void> _deleteMessage(MessageModel msg, bool pourTous) async {
    Navigator.of(context).pop();
    if (_wsConnected) {
      _wsSend({'type': 'delete_message', 'message_id': msg.id, 'pour_tous': pourTous});
    } else {
      try {
        final r = await _repo.supprimerMessage(msg.id, pourTous: pourTous);
        final pt = r['pour_tous'] as bool? ?? pourTous;
        if (pt) {
          setState(() {
            _messages = _messages.map((m) =>
              m.id == msg.id ? m.copyWith(deleted: true) : m,
            ).toList();
          });
        } else {
          setState(() => _messages.removeWhere((m) => m.id == msg.id));
        }
      } catch (_) {}
    }
  }

  // ── Indicateur de frappe ───────────────────────────────────────────────────

  void _onTyping() {
    if (_typingThrottle?.isActive ?? false) return;
    _wsSend({'type': 'typing'});
    _typingThrottle = Timer(const Duration(seconds: 2), () {});
  }

  // ── Menu contextuel ────────────────────────────────────────────────────────

  void _showMessageMenu(MessageModel msg, String currentUserId) {
    final isMine = msg.expediteurId == currentUserId;
    showModalBottomSheet(
      context: context,
      backgroundColor: KColors.base100,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Picker emoji réaction
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: _kEmojis
                    .map((e) => GestureDetector(
                          onTap: () => _react(msg, e),
                          child: Text(e, style: const TextStyle(fontSize: 28)),
                        ))
                    .toList(),
              ),
            ),
            const Divider(height: 0, color: KColors.border),
            // Répondre
            _MenuTile(
              icon: Icons.reply_rounded,
              label: 'Répondre',
              onTap: () {
                Navigator.pop(context);
                setState(() { _replyTo = msg; _editingMsg = null; });
              },
            ),
            // Modifier (si mien + < 15 min + texte)
            if (isMine && msg.peutEtreModifie && msg.messageType == 'text')
              _MenuTile(
                icon: Icons.edit_rounded,
                label: 'Modifier',
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _editingMsg = msg;
                    _replyTo = null;
                    _messageCtrl.text = msg.contenu;
                  });
                },
              ),
            // Supprimer
            if (isMine) ...[
              _MenuTile(
                icon: Icons.delete_outline_rounded,
                label: 'Supprimer pour moi',
                onTap: () => _deleteMessage(msg, false),
                color: KColors.error,
              ),
              _MenuTile(
                icon: Icons.delete_forever_rounded,
                label: 'Supprimer pour tout le monde',
                onTap: () => _deleteMessage(msg, true),
                color: KColors.error,
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Erreur ─────────────────────────────────────────────────────────────────

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: KColors.error),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(currentUserProvider)?.id ?? '';
    final peutEcrire    = widget.statut == 'ouverte' && _wsConnected;
    final canWriteRest  = widget.statut == 'ouverte';

    return Scaffold(
      backgroundColor: KColors.base200,
      appBar: AppBar(
        backgroundColor: KColors.base100,
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: KColors.border)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: KColors.baseContent),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Row(children: [
          // Avatar : icône groupe ou avatar utilisateur
          if (widget.isGroupe)
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: KColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.directions_car_rounded, color: KColors.primary, size: 18),
            )
          else
            KAvatar(name: widget.userName, size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.userName, style: KTextStyles.bodySm.copyWith(
                  fontWeight: FontWeight.w700, color: KColors.baseContent,
                )),
                Text(
                  widget.isGroupe
                      ? 'Chat du trajet'
                      : (_enLigne ? 'En ligne' : _wsConnected ? 'Connecté' : 'Reconnexion…'),
                  style: KTextStyles.caption.copyWith(
                    color: widget.isGroupe
                        ? KColors.primary
                        : (_enLigne ? KColors.success : KColors.baseContentMid),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ]),
        actions: [
          if (!_wsConnected)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.wifi_off_rounded, size: 18, color: KColors.warning),
            ),
        ],
      ),
      body: Column(children: [
        // ── Bannière lecture seule ──────────────────────────────────────
        if (widget.statut != 'ouverte')
          Container(
            color: KColors.warningLight,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              const Icon(Icons.lock_outline_rounded, size: 14, color: KColors.warning),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.statut == 'lecture_seule'
                      ? 'Conversation en lecture seule — réservation refusée.'
                      : 'Cette conversation est fermée.',
                  style: KTextStyles.caption.copyWith(color: KColors.warningContent),
                ),
              ),
            ]),
          ),

        // ── Liste messages ──────────────────────────────────────────────
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: KColors.primary))
              : _messages.isEmpty
                  ? Center(
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Text('💬', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 12),
                        Text('Commencez la conversation',
                            style: KTextStyles.bodySm.copyWith(
                              color: KColors.baseContentMid,
                            )),
                      ]),
                    )
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 16),
                      itemCount: _messages.length + (_isTyping ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (i == _messages.length) {
                          return _TypingBubble(username: _typingUsername);
                        }
                        final msg    = _messages[i];
                        final isMine = msg.expediteurId == currentUserId;
                        final showDate = i == 0 ||
                            !_isSameDay(
                              _messages[i - 1].timestamp,
                              msg.timestamp,
                            );
                        return Column(children: [
                          if (showDate)
                            _DateSeparator(date: msg.timestamp),
                          GestureDetector(
                            onLongPress: () =>
                                _showMessageMenu(msg, currentUserId),
                            child: _MessageBubble(
                              message:       msg,
                              isMine:        isMine,
                              interlocuteur: widget.userName,
                              isGroupe:      widget.isGroupe,
                            ),
                          ),
                        ]);
                      },
                    ),
        ),

        // ── Zone de saisie ──────────────────────────────────────────────
        _buildInputArea(canWriteRest),
      ]),
    );
  }

  Widget _buildInputArea(bool canWrite) {
    return Container(
      color: KColors.base100,
      padding: EdgeInsets.fromLTRB(
        12, 8, 12, MediaQuery.of(context).viewInsets.bottom + 8,
      ),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [

          // Aperçu réponse
          if (_replyTo != null && _editingMsg == null)
            _ReplyPreview(
              msg: _replyTo!,
              onClose: () => setState(() => _replyTo = null),
            ),

          // Bannière édition
          if (_editingMsg != null)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: KColors.warningLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: KColors.warning.withOpacity(0.4)),
              ),
              child: Row(children: [
                const Icon(Icons.edit_rounded, size: 14, color: KColors.warning),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Modification du message',
                    style: KTextStyles.caption.copyWith(color: KColors.warningContent),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() { _editingMsg = null; _messageCtrl.clear(); }),
                  child: const Icon(Icons.close_rounded, size: 16,
                      color: KColors.baseContentMid),
                ),
              ]),
            ),

          if (!canWrite)
            Row(children: [
              const Icon(Icons.lock_outline_rounded, size: 16, color: KColors.baseContentLow),
              const SizedBox(width: 6),
              Text('Conversation en lecture seule',
                  style: KTextStyles.caption.copyWith(color: KColors.baseContentLow)),
            ])
          else if (_recording)
            _RecordingBar(
              elapsed: _recordElapsed,
              onSend: _stopAndSendAudio,
              onCancel: _cancelRecording,
            )
          else
            Row(children: [
              // Micro (appui long pour enregistrer)
              if (_editingMsg == null)
                GestureDetector(
                  onLongPressStart: (_) => _startRecording(),
                  onLongPressEnd:   (_) => _stopAndSendAudio(),
                  child: Container(
                    width: 40,
                    height: 40,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: _sendingAudio
                          ? KColors.primary.withOpacity(0.15)
                          : KColors.base200,
                      shape: BoxShape.circle,
                    ),
                    child: _sendingAudio
                        ? const Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: KColors.primary,
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.mic_rounded,
                            size: 20,
                            color: KColors.baseContentMid,
                          ),
                  ),
                ),

              // Champ texte
              Expanded(
                child: TextField(
                  controller: _messageCtrl,
                  style: KTextStyles.bodyLg.copyWith(
                      color: KColors.baseContent, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: _editingMsg != null
                        ? 'Modifier le message…'
                        : 'Votre message…',
                    hintStyle: KTextStyles.bodyLg
                        .copyWith(color: KColors.baseContentLow, fontSize: 14),
                    filled: true,
                    fillColor: KColors.base200,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onChanged: (_) => _onTyping(),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),

              const SizedBox(width: 8),

              // Bouton envoyer
              Material(
                color: KColors.primary,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: _sendMessage,
                  customBorder: const CircleBorder(),
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ]),
        ]),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ── Widgets auxiliaires ───────────────────────────────────────────────────────

class _DateSeparator extends StatelessWidget {
  final DateTime date;
  const _DateSeparator({required this.date});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(children: [
      const Expanded(child: Divider(color: KColors.border)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(Formatters.date(date),
            style: KTextStyles.caption.copyWith(
                color: KColors.baseContentMid, fontSize: 10)),
      ),
      const Expanded(child: Divider(color: KColors.border)),
    ]),
  );
}

class _TypingBubble extends StatelessWidget {
  final String username;
  const _TypingBubble({required this.username});

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      margin: const EdgeInsets.only(bottom: 8, left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: KColors.base100,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
          bottomRight: Radius.circular(16),
          bottomLeft: Radius.circular(4),
        ),
        border: Border.all(color: KColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$username écrit…',
              style: KTextStyles.caption.copyWith(
                  color: KColors.baseContentMid, fontSize: 10)),
          const SizedBox(height: 4),
          Row(children: [
            for (var i = 0; i < 3; i++) ...[
              _BounceDot(delay: Duration(milliseconds: i * 150)),
              if (i < 2) const SizedBox(width: 4),
            ],
          ]),
        ],
      ),
    ),
  );
}

class _BounceDot extends StatefulWidget {
  final Duration delay;
  const _BounceDot({required this.delay});

  @override
  State<_BounceDot> createState() => _BounceDotState();
}

class _BounceDotState extends State<_BounceDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _anim = Tween<double>(begin: 0, end: -6).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) => Transform.translate(
      offset: Offset(0, _anim.value),
      child: Container(
        width: 7,
        height: 7,
        decoration: const BoxDecoration(
          color: KColors.baseContentLow,
          shape: BoxShape.circle,
        ),
      ),
    ),
  );
}

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMine;
  final String interlocuteur;
  final bool isGroupe;
  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.interlocuteur,
    this.isGroupe = false,
  });

  @override
  Widget build(BuildContext context) {
    if (message.deleted) {
      return Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: KColors.base200,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: KColors.border),
          ),
          child: Text(
            'Ce message a été supprimé.',
            style: KTextStyles.caption.copyWith(
                color: KColors.baseContentLow, fontStyle: FontStyle.italic),
          ),
        ),
      );
    }

    final bg = isMine ? KColors.primary : KColors.base100;
    final br = BorderRadius.only(
      topLeft:     const Radius.circular(16),
      topRight:    const Radius.circular(16),
      bottomLeft:  Radius.circular(isMine ? 16 : 4),
      bottomRight: Radius.circular(isMine ? 4 : 16),
    );

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Nom de l'auteur dans un groupe
          if (isGroupe && !isMine)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 2),
              child: Text(
                message.username,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: KColors.primary.withOpacity(0.7),
                ),
              ),
            ),
          Container(
            margin: const EdgeInsets.only(bottom: 2),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Réponse citée
                if (message.replyTo != null)
                  Container(
                    padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                    decoration: BoxDecoration(
                      color: isMine
                          ? Colors.white.withOpacity(0.12)
                          : KColors.primary.withOpacity(0.07),
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(14)),
                      border: Border(
                        left: BorderSide(
                          color: isMine
                              ? Colors.white.withOpacity(0.5)
                              : KColors.primary.withOpacity(0.5),
                          width: 3,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          message.replyTo!.username,
                          style: KTextStyles.caption.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isMine
                                ? Colors.white70
                                : KColors.primary,
                            fontSize: 10,
                          ),
                        ),
                        Text(
                          message.replyTo!.messageType == 'audio'
                              ? '🎵 Message vocal'
                              : message.replyTo!.contenu,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: KTextStyles.caption.copyWith(
                            color: isMine
                                ? Colors.white60
                                : KColors.baseContentMid,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Corps du message
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: message.replyTo != null
                        ? BorderRadius.only(
                            bottomLeft: Radius.circular(isMine ? 16 : 4),
                            bottomRight: Radius.circular(isMine ? 4 : 16),
                          )
                        : br,
                    border: isMine
                        ? null
                        : Border.all(color: KColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: isMine
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      if (message.messageType == 'audio' &&
                          message.audioUrl != null)
                        _AudioPlayer(
                          url: message.audioUrl!,
                          duration: message.audioDuration,
                          isMine: isMine,
                        )
                      else
                        Text(
                          message.contenu,
                          style: KTextStyles.bodyLg.copyWith(
                            color: isMine ? Colors.white : KColors.baseContent,
                            fontSize: 14,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (message.isEdited)
                            Text(
                              'Modifié  ',
                              style: KTextStyles.caption.copyWith(
                                color: isMine
                                    ? Colors.white54
                                    : KColors.baseContentLow,
                                fontSize: 9,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          Text(
                            Formatters.time(message.timestamp),
                            style: KTextStyles.caption.copyWith(
                              color: isMine
                                  ? Colors.white60
                                  : KColors.baseContentMid,
                              fontSize: 10,
                            ),
                          ),
                          if (isMine) ...[
                            const SizedBox(width: 4),
                            Icon(
                              message.isRead
                                  ? Icons.done_all_rounded
                                  : Icons.done_rounded,
                              size: 14,
                              color: message.isRead
                                  ? Colors.lightBlueAccent
                                  : Colors.white54,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Réactions
          if (message.reactions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Wrap(
                spacing: 4,
                children: message.reactions.entries.map((entry) {
                  final ismine = entry.value.moi;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: ismine
                          ? KColors.primary.withOpacity(0.15)
                          : KColors.base200,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: ismine
                            ? KColors.primary.withOpacity(0.35)
                            : KColors.border,
                      ),
                    ),
                    child: Text(
                      '${entry.key} ${entry.value.count}',
                      style: KTextStyles.caption.copyWith(fontSize: 11),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReplyPreview extends StatelessWidget {
  final MessageModel msg;
  final VoidCallback onClose;
  const _ReplyPreview({required this.msg, required this.onClose});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: KColors.primary.withOpacity(0.06),
      borderRadius: BorderRadius.circular(10),
      border: const Border(
        left: BorderSide(color: KColors.primary, width: 3),
      ),
    ),
    child: Row(children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(msg.expediteurNom,
              style: KTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: KColors.primary,
                  fontSize: 10)),
          Text(
            msg.messageType == 'audio' ? '🎵 Message vocal' : msg.contenu,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: KTextStyles.caption.copyWith(
                color: KColors.baseContentMid, fontSize: 10),
          ),
        ]),
      ),
      GestureDetector(
        onTap: onClose,
        child: const Icon(Icons.close_rounded, size: 16,
            color: KColors.baseContentMid),
      ),
    ]),
  );
}

class _RecordingBar extends StatelessWidget {
  final int elapsed;
  final VoidCallback onSend;
  final VoidCallback onCancel;
  const _RecordingBar({
    required this.elapsed,
    required this.onSend,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: KColors.error.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: KColors.error.withOpacity(0.25)),
    ),
    child: Row(children: [
      Container(
        width: 8, height: 8,
        decoration: const BoxDecoration(
          color: KColors.error,
          shape: BoxShape.circle,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          '${_fmtDuration(elapsed)} — Enregistrement en cours…',
          style: KTextStyles.caption.copyWith(color: KColors.error, fontSize: 12),
        ),
      ),
      IconButton(
        icon: const Icon(Icons.close_rounded, color: KColors.baseContentMid),
        onPressed: onCancel,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        iconSize: 20,
      ),
      const SizedBox(width: 8),
      GestureDetector(
        onTap: onSend,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: KColors.error,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(children: [
            const Icon(Icons.stop_rounded, color: Colors.white, size: 14),
            const SizedBox(width: 4),
            Text('Envoyer',
                style: KTextStyles.caption.copyWith(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    ]),
  );
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, size: 20,
        color: color ?? KColors.baseContent),
    title: Text(label,
        style: KTextStyles.bodySm.copyWith(
            color: color ?? KColors.baseContent)),
    onTap: onTap,
    visualDensity: VisualDensity.compact,
  );
}
