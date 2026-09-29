class AppUser {
  final int id;
  final String username;
  final String email;
  final String displayName;
  final String token;
  final int? membershipLevelId;

  const AppUser({
    required this.id,
    required this.username,
    required this.email,
    required this.displayName,
    required this.token,
    this.membershipLevelId,
  });

  /// Build from the jwt-auth/v1/token response.
  factory AppUser.fromTokenResponse(Map<String, dynamic> json) {
    return AppUser(
      id: json['user_id'] as int? ?? 0,
      username: json['user_login'] as String? ?? '',
      email: json['user_email'] as String? ?? '',
      displayName: json['user_display_name'] as String? ?? '',
      token: json['token'] as String? ?? '',
    );
  }

  AppUser copyWith({int? membershipLevelId}) => AppUser(
        id: id,
        username: username,
        email: email,
        displayName: displayName,
        token: token,
        membershipLevelId: membershipLevelId ?? this.membershipLevelId,
      );
}
