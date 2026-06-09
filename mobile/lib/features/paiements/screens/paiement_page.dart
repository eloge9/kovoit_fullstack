import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../reservations/repositories/reservation_repository.dart';
import '../../reservations/models/paiement_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';

final _reservationRepoProvider =
    Provider<ReservationRepository>((ref) => ReservationRepository());

class PaiementPage extends ConsumerStatefulWidget {
  final int reservationId;

  const PaiementPage({super.key, required this.reservationId});

  @override
  ConsumerState<PaiementPage> createState() => _PaiementPageState();
}

class _PaiementPageState extends ConsumerState<PaiementPage> {
  String _moyenPaiement = 'ESPECE';
  final _phoneCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  String _network = 'FLOOZ';
  bool _isLoading = false;
  PaiementModel? _paiementEnCours;
  String? _error;
  bool _success = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _refCtrl.dispose();
    super.dispose();
  }

  Future<void> _initierPaiement() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repo = ref.read(_reservationRepoProvider);
      PaiementModel paiement;

      if (_moyenPaiement == 'ESPECE') {
        paiement = await repo.initierPaiementEspeces(widget.reservationId);
        setState(() {
          _paiementEnCours = paiement;
          _success = true;
          _isLoading = false;
        });
      } else {
        if (_phoneCtrl.text.isEmpty) {
          setState(() {
            _error = 'Numéro de téléphone requis';
            _isLoading = false;
          });
          return;
        }
        paiement = await repo.initierPaiement(
          reservationId: widget.reservationId,
          phoneNumber: _phoneCtrl.text.trim(),
          network: _network,
        );
        setState(() {
          _paiementEnCours = paiement;
          _isLoading = false;
        });
        _pollStatut(paiement);
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _pollStatut(PaiementModel paiement) async {
    // Polling toutes les 5 secondes jusqu'à confirmation
    for (int i = 0; i < 12; i++) {
      await Future.delayed(const Duration(seconds: 5));
      if (!mounted) return;

      try {
        final repo = ref.read(_reservationRepoProvider);
        final updated = await repo.verifierPaiement(
          paiement.paygateTxRef ?? paiement.id.toString(),
        );
        if (updated.isConfirme) {
          setState(() => _success = true);
          return;
        }
      } catch (_) {}
    }
  }

  Future<void> _soumettreRef() async {
    if (_refCtrl.text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repo = ref.read(_reservationRepoProvider);
      await repo.soumettreReference(
        reservationId: widget.reservationId,
        reference: _refCtrl.text.trim(),
        network: _network,
      );
      setState(() {
        _isLoading = false;
        _success = true;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_success) return _buildSuccess(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Paiement')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sélection moyen de paiement
            const Text(
              'Mode de paiement',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _PaymentOption(
                    label: 'Espèces',
                    icon: Icons.payments,
                    isSelected: _moyenPaiement == 'ESPECE',
                    onTap: () => setState(() => _moyenPaiement = 'ESPECE'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _PaymentOption(
                    label: 'FLOOZ',
                    icon: Icons.phone_android,
                    isSelected: _moyenPaiement == 'FLOOZ',
                    onTap: () => setState(() {
                      _moyenPaiement = 'FLOOZ';
                      _network = 'FLOOZ';
                    }),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _PaymentOption(
                    label: 'TMONEY',
                    icon: Icons.mobile_friendly,
                    isSelected: _moyenPaiement == 'TMONEY',
                    onTap: () => setState(() {
                      _moyenPaiement = 'TMONEY';
                      _network = 'TMONEY';
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Formulaire selon le mode
            if (_moyenPaiement != 'ESPECE') ...[
              AppTextField(
                controller: _phoneCtrl,
                label: 'Numéro $_network',
                hint: '+228 XX XX XX XX',
                keyboardType: TextInputType.phone,
                prefixIcon: const Icon(Icons.phone),
              ),
              const SizedBox(height: 12),
              if (_paiementEnCours != null && !_success) ...[
                Card(
                  color: AppTheme.warningColor.withValues(alpha: 0.1),
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircularProgressIndicator(strokeWidth: 2),
                        SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'Confirmez le paiement sur votre téléphone...',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Ou saisissez manuellement votre référence :'),
                const SizedBox(height: 8),
                AppTextField(
                  controller: _refCtrl,
                  label: 'Référence de paiement',
                  hint: 'TXN-XXXXXXXX',
                  prefixIcon: const Icon(Icons.confirmation_number),
                ),
                const SizedBox(height: 12),
                AppButton(
                  label: 'Valider la référence',
                  onPressed: _isLoading ? null : _soumettreRef,
                  isLoading: _isLoading,
                ),
              ],
            ],

            if (_moyenPaiement == 'ESPECE') ...[
              Card(
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: AppTheme.primaryColor),
                          SizedBox(width: 8),
                          Text(
                            'Paiement en espèces',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Remettez le montant exactement au conducteur lors du trajet. '
                        'Le conducteur confirmera la réception du paiement.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppTheme.errorColor, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: AppTheme.errorColor),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
            if (_paiementEnCours == null || _moyenPaiement == 'ESPECE')
              AppButton(
                label: _moyenPaiement == 'ESPECE'
                    ? 'Confirmer le paiement en espèces'
                    : 'Initier le paiement $_network',
                icon: _moyenPaiement == 'ESPECE' ? Icons.handshake : Icons.send,
                onPressed: _isLoading ? null : _initierPaiement,
                isLoading: _isLoading,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccess(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.check_circle,
                size: 100,
                color: AppTheme.successColor,
              ),
              const SizedBox(height: 24),
              const Text(
                'Paiement confirmé !',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text(
                _moyenPaiement == 'ESPECE'
                    ? 'Remettez le montant au conducteur lors du trajet.'
                    : 'Votre paiement a été enregistré avec succès.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 16),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('Retour à mes réservations'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _PaymentOption({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withValues(alpha: 0.1)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.primaryColor : Colors.grey,
              size: 24,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppTheme.primaryColor : Colors.grey,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
