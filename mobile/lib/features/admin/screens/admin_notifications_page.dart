import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/k_empty_state.dart';

class AdminNotificationsPage extends ConsumerWidget {
  const AdminNotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: KColors.base200,
      appBar: AppBar(
        backgroundColor: KColors.base100,
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: KColors.border)),
        title: Text(
          'Notifications',
          style: KTextStyles.bodySm.copyWith(
            fontWeight: FontWeight.w700,
            color: KColors.baseContent,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => _envoyerNotificationGlobale(context),
            child: Text(
              'Envoyer',
              style: KTextStyles.bodySm.copyWith(color: KColors.primary),
            ),
          ),
        ],
      ),
      body: const KEmptyState(
        emoji: '🔔',
        message: 'Aucune notification système',
      ),
    );
  }

  void _envoyerNotificationGlobale(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: KColors.base100,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => const _EnvoyerNotificationSheet(),
    );
  }
}

class _EnvoyerNotificationSheet extends StatefulWidget {
  const _EnvoyerNotificationSheet();

  @override
  State<_EnvoyerNotificationSheet> createState() =>
      _EnvoyerNotificationSheetState();
}

class _EnvoyerNotificationSheetState extends State<_EnvoyerNotificationSheet> {
  final _titreCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  String _cible = 'tous';
  final bool _sending = false;

  @override
  void dispose() {
    _titreCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        KSpacing.pagePaddingH,
        KSpacing.lg,
        KSpacing.pagePaddingH,
        MediaQuery.of(context).viewInsets.bottom + KSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Envoyer une notification', style: KTextStyles.h3),
          const SizedBox(height: KSpacing.xl),

          Text('Cible', style: KTextStyles.label),
          const SizedBox(height: KSpacing.sm),
          Row(
            children: [
              for (final (val, label) in [
                ('tous', 'Tous'),
                ('passager', 'Passagers'),
                ('conducteur', 'Conducteurs'),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        color: _cible == val
                            ? Colors.white
                            : KColors.baseContentMid,
                      ),
                    ),
                    selected: _cible == val,
                    selectedColor: KColors.primary,
                    backgroundColor: KColors.base200,
                    onSelected: (_) => setState(() => _cible = val),
                  ),
                ),
            ],
          ),
          const SizedBox(height: KSpacing.lg),

          Text('Titre', style: KTextStyles.label),
          const SizedBox(height: KSpacing.sm),
          TextField(
            controller: _titreCtrl,
            decoration: InputDecoration(
              hintText: 'Titre de la notification',
              filled: true,
              fillColor: KColors.base200,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            style: KTextStyles.bodySm,
          ),
          const SizedBox(height: KSpacing.md),

          Text('Message', style: KTextStyles.label),
          const SizedBox(height: KSpacing.sm),
          TextField(
            controller: _messageCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Contenu du message...',
              filled: true,
              fillColor: KColors.base200,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
            style: KTextStyles.bodySm,
          ),
          const SizedBox(height: KSpacing.xl),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _sending ? null : () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: KColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(99),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Envoyer',
                      style: KTextStyles.button.copyWith(color: Colors.white),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
