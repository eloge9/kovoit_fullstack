import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/trajet_model.dart';
import '../models/vehicule_model.dart';
import '../repositories/trajet_repository.dart';

final trajetRepositoryProvider =
    Provider<TrajetRepository>((ref) => TrajetRepository());

// ── État liste des trajets ────────────────────────────────────────────────────

class TrajetsState {
  final List<TrajetModel> trajets;
  final bool isLoading;
  final String? error;
  final int? lastCreatedId;
  final bool isGeoSearch;         // true si résultat de recherche itinéraire
  final String? algorithm;        // algo matching retourné par le backend
  final double toleranceKm;       // tolérance utilisée pour la dernière recherche

  const TrajetsState({
    this.trajets = const [],
    this.isLoading = false,
    this.error,
    this.lastCreatedId,
    this.isGeoSearch = false,
    this.algorithm,
    this.toleranceKm = 1.0,
  });

  TrajetsState copyWith({
    List<TrajetModel>? trajets,
    bool? isLoading,
    String? error,
    int? lastCreatedId,
    bool? isGeoSearch,
    String? algorithm,
    double? toleranceKm,
  }) {
    return TrajetsState(
      trajets: trajets ?? this.trajets,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastCreatedId: lastCreatedId ?? this.lastCreatedId,
      isGeoSearch: isGeoSearch ?? this.isGeoSearch,
      algorithm: algorithm ?? this.algorithm,
      toleranceKm: toleranceKm ?? this.toleranceKm,
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class TrajetsNotifier extends StateNotifier<TrajetsState> {
  final TrajetRepository _repo;

  TrajetsNotifier(this._repo) : super(const TrajetsState());

  /// Charge les trajets disponibles (passager) via /trajets/rechercher/.
  Future<void> loadTrajets({
    String? depart,
    String? destination,
    String? date,
    int? places,
  }) async {
    state = state.copyWith(isLoading: true, error: null, isGeoSearch: false);
    try {
      final trajets = await _repo.getTrajets(
        depart: depart,
        destination: destination,
        date: date,
        places: places,
      );
      debugPrint('[TrajetsNotifier] loadTrajets: ${trajets.length} trajets');
      state = state.copyWith(isLoading: false, trajets: trajets);
    } catch (e) {
      debugPrint('[TrajetsNotifier] loadTrajets error: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Charge les trajets du conducteur connecté via /trajets/mes_trajets/.
  Future<void> loadMesTrajets() async {
    state = state.copyWith(isLoading: true, error: null, isGeoSearch: false);
    try {
      final trajets = await _repo.mesTrajets();
      debugPrint('[TrajetsNotifier] loadMesTrajets: ${trajets.length} trajets');
      state = state.copyWith(isLoading: false, trajets: trajets);
    } catch (e) {
      debugPrint('[TrajetsNotifier] loadMesTrajets error: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Recherche géospatiale par itinéraire (polylines v2).
  Future<void> rechercherItineraire({
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
    String? date,
    int places = 1,
    double toleranceKm = 1.0,
  }) async {
    state = state.copyWith(
      isLoading: true,
      error: null,
      isGeoSearch: true,
      toleranceKm: toleranceKm,
    );
    try {
      final result = await _repo.rechercherParItineraire(
        pickupLat: pickupLat,
        pickupLng: pickupLng,
        dropoffLat: dropoffLat,
        dropoffLng: dropoffLng,
        date: date,
        places: places,
        toleranceKm: toleranceKm,
        scoreMinimum: 30,
      );
      debugPrint(
        '[TrajetsNotifier] rechercherItineraire: ${result.count} résultats '
        'algo=${result.algorithm} tol=${result.toleranceKm}km',
      );
      state = state.copyWith(
        isLoading: false,
        trajets: result.trajets,
        isGeoSearch: true,
        algorithm: result.algorithm,
        toleranceKm: result.toleranceKm,
      );
    } catch (e) {
      debugPrint('[TrajetsNotifier] rechercherItineraire error: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> creerTrajet(Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final trajet = await _repo.creerTrajet(data);
      state = state.copyWith(
        isLoading: false,
        trajets: [trajet, ...state.trajets],
        lastCreatedId: trajet.id,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> commencerTrajet(int id) async {
    try {
      final updated = await _repo.commencerTrajet(id);
      _updateTrajetInList(updated);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> terminerTrajet(int id) async {
    try {
      final updated = await _repo.terminerTrajet(id);
      _updateTrajetInList(updated);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> annulerTrajet(int id) async {
    try {
      await _repo.annulerTrajet(id);
      state = state.copyWith(
        trajets: state.trajets
            .map((t) => t.id == id ? t.copyWith(statut: 'annule') : t)
            .toList(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  void _updateTrajetInList(TrajetModel updated) {
    state = state.copyWith(
      trajets: state.trajets
          .map((t) => t.id == updated.id ? updated : t)
          .toList(),
    );
  }

  void clearError() => state = state.copyWith(error: null);
}

final trajetsProvider =
    StateNotifierProvider<TrajetsNotifier, TrajetsState>(
  (ref) => TrajetsNotifier(ref.watch(trajetRepositoryProvider)),
);

// ── Provider véhicules ────────────────────────────────────────────────────────

class VehiculesNotifier
    extends StateNotifier<AsyncValue<List<VehiculeModel>>> {
  final TrajetRepository _repo;

  VehiculesNotifier(this._repo) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final vehicules = await _repo.mesVehicules();
      state = AsyncValue.data(vehicules);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }

  Future<bool> ajouter(Map<String, dynamic> data) async {
    try {
      final vehicule = await _repo.ajouterVehicule(data);
      final current = state.valueOrNull ?? [];
      state = AsyncValue.data([...current, vehicule]);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> desactiver(int id) async {
    try {
      await _repo.desactiverVehicule(id);
      final current = state.valueOrNull ?? [];
      state = AsyncValue.data(
        current
            .map((v) => v.id == id ? v.copyWith(actif: false) : v)
            .toList(),
      );
      return true;
    } catch (e) {
      return false;
    }
  }
}

final vehiculesProvider = StateNotifierProvider<VehiculesNotifier,
    AsyncValue<List<VehiculeModel>>>(
  (ref) => VehiculesNotifier(ref.watch(trajetRepositoryProvider)),
);
