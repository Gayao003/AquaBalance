// Health condition-based hydration profile
// This helps customize hydration reminders based on user health considerations

class HealthProfile {
  final String id;
  final String userId;
  final List<String> conditions; // Multiple health conditions
  final String? customCondition; // For "Other" option
  final int reminderIntervalMinutes; // Override for reminder frequency
  final String messageTone; // 'gentle', 'neutral', 'frequent'
  final bool isEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Predefined health conditions
  static const List<String> predefinedConditions = [
    'None',
    'Kidney Stones',
    'Urinary Tract Infections (UTIs)',
    'Athlete / Active Lifestyle',
    'Diabetes',
    'Heart Disease',
    'Kidney Disease',
    'Pregnancy',
    'High Blood Pressure',
    'Dry Skin / Dry Climate',
    'Other',
  ];

  // Message templates based on condition and tone
  static const Map<String, Map<String, String>> messageTemplates = {
    'None': {
      'gentle': 'Time to hydrate! 💧',
      'neutral': 'Remember to drink water. 💧',
      'frequent': 'Keep hydrating! 💧',
    },
    'Kidney Stones': {
      'gentle': 'Hydration helps prevent kidney stones. Time to drink! 💧',
      'neutral': 'Drink water to support kidney health. 💧',
      'frequent': 'Keep hydrating to prevent kidney stones! 💧',
    },
    'Urinary Tract Infections (UTIs)': {
      'gentle': 'A glass of water supports urinary health. 💧',
      'neutral': 'Drink water for urinary tract health. 💧',
      'frequent': 'Keep your urinary tract healthy - drink water! 💧',
    },
    'Athlete / Active Lifestyle': {
      'gentle': 'Rehydrate after your activity. 💧',
      'neutral': 'Athlete\'s reminder: stay hydrated! 💧',
      'frequent': 'Keep your hydration up for peak performance! 💧',
    },
    'Diabetes': {
      'gentle': 'Water is a great choice for hydration. 💧',
      'neutral': 'Stay hydrated with water throughout the day. 💧',
      'frequent': 'Consistent hydration supports your health! 💧',
    },
    'Heart Disease': {
      'gentle': 'Support your heart health with hydration. 💧',
      'neutral': 'Heart-healthy hydration reminder. 💧',
      'frequent': 'Maintain heart health with consistent hydration! 💧',
    },
    'Kidney Disease': {
      'gentle': 'Gentle reminder to stay hydrated. 💧',
      'neutral': 'Drink water to support kidney health. 💧',
      'frequent': 'Hydration supports your kidney function! 💧',
    },
    'Pregnancy': {
      'gentle': 'Hydration is important during pregnancy. 💧',
      'neutral': 'Expectant reminder: stay hydrated! 💧',
      'frequent': 'Keep yourself and baby hydrated! 💧',
    },
    'High Blood Pressure': {
      'gentle': 'Water supports healthy hydration. 💧',
      'neutral': 'Maintain hydration for better health. 💧',
      'frequent': 'Stay consistently hydrated! 💧',
    },
    'Dry Skin / Dry Climate': {
      'gentle': 'Hydration helps your skin and overall wellness. 💧',
      'neutral': 'Combat dryness with hydration. 💧',
      'frequent': 'Keep hydrated for healthy skin! 💧',
    },
    'Other': {
      'gentle': 'Remember to stay hydrated! 💧',
      'neutral': 'Time to hydrate. 💧',
      'frequent': 'Keep up your hydration! 💧',
    },
  };

  // Default reminder intervals (in minutes) based on condition
  static const Map<String, int> defaultIntervals = {
    'None': 120, // 2 hours (default)
    'Kidney Stones': 60, // 1 hour
    'Urinary Tract Infections (UTIs)': 90, // 1.5 hours
    'Athlete / Active Lifestyle': 30, // 30 mins
    'Diabetes': 120, // 2 hours
    'Heart Disease': 120, // 2 hours
    'Kidney Disease': 90, // 1.5 hours
    'Pregnancy': 60, // 1 hour
    'High Blood Pressure': 120, // 2 hours
    'Dry Skin / Dry Climate': 60, // 1 hour
    'Other': 120, // 2 hours (default)
  };

  HealthProfile({
    required this.id,
    required this.userId,
    required this.conditions,
    this.customCondition,
    int? reminderIntervalMinutes,
    this.messageTone = 'neutral',
    this.isEnabled = true,
    required this.createdAt,
    required this.updatedAt,
  }) : reminderIntervalMinutes =
           reminderIntervalMinutes ?? _calculateDefaultInterval(conditions);

  // Calculate interval based on most aggressive condition
  static int _calculateDefaultInterval(List<String> conditions) {
    if (conditions.isEmpty) return 120;
    final intervals = conditions.map((c) => defaultIntervals[c] ?? 120).toList()
      ..sort();
    return intervals.first; // Return shortest interval
  }

  // Get the appropriate message for this profile
  String getNotificationMessage() {
    if (conditions.isEmpty) {
      final templates = messageTemplates['Other']!;
      return templates[messageTone] ?? templates['neutral']!;
    }

    // If multiple conditions, prioritize the most urgent one
    final priorityOrder = [
      'Kidney Stones',
      'Urinary Tract Infections (UTIs)',
      'Athlete / Active Lifestyle',
      'Kidney Disease',
      'Pregnancy',
      'Diabetes',
      'High Blood Pressure',
      'Heart Disease',
      'Dry Skin / Dry Climate',
      'Other',
    ];

    String? topCondition;
    for (final priority in priorityOrder) {
      if (conditions.contains(priority)) {
        topCondition = priority;
        break;
      }
    }

    topCondition ??= conditions.first;
    final templates =
        messageTemplates[topCondition] ?? messageTemplates['Other']!;
    return templates[messageTone] ?? templates['neutral']!;
  }

  // Get display name for all conditions
  String getDisplayName() {
    if (conditions.isEmpty) {
      return customCondition ?? 'No conditions selected';
    }
    if (conditions.length == 1) {
      return conditions.first == 'Other' && customCondition != null
          ? customCondition!
          : conditions.first;
    }
    return '${conditions.length} conditions';
  }

  // Get detailed display text
  String getDetailedDisplay() {
    if (conditions.isEmpty) return customCondition ?? 'None';
    final display = conditions.join(', ');
    if (customCondition != null && conditions.contains('Other')) {
      return display.replaceAll('Other', customCondition!);
    }
    return display;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'conditions': conditions,
      'customCondition': customCondition,
      'reminderIntervalMinutes': reminderIntervalMinutes,
      'messageTone': messageTone,
      'isEnabled': isEnabled,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory HealthProfile.fromJson(Map<String, dynamic> json) {
    final conditionsData = json['conditions'];
    List<String> conditions = [];

    if (conditionsData is List) {
      conditions = conditionsData.map((e) => e.toString()).toList();
    } else if (json['condition'] != null) {
      // Backward compatibility with single condition
      conditions = [json['condition'].toString()];
    }

    return HealthProfile(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      conditions: conditions,
      customCondition: json['customCondition'],
      reminderIntervalMinutes: json['reminderIntervalMinutes'],
      messageTone: json['messageTone'] ?? 'neutral',
      isEnabled: json['isEnabled'] ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  HealthProfile copyWith({
    String? id,
    String? userId,
    List<String>? conditions,
    String? customCondition,
    int? reminderIntervalMinutes,
    String? messageTone,
    bool? isEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return HealthProfile(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      conditions: conditions ?? this.conditions,
      customCondition: customCondition ?? this.customCondition,
      reminderIntervalMinutes:
          reminderIntervalMinutes ?? this.reminderIntervalMinutes,
      messageTone: messageTone ?? this.messageTone,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
