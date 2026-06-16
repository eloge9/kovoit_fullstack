import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_model.dart';

class NotificationsState {
  final List<NotificationModel> notifications;

  const NotificationsState({this.notifications = const []});

  int get nonLus => notifications.where((n) => !n.isRead).length;

  NotificationsState copyWith({List<NotificationModel>? notifications}) =>
      NotificationsState(notifications: notifications ?? this.notifications);
}

class NotificationsNotifier extends StateNotifier<NotificationsState> {
  NotificationsNotifier() : super(const NotificationsState());

  void ajouterNotification(NotificationModel notif) {
    state = state.copyWith(
      notifications: [notif, ...state.notifications],
    );
  }

  void marquerCommeLu(int index) {
    if (index < 0 || index >= state.notifications.length) return;
    final updated = List<NotificationModel>.from(state.notifications);
    updated[index] = updated[index].copyWith(isRead: true);
    state = state.copyWith(notifications: updated);
  }

  void marquerToutLu() {
    state = state.copyWith(
      notifications: state.notifications.map((n) => n.copyWith(isRead: true)).toList(),
    );
  }

  void supprimerNotification(int index) {
    if (index < 0 || index >= state.notifications.length) return;
    final updated = List<NotificationModel>.from(state.notifications)..removeAt(index);
    state = state.copyWith(notifications: updated);
  }

  void viderTout() {
    state = const NotificationsState();
  }
}

final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, NotificationsState>(
  (ref) => NotificationsNotifier(),
);

final nonLusProvider = Provider<int>((ref) {
  return ref.watch(notificationsProvider).nonLus;
});
