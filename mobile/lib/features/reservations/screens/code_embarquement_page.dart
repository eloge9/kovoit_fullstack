import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../repositories/reservation_repository.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_card.dart';

class CodeEmbarquementPage extends ConsumerStatefulWidget {
  final int reservationId;
  const CodeEmbarquementPage({super.key, required this.reservationId});

  @override
  ConsumerState<CodeEmbarquementPage> createState() => _CodeEmbarquementPageState();
}

class _CodeEmbarquementPageState extends ConsumerState<CodeEmbarquementPage> {
  final _repo = ReservationRepository();
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _repo.getCodeEmbarquement(widget.reservationId);
      setState(() {
        _data = data;
        _isLoading = false;
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
    return Scaffold(
      backgroundColor: KColors.base200,
      appBar: AppBar(
        backgroundColor: KColors.base100,
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: KColors.border)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: KColors.baseContent),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Code d\'embarquement',
          style: KTextStyles.bodySm.copyWith(
              fontWeight: FontWeight.w700, color: KColors.baseContent),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: KColors.primary))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(KSpacing.xl),
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline,
                              size: 48, color: KColors.error),
                          const SizedBox(height: 12),
                          Text(_error!,
                              textAlign: TextAlign.center,
                              style: KTextStyles.caption),
                          const SizedBox(height: 16),
                          KButton(label: 'Réessayer', onPressed: _load),
                        ]),
                  ),
                )
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final codeRaw = _data!['code_embarquement'];
    final code = codeRaw is String ? codeRaw : codeRaw?.toString() ?? '';
    final trajetRaw = _data!['trajet'];
    final trajet = trajetRaw is Map<String, dynamic> ? trajetRaw : null;
    final statutRaw = _data!['statut_embarquement'];
    final statut = statutRaw is String ? statutRaw : 'non_embarque';
    final prix = _data!['prix_passager'];

    final isEmbarque = statut == 'embarque';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(KSpacing.pagePaddingH),
      child: Column(children: [
        const SizedBox(height: KSpacing.xl),

        // Badge statut
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: (isEmbarque ? KColors.success : KColors.primary)
                .withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(
              isEmbarque
                  ? Icons.check_circle_outline
                  : Icons.confirmation_number_outlined,
              size: 16,
              color: isEmbarque ? KColors.successContent : KColors.primary,
            ),
            const SizedBox(width: 6),
            Text(
              isEmbarque
                  ? 'Embarqué'
                  : 'En attente d\'embarquement',
              style: KTextStyles.caption.copyWith(
                color: isEmbarque
                    ? KColors.successContent
                    : KColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ]),
        ),
        const SizedBox(height: KSpacing.xl),

        // QR Code + code texte
        KCard(
          child: Padding(
            padding: const EdgeInsets.all(KSpacing.xl),
            child: Column(children: [
              Text('Montrez ce code au conducteur',
                  style: KTextStyles.caption),
              const SizedBox(height: KSpacing.xl),

              // QR code
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 16)
                  ],
                ),
                child: QrImageView(
                    data: code, version: QrVersions.auto, size: 200),
              ),
              const SizedBox(height: KSpacing.xl),

              // Code textuel — tap pour copier
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: code));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Code copié !'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: KColors.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: KColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(
                      code,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 6,
                        color: KColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.copy_outlined,
                        size: 18, color: KColors.baseContentMid),
                  ]),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: KSpacing.xl),

        // Infos trajet
        if (trajet != null)
          KCard(
            child: Padding(
              padding: const EdgeInsets.all(KSpacing.xl),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.trip_origin,
                          color: KColors.primary, size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                          child: Text(
                              trajet['depart']?.toString() ?? '',
                              style: KTextStyles.bodySm)),
                    ]),
                    const SizedBox(height: 6),
                    Row(children: [
                      const Icon(Icons.location_on,
                          color: KColors.error, size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                          child: Text(
                              trajet['destination']?.toString() ?? '',
                              style: KTextStyles.bodySm)),
                    ]),
                    if (prix != null) ...[
                      const SizedBox(height: KSpacing.md),
                      const Divider(color: KColors.border),
                      const SizedBox(height: KSpacing.md),
                      Row(children: [
                        Text('Prix à payer :',
                            style: KTextStyles.caption),
                        const Spacer(),
                        Text(
                          '$prix FCFA',
                          style: KTextStyles.bodySm.copyWith(
                            fontWeight: FontWeight.w700,
                            color: KColors.primary,
                          ),
                        ),
                      ]),
                    ],
                  ]),
            ),
          ),

        const SizedBox(height: KSpacing.xl),
      ]),
    );
  }
}
