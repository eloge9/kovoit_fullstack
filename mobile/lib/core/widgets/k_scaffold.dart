import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';

/// Scaffold KoVoit — fond base-200, appbar white + border
class KScaffold extends StatelessWidget {
  final String? title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final bool showBack;

  const KScaffold({
    super.key,
    this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.showBack = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColors.base200,
      appBar: title != null
          ? AppBar(
              title: Row(
                children: [
                  // Logo KoVoit petite taille
                  Image.asset('assets/logos/logo1.png', width: 22, height: 22),
                  const SizedBox(width: 8),
                  Text(
                    title!,
                    style: KTextStyles.bodySm.copyWith(
                      fontWeight: FontWeight.w700,
                      color: KColors.baseContent,
                    ),
                  ),
                ],
              ),
              backgroundColor: KColors.base100,
              elevation: 0,
              scrolledUnderElevation: 0,
              actions: actions,
              automaticallyImplyLeading: showBack,
              shape: const Border(
                bottom: BorderSide(color: KColors.border),
              ),
            )
          : null,
      body: body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}
