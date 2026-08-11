/// Profile model for the signed-in user.
///
/// The identity-service `UserResponse` returns `phone` as nullable and does not
/// return the stats (`programsJoined`/`tasksCompleted`/`badgesEarned`) or a flat
/// `location` (it lives under `profile.country`/`profile.city`). Parsing must be
/// tolerant of those missing/null values so the screen renders instead of
/// throwing "type Null is not a subtype of type String".
class ProfileModel {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String location;
  final String avatarUrl;
  final String coverUrl;
  final int programsJoined;
  final int tasksCompleted;
  final int badgesEarned;
  final int followersCount;
  final int followingCount;

  const ProfileModel({
    required this.id,
    this.fullName = '',
    this.email = '',
    this.phone = '',
    this.location = '',
    this.avatarUrl = '',
    this.coverUrl = '',
    this.programsJoined = 0,
    this.tasksCompleted = 0,
    this.badgesEarned = 0,
    this.followersCount = 0,
    this.followingCount = 0,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    final profile = json['profile'] is Map<String, dynamic>
        ? json['profile'] as Map<String, dynamic>
        : null;
    final country = (profile?['country'] as String?) ?? '';
    final city = (profile?['city'] as String?) ?? '';
    final location = [country, city].where((e) => e.isNotEmpty).join(', ');
    return ProfileModel(
      id: (json['id'] as String?) ?? '',
      fullName: (json['full_name'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      phone: (json['phone'] as String?) ?? '',
      location: location,
      avatarUrl: (profile?['avatar_url'] as String?) ?? '',
      coverUrl: (profile?['cover_url'] as String?) ?? '',
      programsJoined: (json['programs_joined'] as int?) ?? 0,
      tasksCompleted: (json['tasks_completed'] as int?) ?? 0,
      badgesEarned: (json['badges_earned'] as int?) ?? 0,
      followersCount: (profile?['followers_count'] as int?) ?? 0,
      followingCount: (profile?['following_count'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'location': location,
        'avatarUrl': avatarUrl,
        'programsJoined': programsJoined,
        'tasksCompleted': tasksCompleted,
        'badgesEarned': badgesEarned,
      };
}



