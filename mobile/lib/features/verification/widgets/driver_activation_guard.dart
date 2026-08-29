import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/colors.dart';

void showDriverActivationDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      icon: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3CD),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.verified_user_rounded,
          color: Color(0xFFF59E0B),
          size: 32,
        ),
      ),
      title: const Text(
        'Compte non activé',
        textAlign: TextAlign.center,
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
      content: const Text(
        'Votre compte conducteur n\'est pas encore activé.\n\n'
        'Veuillez compléter vos documents ou attendre leur validation.\n\n'
        'Certaines fonctionnalités resteront indisponibles jusqu\'à l\'activation.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13, height: 1.5),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actionsOverflowButtonSpacing: 8,
      actions: [
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: KColors.primary),
          onPressed: () {
            Navigator.pop(ctx);
            context.push('/conducteur/dossier');
          },
          child: const Text('Envoyer mes documents'),
        ),
        OutlinedButton(
          onPressed: () {
            Navigator.pop(ctx);
            context.push('/conducteur/documents');
          },
          child: const Text('Voir mes documents'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Retour'),
        ),
      ],
    ),
  );
}
