import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constants/api_constants.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';

/// Avatar KoVoit — affiche la photo de profil ou l'initiale.
/// Construit automatiquement l'URL absolue si le chemin est relatif.
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
    final url = ApiConstants.buildMediaUrl(photoUrl);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor ?? KColors.primary.withValues(alpha: 0.12),
      ),
      clipBehavior: Clip.antiAlias,
      child: url.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              fadeInDuration: const Duration(milliseconds: 200),
              errorWidget: (_, _, _) => _initiale(initiale),
              placeholder: (_, _) => _shimmer(),
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

  Widget _shimmer() => Container(color: KColors.base300);
}
