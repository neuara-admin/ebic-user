import '../../../../core/auth/session_manager.dart';
import 'user_entity.dart';

/// Section 50 & 60 - Auth Session Entity
class AuthSessionEntity {
  final String? accessToken;
  final String? refreshToken;
  final UserEntity? user;
  final AuthSessionStatus status;
  final DateTime? lastSeenAt;

  const AuthSessionEntity({
    this.accessToken,
    this.refreshToken,
    this.user,
    this.status = AuthSessionStatus.unauthenticated,
    this.lastSeenAt,
  });

  bool get isAuthenticated => status == AuthSessionStatus.authenticated && accessToken != null;

  AuthSessionEntity copyWith({
    String? accessToken,
    String? refreshToken,
    UserEntity? user,
    AuthSessionStatus? status,
    DateTime? lastSeenAt,
  }) {
    return AuthSessionEntity(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      user: user ?? this.user,
      status: status ?? this.status,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    );
  }
}
