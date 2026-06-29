import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/text_styles.dart';
import 'chatbot_provider.dart';

// ── Indicateur de frappe (trois points) ──────────────────────────────────────

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final offset = ((_ctrl.value * 3 - i) % 1).clamp(0.0, 1.0);
          final scale  = 1.0 + 0.4 * (offset < 0.5 ? offset * 2 : (1 - offset) * 2);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Transform.scale(
              scale: scale,
              child: Container(
                width: 7, height: 7,
                decoration: BoxDecoration(
                  color: KColors.primary.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Bulle de message ──────────────────────────────────────────────────────────

class _ChatBubble extends StatelessWidget {
  final ChatUIMessage message;
  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';

    return Padding(
      padding: EdgeInsets.only(
        bottom: 8,
        left:  isUser ? 48 : 0,
        right: isUser ? 0  : 48,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          // Avatar Kovi
          if (!isUser) ...[
            Container(
              width: 30, height: 30,
              decoration: const BoxDecoration(
                color: KColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('K',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
              ),
            ),
            const SizedBox(width: 6),
          ],

          // Bulle
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? KColors.primary : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft:     const Radius.circular(16),
                  topRight:    const Radius.circular(16),
                  bottomLeft:  Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4  : 16),
                ),
                border: isUser ? null : Border.all(color: KColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 6, offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: message.isStreaming && message.content.isEmpty
                  ? const _TypingIndicator()
                  : Text(
                      message.content,
                      style: KTextStyles.bodyLg.copyWith(
                        color: isUser ? Colors.white : KColors.baseContent,
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Suggestions rapides ───────────────────────────────────────────────────────

const _quickQuestions = [
  'Comment réserver un trajet ?',
  'Comment devenir conducteur ?',
  'Comment payer sur Kovoit ?',
  'Contacter le support',
];

// ── Écran principal ───────────────────────────────────────────────────────────

class ChatbotScreen extends ConsumerStatefulWidget {
  const ChatbotScreen({super.key});

  @override
  ConsumerState<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends ConsumerState<ChatbotScreen> {
  final _scrollCtrl = ScrollController();
  final _inputCtrl  = TextEditingController();
  bool _showQuick   = true;

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _inputCtrl.dispose();
    super.dispose();
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

  void _send() {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    _inputCtrl.clear();
    setState(() => _showQuick = false);
    ref.read(chatbotProvider.notifier).sendMessage(text);
    _scrollToBottom();
  }

  void _sendQuick(String q) {
    setState(() => _showQuick = false);
    ref.read(chatbotProvider.notifier).sendMessage(q);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatbotProvider);

    // Auto-scroll quand les messages changent
    ref.listen(chatbotProvider, (_, __) => _scrollToBottom());

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: KColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('K',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Kovi', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              Text('Assistant Kovoit',
                  style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.8))),
            ],
          ),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            tooltip: 'Nouvelle conversation',
            onPressed: () {
              ref.read(chatbotProvider.notifier).clearHistory();
              setState(() => _showQuick = true);
            },
          ),
        ],
      ),

      body: Column(children: [
        // ── Messages ─────────────────────────────────────────────────
        Expanded(
          child: ListView.builder(
            controller: _scrollCtrl,
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
            itemCount: state.messages.length + (_showQuick && state.messages.length == 1 ? 1 : 0),
            itemBuilder: (ctx, i) {
              // Questions rapides après le message de bienvenue
              if (_showQuick && state.messages.length == 1 && i == 1) {
                return Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 8, left: 36),
                  child: Wrap(spacing: 6, runSpacing: 6, children: _quickQuestions
                      .map((q) => GestureDetector(
                            onTap: () => _sendQuick(q),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: KColors.primary.withOpacity(0.4)),
                              ),
                              child: Text(q,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: KColors.primary,
                                      fontWeight: FontWeight.w500)),
                            ),
                          ))
                      .toList()),
                );
              }
              return _ChatBubble(message: state.messages[i]);
            },
          ),
        ),

        // ── Zone de saisie ───────────────────────────────────────────
        Container(
          color: Colors.white,
          padding: EdgeInsets.fromLTRB(
              12, 10, 12, 10 + MediaQuery.of(context).viewInsets.bottom),
          child: SafeArea(
            top: false,
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _inputCtrl,
                  maxLines: null,
                  maxLength: 500,
                  buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
                      null,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Posez votre question…',
                    hintStyle: TextStyle(color: KColors.baseContentMid, fontSize: 14),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: state.isLoading ? null : _send,
                child: Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: state.isLoading ? KColors.baseContentMid : KColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: state.isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
