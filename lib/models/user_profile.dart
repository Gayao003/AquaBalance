class UserProfile {
  final String userId;
  final String email;
  final String name;
  final int? age;
  final DateTime? dateOfBirth;
  final double? weightKg;
  final double? heightCm;
  final DateTime createdAt;
  final DateTime lastUpdated;

  UserProfile({
    required this.userId,
    required this.email,
    required this.name,
    this.age,
    this.dateOfBirth,
    this.weightKg,
    this.heightCm,
    required this.createdAt,
    required this.lastUpdated,
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'email': email,
      'name': name,
      'age': age,
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'weightKg': weightKg,
      'heightCm': heightCm,
      'createdAt': createdAt.toIso8601String(),
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final ageValue = json['age'];
    final dateOfBirthValue = json['dateOfBirth'];
    final weightValue = json['weightKg'];
    final heightValue = json['heightCm'];

    return UserProfile(
      userId: json['userId'],
      email: json['email'],
      name: json['name'],
      age: ageValue == null
          ? null
          : (ageValue is int ? ageValue : int.tryParse(ageValue.toString())),
      dateOfBirth: dateOfBirthValue == null
          ? null
          : DateTime.tryParse(dateOfBirthValue.toString()),
      weightKg: weightValue == null
          ? null
          : (weightValue is num
                ? weightValue.toDouble()
                : double.tryParse(weightValue.toString())),
      heightCm: heightValue == null
          ? null
          : (heightValue is num
                ? heightValue.toDouble()
                : double.tryParse(heightValue.toString())),
      createdAt: DateTime.parse(json['createdAt']),
      lastUpdated: DateTime.parse(json['lastUpdated']),
    );
  }
}
