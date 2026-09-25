/// Aptiqu User Domain Model
/// Consistent with backend multi-schema database models.
class UserModel {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final DateTime? dob;
  final String gender;
  final String religion;
  final String country;
  final String avatarUrl;
  final int level;
  final String streak;
  // NOTE: coins instead of xp across entire application
  final int coins;
  final bool isRegistrationComplete;

  const UserModel({
    required this.id,
    required this.email,
    required this.firstName,
    this.lastName = '',
    this.dob,
    this.gender = '',
    this.religion = '',
    this.country = '',
    this.avatarUrl = '',
    this.level = 1,
    this.streak = '0d',
    this.coins = 0,
    this.isRegistrationComplete = false,
  });

  UserModel copyWith({
    String? id,
    String? email,
    String? firstName,
    String? lastName,
    DateTime? dob,
    String? gender,
    String? religion,
    String? country,
    String? avatarUrl,
    int? level,
    String? streak,
    int? coins,
    bool? isRegistrationComplete,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      dob: dob ?? this.dob,
      gender: gender ?? this.gender,
      religion: religion ?? this.religion,
      country: country ?? this.country,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      level: level ?? this.level,
      streak: streak ?? this.streak,
      coins: coins ?? this.coins,
      isRegistrationComplete:
          isRegistrationComplete ?? this.isRegistrationComplete,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      dob: json['dob'] != null ? DateTime.tryParse(json['dob']) : null,
      gender: json['gender'] ?? '',
      religion: json['religion'] ?? '',
      country: json['country'] ?? '',
      avatarUrl: json['avatarUrl'] ?? '',
      level: json['level'] ?? 1,
      // Streak from backend
      streak: json['streak']?.toString() ?? '0d',
      // Coins from backend
      coins: json['coins'] ?? 0,
      isRegistrationComplete: json['isRegistrationComplete'] ?? false,
    );
  }

  /// Default demo user matching Shagun
  factory UserModel.demoShagun() {
    return UserModel(
      id: 'shagun_101',
      email: 'shagun@gmail.com',
      firstName: 'Shagun',
      lastName: 'Kumar',
      dob: DateTime(2002, 5, 14),
      gender: 'Male',
      religion: 'Prefer not to say',
      country: 'India',
      avatarUrl:
          'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=250&q=80',
      level: 1,
      streak: '0d',
      coins: 0,
      isRegistrationComplete: true,
    );
  }
}
