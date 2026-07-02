import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/server_provider.dart';
import '../../../core/theme/colors.dart';

class ServerSettingsScreen extends ConsumerStatefulWidget {
  const ServerSettingsScreen({super.key});

  @override
  ConsumerState<ServerSettingsScreen> createState() =>
      _ServerSettingsScreenState();
}

class _ServerSettingsScreenState extends ConsumerState<ServerSettingsScreen> {
  late TextEditingController _urlController;
  String? _feedback;
  bool _feedbackIsError = false;

  @override
  void initState() {
    super.initState();
    final current = ref.read(serverProvider).serverUrl ?? '';
    _urlController = TextEditingController(text: current);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _showFeedback(String msg, {bool error = false}) {
    setState(() {
      _feedback = msg;
      _feedbackIsError = error;
    });
  }

  Future<void> _testAndSave() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      _showFeedback('Entrez une URL valide.', error: true);
      return;
    }
    final ok = await ref.read(serverProvider.notifier).setManualUrl(url);
    if (!mounted) return;
    if (ok) {
      // Retour vers splash pour relancer le flux d'authentification
      context.go('/splash');
    } else {
      _showFeedback('Impossible de joindre le serveur.', error: true);
    }
  }

  Future<void> _rediscover() async {
    setState(() => _feedback = null);
    await ref.read(serverProvider.notifier).rediscover();
    final state = ref.read(serverProvider);
    if (state.isConnected) {
      _urlController.text = state.serverUrl ?? '';
      _showFeedback('Serveur trouvé : ${state.serverUrl}');
    } else {
      _showFeedback('Serveur introuvable sur le réseau.', error: true);
    }
  }

  Future<void> _reset() async {
    await ref.read(serverProvider.notifier).reset();
    _urlController.clear();
    _showFeedback('Configuration réinitialisée.');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(serverProvider);

    return Scaffold(
      backgroundColor: KColors.base200,
      appBar: AppBar(
        title: const Text('Serveur Django'),
        backgroundColor: KColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Statut actuel
          _StatusCard(state: state),
          const SizedBox(height: 20),

          // Saisie manuelle
          _SectionLabel('URL du serveur'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _urlController,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              hintText: 'http://192.168.1.100:8000',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: KColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: KColors.border),
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.copy_rounded, size: 18),
                tooltip: 'Copier',
                onPressed: () {
                  Clipboard.setData(
                      ClipboardData(text: _urlController.text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('URL copiée')),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Bouton tester & sauvegarder
          FilledButton.icon(
            onPressed: state.isBusy ? null : _testAndSave,
            icon: const Icon(Icons.check_circle_rounded),
            label: const Text('Tester et sauvegarder'),
            style: FilledButton.styleFrom(
              backgroundColor: KColors.primary,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 24),

          // Découverte automatique
          _SectionLabel('Découverte automatique'),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: state.isBusy ? null : _rediscover,
            icon: state.status == ServerStatus.discovering
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.radar_rounded),
            label: Text(state.status == ServerStatus.discovering
                ? state.message
                : 'Scanner le réseau local'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              side: const BorderSide(color: KColors.primary),
              foregroundColor: KColors.primary,
            ),
          ),
          const SizedBox(height: 12),

          // Réinitialiser
          TextButton.icon(
            onPressed: state.isBusy ? null : _reset,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Réinitialiser la configuration'),
            style: TextButton.styleFrom(
              foregroundColor: KColors.error,
              minimumSize: const Size.fromHeight(44),
            ),
          ),

          // Message de feedback
          if (_feedback != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _feedbackIsError
                    ? KColors.errorLight
                    : KColors.successLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    _feedbackIsError
                        ? Icons.error_outline_rounded
                        : Icons.check_circle_outline_rounded,
                    color: _feedbackIsError
                        ? KColors.error
                        : KColors.successContent,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _feedback!,
                      style: TextStyle(
                        color: _feedbackIsError
                            ? KColors.errorContent
                            : KColors.successContent,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 32),
          _HelpCard(),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final ServerState state;
  const _StatusCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final (icon, color, bg, label) = switch (state.status) {
      ServerStatus.connected => (
          Icons.wifi_rounded,
          const Color(0xFF13201F),
          KColors.successLight,
          'Connecté',
        ),
      ServerStatus.discovering || ServerStatus.checking => (
          Icons.search_rounded,
          KColors.baseContent,
          KColors.infoLight,
          state.message.isNotEmpty ? state.message : 'Recherche...',
        ),
      ServerStatus.notFound => (
          Icons.wifi_off_rounded,
          KColors.errorContent,
          KColors.errorLight,
          'Non connecté',
        ),
      ServerStatus.idle => (
          Icons.settings_ethernet_rounded,
          KColors.baseContent,
          KColors.base300,
          'Non configuré',
        ),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          if (state.isBusy)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: color,
                    fontSize: 14,
                  ),
                ),
                if (state.serverUrl != null)
                  Text(
                    state.serverUrl!,
                    style: TextStyle(
                      color: color.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: KColors.baseContent,
          letterSpacing: 0.3,
        ),
      );
}

class _HelpCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KColors.infoLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 16, color: KColors.infoContent),
              SizedBox(width: 8),
              Text(
                'Comment trouver l\'IP du PC ?',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: KColors.infoContent,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            '• Windows : ipconfig dans CMD\n'
            '• Linux/Mac : ifconfig ou ip a\n'
            '• Émulateur Android : utiliser 10.0.2.2\n'
            '• Démarrer Django avec : python manage.py runserver 0.0.0.0:8000',
            style: TextStyle(fontSize: 12, color: KColors.infoContent),
          ),
        ],
      ),
    );
  }
}
