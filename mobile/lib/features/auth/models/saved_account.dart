import 'user_model.dart';

class SavedAccount {
  final String id;
  final String username;
  final String email;
  final String? firstName;
  final String? lastName;
  final String? photoUrl;
  final String role;
  final String authProvider;
  final DateTime lastSeen;

  const SavedAccount({
    required this.id,
    required this.username,
    required this.email,
    this.firstName,
    this.lastName,
    this.photoUrl,
    required this.role,
    required this.authProvider,
    required this.lastSeen,
  });

  String get displayName {
    final f = firstName ?? '';
    final l = lastName ?? '';
    final full = '$f $l'.trim();
    return full.isNotEmpty ? full : username;
  }

  String get roleLabel {
    switch (role) {
      case 'conducteur': return 'Conducteur';
      case 'admin':      return 'Administrateur';
      default:           return 'Passager';
    }
  }

  factory SavedAccount.fromUser(UserModel user) => SavedAccount(
    id:           user.id,
    username:     user.username,
    email:        user.email,
    firstName:    user.firstName,
    lastName:     user.lastName,
    photoUrl:     user.photoGoogle ?? user.photoProfile,
    role:         user.role,
    authProvider: user.authProvider,
    lastSeen:     DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'id':           id,
    'username':     username,
    'email':        email,
    'firstName':    firstName,
    'lastName':     lastName,
    'photoUrl':     photoUrl,
    'role':         role,
    'authProvider': authProvider,
    'lastSeen':     lastSeen.toIso8601String(),
  };

  factory SavedAccount.fromJson(Map<String, dynamic> json) => SavedAccount(
    id:           json['id'] as String? ?? '',
    username:     json['username'] as String? ?? '',
    email:        json['email'] as String? ?? '',
    firstName:    json['firstName'] as String?,
    lastName:     json['lastName'] as String?,
    photoUrl:     json['photoUrl'] as String?,
    role:         json['role'] as String? ?? 'passager',
    authProvider: json['authProvider'] as String? ?? 'email',
    lastSeen:     json['lastSeen'] != null
        ? DateTime.tryParse(json['lastSeen'] as String) ?? DateTime.now()
        : DateTime.now(),
  );
}
