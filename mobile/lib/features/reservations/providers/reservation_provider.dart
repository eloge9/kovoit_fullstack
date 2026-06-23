import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/reservation_model.dart';
import '../repositories/reservation_repository.dart';

final reservationRepositoryProvider =
    Provider<ReservationRepository>((ref) => ReservationRepository());

// ── Filtres historique ────────────────────────────────────────────────────────

class HistoriqueFilters {
  final String? statut;
  final DateTime? dateDebut;
  final DateTime? dateFin;
  final String search;

  const HistoriqueFilters({
    this.statut,
    this.dateDebut,
    this.dateFin,
    this.search = '',
  });

  HistoriqueFilters copyWith({
    Object? statut = _sentinel,
    Object? dateDebut = _sentinel,
    Object? dateFin = _sentinel,
    String? search,
  }) {
    return HistoriqueFilters(
      statut: statut == _sentinel ? this.statut : statut as String?,
      dateDebut: dateDebut == _sentinel ? this.dateDebut : dateDebut as DateTime?,
      dateFin: dateFin == _sentinel ? this.dateFin : dateFin as DateTime?,
      search: search ?? this.search,
    );
  }

  static const _sentinel = Object();

  bool get hasActiveFilters =>
      statut != null || dateDebut != null || dateFin != null || search.isNotEmpty;
}

// ── Provider filtres passager historique ─────────────────────────────────────

final historiqueFiltersProvider = StateProvider.autoDispose<HistoriqueFilters>(
  (ref) => const HistoriqueFilters(),
);

// ── Provider filtres conducteur historique ───────────────────────────────────

final conducteurHistoriqueFiltersProvider = StateProvider.autoDispose<HistoriqueFilters>(
  (ref) => const HistoriqueFilters(),
);

// ── Data providers historique ─────────────────────────────────────────────────

final historiqueProvider = FutureProvider.autoDispose<List<ReservationModel>>((ref) {
  final filters = ref.watch(historiqueFiltersProvider);
  final repo = ref.watch(reservationRepositoryProvider);
  return repo.historique(
    statut: filters.statut,
    dateDebut: filters.dateDebut,
    dateFin: filters.dateFin,
    search: filters.search.isNotEmpty ? filters.search : null,
  );
});

final conducteurHistoriqueProvider =
    FutureProvider.autoDispose<List<ReservationModel>>((ref) {
  final filters = ref.watch(conducteurHistoriqueFiltersProvider);
  final repo = ref.watch(reservationRepositoryProvider);
  return repo.conducteurHistorique(
    statut: filters.statut,
    dateDebut: filters.dateDebut,
    dateFin: filters.dateFin,
    search: filters.search.isNotEmpty ? filters.search : null,
  );
});

// ── Provider réservations actives ─────────────────────────────────────────────

class ReservationsState {
  final List<ReservationModel> mesReservations;
  final List<ReservationModel> reservationsRecues;
  final bool isLoading;
  final String? error;
  final String? successMessage;

  const ReservationsState({
    this.mesReservations = const [],
    this.reservationsRecues = const [],
    this.isLoading = false,
    this.error,
    this.successMessage,
  });

  ReservationsState copyWith({
    List<ReservationModel>? mesReservations,
    List<ReservationModel>? reservationsRecues,
    bool? isLoading,
    String? error,
    String? successMessage,
  }) {
    return ReservationsState(
      mesReservations: mesReservations ?? this.mesReservations,
      reservationsRecues: reservationsRecues ?? this.reservationsRecues,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      successMessage: successMessage,
    );
  }
}

class ReservationsNotifier extends StateNotifier<ReservationsState> {
  final ReservationRepository _repo;

  ReservationsNotifier(this._repo) : super(const ReservationsState());

  Future<void> loadMesReservations() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final reservations = await _repo.mesReservations();
      state = state.copyWith(isLoading: false, mesReservations: reservations);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadReservationsRecues() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final reservations = await _repo.reservationsRecues();
      state = state.copyWith(isLoading: false, reservationsRecues: reservations);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> reserver(int trajetId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final reservation = await _repo.reserver(trajetId);
      state = state.copyWith(
        isLoading: false,
        mesReservations: [reservation, ...state.mesReservations],
        successMessage: 'Réservation effectuée avec succès !',
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> confirmer(int id) async {
    try {
      final updated = await _repo.confirmerReservation(id);
      _updateRecue(updated);
      state = state.copyWith(successMessage: 'Réservation confirmée !');
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> decliner(int id) async {
    try {
      final updated = await _repo.declinerReservation(id);
      _updateRecue(updated);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> annuler(int id) async {
    try {
      await _repo.annulerReservation(id);
      state = state.copyWith(
        mesReservations: state.mesReservations.where((r) => r.id != id).toList(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  void _updateRecue(ReservationModel updated) {
    state = state.copyWith(
      reservationsRecues: state.reservationsRecues
          .map((r) => r.id == updated.id ? updated : r)
          .toList(),
    );
  }

  void clearMessages() => state = state.copyWith(error: null, successMessage: null);
}

final reservationsProvider =
    StateNotifierProvider<ReservationsNotifier, ReservationsState>(
  (ref) => ReservationsNotifier(ref.watch(reservationRepositoryProvider)),
);
