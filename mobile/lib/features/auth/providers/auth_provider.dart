import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../repositories/auth_repository.dart';
import '../../../core/network/api_interceptor.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/session_service.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());

class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? error;
  final bool isAuthenticated;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.error,
    this.isAuthenticated = false,
  });

  AuthState copyWith({
    UserModel? user,
    bool? isLoading,
    String? error,
    bool? isAuthenticated,
  }) =>
      AuthState(
        user:            user ?? this.user,
        isLoading:       isLoading ?? this.isLoading,
        error:           error,
        isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      );
}

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
    if (loggedIn) {
      await loadProfil();
    } else {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<bool> connexion({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _repo.connexion(email: email, password: password);
      // Le backend retourne { "utilisateur": {...}, "tokens": {...} }
      final utilisateurJson = data['utilisateur'] as Map<String, dynamic>?;
      final user = utilisateurJson != null ? UserModel.fromJson(utilisateurJson) : null;
      state = state.copyWith(isLoading: false, user: user, isAuthenticated: true);
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
      // Auto-login : le backend renvoie aussi l'utilisateur et les tokens
      final utilisateurJson = response['utilisateur'] as Map<String, dynamic>?;
      final user = utilisateurJson != null ? UserModel.fromJson(utilisateurJson) : null;
      state = state.copyWith(
        isLoading: false,
        user: user,
        isAuthenticated: user != null,
      );
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
      state = state.copyWith(isLoading: false, user: user, isAuthenticated: true);
    } catch (e) {
      // Supprimer les tokens UNIQUEMENT sur erreur d'authentification (401/403)
      // Pas sur erreur réseau (serveur pas encore découvert, timeout, etc.)
      final isAuthFailure = e is ApiException &&
          (e.statusCode == 401 || e.statusCode == 403);
      if (isAuthFailure) {
        await StorageService.clearAll();
        state = state.copyWith(isLoading: false, isAuthenticated: false, user: null);
      } else {
        // Erreur réseau temporaire : garder les tokens, le profil sera rechargé
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
    state = const AuthState();
  }

  Future<bool> changerMode(String mode) async {
    try {
      final res = await _repo.changerMode(mode);
      final utilisateurJson = res['utilisateur'] as Map<String, dynamic>?;
      if (utilisateurJson != null && state.user != null) {
        state = state.copyWith(user: UserModel.fromJson(utilisateurJson));
      }
      return true;
    } catch (e) {
      state = state.copyWith(error: _parseError(e));
      return false;
    }
  }

  void clearError() => state = state.copyWith(error: null);

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
