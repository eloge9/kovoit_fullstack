import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/splash/splash_screen.dart';
import '../features/auth/screens/login_page.dart';
import '../features/auth/screens/register_page.dart';
import '../features/auth/screens/forgot_password_page.dart';
import '../features/home/screens/passager_home_page.dart';
import '../features/home/screens/conducteur_home_page.dart';
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

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final isAuth = authState.isAuthenticated;
      final isLoading = authState.isLoading;
      final location = state.matchedLocation;

      if (isLoading) return '/splash';

      final publicRoutes = ['/login', '/register', '/forgot-password', '/splash'];
      final isPublic = publicRoutes.contains(location);

      if (!isAuth && !isPublic) return '/login';
      if (isAuth && isPublic && location != '/splash') {
        final user = authState.user;
        if (user?.role == 'conducteur' || user?.peutConduire == true) {
          return '/conducteur';
        }
        return '/passager';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordPage(),
      ),

      // Dashboard Passager
      GoRoute(
        path: '/passager',
        builder: (context, state) => const PassagerHomePage(),
        routes: [
          GoRoute(
            path: 'trajets',
            builder: (context, state) => const TrajetsListPage(),
          ),
          GoRoute(
            path: 'trajet/:id',
            builder: (context, state) => TrajetDetailPage(
              trajetId: int.parse(state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: 'reservations',
            builder: (context, state) => const ReservationsPage(isConducteur: false),
          ),
          GoRoute(
            path: 'paiement/:reservationId',
            builder: (context, state) => PaiementPage(
              reservationId: int.parse(state.pathParameters['reservationId']!),
            ),
          ),
          GoRoute(
            path: 'evaluation/:trajetId/:cibleId',
            builder: (context, state) => EvaluationPage(
              trajetId: int.parse(state.pathParameters['trajetId']!),
              cibleId: state.pathParameters['cibleId']!,
            ),
          ),
          GoRoute(
            path: 'messages',
            builder: (context, state) => const MessageriePage(),
            routes: [
              GoRoute(
                path: ':userId',
                builder: (context, state) => ConversationPage(
                  userId: state.pathParameters['userId']!,
                  userName: state.uri.queryParameters['name'] ?? '',
                ),
              ),
            ],
          ),
          GoRoute(
            path: 'profile',
            builder: (context, state) => const ProfilePage(),
            routes: [
              GoRoute(
                path: 'edit',
                builder: (context, state) => const EditProfilePage(),
              ),
              GoRoute(
                path: 'documents',
                builder: (context, state) => const DocumentsPage(),
              ),
            ],
          ),
        ],
      ),

      // Dashboard Conducteur
      GoRoute(
        path: '/conducteur',
        builder: (context, state) => const ConducteurHomePage(),
        routes: [
          GoRoute(
            path: 'trajets',
            builder: (context, state) => const TrajetsListPage(isMesTrajets: true),
          ),
          GoRoute(
            path: 'trajet/:id',
            builder: (context, state) => TrajetDetailPage(
              trajetId: int.parse(state.pathParameters['id']!),
              isConducteur: true,
            ),
          ),
          GoRoute(
            path: 'create-trajet',
            builder: (context, state) => const CreateTrajetPage(),
          ),
          GoRoute(
            path: 'reservations',
            builder: (context, state) => const ReservationsPage(isConducteur: true),
          ),
          GoRoute(
            path: 'vehicules',
            builder: (context, state) => const VehiculesPage(),
          ),
          GoRoute(
            path: 'messages',
            builder: (context, state) => const MessageriePage(),
            routes: [
              GoRoute(
                path: ':userId',
                builder: (context, state) => ConversationPage(
                  userId: state.pathParameters['userId']!,
                  userName: state.uri.queryParameters['name'] ?? '',
                ),
              ),
            ],
          ),
          GoRoute(
            path: 'profile',
            builder: (context, state) => const ProfilePage(),
            routes: [
              GoRoute(
                path: 'edit',
                builder: (context, state) => const EditProfilePage(),
              ),
              GoRoute(
                path: 'documents',
                builder: (context, state) => const DocumentsPage(),
              ),
            ],
          ),
          GoRoute(
            path: 'evaluation/:trajetId/:cibleId',
            builder: (context, state) => EvaluationPage(
              trajetId: int.parse(state.pathParameters['trajetId']!),
              cibleId: state.pathParameters['cibleId']!,
            ),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page non trouvée: ${state.error}'),
      ),
    ),
  );
});
