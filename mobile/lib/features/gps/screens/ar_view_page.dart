import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/inline_ar_view.dart';

/// Page AR full-screen (route /ar). Délègue tout à InlineArView.
class ArViewPage extends StatelessWidget {
  final double targetLat;
  final double targetLng;
  final String targetName;
  final String targetType;

  const ArViewPage({
    super.key,
    required this.targetLat,
    required this.targetLng,
    required this.targetName,
    required this.targetType,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    body: InlineArView(
      targetLat:  targetLat,
      targetLng:  targetLng,
      targetName: targetName,
      targetType: targetType,
      onBack:     () => context.pop(),
    ),
  );
}
