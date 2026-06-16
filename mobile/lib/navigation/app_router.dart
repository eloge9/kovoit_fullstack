import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/providers/auth_provider.dart';
import '../features/splash/splash_screen.dart';
import '../features/auth/screens/login_page.dart';
import '../features/auth/screens/register_page.dart';
import '../features/auth/screens/forgot_password_page.dart';

// Passager
import '../features/passager/screens/passager_shell.dart';
import '../features/passager/screens/passager_dashboard_page.dart';

// Conducteur
import '../features/conducteur/screens/conducteur_shell.dart';
import '../features/conducteur/screens/conducteur_dashboard_page.dart';

// Admin
import '../features/admin/screens/admin_shell.dart';
import '../features/admin/screens/admin_dashboard_page.dart';
import '../features/admin/screens/admin_utilisateurs_page.dart';
import '../features/admin/screens/admin_conducteurs_page.dart';
import '../features/admin/screens/admin_settings_page.dart';
import '../features/admin/screens/admin_trajets_page.dart';
import '../features/admin/screens/admin_audit_page.dart';
import '../features/admin/screens/admin_reservations_page.dart';
import '../features/admin/screens/admin_paiements_page.dart';
import '../features/admin/screens/admin_statistiques_page.dart';
import '../features/admin/screens/admin_messagerie_page.dart';
import '../features/admin/screens/admin_notifications_page.dart';
import '../features/admin/screens/admin_plaintes_page.dart';

// Features partagées
import '../features/trajets/screens/trajets_list_page.dart';
import '../features/trajets/screens/trajet_detail_page.dart';
import '../features/trajets/screens/create_trajet_page.dart';
import '../features/reservations/screens/reservations_page.dart';
import '../features/paiements/screens/paiement_page.dart';
import '../features/evaluations/screens/evaluation_page.dart';
import '../features/messagerie/screens/messagerie_page.dart';
import '../features/messagerie/screens/conversation_page.dart';
import '../features/profile/screens/profile_page.dart';
import '../features/profile/screens/edit_profile_page.dart';
import '../features/profile/screens/documents_page.dart';
import '../features/profile/screens/vehicules_page.dart';
import '../features/economie/screens/conducteur_economie_page.dart';
import '../features/economie/screens/passager_economie_page.dart';
import '../features/gps/screens/conducteur_gps_page.dart';
import '../features/gps/screens/passager_suivi_page.dart';
import '../features/evaluations/screens/evaluation_list_page.dart';
import '../features/passager/screens/devenir_conducteur_page.dart';
import '../features/conducteur/screens/verification_page.dart';
import '../features/notifications/screens/notifications_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final isAuth    = authState.isAuthenticated;
      final isLoading = authState.isLoading;
      final location  = state.matchedLocation;

      if (isLoading) return '/splash';

      final publicRoutes = ['/login', '/register', '/forgot-password', '/splash'];
      final isPublic = publicRoutes.contains(location);

      if (!isAuth && !isPublic) return '/login';
      if (isAuth && isPublic && location != '/splash') {
        final user = authState.user;
        if (user?.role == 'conducteur') return '/conducteur';
        if (user?.role == 'admin')      return '/admin';
        return '/passager';
      }
      return null;
    },
    routes: [
      // ── Splash ──────────────────────────────────────────────────────────
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),

      // ── Auth ─────────────────────────────────────────────────────────────
      GoRoute(path: '/login',          builder: (_, _) => const LoginPage()),
      GoRoute(path: '/register',       builder: (_, _) => const RegisterPage()),
      GoRoute(path: '/forgot-password',builder: (_, _) => const ForgotPasswordPage()),

      // ── Passager (shell avec Bottom Nav) ─────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => const PassagerShell(),
        routes: [
          GoRoute(path: '/passager',
              builder: (_, _) => const PassagerDashboardPage()),
          GoRoute(path: '/passager/trajets',
              builder: (_, _) => const TrajetsListPage(isMesTrajets: false)),
          GoRoute(
            path: '/passager/trajet/:id',
            builder: (_, state) => TrajetDetailPage(
              trajetId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
            ),
          ),
          GoRoute(path: '/passager/reservations',
              builder: (_, _) => const ReservationsPage(isConducteur: false)),
          GoRoute(
            path: '/passager/paiement/:id',
            builder: (_, state) => PaiementPage(
              reservationId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
            ),
          ),
          GoRoute(
            path: '/passager/evaluation/:trajetId/:cibleId',
            builder: (_, state) => EvaluationPage(
              trajetId: int.tryParse(state.pathParameters['trajetId'] ?? '') ?? 0,
              cibleId: state.pathParameters['cibleId'] ?? '',
            ),
          ),
          GoRoute(path: '/passager/messages',
              builder: (_, _) => const MessageriePage()),
          GoRoute(
            path: '/passager/messages/:userId',
            builder: (_, state) => ConversationPage(
              userId: state.pathParameters['userId'] ?? '',
              userName: state.uri.queryParameters['name'] ?? '',
            ),
          ),
          GoRoute(path: '/passager/profile',
              builder: (_, _) => const ProfilePage()),
          GoRoute(path: '/passager/profile/edit',
              builder: (_, _) => const EditProfilePage()),
          GoRoute(path: '/passager/profile/documents',
              builder: (_, _) => const DocumentsPage()),
          GoRoute(path: '/passager/devenir-conducteur',
              builder: (_, _) => const DevenirConducteurPage()),
          GoRoute(path: '/passager/evaluations',
              builder: (_, _) => const EvaluationListPage()),
          GoRoute(path: '/passager/economie',
              builder: (_, _) => const PassagerEconomiePage()),
          GoRoute(
            path: '/passager/trajet/:id/suivi',
            builder: (_, state) => PassagerSuiviPage(
              trajetId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
              depart: state.uri.queryParameters['depart'] ?? '',
              destination: state.uri.queryParameters['destination'] ?? '',
              conducteurNom: state.uri.queryParameters['conducteur'] ?? 'Conducteur',
            ),
          ),
          GoRoute(path: '/passager/notifications',
              builder: (_, _) => const NotificationsPage()),
        ],
      ),

      // ── Conducteur (shell avec Bottom Nav) ───────────────────────────────
      ShellRoute(
        builder: (context, state, child) => const ConducteurShell(),
        routes: [
          GoRoute(path: '/conducteur',
              builder: (_, _) => const ConducteurDashboardPage()),
          GoRoute(path: '/conducteur/trajets',
              builder: (_, _) => const TrajetsListPage(isMesTrajets: true)),
          GoRoute(
            path: '/conducteur/trajet/:id',
            builder: (_, state) => TrajetDetailPage(
              trajetId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
              isConducteur: true,
            ),
          ),
          GoRoute(path: '/conducteur/create-trajet',
              builder: (_, _) => const CreateTrajetPage()),
          GoRoute(path: '/conducteur/reservations',
              builder: (_, _) => const ReservationsPage(isConducteur: true)),
          GoRoute(path: '/conducteur/vehicules',
              builder: (_, _) => const VehiculesPage()),
          GoRoute(path: '/conducteur/messages',
              builder: (_, _) => const MessageriePage()),
          GoRoute(
            path: '/conducteur/messages/:userId',
            builder: (_, state) => ConversationPage(
              userId: state.pathParameters['userId'] ?? '',
              userName: state.uri.queryParameters['name'] ?? '',
            ),
          ),
          GoRoute(path: '/conducteur/profile',
              builder: (_, _) => const ProfilePage()),
          GoRoute(path: '/conducteur/profile/edit',
              builder: (_, _) => const EditProfilePage()),
          GoRoute(path: '/conducteur/documents',
              builder: (_, _) => const DocumentsPage()),
          GoRoute(path: '/conducteur/verification',
              builder: (_, _) => const VerificationPage()),
          GoRoute(path: '/conducteur/economie',
              builder: (_, _) => const ConducteurEconomiePage()),
          GoRoute(path: '/conducteur/evaluations',
              builder: (_, _) => const EvaluationListPage()),
          GoRoute(
            path: '/conducteur/trajet/:id/gps',
            builder: (_, state) => ConducteurGpsPage(
              trajetId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
              depart: state.uri.queryParameters['depart'] ?? '',
              destination: state.uri.queryParameters['destination'] ?? '',
            ),
          ),
          GoRoute(
            path: '/conducteur/evaluation/:trajetId/:cibleId',
            builder: (_, state) => EvaluationPage(
              trajetId: int.tryParse(state.pathParameters['trajetId'] ?? '') ?? 0,
              cibleId: state.pathParameters['cibleId'] ?? '',
            ),
          ),
          GoRoute(path: '/conducteur/notifications',
              builder: (_, _) => const NotificationsPage()),
        ],
      ),

      // ── Admin (shell avec Bottom Nav + Drawer) ───────────────────────────
      ShellRoute(
        builder: (context, state, child) => const AdminShell(),
        routes: [
          GoRoute(path: '/admin',
              builder: (_, _) => const AdminDashboardPage()),
          GoRoute(path: '/admin/utilisateurs',
              builder: (_, _) => const AdminUtilisateursPage()),
          GoRoute(path: '/admin/conducteurs',
              builder: (_, _) => const AdminConducteursPage()),
          GoRoute(path: '/admin/trajets',
              builder: (_, _) => const AdminTrajetsPage()),
          GoRoute(path: '/admin/audit',
              builder: (_, _) => const AdminAuditPage()),
          GoRoute(path: '/admin/settings',
              builder: (_, _) => const AdminSettingsPage()),
          // Nouvelles pages admin
          GoRoute(path: '/admin/reservations',
              builder: (_, _) => const AdminReservationsPage()),
          GoRoute(path: '/admin/paiements',
              builder: (_, _) => const AdminPaiementsPage()),
          GoRoute(path: '/admin/statistiques',
              builder: (_, _) => const AdminStatistiquesPage()),
          GoRoute(path: '/admin/messagerie',
              builder: (_, _) => const AdminMessageriePage()),
          GoRoute(path: '/admin/notifications',
              builder: (_, _) => const AdminNotificationsPage()),
          GoRoute(path: '/admin/plaintes',
              builder: (_, _) => const AdminPlaintesPage()),
        ],
      ),
    ],

    errorBuilder: (context, state) => Scaffold(
      backgroundColor: const Color(0xFFE7F0F8),
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, size: 48, color: Color(0xFF8EA4BC)),
          const SizedBox(height: 16),
          Text('Page introuvable',
              style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF394E6A),
              )),
          TextButton(
            onPressed: () => context.go('/passager'),
            child: const Text('Retour à l\'accueil'),
          ),
        ]),
      ),
    ),
  );
});
