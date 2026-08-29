import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/wallet_model.dart';
import '../repositories/wallet_repository.dart';
import '../../reservations/models/paiement_model.dart' show OperateurMobileMoney, OperateurMobileMoneyExt;
import '../../../core/theme/colors.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_text_field.dart';

final _walletRepoProvider = Provider<WalletRepository>((ref) => WalletRepository());

String _formatF(num v) =>
    v.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');

// ════════════════════════════════════════════════════════════════════════════
class PortefeuillePage extends ConsumerStatefulWidget {
  const PortefeuillePage({super.key});

  @override
  ConsumerState<PortefeuillePage> createState() => _PortefeuillePageState();
}

class _PortefeuillePageState extends ConsumerState<PortefeuillePage> {
  MonWalletModel? _wallet;
  List<WalletTransactionModel> _transactions = [];
  List<RetraitModel> _retraits = [];
  bool _loading = true;
  String? _error;
  int _tab = 0; // 0 = transactions, 1 = retraits

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final repo = ref.read(_walletRepoProvider);
      final results = await Future.wait([
        repo.monWallet(),
        repo.mesTransactions(),
        repo.mesRetraits(),
      ]);
      if (!mounted) return;
      setState(() {
        _wallet = results[0] as MonWalletModel;
        _transactions = results[1] as List<WalletTransactionModel>;
        _retraits = results[2] as List<RetraitModel>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'Impossible de charger votre portefeuille.'; _loading = false; });
    }
  }

  void _openDeposit() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _DepositSheet(onDone: _load),
    );
  }

  void _openWithdraw() {
    if (_wallet == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _WithdrawSheet(soldeDisponible: _wallet!.soldeDisponible, onDone: _load),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('Mon portefeuille', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: KColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(children: [
                        const Icon(Icons.error_outline, color: KColors.error, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_error!, style: const TextStyle(color: KColors.error, fontSize: 13))),
                        TextButton(onPressed: _load, child: const Text('Réessayer')),
                      ]),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (_wallet != null && _wallet!.soldeDu > 0) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: KColors.warningLight,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: KColors.warning),
                      ),
                      child: Row(children: [
                        const Text('⚠️', style: TextStyle(fontSize: 20)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(
                              'Vous devez ${_formatF(_wallet!.soldeDu)} FCFA de commission KoVoit',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              "Sur vos courses payées en espèces. Déposez pour régler.",
                              style: TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ]),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 16),
                  ],

                  Row(children: [
                    Expanded(
                      child: _SoldeCard(
                        label: 'Disponible',
                        value: _wallet != null ? '${_formatF(_wallet!.soldeDisponible)} F' : '—',
                        color: KColors.success,
                        icon: Icons.account_balance_wallet,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SoldeCard(
                        label: 'Commission due',
                        value: _wallet != null ? '${_formatF(_wallet!.soldeDu)} F' : '—',
                        color: (_wallet?.soldeDu ?? 0) > 0 ? KColors.warning : KColors.baseContentLow,
                        icon: Icons.receipt_long,
                      ),
                    ),
                  ]),

                  const SizedBox(height: 16),

                  Row(children: [
                    Expanded(
                      child: KButton(
                        label: 'Déposer',
                        icon: Icons.add_circle_outline,
                        onPressed: _openDeposit,
                        fullWidth: false,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: KButton(
                        label: 'Retirer',
                        icon: Icons.arrow_upward,
                        variant: KButtonVariant.outline,
                        onPressed: (_wallet?.peutRetirer ?? false) ? _openWithdraw : null,
                        fullWidth: false,
                      ),
                    ),
                  ]),

                  const SizedBox(height: 20),

                  // Onglets
                  Row(children: [
                    _TabButton(label: 'Transactions', selected: _tab == 0, onTap: () => setState(() => _tab = 0)),
                    const SizedBox(width: 8),
                    _TabButton(label: 'Retraits', selected: _tab == 1, onTap: () => setState(() => _tab = 1)),
                  ]),

                  const SizedBox(height: 12),

                  if (_tab == 0) ..._buildTransactions() else ..._buildRetraits(),
                ],
              ),
            ),
    );
  }

  List<Widget> _buildTransactions() {
    if (_transactions.isEmpty) {
      return [const _EmptyState(emoji: '📜', message: 'Aucune transaction pour le moment.')];
    }
    return _transactions.map((t) => Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.typeLabel, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            if (t.description.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(t.description, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
            if (t.createdAt != null) ...[
              const SizedBox(height: 2),
              Text(_fmtDate(t.createdAt!), style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ]),
        ),
        Text(
          '${t.isCredit ? '+' : '−'}${_formatF(t.montant)} F',
          style: TextStyle(
            fontWeight: FontWeight.w800, fontSize: 14,
            color: t.isCredit ? KColors.success : KColors.error,
          ),
        ),
      ]),
    )).toList();
  }

  List<Widget> _buildRetraits() {
    if (_retraits.isEmpty) {
      return [const _EmptyState(emoji: '🏦', message: 'Aucun retrait demandé.')];
    }
    return _retraits.map((r) => Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${r.moyenLabel} — ${r.numeroDestination}',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            if (r.statut == 'ECHOUE' && r.motifEchec.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(r.motifEchec, style: const TextStyle(fontSize: 11, color: KColors.error)),
            ],
            if (r.dateDemande != null) ...[
              const SizedBox(height: 2),
              Text('Demandé le ${_fmtDate(r.dateDemande!)}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${_formatF(r.montant)} F', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: KColors.statusBgColor(r.statut),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(r.statutLabel,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: KColors.statusColor(r.statut))),
          ),
        ]),
      ]),
    )).toList();
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

// ── Widgets partagés ──────────────────────────────────────────────────────────

class _SoldeCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  const _SoldeCard({required this.label, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey))),
        ]),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
      ]),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TabButton({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? KColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? KColors.primary : KColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : KColors.baseContent,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String emoji;
  final String message;
  const _EmptyState({required this.emoji, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(children: [
        Text(emoji, style: const TextStyle(fontSize: 40)),
        const SizedBox(height: 8),
        Text(message, style: const TextStyle(color: Colors.grey, fontSize: 13)),
      ]),
    );
  }
}

// ── Bottom sheet : Dépôt ──────────────────────────────────────────────────────

class _DepositSheet extends ConsumerStatefulWidget {
  final VoidCallback onDone;
  const _DepositSheet({required this.onDone});

  @override
  ConsumerState<_DepositSheet> createState() => _DepositSheetState();
}

class _DepositSheetState extends ConsumerState<_DepositSheet> {
  final _montantCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  OperateurMobileMoney _network = OperateurMobileMoney.flooz;

  bool _loading = false;
  String? _error;

  String? _token;
  String? _transref;
  double _montant = 0;
  Timer? _pollingTimer;
  int _pollingCount = 0;
  static const _kMaxPolls = 24;
  bool _checking = false;
  bool _confirmed = false;

  @override
  void dispose() {
    _montantCtrl.dispose();
    _phoneCtrl.dispose();
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _initier() async {
    final montant = double.tryParse(_montantCtrl.text.trim());
    if (montant == null || montant <= 0) {
      setState(() => _error = 'Entrez un montant valide.');
      return;
    }
    final phone = _phoneCtrl.text.trim().replaceAll(RegExp(r'\s+'), '');
    if (phone.isEmpty) {
      setState(() => _error = 'Entrez votre numéro de téléphone.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final repo = ref.read(_walletRepoProvider);
      final (token, transref, paymentUrl, montantConfirme) = await repo.deposerInitier(
        montant: montant, phoneNumber: phone, network: _network.code,
      );
      setState(() {
        _token = token;
        _transref = transref;
        _montant = montantConfirme;
        _loading = false;
      });
      _startPolling();
      try {
        await launchUrl(Uri.parse(paymentUrl), mode: LaunchMode.inAppBrowserView);
      } catch (e) {
        debugPrint('[DepositSheet] échec ouverture page de paiement: $e');
      }
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _startPolling() {
    _pollingCount = 0;
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) => _verifier());
  }

  Future<void> _verifier() async {
    if (_token == null || _transref == null || _confirmed) return;
    _pollingCount++;
    if (_pollingCount >= _kMaxPolls) {
      _pollingTimer?.cancel();
      return;
    }
    setState(() => _checking = true);
    try {
      final repo = ref.read(_walletRepoProvider);
      final ok = await repo.deposerVerifier(token: _token!, transref: _transref!);
      if (ok && mounted) {
        _pollingTimer?.cancel();
        setState(() { _confirmed = true; _checking = false; });
      } else if (mounted) {
        setState(() => _checking = false);
      }
    } catch (_) {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_confirmed) ...[
            const Icon(Icons.check_circle, color: KColors.success, size: 56),
            const SizedBox(height: 12),
            const Text('Dépôt crédité !', textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 6),
            const Text('Votre portefeuille a été mis à jour.', textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            KButton(label: 'Fermer', onPressed: () { Navigator.pop(context); widget.onDone(); }),
          ] else if (_token != null) ...[
            const Center(child: CircularProgressIndicator(color: KColors.warning)),
            const SizedBox(height: 12),
            const Text('En attente de confirmation', textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 6),
            Text('Confirmez le dépôt de ${_formatF(_montant)} FCFA sur votre téléphone.',
                textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 16),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: KColors.error, fontSize: 12), textAlign: TextAlign.center),
              const SizedBox(height: 8),
            ],
            KButton(label: 'Vérifier maintenant', isLoading: _checking, onPressed: _verifier),
            const SizedBox(height: 8),
            KButton(label: 'Fermer', variant: KButtonVariant.ghost, onPressed: () => Navigator.pop(context)),
            const SizedBox(height: 8),
            const Text('Vérification automatique toutes les 5 secondes…',
                textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 11)),
          ] else ...[
            const Text('Déposer sur mon portefeuille', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            const SizedBox(height: 16),
            KTextField(
              controller: _montantCtrl, label: 'Montant (FCFA)', hint: 'ex : 5000',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            Row(children: OperateurMobileMoney.values.map((op) {
              final selected = _network == op;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _network = op),
                  child: Container(
                    margin: EdgeInsets.only(right: op == OperateurMobileMoney.values.last ? 0 : 8),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: selected ? KColors.primary.withValues(alpha: 0.08) : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: selected ? KColors.primary : Colors.grey.shade200, width: selected ? 2 : 1),
                    ),
                    alignment: Alignment.center,
                    child: Text(op.label, style: TextStyle(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                      color: selected ? KColors.primary : Colors.grey,
                      fontSize: 13,
                    )),
                  ),
                ),
              );
            }).toList()),
            const SizedBox(height: 12),
            KTextField(
              controller: _phoneCtrl, label: 'Numéro ${_network.label}', hint: 'ex : 90 00 00 00',
              keyboardType: TextInputType.phone,
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: KColors.error, fontSize: 12)),
            ],
            const SizedBox(height: 16),
            KButton(label: 'Déposer', isLoading: _loading, onPressed: _initier),
          ],
        ],
      ),
    );
  }
}

// ── Bottom sheet : Retrait ────────────────────────────────────────────────────

class _WithdrawSheet extends ConsumerStatefulWidget {
  final double soldeDisponible;
  final VoidCallback onDone;
  const _WithdrawSheet({required this.soldeDisponible, required this.onDone});

  @override
  ConsumerState<_WithdrawSheet> createState() => _WithdrawSheetState();
}

class _WithdrawSheetState extends ConsumerState<_WithdrawSheet> {
  final _montantCtrl = TextEditingController();
  final _numeroCtrl = TextEditingController();
  OperateurMobileMoney _moyen = OperateurMobileMoney.flooz;
  bool _loading = false;
  bool _done = false;
  String? _error;

  @override
  void dispose() {
    _montantCtrl.dispose();
    _numeroCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final montant = double.tryParse(_montantCtrl.text.trim());
    if (montant == null || montant <= 0) {
      setState(() => _error = 'Entrez un montant valide.');
      return;
    }
    if (montant > widget.soldeDisponible) {
      setState(() => _error = 'Montant supérieur à votre solde disponible.');
      return;
    }
    final numero = _numeroCtrl.text.trim().replaceAll(RegExp(r'\s+'), '');
    if (numero.isEmpty) {
      setState(() => _error = 'Entrez le numéro de destination.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final repo = ref.read(_walletRepoProvider);
      await repo.demanderRetrait(montant: montant, moyen: _moyen.code, numeroDestination: numero);
      setState(() { _done = true; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_done) ...[
            const Icon(Icons.check_circle, color: KColors.success, size: 56),
            const SizedBox(height: 12),
            const Text('Demande enregistrée', textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 6),
            const Text('Votre retrait sera traité manuellement sous 24 à 48h.', textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            KButton(label: 'Fermer', onPressed: () { Navigator.pop(context); widget.onDone(); }),
          ] else ...[
            const Text('Retirer mon solde', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            const SizedBox(height: 4),
            Text('Disponible : ${_formatF(widget.soldeDisponible)} FCFA',
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 16),
            KTextField(
              controller: _montantCtrl, label: 'Montant (FCFA)', hint: 'ex : 5000',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            Row(children: OperateurMobileMoney.values.map((op) {
              final selected = _moyen == op;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _moyen = op),
                  child: Container(
                    margin: EdgeInsets.only(right: op == OperateurMobileMoney.values.last ? 0 : 8),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: selected ? KColors.primary.withValues(alpha: 0.08) : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: selected ? KColors.primary : Colors.grey.shade200, width: selected ? 2 : 1),
                    ),
                    alignment: Alignment.center,
                    child: Text(op.label, style: TextStyle(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                      color: selected ? KColors.primary : Colors.grey,
                      fontSize: 13,
                    )),
                  ),
                ),
              );
            }).toList()),
            const SizedBox(height: 12),
            KTextField(
              controller: _numeroCtrl, label: 'Numéro ${_moyen.label}', hint: 'ex : 90 00 00 00',
              keyboardType: TextInputType.phone,
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: KColors.error, fontSize: 12)),
            ],
            const SizedBox(height: 16),
            KButton(label: 'Demander le retrait', isLoading: _loading, onPressed: _submit),
          ],
        ],
      ),
    );
  }
}
