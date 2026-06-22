import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
import '../repositories/messagerie_repository.dart';
import '../models/message_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/k_avatar.dart';

class ConversationPage extends ConsumerStatefulWidget {
  final int convId;
  final String userName;
  // userId is the interlocutor's UUID, used only for the WebSocket channel
  final String? userId;

  const ConversationPage({
    super.key,
    required this.convId,
    required this.userName,
    this.userId,
  });

  @override
  ConsumerState<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends ConsumerState<ConversationPage> {
  final _messageCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _repo = MessagerieRepository();
  List<MessageModel> _messages = [];
  bool _isLoading = true;
  WebSocketChannel? _wsChannel;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _connectWebSocket();
  }

  Future<void> _loadMessages() async {
    try {
      final messages = await _repo.getMessages(widget.convId);
      setState(() {
        _messages = messages;
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _connectWebSocket() async {
    final token = await StorageService.getAccessToken();
    if (token == null || widget.convId == 0) return;

    try {
      final uri = Uri.parse(
        '${ApiConstants.wsBaseUrl}/conv/${widget.convId}/?token=$token',
      );
      _wsChannel = WebSocketChannel.connect(uri);
      _wsChannel!.stream.listen(
        (data) {
          final json = jsonDecode(data as String) as Map<String, dynamic>;
          if (json['type'] == 'message') {
            final msg = MessageModel.fromJson(json);
            setState(() => _messages.add(msg));
            _scrollToBottom();
            if (widget.userId != null && msg.expediteurId == widget.userId) {
              NotificationService.nouveauMessage(
                widget.userName,
                msg.contenu.length > 60
                    ? '${msg.contenu.substring(0, 60)}…'
                    : msg.contenu,
              );
            }
          }
        },
        onError: (e) {
          debugPrint('WS Error: $e');
          setState(() => _wsChannel = null);
        },
        onDone: () {
          debugPrint('WS Closed');
          setState(() => _wsChannel = null);
        },
      );
    } catch (e) {
      debugPrint('WS Connect Error: $e');
      _wsChannel = null;
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty) return;

    _messageCtrl.clear();

    if (_wsChannel != null) {
      _wsChannel!.sink.add(jsonEncode({'type': 'message', 'contenu': text}));
      return;
    }

    // Fallback REST
    try {
      final msg = await _repo.envoyerMessage(widget.convId, text);
      setState(() => _messages.add(msg));
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: KColors.error,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    _wsChannel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(currentUserProvider)?.id ?? '';

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
          KAvatar(name: widget.userName, size: 34),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.userName, style: KTextStyles.bodySm.copyWith(
                fontWeight: FontWeight.w700, color: KColors.baseContent,
              )),
              Text('En ligne', style: KTextStyles.caption.copyWith(
                color: KColors.success, fontSize: 10,
              )),
            ],
          )),
        ]),
      ),
      body: Column(
        children: [
          // ── Messages list ──────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: KColors.primary))
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('💬', style: TextStyle(fontSize: 48)),
                            const SizedBox(height: 12),
                            Text(
                              'Commencez la conversation',
                              style: KTextStyles.bodySm.copyWith(color: KColors.baseContentMid),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        itemCount: _messages.length,
                        itemBuilder: (context, i) {
                          final msg = _messages[i];
                          final isMine = msg.expediteurId == currentUserId;
                          final showDate = i == 0 ||
                              !_isSameDay(_messages[i - 1].timestamp, msg.timestamp);
                          return Column(children: [
                            if (showDate) _DateSeparator(date: msg.timestamp),
                            _MessageBubble(message: msg, isMine: isMine),
                          ]);
                        },
                      ),
          ),

          // ── Input bar ─────────────────────────────────────────────────
          Container(
            color: KColors.base100,
            padding: EdgeInsets.fromLTRB(
              12, 8, 12, MediaQuery.of(context).viewInsets.bottom + 8,
            ),
            child: SafeArea(
              top: false,
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _messageCtrl,
                    style: KTextStyles.bodyLg.copyWith(color: KColors.baseContent),
                    decoration: InputDecoration(
                      hintText: 'Votre message…',
                      hintStyle: KTextStyles.bodyLg.copyWith(color: KColors.baseContentLow),
                      filled: true,
                      fillColor: KColors.base200,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10,
                      ),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
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
            ),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DateSeparator extends StatelessWidget {
  final DateTime date;
  const _DateSeparator({required this.date});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        const Expanded(child: Divider(color: KColors.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            Formatters.date(date),
            style: KTextStyles.caption.copyWith(color: KColors.baseContentMid),
          ),
        ),
        const Expanded(child: Divider(color: KColors.border)),
      ]),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMine;

  const _MessageBubble({required this.message, required this.isMine});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        decoration: BoxDecoration(
          color: isMine ? KColors.primary : KColors.base100,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMine ? 16 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 16),
          ),
          border: isMine ? null : Border.all(color: KColors.border),
        ),
        child: Column(
          crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              message.contenu,
              style: KTextStyles.bodyLg.copyWith(
                color: isMine ? Colors.white : KColors.baseContent,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              Formatters.time(message.timestamp),
              style: KTextStyles.caption.copyWith(
                color: isMine ? Colors.white70 : KColors.baseContentMid,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
