import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../repositories/reservation_repository.dart';
import '../../../core/network/api_interceptor.dart';
import '../../../core/theme/colors.dart';

/// Page de scan QR conducteur.
/// Retourne `true` si un passager a été embarqué avec succès.
class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _processing = false;
  String? _lastError;
  bool _success = false;
  String? _passagerNom;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saisirManuellement() async {
    // Pause le scanner pendant la saisie
    await _controller.stop();
    if (!mounted) return;
    final code = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _CodeManuelDialog(),
    );
    if (!mounted) return;
    if (code == null) {
      // Annulé → relancer le scanner
      await _controller.start();
      return;
    }
    // Valider le code saisi
    setState(() { _processing = true; _lastError = null; });
    try {
      final result = await ReservationRepository().embarquer(code);
      final nom = result['passager']?.toString() ?? 'Passager';
      if (!mounted) return;
      setState(() { _success = true; _passagerNom = nom; _processing = false; });
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.of(context).pop(true);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _lastError = e is ApiException ? e.message : 'Code invalide ou déjà utilisé.';
        _processing = false;
      });
      // Relancer le scanner
      await _controller.start();
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _lastError = null);
      });
    }
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing || _success) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;

    final code = raw.trim().toUpperCase();
    // Accepter uniquement les codes KVT-XXXX
    if (!RegExp(r'^KVT-\d{4}$').hasMatch(code)) {
      if (mounted) setState(() => _lastError = 'QR non reconnu. Utilisez le code KVT du passager.');
      return;
    }

    setState(() { _processing = true; _lastError = null; });
    try {
      final result = await ReservationRepository().embarquer(code);
      final nom = result['passager']?.toString() ?? 'Passager';
      if (!mounted) return;
      setState(() {
        _success = true;
        _passagerNom = nom;
        _processing = false;
      });
      // Fermer après 2 secondes
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.of(context).pop(true);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _lastError = e is ApiException ? e.message : 'Code invalide ou déjà utilisé.';
        _processing = false;
      });
      // Reprendre le scan après 2 secondes
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _lastError = null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        title: const Text(
          'Scanner le QR du passager',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: _controller,
              builder: (context2, state, child2) => Icon(
                state.torchState == TorchState.on ? Icons.flash_on : Icons.flash_off,
                color: state.torchState == TorchState.on ? KColors.warning : Colors.white54,
              ),
            ),
            onPressed: _controller.toggleTorch,
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── Caméra ────────────────────────────────────────────────
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),

          // ── Overlay de visée ───────────────────────────────────────
          _ScanOverlay(processing: _processing, success: _success),

          // ── Message succès ─────────────────────────────────────────
          if (_success)
            Center(
              child: Container(
                margin: const EdgeInsets.all(32),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: KColors.success,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.white, size: 64),
                    const SizedBox(height: 12),
                    Text(
                      'Embarqué !',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (_passagerNom != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _passagerNom!,
                        style: const TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                    ],
                  ],
                ),
              ),
            ),

          // ── Message erreur ─────────────────────────────────────────
          if (_lastError != null && !_success)
            Positioned(
              bottom: 120,
              left: 24,
              right: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: KColors.error,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _lastError!,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Indicateur chargement ──────────────────────────────────
          if (_processing)
            Container(
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),

          // ── Instructions + saisie manuelle ────────────────────────
          if (!_success)
            Positioned(
              bottom: 24,
              left: 24,
              right: 24,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Pointez la caméra sur le QR code\naffiché par le passager',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: _processing ? null : _saisirManuellement,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: Colors.white30),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.keyboard_rounded, color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Saisir le code manuellement',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Dialog saisie manuelle du code ───────────────────────────────────────────

class _CodeManuelDialog extends StatefulWidget {
  @override
  State<_CodeManuelDialog> createState() => _CodeManuelDialogState();
}

class _CodeManuelDialogState extends State<_CodeManuelDialog> {
  final _ctrl = TextEditingController();
  String? _err;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _valider() {
    final code = _ctrl.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _err = 'Entrez le code du passager.');
      return;
    }
    if (!RegExp(r'^KVT-\d{4}$').hasMatch(code)) {
      setState(() => _err = 'Format invalide. Exemple : KVT-1234');
      return;
    }
    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.confirmation_number_outlined, color: KColors.primary, size: 20),
          SizedBox(width: 8),
          Text('Code d\'embarquement', style: TextStyle(fontSize: 16)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Demandez au passager son code KVT et saisissez-le ci-dessous.',
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9\-]')),
              LengthLimitingTextInputFormatter(8),
            ],
            style: const TextStyle(
              letterSpacing: 4,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: KColors.primary,
            ),
            decoration: InputDecoration(
              hintText: 'KVT-1234',
              hintStyle: const TextStyle(letterSpacing: 2, color: Colors.black26),
              errorText: _err,
              filled: true,
              fillColor: const Color(0xFFF3F7FF),
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
            ),
            onSubmitted: (_) => _valider(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: KColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _valider,
          child: const Text('Valider', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

// ── Overlay de visée ──────────────────────────────────────────────────────────

class _ScanOverlay extends StatelessWidget {
  final bool processing;
  final bool success;
  const _ScanOverlay({required this.processing, required this.success});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final boxSize = size.width * 0.70;
    final top = (size.height - boxSize) / 2.5;

    return Stack(
      children: [
        // Fond semi-transparent
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withValues(alpha: 0.55),
            BlendMode.srcOut,
          ),
          child: Stack(
            children: [
              Container(decoration: const BoxDecoration(
                color: Colors.black,
                backgroundBlendMode: BlendMode.dstOut,
              )),
              Positioned(
                top: top,
                left: (size.width - boxSize) / 2,
                child: Container(
                  width: boxSize,
                  height: boxSize,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ),
        ),

        // Coins de visée
        Positioned(
          top: top,
          left: (size.width - boxSize) / 2,
          child: _CornerFrame(
            size: boxSize,
            color: success ? KColors.success : KColors.primary,
          ),
        ),
      ],
    );
  }
}

class _CornerFrame extends StatelessWidget {
  final double size;
  final Color color;
  const _CornerFrame({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    const w = 4.0;
    const len = 28.0;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(children: [
        // Coins
        for (final corner in [
          Alignment.topLeft, Alignment.topRight,
          Alignment.bottomLeft, Alignment.bottomRight,
        ])
          Align(
            alignment: corner,
            child: CustomPaint(
              size: const Size(len, len),
              painter: _CornerPainter(color: color, strokeWidth: w, alignment: corner),
            ),
          ),
      ]),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final Alignment alignment;
  const _CornerPainter({required this.color, required this.strokeWidth, required this.alignment});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final isLeft = alignment == Alignment.topLeft || alignment == Alignment.bottomLeft;
    final isTop = alignment == Alignment.topLeft || alignment == Alignment.topRight;
    final x = isLeft ? 0.0 : size.width;
    final y = isTop ? 0.0 : size.height;
    final dx = isLeft ? size.width : -size.width;
    final dy = isTop ? size.height : -size.height;

    final path = Path()
      ..moveTo(x + dx, y)
      ..lineTo(x, y)
      ..lineTo(x, y + dy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CornerPainter old) =>
      old.color != color || old.strokeWidth != strokeWidth;
}
