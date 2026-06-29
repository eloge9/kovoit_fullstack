import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'chatbot_service.dart';

const _maxHistory = 10;

class ChatUIMessage {
  final String id;
  final String role;      // "user" | "assistant"
  final String content;
  final bool   isStreaming;
  final String provider;

  const ChatUIMessage({
    required this.id,
    required this.role,
    required this.content,
    this.isStreaming = false,
    this.provider    = '',
  });

  ChatUIMessage copyWith({String? content, bool? isStreaming, String? provider}) =>
      ChatUIMessage(
        id:          id,
        role:        role,
        content:     content ?? this.content,
        isStreaming: isStreaming ?? this.isStreaming,
        provider:    provider   ?? this.provider,
      );
}

class ChatbotState {
  final List<ChatUIMessage> messages;
  final bool isLoading;

  const ChatbotState({
    required this.messages,
    this.isLoading = false,
  });

  ChatbotState copyWith({List<ChatUIMessage>? messages, bool? isLoading}) =>
      ChatbotState(
        messages:  messages  ?? this.messages,
        isLoading: isLoading ?? this.isLoading,
      );
}

final _welcomeMsg = ChatUIMessage(
  id:       'welcome',
  role:     'assistant',
  content:  'Bonjour ! Je suis Kovi, votre assistant Kovoit 👋\nComment puis-je vous aider aujourd\'hui ?',
  provider: 'system',
);

class ChatbotNotifier extends StateNotifier<ChatbotState> {
  ChatbotNotifier() : super(ChatbotState(messages: [_welcomeMsg]));

  final _service = ChatbotService();
  final List<ChatMessage> _history = [];

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty || state.isLoading) return;

    final userMsg = ChatUIMessage(
      id:   'u-${DateTime.now().millisecondsSinceEpoch}',
      role: 'user',
      content: text.trim(),
    );
    final assistantId = 'a-${DateTime.now().millisecondsSinceEpoch}';
    final assistantMsg = ChatUIMessage(
      id:          assistantId,
      role:        'assistant',
      content:     '',
      isStreaming: true,
    );

    state = state.copyWith(
      messages:  [...state.messages, userMsg, assistantMsg],
      isLoading: true,
    );

    final history = _history.length > _maxHistory * 2
        ? _history.sublist(_history.length - _maxHistory * 2)
        : List<ChatMessage>.from(_history);

    String fullText = '';
    String provider = 'gemini';

    try {
      await for (final chunk in _service.streamMessage(text.trim(), history)) {
        if (chunk.startsWith('[PROVIDER:')) {
          provider = chunk.substring(10, chunk.length - 1);
          state = state.copyWith(
            messages: state.messages
                .map((m) => m.id == assistantId ? m.copyWith(provider: provider) : m)
                .toList(),
          );
        } else if (chunk.startsWith('[ERROR]')) {
          final errText = chunk.substring(7);
          state = state.copyWith(
            messages: state.messages
                .map((m) => m.id == assistantId
                    ? m.copyWith(content: errText, isStreaming: false)
                    : m)
                .toList(),
            isLoading: false,
          );
          return;
        } else if (chunk == '[DONE]') {
          break;
        } else {
          fullText += chunk;
          state = state.copyWith(
            messages: state.messages
                .map((m) => m.id == assistantId ? m.copyWith(content: fullText) : m)
                .toList(),
          );
        }
      }

      // Finaliser
      state = state.copyWith(
        messages: state.messages
            .map((m) => m.id == assistantId
                ? m.copyWith(isStreaming: false, provider: provider)
                : m)
            .toList(),
        isLoading: false,
      );

      // Mise à jour de l'historique
      _history.addAll([
        ChatMessage(role: 'user',      content: text.trim()),
        ChatMessage(role: 'assistant', content: fullText),
      ]);

    } catch (e) {
      state = state.copyWith(
        messages: state.messages
            .map((m) => m.id == assistantId
                ? m.copyWith(
                    content: 'Désolé, une erreur est survenue. Contactez le support au 91 27 10 04.',
                    isStreaming: false)
                : m)
            .toList(),
        isLoading: false,
      );
    }
  }

  void clearHistory() {
    _history.clear();
    state = ChatbotState(messages: [_welcomeMsg]);
  }
}

final chatbotProvider =
    StateNotifierProvider<ChatbotNotifier, ChatbotState>(
  (_) => ChatbotNotifier(),
);
