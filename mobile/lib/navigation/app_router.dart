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
import '../features/admin/screens/admin_conducteur_detail_page.dart';

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
import '../features/reservations/screens/code_embarquement_page.dart';
import '../features/reservations/screens/embarquement_conducteur_page.dart';
import '../features/conducteur/screens/conducteur_depart_page.dart';
import '../features/reservations/screens/reservation_detail_page.dart';
import '../features/reservations/models/reservation_model.dart';
import '../features/settings/screens/server_settings_screen.dart';
import '../features/verification/screens/driver_status_page.dart';
import '../features/verification/screens/document_upload_page.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

// ── RouterNotifier — reçoit les changements d'auth sans recréer GoRouter ─────

class _RouterNotifier extends ChangeNotifier {
  final Ref _ref;
  AuthState _authState;

  _RouterNotifier(this._ref) : _authState = _ref.read(authProvider) {
    _ref.listen<AuthState>(authProvider, (_, next) {
      _authState = next;
      notifyListeners();
    });
  }

  AuthState get authState => _authState;
}

// Provider du notifier (singleton par session)
final _routerNotifierProvider =
    ChangeNotifierProvider<_RouterNotifier>((ref) => _RouterNotifier(ref));

// ── GoRouter créé une seule fois ──────────────────────────────────────────────

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(_routerNotifierProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: notifier,

    redirect: (context, state) {
      final auth      = notifier.authState;
      final isAuth    = auth.isAuthenticated;
      final isLoading = auth.isLoading;
      final location  = state.matchedLocation;

      if (isLoading) return '/splash';

      const publicRoutes = ['/login', '/register', '/forgot-password', '/splash'];
      final isPublic = publicRoutes.contains(location);

      if (!isAuth && !isPublic) return '/login';
      if (isAuth && isPublic) {
        if (location == '/splash') return null; // SplashScreen gère la navigation
        final user = auth.user;
        if (user?.role == 'admin')      return '/admin';
        if (user?.role == 'conducteur') return '/conducteur';
        return '/passager';
      }
      return null;
    },

    routes: [
      // ── Splash ──────────────────────────────────────────────────────────
      GoRoute(path: '/splash',         builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/server-settings',builder: (_, _) => const ServerSettingsScreen()),

      // ── Auth ─────────────────────────────────────────────────────────────
      GoRoute(path: '/login',           builder: (_, _) => const LoginPage()),
      GoRoute(path: '/register',        builder: (_, _) => const RegisterPage()),
      GoRoute(path: '/forgot-password', builder: (_, _) => const ForgotPasswordPage()),

      // ── Passager shell ────────────────────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => PassagerShell(
          key: const ValueKey('passager-shell'),
          child: child,
        ),
        routes: [
          GoRoute(path: '/passager',
              builder: (_, _) => const PassagerDashboardPage()),
          GoRoute(path: '/passager/trajets',
              builder: (_, _) => const TrajetsListPage(isMesTrajets: false, hideAppBar: true)),
          GoRoute(path: '/passager/reservations',
              builder: (_, _) => const ReservationsPage(isConducteur: false, hideAppBar: true)),
          GoRoute(path: '/passager/messages',
              builder: (_, _) => const MessageriePage(hideAppBar: true)),
        ],
      ),

      // ── Conducteur shell ──────────────────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => ConducteurShell(
          key: const ValueKey('conducteur-shell'),
          child: child,
        ),
        routes: [
          GoRoute(path: '/conducteur',
              builder: (_, _) => const ConducteurDashboardPage()),
          GoRoute(path: '/conducteur/trajets',
              builder: (_, _) => const TrajetsListPage(isMesTrajets: true, hideAppBar: true)),
          GoRoute(path: '/conducteur/historique',
              builder: (_, _) => const TrajetsListPage(isMesTrajets: true, hideAppBar: true)),
          GoRoute(path: '/conducteur/reservations',
              builder: (_, _) => const ReservationsPage(isConducteur: true, hideAppBar: true)),
          GoRoute(path: '/conducteur/messages',
              builder: (_, _) => const MessageriePage(hideAppBar: true)),
          GoRoute(path: '/conducteur/statut',
              builder: (_, _) => const DriverStatusPage()),
        ],
      ),

      // ── Admin shell ───────────────────────────────────────────────────────
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
          GoRoute(path: '/admin/reservations',
              builder: (_, _) => const AdminReservationsPage()),
          GoRoute(path: '/admin/paiements',
              builder: (_, _) => const AdminPaiementsPage()),
          GoRoute(path: '/admin/statistiques',
              builder: (_, _) => const AdminStatistiquesPage()),
          GoRoute(path: '/admin/messagerie',
              builder: (_, _) => const AdminMessageriePage()),
          GoRoute(
            path: '/admin/messagerie/:convId',
            builder: (_, state) => ConversationPage(
              convId:   int.tryParse(state.pathParameters['convId'] ?? '') ?? 0,
              userName: state.uri.queryParameters['name'] ?? '',
              userId:   state.uri.queryParameters['userId'],
              statut:   state.uri.queryParameters['statut'] ?? 'ouverte',
            ),
          ),
          GoRoute(path: '/admin/notifications',
              builder: (_, _) => const AdminNotificationsPage()),
          GoRoute(path: '/admin/plaintes',
              builder: (_, _) => const AdminPlaintesPage()),
          GoRoute(
            path: '/admin/conducteur/:id',
            builder: (_, state) => AdminConducteurDetailPage(
              conducteurId: state.pathParameters['id'] ?? '',
            ),
          ),
        ],
      ),

      // ── Routes détail passager (plein écran) ──────────────────────────────
      GoRoute(
        path: '/passager/trajet/:id',
        builder: (_, state) => TrajetDetailPage(
          trajetId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
        path: '/passager/trajet/:id/suivi',
        builder: (_, state) => PassagerSuiviPage(
          trajetId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
          depart:        state.uri.queryParameters['depart'] ?? '',
          destination:   state.uri.queryParameters['destination'] ?? '',
          conducteurNom: state.uri.queryParameters['conducteur'] ?? 'Conducteur',
          departLat:      double.tryParse(state.uri.queryParameters['departLat'] ?? ''),
          departLng:      double.tryParse(state.uri.queryParameters['departLng'] ?? ''),
          destinationLat: double.tryParse(state.uri.queryParameters['destinationLat'] ?? ''),
          destinationLng: double.tryParse(state.uri.queryParameters['destinationLng'] ?? ''),
        ),
      ),
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
          cibleId:  state.pathParameters['cibleId'] ?? '',
        ),
      ),
      GoRoute(
        path: '/passager/messages/:convId',
        builder: (_, state) => ConversationPage(
          convId:   int.tryParse(state.pathParameters['convId'] ?? '') ?? 0,
          userName: state.uri.queryParameters['name'] ?? '',
          userId:   state.uri.queryParameters['userId'],
          statut:   state.uri.queryParameters['statut'] ?? 'ouverte',
        ),
      ),
      GoRoute(path: '/passager/profile',           builder: (_, _) => const ProfilePage()),
      GoRoute(path: '/passager/profile/edit',      builder: (_, _) => const EditProfilePage()),
      GoRoute(path: '/passager/profile/documents', builder: (_, _) => const DocumentsPage()),
      GoRoute(path: '/passager/devenir-conducteur',builder: (_, _) => const DevenirConducteurPage()),
      GoRoute(path: '/passager/evaluations',       builder: (_, _) => const EvaluationListPage()),
      GoRoute(path: '/passager/economie',          builder: (_, _) => const PassagerEconomiePage()),
      GoRoute(path: '/passager/notifications',     builder: (_, _) => const NotificationsPage()),
      GoRoute(
        path: '/passager/reservation/:id/code-embarquement',
        builder: (_, state) => CodeEmbarquementPage(
          reservationId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
        path: '/passager/reservation/:id/detail',
        builder: (_, state) => ReservationDetailPage(
          reservationId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
          initialData: state.extra is ReservationModel
              ? state.extra as ReservationModel
              : null,
          isConducteur: false,
        ),
      ),

      // ── Routes détail conducteur (plein écran) ────────────────────────────
      GoRoute(
        path: '/conducteur/trajet/:id',
        builder: (_, state) => TrajetDetailPage(
          trajetId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
          isConducteur: true,
        ),
      ),
      GoRoute(
        path: '/conducteur/trajet/:id/depart',
        builder: (_, state) => ConducteurDepartPage(
          trajetId:       int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
          depart:         state.uri.queryParameters['depart'] ?? '',
          destination:    state.uri.queryParameters['destination'] ?? '',
          departLat:      double.tryParse(state.uri.queryParameters['departLat'] ?? ''),
          departLng:      double.tryParse(state.uri.queryParameters['departLng'] ?? ''),
          destinationLat: double.tryParse(state.uri.queryParameters['destinationLat'] ?? ''),
          destinationLng: double.tryParse(state.uri.queryParameters['destinationLng'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/conducteur/trajet/:id/gps',
        builder: (_, state) => ConducteurGpsPage(
          trajetId:       int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
          depart:         state.uri.queryParameters['depart'] ?? '',
          destination:    state.uri.queryParameters['destination'] ?? '',
          departLat:      double.tryParse(state.uri.queryParameters['departLat'] ?? ''),
          departLng:      double.tryParse(state.uri.queryParameters['departLng'] ?? ''),
          destinationLat: double.tryParse(state.uri.queryParameters['destinationLat'] ?? ''),
          destinationLng: double.tryParse(state.uri.queryParameters['destinationLng'] ?? ''),
        ),
      ),
      GoRoute(path: '/conducteur/create-trajet',   builder: (_, _) => const CreateTrajetPage()),
      GoRoute(path: '/conducteur/vehicules',        builder: (_, _) => const VehiculesPage()),
      GoRoute(
        path: '/conducteur/messages/:convId',
        builder: (_, state) => ConversationPage(
          convId:   int.tryParse(state.pathParameters['convId'] ?? '') ?? 0,
          userName: state.uri.queryParameters['name'] ?? '',
          userId:   state.uri.queryParameters['userId'],
          statut:   state.uri.queryParameters['statut'] ?? 'ouverte',
        ),
      ),
      GoRoute(path: '/conducteur/profile',          builder: (_, _) => const ProfilePage()),
      GoRoute(path: '/conducteur/profile/edit',     builder: (_, _) => const EditProfilePage()),
      GoRoute(path: '/conducteur/documents',        builder: (_, _) => const DocumentsPage()),
      GoRoute(path: '/conducteur/verification',     builder: (_, _) => const VerificationPage()),
      GoRoute(path: '/conducteur/economie',         builder: (_, _) => const ConducteurEconomiePage()),
      GoRoute(path: '/conducteur/evaluations',      builder: (_, _) => const EvaluationListPage()),
      GoRoute(
        path: '/conducteur/evaluation/:trajetId/:cibleId',
        builder: (_, state) => EvaluationPage(
          trajetId: int.tryParse(state.pathParameters['trajetId'] ?? '') ?? 0,
          cibleId:  state.pathParameters['cibleId'] ?? '',
        ),
      ),
      GoRoute(path: '/conducteur/notifications',   builder: (_, _) => const NotificationsPage()),
      GoRoute(path: '/conducteur/embarquement',    builder: (_, _) => const EmbarquementConducteurPage()),
      GoRoute(path: '/conducteur/dossier',         builder: (_, _) => const DocumentUploadPage()),
      GoRoute(
        path: '/conducteur/reservation/:id/detail',
        builder: (_, state) => ReservationDetailPage(
          reservationId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
          initialData: state.extra is ReservationModel
              ? state.extra as ReservationModel
              : null,
          isConducteur: true,
        ),
      ),
    ],

    errorBuilder: (context, state) => Scaffold(
      backgroundColor: const Color(0xFFE7F0F8),
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, size: 48, color: Color(0xFF8EA4BC)),
          const SizedBox(height: 16),
          const Text('Page introuvable',
              style: TextStyle(
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
