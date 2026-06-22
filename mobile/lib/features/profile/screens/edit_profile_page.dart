import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_text_field.dart';

class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _urgenceNomCtrl;
  late final TextEditingController _urgenceTelCtrl;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    _usernameCtrl = TextEditingController(text: user?.username);
    _phoneCtrl = TextEditingController(text: user?.phoneNumber);
    _urgenceNomCtrl = TextEditingController(text: user?.contactUrgenceNom);
    _urgenceTelCtrl = TextEditingController(text: user?.contactUrgenceTelephone);
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _phoneCtrl.dispose();
    _urgenceNomCtrl.dispose();
    _urgenceTelCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final data = <String, dynamic>{
      'username': _usernameCtrl.text.trim(),
      if (_phoneCtrl.text.isNotEmpty)
        'numero_telephone': _phoneCtrl.text.trim(),
      if (_urgenceNomCtrl.text.isNotEmpty)
        'contact_urgence_nom': _urgenceNomCtrl.text.trim(),
      if (_urgenceTelCtrl.text.isNotEmpty)
        'contact_urgence_telephone': _urgenceTelCtrl.text.trim(),
    };

    final ok = await ref.read(authProvider.notifier).updateProfil(data);

    if (!mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil mis à jour !'),
          backgroundColor: KColors.success,
        ),
      );
      context.pop();
    } else {
      final error = ref.read(authProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'Erreur lors de la mise à jour'),
          backgroundColor: KColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authProvider).isLoading;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: KColors.base100,
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: KColors.border)),
        iconTheme: const IconThemeData(color: KColors.baseContent),
        title: Text(
          'Modifier le profil',
          style: KTextStyles.bodySm.copyWith(
            fontWeight: FontWeight.w700,
            color: KColors.baseContent,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SizedBox(height: 8),
            KTextField(
              controller: _usernameCtrl,
              label: 'Nom d\'utilisateur',
              prefixIcon: const Icon(Icons.person_outline),
              validator: (v) => v?.isEmpty == true ? 'Champ requis' : null,
            ),
            const SizedBox(height: 12),
            KTextField(
              controller: _phoneCtrl,
              label: 'Téléphone',
              hint: '+228 XX XX XX XX',
              keyboardType: TextInputType.phone,
              prefixIcon: const Icon(Icons.phone_outlined),
            ),
            const SizedBox(height: 24),
            const Text(
              'Contact d\'urgence',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              'Utilisé en cas d\'alerte SOS',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 12),
            KTextField(
              controller: _urgenceNomCtrl,
              label: 'Nom du contact',
              prefixIcon: const Icon(Icons.contact_emergency_outlined),
            ),
            const SizedBox(height: 12),
            KTextField(
              controller: _urgenceTelCtrl,
              label: 'Téléphone du contact',
              keyboardType: TextInputType.phone,
              prefixIcon: const Icon(Icons.phone_outlined),
            ),
            const SizedBox(height: 32),
            KButton(
              label: 'Enregistrer',
              onPressed: isLoading ? null : _submit,
              isLoading: isLoading,
            ),
          ],
        ),
      ),
    );
  }
}
