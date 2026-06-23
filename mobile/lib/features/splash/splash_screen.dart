import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth/providers/auth_provider.dart';
import '../../core/theme/colors.dart';
import '../../core/providers/server_provider.dart';
import '../../core/services/storage_service.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  bool _serverNotFound = false;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _scaleAnimation = Tween<double>(begin: 0.6, end: 1).animate(
        CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _controller.forward();
    _start();
  }

  Future<void> _start() async {
    // Animation minimum 1.5s
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    setState(() => _statusMessage = 'Recherche du serveur...');

    // Découverte du serveur
    await ref.read(serverProvider.notifier).initialize();
    if (!mounted) return;

    final serverState = ref.read(serverProvider);
    if (!serverState.isConnected) {
      setState(() {
        _serverNotFound = true;
        _statusMessage = serverState.message;
      });
      return;
    }

    // Si l'utilisateur avait des tokens mais que loadProfil() a échoué
    // (serveur pas encore découvert), on relance maintenant que le serveur est trouvé
    final auth = ref.read(authProvider);
    if (auth.isAuthenticated && auth.user == null) {
      setState(() => _statusMessage = 'Chargement du profil...');
      await ref.read(authProvider.notifier).loadProfil();
    }

    // Attendre la fin du chargement
    while (mounted && ref.read(authProvider).isLoading) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    if (!mounted) return;

    _navigate();
  }

  Future<void> _navigate() async {
    final authState = ref.read(authProvider);
    if (!authState.isAuthenticated) {
      context.go('/login');
      return;
    }

    final user = authState.user;
    if (user == null) {
      context.go('/login');
      return;
    }

    if (user.role == 'admin') {
      context.go('/admin');
      return;
    }

    debugPrint('[Splash] Role: ${user.role}, modeCourant: ${user.modeCourant}, peutConduire: ${user.peutConduire}');

    if (!mounted) return;

    // Un conducteur va toujours sur son dashboard
    if (user.role == 'conducteur') {
      context.go('/conducteur');
      return;
    }

    // Passager avec droits conducteur : utiliser le dernier mode choisi
    if (user.peutConduire) {
      String? mode = user.modeCourant;
      if (mode == null || mode.isEmpty) {
        mode = await StorageService.getActiveMode();
      }
      if (!mounted) return;
      debugPrint('[Splash] Mode actif passager/conducteur: $mode');
      if (mode == 'conducteur') {
        context.go('/conducteur');
        return;
      }
    }

    context.go('/passager');
  }

  Future<void> _retry() async {
    setState(() {
      _serverNotFound = false;
      _statusMessage = 'Nouvelle recherche...';
    });
    await ref.read(serverProvider.notifier).rediscover();
    if (!mounted) return;

    final serverState = ref.read(serverProvider);
    if (serverState.isConnected) {
      final auth = ref.read(authProvider);
      if (auth.isAuthenticated && auth.user == null) {
        await ref.read(authProvider.notifier).loadProfil();
      }
      while (mounted && ref.read(authProvider).isLoading) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      if (mounted) _navigate();
    } else {
      setState(() {
        _serverNotFound = true;
        _statusMessage = serverState.message;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Mise à jour du message pendant le scan
    final serverState = ref.watch(serverProvider);
    if (serverState.isBusy && serverState.message.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_serverNotFound) {
          setState(() => _statusMessage = serverState.message);
        }
      });
    }

    return Scaffold(
      backgroundColor: KColors.primary,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) => FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(scale: _scaleAnimation, child: child),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.directions_car_rounded,
                  size: 60,
                  color: KColors.primary,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'KoVoit',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Covoiturage au Togo',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 16,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 60),

              if (!_serverNotFound) ...[
                // Chargement normal
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 2,
                ),
                const SizedBox(height: 16),
                Text(
                  _statusMessage,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
              ] else ...[
                // Serveur introuvable
                _ServerNotFoundPanel(
                  message: _statusMessage,
                  onRetry: _retry,
                  onConfigure: () => context.push('/server-settings'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ServerNotFoundPanel extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onConfigure;

  const _ServerNotFoundPanel({
    required this.message,
    required this.onRetry,
    required this.onConfigure,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.wifi_off_rounded,
                  color: Colors.white,
                  size: 36,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Serveur introuvable',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Réessayer'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onConfigure,
                  icon: const Icon(Icons.settings_rounded, size: 18),
                  label: const Text('Configurer'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: KColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
