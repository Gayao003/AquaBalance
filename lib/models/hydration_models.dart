class HydrationSchedule {
  final int id;
  final String userId;
  final String label;
  final int hour;
  final int minute;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool enabled;
  final String? templateId;
  final DateTime createdAt;
  final DateTime updatedAt;

  HydrationSchedule({
    required this.id,
    required this.userId,
    required this.label,
    required this.hour,
    required this.minute,
    required this.startDate,
    required this.endDate,
    required this.enabled,
    required this.createdAt,
    required this.updatedAt,
    this.templateId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'label': label,
      'hour': hour,
      'minute': minute,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'enabled': enabled,
      'templateId': templateId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory HydrationSchedule.fromJson(Map<String, dynamic> json) {
    return HydrationSchedule(
      id: json['id'],
      userId: json['userId'],
      label: json['label'] ?? '',
      hour: json['hour'],
      minute: json['minute'],
      startDate: json['startDate'] == null
          ? null
          : DateTime.tryParse(json['startDate'].toString()),
      endDate: json['endDate'] == null
          ? null
          : DateTime.tryParse(json['endDate'].toString()),
      enabled: json['enabled'] ?? true,
      templateId: json['templateId'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  HydrationSchedule copyWith({
    String? label,
    int? hour,
    int? minute,
    DateTime? startDate,
    DateTime? endDate,
    bool? enabled,
    String? templateId,
    DateTime? updatedAt,
  }) {
    return HydrationSchedule(
      id: id,
      userId: userId,
      label: label ?? this.label,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      enabled: enabled ?? this.enabled,
      templateId: templateId ?? this.templateId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class HydrationCheckIn {
  final String id;
  final String userId;
  final int? scheduleId;
  final String beverageType;
  final double amountMl;
  final DateTime timestamp;

  HydrationCheckIn({
    required this.id,
    required this.userId,
    required this.scheduleId,
    required this.beverageType,
    required this.amountMl,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'scheduleId': scheduleId,
      'beverageType': beverageType,
      'amountMl': amountMl,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory HydrationCheckIn.fromJson(Map<String, dynamic> json) {
    return HydrationCheckIn(
      id: json['id'],
      userId: json['userId'],
      scheduleId: json['scheduleId'],
      beverageType: json['beverageType'] ?? 'Water',
      amountMl: (json['amountMl'] as num?)?.toDouble() ?? 0,
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

class HydrationTemplateTime {
  final int hour;
  final int minute;

  const HydrationTemplateTime({required this.hour, required this.minute});

  Map<String, dynamic> toJson() {
    return {'hour': hour, 'minute': minute};
  }

  factory HydrationTemplateTime.fromJson(Map<String, dynamic> json) {
    return HydrationTemplateTime(hour: json['hour'], minute: json['minute']);
  }
}

class HydrationTemplate {
  final String id;
  final String userId;
  final String title;
  final List<HydrationTemplateTime> times;
  final DateTime createdAt;

  HydrationTemplate({
    required this.id,
    required this.userId,
    required this.title,
    required this.times,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'times': times.map((t) => t.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory HydrationTemplate.fromJson(Map<String, dynamic> json) {
    final times = (json['times'] as List? ?? [])
        .map((t) => HydrationTemplateTime.fromJson(t))
        .toList();
    return HydrationTemplate(
      id: json['id'],
      userId: json['userId'],
      title: json['title'] ?? '',
      times: times,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}
