import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isConducteur = user?.role == 'conducteur' || user?.peutConduire == true;
    final prefix = isConducteur ? '/conducteur' : '/passager';

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon profil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => context.push('$prefix/profile/edit'),
          ),
        ],
      ),
      body: ListView(
        children: [
          // En-tête profil
          Container(
            color: AppTheme.primaryColor,
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: Colors.white,
                  child: Text(
                    user.username.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      fontSize: 32,
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  user.username,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  user.email,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.star, color: AppTheme.secondaryColor, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${user.note.toStringAsFixed(1)} / 5.0',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Infos
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Informations personnelles',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      _InfoTile(
                        icon: Icons.person,
                        label: 'Nom',
                        value: user.username,
                      ),
                      const Divider(height: 1),
                      _InfoTile(
                        icon: Icons.email,
                        label: 'Email',
                        value: user.email,
                      ),
                      if (user.phoneNumber != null) ...[
                        const Divider(height: 1),
                        _InfoTile(
                          icon: Icons.phone,
                          label: 'Téléphone',
                          value: user.phoneNumber!,
                        ),
                      ],
                      const Divider(height: 1),
                      _InfoTile(
                        icon: Icons.badge,
                        label: 'Rôle',
                        value: _roleLabel(user.role, user.peutConduire),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                const Text(
                  'Vérification',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: Icon(
                      _statutIcon(user.statutValidation),
                      color: _statutColor(user.statutValidation),
                    ),
                    title: const Text('Documents d\'identité'),
                    subtitle: Text(
                      _statutLabel(user.statutValidation),
                      style: TextStyle(
                        color: _statutColor(user.statutValidation),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                    onTap: () => context.push('$prefix/profile/documents'),
                  ),
                ),

                if (user.contactUrgenceNom != null) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Contact d\'urgence',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Column(
                      children: [
                        _InfoTile(
                          icon: Icons.contact_emergency,
                          label: 'Nom',
                          value: user.contactUrgenceNom!,
                        ),
                        if (user.contactUrgenceTelephone != null) ...[
                          const Divider(height: 1),
                          _InfoTile(
                            icon: Icons.phone,
                            label: 'Téléphone',
                            value: user.contactUrgenceTelephone!,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _roleLabel(String role, bool peutConduire) {
    if (role == 'conducteur') return 'Conducteur';
    if (peutConduire) return 'Passager / Conducteur';
    return 'Passager';
  }

  IconData _statutIcon(String statut) {
    switch (statut) {
      case 'valide':
        return Icons.verified;
      case 'en_attente':
        return Icons.hourglass_empty;
      case 'rejete':
        return Icons.cancel;
      default:
        return Icons.upload_file;
    }
  }

  Color _statutColor(String statut) {
    switch (statut) {
      case 'valide':
        return AppTheme.successColor;
      case 'en_attente':
        return AppTheme.warningColor;
      case 'rejete':
        return AppTheme.errorColor;
      default:
        return Colors.grey;
    }
  }

  String _statutLabel(String statut) {
    switch (statut) {
      case 'valide':
        return 'Documents validés ✓';
      case 'en_attente':
        return 'En cours de vérification...';
      case 'rejete':
        return 'Documents rejetés - Renvoyez';
      default:
        return 'Documents non soumis - Cliquez pour soumettre';
    }
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryColor, size: 20),
      title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      subtitle: Text(value, style: const TextStyle(fontSize: 14, color: Colors.black87)),
    );
  }
}
