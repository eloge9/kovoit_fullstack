import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../repositories/reservation_repository.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_card.dart';

class EmbarquementConducteurPage extends ConsumerStatefulWidget {
  const EmbarquementConducteurPage({super.key});

  @override
  ConsumerState<EmbarquementConducteurPage> createState() =>
      _EmbarquementConducteurPageState();
}

class _EmbarquementConducteurPageState
    extends ConsumerState<EmbarquementConducteurPage> {
  final _repo = ReservationRepository();
  final _codeCtrl = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _result;
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _valider() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) return;
    setState(() {
      _isLoading = true;
      _error = null;
      _result = null;
    });
    try {
      final result = await _repo.embarquer(code);
      setState(() {
        _result = result;
        _isLoading = false;
      });
    } catch (e) {
      String msg = e.toString();
      if (msg.contains('Exception:')) {
        msg = msg.split('Exception:').last.trim();
      }
      setState(() {
        _error = msg;
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
          'Embarquement passager',
          style: KTextStyles.bodySm.copyWith(
              fontWeight: FontWeight.w700, color: KColors.baseContent),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(KSpacing.pagePaddingH),
        child: Column(children: [
          const SizedBox(height: KSpacing.xl),

          // ── Succès ───────────────────────────────────────────────────
          if (_result != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(KSpacing.xl),
              decoration: BoxDecoration(
                color: KColors.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: KColors.success.withValues(alpha: 0.4)),
              ),
              child: Column(children: [
                const Icon(Icons.check_circle_rounded,
                    size: 56, color: KColors.successContent),
                const SizedBox(height: 12),
                Text(
                  'Passager embarqué !',
                  style: KTextStyles.h2
                      .copyWith(color: KColors.successContent),
                ),
                const SizedBox(height: 8),
                Text(
                  (_result!['passager'] as Map<String, dynamic>?)?[
                              'username']
                          ?.toString() ??
                      '',
                  style: KTextStyles.bodySm,
                ),
                const SizedBox(height: KSpacing.lg),
                KButton(
                  label: 'Embarquer un autre passager',
                  variant: KButtonVariant.outline,
                  onPressed: () => setState(() {
                    _result = null;
                    _codeCtrl.clear();
                  }),
                ),
              ]),
            ),
          ],

          // ── Saisie code ───────────────────────────────────────────────
          if (_result == null) ...[
            KCard(
              child: Padding(
                padding: const EdgeInsets.all(KSpacing.xl),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(
                            Icons.confirmation_number_outlined,
                            size: 16,
                            color: KColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Saisir le code passager',
                          style: KTextStyles.bodySm
                              .copyWith(fontWeight: FontWeight.w700),
                        ),
                      ]),
                      const SizedBox(height: KSpacing.lg),

                      // Erreur
                      if (_error != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: KSpacing.md),
                          decoration: BoxDecoration(
                            color: KColors.error.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color:
                                    KColors.error.withValues(alpha: 0.3)),
                          ),
                          child: Text(_error!,
                              style: KTextStyles.caption
                                  .copyWith(color: KColors.error)),
                        ),
                      ],

                      // Champ code
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Code KVT',
                              style: KTextStyles.bodySm.copyWith(
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _codeCtrl,
                            textCapitalization:
                                TextCapitalization.characters,
                            style: KTextStyles.bodyLg.copyWith(
                              color: KColors.baseContent,
                              letterSpacing: 2,
                            ),
                            decoration: InputDecoration(
                              hintText: 'KVT-1234',
                              prefixIcon: const Icon(Icons.tag_outlined,
                                  color: KColors.primary, size: 18),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: KColors.border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: KColors.border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: KColors.primary, width: 2),
                              ),
                              filled: true,
                              fillColor: KColors.base100,
                              contentPadding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 14),
                              hintStyle: KTextStyles.bodyLg
                                  .copyWith(color: KColors.baseContentLow),
                            ),
                            onChanged: (_) =>
                                setState(() => _error = null),
                          ),
                        ],
                      ),

                      const SizedBox(height: KSpacing.sm),
                      Text(
                        'Le passager vous montre un code (ex: KVT-1234) ou un QR code.',
                        style: KTextStyles.meta,
                      ),
                      const SizedBox(height: KSpacing.xl),
                      KButton(
                        label: 'Valider l\'embarquement',
                        icon: Icons.how_to_reg_rounded,
                        isLoading: _isLoading,
                        onPressed: _isLoading ? null : _valider,
                      ),
                    ]),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}
