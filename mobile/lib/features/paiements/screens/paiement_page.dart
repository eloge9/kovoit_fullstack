import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../reservations/models/paiement_model.dart';
import '../../reservations/models/reservation_model.dart';
import '../../reservations/repositories/reservation_repository.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_text_field.dart';

final _reservationRepoProvider = Provider<ReservationRepository>(
  (ref) => ReservationRepository(),
);

// ── Palette opérateurs ───────────────────────────────────────────────────────
const _kFloozColor  = Color(0xFF0066CC); // Moov Flooz — bleu
const _kYasColor    = Color(0xFFF5A623); // Mixx by Yas — jaune
const _kEspeceColor = Color(0xFF34C759); // Espèces — vert

// ── Données opérateurs ───────────────────────────────────────────────────────
class _OperateurInfo {
  final String code;
  final String label;
  final String prefixes;
  final Color color;
  final IconData icon;

  const _OperateurInfo({
    required this.code,
    required this.label,
    required this.prefixes,
    required this.color,
    required this.icon,
  });
}

const _operateurs = [
  _OperateurInfo(
    code: 'FLOOZ',
    label: 'Moov Flooz',
    prefixes: '90 / 91 / 92',
    color: _kFloozColor,
    icon: Icons.phone_android,
  ),
  _OperateurInfo(
    code: 'YAS',
    label: 'Mixx by Yas',
    prefixes: '70 / 71 / 72',
    color: _kYasColor,
    icon: Icons.mobile_friendly,
  ),
];

// ════════════════════════════════════════════════════════════════════════════
class PaiementPage extends ConsumerStatefulWidget {
  final int reservationId;
  final double montant;
  final String? depart;
  final String? destination;

  const PaiementPage({
    super.key,
    required this.reservationId,
    this.montant = 0,
    this.depart,
    this.destination,
  });

  @override
  ConsumerState<PaiementPage> createState() => _PaiementPageState();
}

// ════════════════════════════════════════════════════════════════════════════
class _PaiementPageState extends ConsumerState<PaiementPage>
    with SingleTickerProviderStateMixin {
  // -- Réservation chargée --
  ReservationModel? _reservation;
  bool _loadingResa = false;

  // -- Choix méthode --
  String _methode = 'MOBILE';       // 'MOBILE' | 'ESPECE'
  String _operateur = 'FLOOZ';      // 'FLOOZ' | 'YAS'

  // -- Formulaire --
  final _phoneCtrl = TextEditingController();

  // -- État --
  bool _isLoading = false;
  String? _error;
  bool _success = false;
  String? _successMessage;

  // -- Après initiation Mobile Money --
  PaiementModel? _paiementEnCours;
  Timer? _pollingTimer;
  int _pollingCount = 0;
  static const _kMaxPolls = 24; // 2 min à 5 s/poll

  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    // Charger la réservation si montant non fourni
    if (widget.montant == 0) _chargerReservation();
  }

  Future<void> _chargerReservation() async {
    setState(() => _loadingResa = true);
    try {
      final repo = ref.read(_reservationRepoProvider);
      final reservations = await repo.mesReservations();
      final resa = reservations.firstWhere(
        (r) => r.id == widget.reservationId,
        orElse: () => reservations.first,
      );
      if (mounted) setState(() { _reservation = resa; _loadingResa = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingResa = false);
    }
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _pollingTimer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  _OperateurInfo get _currentOp =>
      _operateurs.firstWhere((o) => o.code == _operateur);

  double get _montant => widget.montant > 0 ? widget.montant : (_reservation?.montantTotal ?? 0);
  String? get _depart => widget.depart ?? _reservation?.trajet?.depart;
  String? get _destination => widget.destination ?? _reservation?.trajet?.destination;
  double get _commission => (_montant * 0.10).roundToDouble();
  double get _montantNet => _montant - _commission;

  // ── Actions ──────────────────────────────────────────────────────────────

  Future<void> _initierMobileMoney() async {
    final phone = _phoneCtrl.text.trim().replaceAll(RegExp(r'\s+'), '');
    if (phone.isEmpty) {
      setState(() => _error = 'Entrez votre numéro de téléphone.');
      return;
    }

    setState(() { _isLoading = true; _error = null; });

    try {
      final repo = ref.read(_reservationRepoProvider);
      final paiement = await repo.initierPaiement(
        reservationId:  widget.reservationId,
        phoneNumber:    phone,
        network:        _operateur,
      );
      setState(() {
        _paiementEnCours = paiement;
        _isLoading = false;
      });
      _startPolling(paiement);
    } catch (e) {
      setState(() {
        _error = _parseError(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _initierEspeces() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final repo = ref.read(_reservationRepoProvider);
      await repo.initierPaiementEspeces(widget.reservationId);
      setState(() {
        _success = true;
        _successMessage =
            'Paiement en espèces enregistré.\nRemettez ${_formatF(_montant)} FCFA au conducteur lors du trajet.';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = _parseError(e);
        _isLoading = false;
      });
    }
  }

  void _startPolling(PaiementModel paiement) {
    _pollingCount = 0;
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      _pollingCount++;
      if (_pollingCount >= _kMaxPolls) {
        _pollingTimer?.cancel();
        if (mounted && !_success) {
          setState(() => _error = 'Délai expiré. Veuillez vérifier votre paiement manuellement.');
        }
        return;
      }

      try {
        final repo = ref.read(_reservationRepoProvider);
        final token = _paiementEnCours?.token ?? _paiementEnCours?.transref ?? '';
        if (token.isEmpty) return;
        final updated = await repo.verifierPaiement(token);
        if (mounted && (updated.isPayee || updated.isConfirme)) {
          _pollingTimer?.cancel();
          setState(() {
            _success = true;
            _successMessage = 'Paiement ${_currentOp.label} confirmé avec succès !';
          });
        }
      } catch (e) {
        debugPrint('[PaiementPage] poll[$_pollingCount] error: $e');
      }
    });
  }

  void _annulerMobileMoney() {
    _pollingTimer?.cancel();
    setState(() {
      _paiementEnCours = null;
      _error = null;
    });
  }

  String _parseError(Object e) {
    final msg = e.toString();
    if (msg.contains('phone_number')) return 'Numéro de téléphone invalide.';
    if (msg.contains('timeout') || msg.contains('Timeout')) return 'Timeout. Vérifiez votre connexion.';
    if (msg.contains('503')) return 'Service PayPlus temporairement indisponible.';
    return msg.replaceFirst('Exception: ', '');
  }

  String _formatF(double v) =>
      v.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_success) return _buildSuccess();

    if (_loadingResa) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('Paiement', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            // ── Récapitulatif ───────────────────────────────────────────────
            _buildCard(children: [
              if (_depart != null && _destination != null) ...[
                Row(children: [
                  const Icon(Icons.route, size: 16, color: KColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$_depart → $_destination',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ]),
                const Divider(height: 20),
              ],
              _buildRow('Montant',         '${_formatF(_montant)} FCFA', bold: true),
              _buildRow('Commission (10%)', '${_formatF(_commission)} FCFA'),
              _buildRow('Conducteur reçoit', '${_formatF(_montantNet)} FCFA'),
              const Divider(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Total à payer', style: TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  '${_formatF(_montant)} FCFA',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: KColors.primary),
                ),
              ]),
            ]),

            const SizedBox(height: 16),

            // ── Erreur ──────────────────────────────────────────────────────
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: KColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: KColors.error.withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.error_outline, color: KColors.error, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!, style: const TextStyle(color: KColors.error, fontSize: 13))),
                ]),
              ),
              const SizedBox(height: 12),
            ],

            // ── En attente Mobile Money ──────────────────────────────────────
            if (_paiementEnCours != null) ...[
              _buildEnAttenteCard(),
            ] else ...[

              // ── Choix méthode ──────────────────────────────────────────────
              _buildCard(children: [
                const Text('Méthode de paiement',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: _MethodeButton(
                      label: '📱 Mobile Money',
                      isSelected: _methode == 'MOBILE',
                      onTap: () => setState(() { _methode = 'MOBILE'; _error = null; }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MethodeButton(
                      label: '💵 Espèces',
                      isSelected: _methode == 'ESPECE',
                      onTap: () => setState(() { _methode = 'ESPECE'; _error = null; }),
                    ),
                  ),
                ]),
              ]),

              const SizedBox(height: 12),

              // ── Formulaire selon la méthode ───────────────────────────────
              if (_methode == 'MOBILE') ...[
                _buildMobileMoney(),
              ] else ...[
                _buildEspeces(),
              ],
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── En attente Mobile Money ──────────────────────────────────────────────
  Widget _buildEnAttenteCard() {
    return _buildCard(children: [
      Center(
        child: AnimatedBuilder(
          animation: _pulseCtrl,
          builder: (_, __) => Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _currentOp.color.withValues(alpha: 0.1 + 0.1 * _pulseCtrl.value),
            ),
            child: Icon(_currentOp.icon, color: _currentOp.color, size: 36),
          ),
        ),
      ),
      const SizedBox(height: 16),
      Center(
        child: Column(children: [
          Text(
            'Confirmez le paiement',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            'Une demande ${_currentOp.label} a été envoyée sur\n${_phoneCtrl.text}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ]),
      ),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: [
          _buildRow('Opérateur', _currentOp.label),
          _buildRow('Montant',   '${_formatF(_montant)} FCFA'),
          if (_paiementEnCours?.transref != null)
            _buildRow('Référence', _paiementEnCours!.transref!),
        ]),
      ),
      const SizedBox(height: 16),
      const Text(
        'Vérification automatique toutes les 5 secondes…',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey, fontSize: 12),
      ),
      const SizedBox(height: 12),
      OutlinedButton(
        onPressed: _annulerMobileMoney,
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text('Annuler'),
      ),
    ]);
  }

  // ── Mobile Money ─────────────────────────────────────────────────────────
  Widget _buildMobileMoney() {
    return _buildCard(children: [
      const Text('Sélectionner l\'opérateur',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      const SizedBox(height: 12),

      // Cartes opérateurs
      Row(children: _operateurs.map((op) {
        final isSelected = _operateur == op.code;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() { _operateur = op.code; _error = null; }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(right: _operateurs.last == op ? 0 : 8),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              decoration: BoxDecoration(
                color: isSelected ? op.color.withValues(alpha: 0.08) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? op.color : Colors.grey.shade200,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(children: [
                Icon(op.icon, color: isSelected ? op.color : Colors.grey, size: 28),
                const SizedBox(height: 6),
                Text(
                  op.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                    color: isSelected ? op.color : Colors.grey,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  op.prefixes,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ]),
            ),
          ),
        );
      }).toList()),

      const SizedBox(height: 16),

      KTextField(
        controller: _phoneCtrl,
        label: 'Numéro ${_currentOp.label}',
        hint: 'ex : 90 00 00 00',
        keyboardType: TextInputType.phone,
        prefixIcon: Icon(Icons.phone, color: _currentOp.color),
      ),

      const SizedBox(height: 16),

      SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: _isLoading ? null : _initierMobileMoney,
          style: ElevatedButton.styleFrom(
            backgroundColor: _currentOp.color,
            foregroundColor: Colors.white,
            shape: const StadiumBorder(),
          ),
          child: _isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text('Payer ${_formatF(_montant)} FCFA via ${_currentOp.label}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ),
    ]);
  }

  // ── Espèces ───────────────────────────────────────────────────────────────
  Widget _buildEspeces() {
    return _buildCard(children: [
      Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _kEspeceColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.payments, color: _kEspeceColor, size: 24),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Paiement en espèces', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            Text('Remise directe au conducteur', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ]),
        ),
      ]),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Comment ça fonctionne :', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          SizedBox(height: 8),
          _BulletPoint('Vous réservez maintenant sans payer.'),
          _BulletPoint('Remettez le montant exact en espèces lors du trajet.'),
          _BulletPoint('Le conducteur confirmera la réception du paiement.'),
        ]),
      ),
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton.icon(
          onPressed: _isLoading ? null : _initierEspeces,
          style: ElevatedButton.styleFrom(
            backgroundColor: _kEspeceColor,
            foregroundColor: Colors.white,
            shape: const StadiumBorder(),
          ),
          icon: _isLoading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.handshake, size: 20),
          label: Text(_isLoading ? '' : 'Confirmer — payer en espèces',
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ),
    ]);
  }

  // ── Succès ───────────────────────────────────────────────────────────────
  Widget _buildSuccess() {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: KColors.success.withValues(alpha: 0.12),
                ),
                child: const Icon(Icons.check_circle, size: 60, color: KColors.success),
              ),
              const SizedBox(height: 24),
              const Text('Paiement enregistré !',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Text(
                _successMessage ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 15, height: 1.5),
              ),
              const SizedBox(height: 40),
              KButton(
                label: 'Voir mes réservations',
                onPressed: () => context.pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Widgets helpers ───────────────────────────────────────────────────────

  Widget _buildCard({required List<Widget> children}) => Container(
    margin: const EdgeInsets.only(bottom: 4),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2)),
      ],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
  );

  Widget _buildRow(String label, String value, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
      Text(value, style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w500, fontSize: 13)),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────

class _MethodeButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _MethodeButton({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? KColors.primary.withValues(alpha: 0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? KColors.primary : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
            color: isSelected ? KColors.primary : Colors.grey,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _BulletPoint extends StatelessWidget {
  final String text;
  const _BulletPoint(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('• ', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
      ]),
    );
  }
}
