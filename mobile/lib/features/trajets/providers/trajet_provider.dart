import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/trajet_model.dart';
import '../models/vehicule_model.dart';
import '../repositories/trajet_repository.dart';

final trajetRepositoryProvider = Provider<TrajetRepository>((ref) => TrajetRepository());

// État liste des trajets
class TrajetsState {
  final List<TrajetModel> trajets;
  final bool isLoading;
  final String? error;
  final int? lastCreatedId;

  const TrajetsState({
    this.trajets = const [],
    this.isLoading = false,
    this.error,
    this.lastCreatedId,
  });

  TrajetsState copyWith({
    List<TrajetModel>? trajets,
    bool? isLoading,
    String? error,
    int? lastCreatedId,
  }) {
    return TrajetsState(
      trajets: trajets ?? this.trajets,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastCreatedId: lastCreatedId ?? this.lastCreatedId,
    );
  }
}

class TrajetsNotifier extends StateNotifier<TrajetsState> {
  final TrajetRepository _repo;

  TrajetsNotifier(this._repo) : super(const TrajetsState());

  Future<void> loadTrajets({
    String? depart,
    String? destination,
    String? date,
    int? places,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final trajets = await _repo.getTrajets(
        depart: depart,
        destination: destination,
        date: date,
        places: places,
      );
      state = state.copyWith(isLoading: false, trajets: trajets);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMesTrajets() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final trajets = await _repo.mesTrajets();
      state = state.copyWith(isLoading: false, trajets: trajets);
    } catch (e) {
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

  Future<void> rechercherItineraire({
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
    String? date,
    int? places,
    double toleranceKm = 2.0,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final trajets = await _repo.rechercherParItineraire(
        pickupLat: pickupLat,
        pickupLng: pickupLng,
        dropoffLat: dropoffLat,
        dropoffLng: dropoffLng,
        date: date,
        places: places,
        toleranceKm: toleranceKm,
      );
      state = state.copyWith(isLoading: false, trajets: trajets);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void clearError() => state = state.copyWith(error: null);
}

final trajetsProvider = StateNotifierProvider<TrajetsNotifier, TrajetsState>(
  (ref) => TrajetsNotifier(ref.watch(trajetRepositoryProvider)),
);

// Provider véhicules
class VehiculesNotifier extends StateNotifier<AsyncValue<List<VehiculeModel>>> {
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
        current.map((v) => v.id == id ? v.copyWith(actif: false) : v).toList(),
      );
      return true;
    } catch (e) {
      return false;
    }
  }
}

final vehiculesProvider =
    StateNotifierProvider<VehiculesNotifier, AsyncValue<List<VehiculeModel>>>(
  (ref) => VehiculesNotifier(ref.watch(trajetRepositoryProvider)),
);
