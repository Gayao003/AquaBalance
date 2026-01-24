class UserProfile {
  final String userId;
  final String email;
  final String name;
  final int age;
  final DateTime createdAt;
  final DateTime lastUpdated;

  UserProfile({
    required this.userId,
    required this.email,
    required this.name,
    required this.age,
    required this.createdAt,
    required this.lastUpdated,
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'email': email,
      'name': name,
      'age': age,
      'createdAt': createdAt.toIso8601String(),
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: json['userId'],
      email: json['email'],
      name: json['name'],
      age: json['age'] is int
          ? json['age']
          : int.tryParse(json['age'].toString()) ?? 0,
      createdAt: DateTime.parse(json['createdAt']),
      lastUpdated: DateTime.parse(json['lastUpdated']),
    );
  }
}
