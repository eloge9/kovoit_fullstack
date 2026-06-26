import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../reservations/models/reservation_model.dart';
import '../../reservations/repositories/reservation_repository.dart';
import '../../reservations/screens/qr_scanner_page.dart';
import '../../trajets/providers/trajet_provider.dart';
import '../../../core/network/api_interceptor.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/k_avatar.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_card.dart';

class ConducteurDepartPage extends ConsumerStatefulWidget {
  final int trajetId;
  final String depart;
  final String destination;
  final double? departLat;
  final double? departLng;
  final double? destinationLat;
  final double? destinationLng;

  const ConducteurDepartPage({
    super.key,
    required this.trajetId,
    required this.depart,
    required this.destination,
    this.departLat,
    this.departLng,
    this.destinationLat,
    this.destinationLng,
  });

  @override
  ConsumerState<ConducteurDepartPage> createState() => _ConducteurDepartPageState();
}

class _ConducteurDepartPageState extends ConsumerState<ConducteurDepartPage> {
  final _codeCtrl = TextEditingController();
  List<ReservationModel> _passagers = [];
  bool _loading = true;
  bool _validating = false;
  bool _starting = false;
  String? _codeError;
  String? _fetchError;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    setState(() { _loading = true; _fetchError = null; });
    try {
      final list = await ReservationRepository().passagersTrajet(widget.trajetId);
      if (mounted) {
        setState(() {
          _passagers = list.where((r) => r.isConfirmee).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _fetchError = e is ApiException ? e.message : 'Impossible de charger les passagers.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _scannerQr() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const QrScannerPage()),
    );
    if (ok == true && mounted) _charger();
  }

  Future<void> _validerCode() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _codeError = 'Entrez le code KVT affiché par le passager.');
      return;
    }
    setState(() { _validating = true; _codeError = null; });
    try {
      await ReservationRepository().embarquer(code);
      _codeCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Passager embarqué avec succès !'),
            backgroundColor: KColors.success,
          ),
        );
        await _charger();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _codeError = e is ApiException ? e.message : 'Code invalide ou déjà utilisé.';
        });
      }
    } finally {
      if (mounted) setState(() => _validating = false);
    }
  }

  Future<void> _demarrer() async {
    final nbEmbarques = _passagers.where((p) => p.isEmbarque).length;
    final total = _passagers.length;

    final confirmer = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Démarrer le trajet ?'),
        content: Text(
          total == 0
              ? 'Aucun passager confirmé pour ce trajet. Démarrer quand même ?'
              : nbEmbarques < total
                  ? '$nbEmbarques/$total passager${total > 1 ? 's' : ''} embarqué${nbEmbarques > 1 ? 's' : ''}.\nDémarrer sans attendre les autres ?'
                  : 'Tous les passagers sont à bord. Bonne route !',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: KColors.success),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Démarrer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmer != true || !mounted) return;

    setState(() => _starting = true);
    final ok = await ref.read(trajetsProvider.notifier).commencerTrajet(widget.trajetId);
    if (!mounted) return;
    setState(() => _starting = false);

    if (ok) {
      _ouvrirGps();
    } else {
      final error = (ref.read(trajetsProvider).error ?? '').toLowerCase();
      final dejaEnCours = error.contains('cours') ||
          error.contains('déjà') ||
          error.contains('deja') ||
          error.contains('statut') ||
          error.contains('started');
      if (dejaEnCours) {
        // Trajet déjà démarré — aller sur GPS sans refaire l'appel
        _ouvrirGps();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ref.read(trajetsProvider).error ?? 'Impossible de démarrer le trajet.',
            ),
            backgroundColor: KColors.error,
          ),
        );
      }
    }
  }

  void _ouvrirGps() {
    context.pushReplacement(
      '/conducteur/trajet/${widget.trajetId}/gps'
      '?depart=${Uri.encodeComponent(widget.depart)}'
      '&destination=${Uri.encodeComponent(widget.destination)}'
      '&departLat=${widget.departLat ?? ""}'
      '&departLng=${widget.departLng ?? ""}'
      '&destinationLat=${widget.destinationLat ?? ""}'
      '&destinationLng=${widget.destinationLng ?? ""}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final nbEmbarques = _passagers.where((p) => p.isEmbarque).length;
    final total = _passagers.length;
    final canStart = !_loading && !_starting;

    return Scaffold(
      backgroundColor: KColors.base200,
      appBar: AppBar(
        backgroundColor: KColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Départ imminent',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
            ),
            Text(
              '${widget.depart} → ${widget.destination}',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Actualiser',
            onPressed: _loading ? null : _charger,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: KColors.primary))
          : _fetchError != null
              ? _ErrorView(message: _fetchError!, onRetry: _charger)
              : _buildBody(nbEmbarques, total),
      bottomNavigationBar: _loading || _fetchError != null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: KButton(
                  label: 'Démarrer le trajet',
                  icon: Icons.play_circle_rounded,
                  variant: KButtonVariant.success,
                  isLoading: _starting,
                  onPressed: canStart ? _demarrer : null,
                ),
              ),
            ),
    );
  }

  Widget _buildBody(int nbEmbarques, int total) {
    return RefreshIndicator(
      color: KColors.primary,
      onRefresh: _charger,
      child: ListView(
        padding: const EdgeInsets.all(KSpacing.pagePaddingH),
        children: [
          const SizedBox(height: KSpacing.lg),

          // ── Barre de progression embarquement ──────────────────────
          _ProgressCard(nbEmbarques: nbEmbarques, total: total),
          const SizedBox(height: KSpacing.xl),

          // ── Liste des passagers ─────────────────────────────────────
          if (_passagers.isEmpty)
            _EmptyPassagers()
          else ...[
            Text('Passagers confirmés', style: KTextStyles.label),
            const SizedBox(height: KSpacing.md),
            KCard(
              child: Column(
                children: _passagers.asMap().entries.map((entry) {
                  final i = entry.key;
                  final p = entry.value;
                  return Column(
                    children: [
                      _PassagerRow(
                        passager: p,
                        onMessage: p.conversationId != null
                            ? () => context.push(
                                '/conducteur/messages/${p.conversationId}'
                                '?name=${Uri.encodeComponent(p.passagerNom)}',
                              )
                            : null,
                      ),
                      if (i < _passagers.length - 1)
                        const Divider(height: 1, color: KColors.border),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],

          const SizedBox(height: KSpacing.xl),

          // ── Validation par code KVT ou QR ──────────────────────────
          _CodeSection(
            codeCtrl: _codeCtrl,
            codeError: _codeError,
            validating: _validating,
            onValider: _validerCode,
            onScannerQr: _scannerQr,
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

// ── Carte de progression ──────────────────────────────────────────────────────

class _ProgressCard extends StatelessWidget {
  final int nbEmbarques;
  final int total;
  const _ProgressCard({required this.nbEmbarques, required this.total});

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 1.0 : nbEmbarques / total;
    final allDone = total > 0 && nbEmbarques >= total;

    return Container(
      padding: const EdgeInsets.all(KSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: allDone
              ? [KColors.success, const Color(0xFF1B7C4A)]
              : [KColors.primary, KColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                allDone ? 'Prêt à partir !' : 'Embarquement en cours',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  total == 0 ? '—' : '$nbEmbarques / $total',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            total == 0
                ? 'Aucun passager confirmé'
                : allDone
                    ? 'Tous les passagers sont à bord'
                    : '${total - nbEmbarques} passager${(total - nbEmbarques) > 1 ? 's' : ''} en attente',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ── Ligne passager ────────────────────────────────────────────────────────────

class _PassagerRow extends StatelessWidget {
  final ReservationModel passager;
  final VoidCallback? onMessage;
  const _PassagerRow({required this.passager, this.onMessage});

  @override
  Widget build(BuildContext context) {
    final embarque = passager.isEmbarque;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: KSpacing.xl, vertical: KSpacing.md),
      child: Row(
        children: [
          // Avatar avec indicateur coloré
          Stack(
            children: [
              KAvatar(
                name: passager.passagerNom,
                photoUrl: passager.passagerPhoto,
                size: 42,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: embarque ? KColors.success : KColors.warning,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Icon(
                    embarque ? Icons.check : Icons.schedule,
                    size: 7,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: KSpacing.md),

          // Nom + places
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  passager.passagerNom.isEmpty ? 'Passager' : passager.passagerNom,
                  style: KTextStyles.bodySm.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    Text(
                      '${passager.placesReservees} place${passager.placesReservees > 1 ? 's' : ''}',
                      style: KTextStyles.meta,
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: embarque
                            ? KColors.success.withValues(alpha: 0.1)
                            : KColors.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        embarque ? 'Embarqué' : 'En attente',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: embarque ? KColors.success : KColors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Bouton message
          if (onMessage != null)
            IconButton(
              icon: const Icon(Icons.message_rounded, size: 20, color: KColors.primary),
              tooltip: 'Écrire au passager',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              onPressed: onMessage,
            )
          else
            const SizedBox(width: 36),
        ],
      ),
    );
  }
}

// ── Section code embarquement ─────────────────────────────────────────────────

class _CodeSection extends StatelessWidget {
  final TextEditingController codeCtrl;
  final String? codeError;
  final bool validating;
  final VoidCallback onValider;
  final VoidCallback onScannerQr;

  const _CodeSection({
    required this.codeCtrl,
    required this.codeError,
    required this.validating,
    required this.onValider,
    required this.onScannerQr,
  });

  @override
  Widget build(BuildContext context) {
    return KCard(
      child: Padding(
        padding: const EdgeInsets.all(KSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.confirmation_number_outlined, size: 18, color: KColors.primary),
                const SizedBox(width: 8),
                Text(
                  'Valider l\'embarquement',
                  style: KTextStyles.bodySm.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Scannez le QR ou saisissez le code KVT affiché par le passager.',
              style: KTextStyles.caption.copyWith(color: KColors.baseContentMid),
            ),
            const SizedBox(height: KSpacing.md),

            // ── Bouton Scanner QR (prioritaire) ────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: KColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text('Scanner le QR Code', style: TextStyle(fontWeight: FontWeight.w700)),
                onPressed: onScannerQr,
              ),
            ),
            const SizedBox(height: KSpacing.md),

            // ── Séparateur ──────────────────────────────────────────────
            Row(children: [
              const Expanded(child: Divider(color: KColors.border)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('ou saisir le code', style: KTextStyles.meta),
              ),
              const Expanded(child: Divider(color: KColors.border)),
            ]),
            const SizedBox(height: KSpacing.md),

            // ── Saisie manuelle ─────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: codeCtrl,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(letterSpacing: 3, fontSize: 16, fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      hintText: 'KVT-XXXX',
                      errorText: codeError,
                      isDense: true,
                      prefixIcon: const Icon(Icons.tag_rounded, color: KColors.primary, size: 20),
                      filled: true,
                      fillColor: KColors.base200,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: KColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: KColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: KColors.primary, width: 2),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: KColors.error, width: 2),
                      ),
                    ),
                    onSubmitted: (_) => onValider(),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: KColors.success,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                    ),
                    onPressed: validating ? null : onValider,
                    child: validating
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_rounded, color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── État vide ─────────────────────────────────────────────────────────────────

class _EmptyPassagers extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(KSpacing.xl),
      decoration: BoxDecoration(
        color: KColors.base100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KColors.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.people_outline, size: 40, color: KColors.baseContentMid),
          const SizedBox(height: 8),
          Text(
            'Aucun passager confirmé',
            style: KTextStyles.bodySm.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Vous pouvez démarrer le trajet dès que vous êtes prêt.',
            style: KTextStyles.caption.copyWith(color: KColors.baseContentMid),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Erreur de chargement ──────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: KColors.baseContentMid),
            const SizedBox(height: 12),
            Text(message, style: KTextStyles.caption, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            KButton(
              label: 'Réessayer',
              variant: KButtonVariant.outline,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
