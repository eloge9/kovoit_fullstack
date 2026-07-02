import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';
import '../models/saved_account.dart';
import '../repositories/auth_repository.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_interceptor.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/session_service.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());

class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? error;
  final bool isAuthenticated;
  final List<SavedAccount> savedAccounts;
  final bool showContinueAs;
  /// True si des tokens JWT sont en storage (non encore vérifiés avec le serveur).
  final bool hasTokens;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.error,
    this.isAuthenticated = false,
    this.savedAccounts = const [],
    this.showContinueAs = false,
    this.hasTokens = false,
  });

  AuthState copyWith({
    UserModel? user,
    bool? isLoading,
    String? error,
    bool? isAuthenticated,
    List<SavedAccount>? savedAccounts,
    bool? showContinueAs,
    bool? hasTokens,
  }) =>
      AuthState(
        user:            user ?? this.user,
        isLoading:       isLoading ?? this.isLoading,
        error:           error,
        isAuthenticated: isAuthenticated ?? this.isAuthenticated,
        savedAccounts:   savedAccounts ?? this.savedAccounts,
        showContinueAs:  showContinueAs ?? this.showContinueAs,
        hasTokens:       hasTokens ?? this.hasTokens,
      );
}

/// Provider pour passer le compte sélectionné depuis ContinueAsScreen à LoginPage.
final continueAsAccountProvider = StateProvider<SavedAccount?>((ref) => null);

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repo;
  late final StreamSubscription<void> _sessionSub;

  AuthNotifier(this._repo) : super(const AuthState(isLoading: true)) {
    _sessionSub = SessionService.sessionExpiredStream.listen((_) {
      state = const AuthState(isAuthenticated: false);
    });
    _init();
  }

  @override
  void dispose() {
    _sessionSub.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    final loggedIn = await StorageService.isLoggedIn();
    final accounts = await StorageService.getSavedAccounts();
    // Lecture uniquement depuis le stockage — aucun appel réseau ici.
    // Le SplashScreen lancera loadProfil() une fois le serveur découvert.
    state = state.copyWith(
      isLoading: false,
      hasTokens: loggedIn,
      savedAccounts: accounts,
      showContinueAs: !loggedIn && accounts.isNotEmpty,
    );
  }

  /// Tente une reconnexion automatique avec les identifiants sauvegardés (Remember Me).
  /// Appelé par SplashScreen après que le serveur est trouvé.
  Future<bool> tryAutoRelogin() async {
    final saved = await StorageService.getSavedCredentials();
    if (saved == null) return false;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _repo.connexion(
        email: saved.email,
        password: saved.password,
      );
      final utilisateurJson = data['utilisateur'] as Map<String, dynamic>?;
      final user = utilisateurJson != null ? UserModel.fromJson(utilisateurJson) : null;
      if (user != null) {
        final account = SavedAccount.fromUser(user);
        await StorageService.saveAccount(account);
        final accounts = await StorageService.getSavedAccounts();
        state = state.copyWith(
          isLoading: false, user: user, isAuthenticated: true,
          savedAccounts: accounts, showContinueAs: false,
        );
      } else {
        state = state.copyWith(isLoading: false, isAuthenticated: false);
      }
      return user != null;
    } catch (_) {
      // Mot de passe changé ou compte supprimé : on efface les credentials
      await StorageService.clearSavedCredentials();
      final accounts = await StorageService.getSavedAccounts();
      state = state.copyWith(
        isLoading: false, isAuthenticated: false,
        savedAccounts: accounts, showContinueAs: accounts.isNotEmpty,
      );
      return false;
    }
  }

  Future<bool> connexion({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _repo.connexion(email: email, password: password);
      final utilisateurJson = data['utilisateur'] as Map<String, dynamic>?;
      final user = utilisateurJson != null ? UserModel.fromJson(utilisateurJson) : null;
      if (user != null) {
        final account = SavedAccount.fromUser(user);
        await StorageService.saveAccount(account);
        final accounts = await StorageService.getSavedAccounts();
        state = state.copyWith(
          isLoading: false, user: user, isAuthenticated: true,
          savedAccounts: accounts, showContinueAs: false,
        );
      } else {
        state = state.copyWith(isLoading: false, isAuthenticated: true, showContinueAs: false);
      }
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _parseError(e));
      return false;
    }
  }

  Future<bool> googleConnexion() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final gs = GoogleSignIn(
        serverClientId: ApiConstants.googleServerClientId,
        scopes: ['email', 'profile'],
      );
      final account = await gs.signIn();
      if (account == null) {
        state = state.copyWith(isLoading: false);
        return false;
      }
      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Token Google introuvable. Réessayez.',
        );
        return false;
      }
      final data = await _repo.googleSignIn(idToken);
      final utilisateurJson = data['utilisateur'] as Map<String, dynamic>?;
      final user = utilisateurJson != null ? UserModel.fromJson(utilisateurJson) : null;
      if (user != null) {
        final account = SavedAccount.fromUser(user);
        await StorageService.saveAccount(account);
        final accounts = await StorageService.getSavedAccounts();
        state = state.copyWith(
          isLoading: false, user: user, isAuthenticated: true,
          savedAccounts: accounts, showContinueAs: false,
        );
      } else {
        state = state.copyWith(isLoading: false, isAuthenticated: true, showContinueAs: false);
      }
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _parseError(e));
      return false;
    }
  }

  Future<bool> inscription(Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _repo.inscription(data);
      final utilisateurJson = response['utilisateur'] as Map<String, dynamic>?;
      final user = utilisateurJson != null ? UserModel.fromJson(utilisateurJson) : null;
      if (user != null) {
        final account = SavedAccount.fromUser(user);
        await StorageService.saveAccount(account);
        final accounts = await StorageService.getSavedAccounts();
        state = state.copyWith(
          isLoading: false, user: user, isAuthenticated: true,
          savedAccounts: accounts, showContinueAs: false,
        );
      } else {
        state = state.copyWith(isLoading: false, isAuthenticated: false);
      }
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _parseError(e));
      return false;
    }
  }

  Future<void> loadProfil() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _repo.getProfil();
      // Mettre à jour le profil sauvegardé avec les données fraîches du serveur
      final account = SavedAccount.fromUser(user);
      await StorageService.saveAccount(account);
      final accounts = await StorageService.getSavedAccounts();
      state = state.copyWith(
        isLoading: false, user: user, isAuthenticated: true,
        savedAccounts: accounts, showContinueAs: false,
      );
    } catch (e) {
      final isAuthFailure = e is ApiException &&
          (e.statusCode == 401 || e.statusCode == 403);
      if (isAuthFailure) {
        await StorageService.clearAll();
        final accounts = await StorageService.getSavedAccounts();
        state = state.copyWith(
          isLoading: false, isAuthenticated: false, user: null,
          savedAccounts: accounts, showContinueAs: accounts.isNotEmpty,
        );
      } else {
        state = state.copyWith(isLoading: false, isAuthenticated: true);
      }
    }
  }

  Future<bool> updateProfil(Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _repo.updateProfil(data);
      state = state.copyWith(isLoading: false, user: user);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _parseError(e));
      return false;
    }
  }

  Future<void> deconnexion() async {
    await _repo.deconnexion();
    // Garder les comptes sauvegardés pour la reconnexion rapide, mais ne pas afficher
    // l'écran "Continuer avec" — l'utilisateur a choisi de se déconnecter explicitement.
    final accounts = state.savedAccounts;
    state = AuthState(savedAccounts: accounts, showContinueAs: false);
  }

  Future<bool> changerMode(String mode) async {
    try {
      debugPrint('[Auth] Switch vers: $mode');
      final res = await _repo.changerMode(mode);
      final utilisateurJson = res['utilisateur'] as Map<String, dynamic>?;
      if (utilisateurJson != null) {
        // Le backend ne change plus le rôle permanent.
        // On met à jour l'état local avec le mode courant pour la session.
        final userFromServer = UserModel.fromJson(utilisateurJson);
        // 'role' côté serveur = rôle permanent. Pour la navigation en session,
        // on surcharge localement avec le mode choisi (sans toucher au rôle DB).
        state = state.copyWith(
          user: userFromServer.copyWith(modeCourant: mode),
        );
      } else if (state.user != null) {
        state = state.copyWith(user: state.user!.copyWith(modeCourant: mode));
      }
      await StorageService.saveActiveMode(mode);
      debugPrint('[Auth] Mode actif: $mode');
      return true;
    } catch (e) {
      debugPrint('[Auth] Erreur changerMode: $e');
      state = state.copyWith(error: _parseError(e));
      return false;
    }
  }

  void clearError() => state = state.copyWith(error: null);

  // Appelé par SplashScreen après timeout pour débloquer la navigation
  void cancelLoading() {
    if (state.isLoading) {
      state = state.copyWith(isLoading: false);
    }
  }

  String _parseError(Object e) {
    final s = e.toString();
    if (s.contains('Exception:')) return s.split('Exception:').last.trim();
    return s;
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref.watch(authRepositoryProvider)),
);

final currentUserProvider = Provider<UserModel?>((ref) => ref.watch(authProvider).user);
final isAuthenticatedProvider = Provider<bool>((ref) => ref.watch(authProvider).isAuthenticated);
