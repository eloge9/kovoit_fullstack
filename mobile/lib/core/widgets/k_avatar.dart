import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';

/// Avatar KoVoit — reproduit l'avatar du Web (initiale sur fond primary/10)
class KAvatar extends StatelessWidget {
  final String? photoUrl;
  final String? name;
  final double size;
  final Color? backgroundColor;

  const KAvatar({
    super.key,
    this.photoUrl,
    this.name,
    this.size = 36,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final initiale = name?.isNotEmpty == true ? name![0].toUpperCase() : '?';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor ?? KColors.primary.withValues(alpha: 0.12),
      ),
      clipBehavior: Clip.antiAlias,
      child: photoUrl != null && photoUrl!.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: photoUrl!,
              fit: BoxFit.cover,
              errorWidget: (_, _, _) => _initiale(initiale),
              placeholder: (_, _) => _initiale(initiale),
            )
          : _initiale(initiale),
    );
  }

  Widget _initiale(String c) => Center(
    child: Text(
      c,
      style: KTextStyles.button.copyWith(
        color: KColors.primary,
        fontSize: size * 0.38,
      ),
    ),
  );
}
