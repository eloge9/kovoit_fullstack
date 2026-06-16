import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'navigation/app_router.dart';

class KoVoitApp extends ConsumerWidget {
  const KoVoitApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    // Le Web utilise toujours le thème "winter" (clair) — on fait pareil
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Color(0xFFFFFFFF),
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    return MaterialApp.router(
      title: 'KoVoit',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      themeMode: ThemeMode.light, // toujours light — fidèle au Web
      routerConfig: router,
      locale: const Locale('fr', 'FR'),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
        child: child!,
      ),
    );
  }
}
