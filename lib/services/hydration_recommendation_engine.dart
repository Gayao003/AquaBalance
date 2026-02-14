import '../models/user_profile.dart';
import '../models/health_profile.dart';

/// Smart hydration recommendation engine that calculates personalized
/// water intake goals based on user metrics and health conditions
class HydrationRecommendationEngine {
  /// Calculate recommended daily water intake in milliliters
  /// Based on weight, height, age, and health conditions
  static double calculateDailyGoalMl({
    required UserProfile userProfile,
    HealthProfile? healthProfile,
  }) {
    // Base calculation: 35ml per kg of body weight (standard recommendation)
    double baseGoal = 2500; // Default if no weight provided

    if (userProfile.weightKg != null && userProfile.weightKg! > 0) {
      baseGoal = userProfile.weightKg! * 35;
    }

    // Adjust for age
    if (userProfile.age != null) {
      if (userProfile.age! >= 65) {
        // Older adults need slightly less
        baseGoal *= 0.95;
      } else if (userProfile.age! >= 18 && userProfile.age! <= 30) {
        // Young adults need slightly more
        baseGoal *= 1.05;
      }
    }

    // Adjust for height (taller people need more)
    if (userProfile.heightCm != null && userProfile.heightCm! > 0) {
      if (userProfile.heightCm! > 180) {
        baseGoal *= 1.1;
      } else if (userProfile.heightCm! < 160) {
        baseGoal *= 0.95;
      }
    }

    // Adjust for health conditions
    if (healthProfile != null && healthProfile.isEnabled) {
      final multiplier = _getHealthConditionMultiplier(
        healthProfile.conditions,
      );
      baseGoal *= multiplier;
    }

    // Cap at reasonable limits (1500ml - 5000ml)
    return baseGoal.clamp(1500.0, 5000.0);
  }

  /// Get water intake multiplier based on health conditions
  static double _getHealthConditionMultiplier(List<String> conditions) {
    if (conditions.isEmpty) return 1.0;

    double maxMultiplier = 1.0;

    for (final condition in conditions) {
      double multiplier = 1.0;

      switch (condition) {
        case 'Kidney Stones':
          multiplier = 1.4; // Significantly more water needed
          break;
        case 'Urinary Tract Infections (UTIs)':
          multiplier = 1.35; // More water to flush bacteria
          break;
        case 'Athlete / Active Lifestyle':
          multiplier = 1.5; // Much more for active individuals
          break;
        case 'Kidney Disease':
          multiplier =
              1.2; // Moderate increase (note: some stages require restriction)
          break;
        case 'Pregnancy':
          multiplier = 1.3; // Extra hydration for pregnancy
          break;
        case 'Diabetes':
          multiplier = 1.25; // Slightly more to manage blood sugar
          break;
        case 'High Blood Pressure':
          multiplier = 1.15; // Moderate increase
          break;
        case 'Heart Disease':
          multiplier = 1.1; // Slight increase (some cases may need restriction)
          break;
        case 'Dry Skin / Dry Climate':
          multiplier = 1.2; // More for hydration
          break;
        default:
          multiplier = 1.0;
      }

      // Take the highest multiplier if multiple conditions
      if (multiplier > maxMultiplier) {
        maxMultiplier = multiplier;
      }
    }

    return maxMultiplier;
  }

  /// Calculate recommended reminder interval in minutes
  static int calculateReminderIntervalMinutes({
    required double dailyGoalMl,
    HealthProfile? healthProfile,
    int? wakeHours = 16, // Assuming 16 waking hours
  }) {
    // If health profile has custom interval, respect it
    if (healthProfile != null && healthProfile.reminderIntervalMinutes > 0) {
      return healthProfile.reminderIntervalMinutes;
    }

    // Calculate based on daily goal and waking hours
    // Aim for 8-12 reminders per day
    final targetRemindersPerDay = _getTargetRemindersPerDay(
      healthProfile?.conditions ?? [],
    );

    final wakeMinutes = (wakeHours ?? 16) * 60;
    final intervalMinutes = (wakeMinutes / targetRemindersPerDay).round();

    // Clamp between 30 minutes and 3 hours
    return intervalMinutes.clamp(30, 180);
  }

  /// Get target number of reminders per day based on health conditions
  static int _getTargetRemindersPerDay(List<String> conditions) {
    if (conditions.isEmpty) return 8; // Default: every 2 hours

    int maxReminders = 8;

    for (final condition in conditions) {
      int reminders = 8;

      switch (condition) {
        case 'Kidney Stones':
          reminders = 16; // Every 60 mins (aggressive)
          break;
        case 'Urinary Tract Infections (UTIs)':
          reminders = 12; // Every 80 mins
          break;
        case 'Athlete / Active Lifestyle':
          reminders = 16; // Every 60 mins
          break;
        case 'Kidney Disease':
          reminders = 10; // Every 96 mins
          break;
        case 'Pregnancy':
          reminders = 12; // Every 80 mins
          break;
        case 'Diabetes':
          reminders = 10; // Every 96 mins
          break;
        case 'High Blood Pressure':
          reminders = 8; // Every 120 mins
          break;
        case 'Heart Disease':
          reminders = 8; // Every 120 mins
          break;
        case 'Dry Skin / Dry Climate':
          reminders = 10; // Every 96 mins
          break;
        default:
          reminders = 8;
      }

      // Take the highest frequency if multiple conditions
      if (reminders > maxReminders) {
        maxReminders = reminders;
      }
    }

    return maxReminders;
  }

  /// Calculate recommended amount per reminder
  static double calculateAmountPerReminderMl({
    required double dailyGoalMl,
    required int reminderIntervalMinutes,
    int? wakeHours = 16,
  }) {
    final wakeMinutes = (wakeHours ?? 16) * 60;
    final remindersPerDay = (wakeMinutes / reminderIntervalMinutes).floor();

    if (remindersPerDay <= 0) return 250.0;

    final amountPerReminder = dailyGoalMl / remindersPerDay;

    // Clamp between 100ml and 500ml per reminder
    return amountPerReminder.clamp(100.0, 500.0);
  }

  /// Get comprehensive hydration recommendation
  static HydrationRecommendation getRecommendation({
    required UserProfile userProfile,
    HealthProfile? healthProfile,
    int? wakeHours = 16,
  }) {
    final dailyGoalMl = calculateDailyGoalMl(
      userProfile: userProfile,
      healthProfile: healthProfile,
    );

    final intervalMinutes = calculateReminderIntervalMinutes(
      dailyGoalMl: dailyGoalMl,
      healthProfile: healthProfile,
      wakeHours: wakeHours,
    );

    final amountPerReminderMl = calculateAmountPerReminderMl(
      dailyGoalMl: dailyGoalMl,
      reminderIntervalMinutes: intervalMinutes,
      wakeHours: wakeHours,
    );

    final message = _generateRecommendationMessage(
      userProfile: userProfile,
      healthProfile: healthProfile,
      dailyGoalMl: dailyGoalMl,
    );

    return HydrationRecommendation(
      dailyGoalMl: dailyGoalMl,
      reminderIntervalMinutes: intervalMinutes,
      amountPerReminderMl: amountPerReminderMl,
      message: message,
      healthProfile: healthProfile,
    );
  }

  /// Generate personalized recommendation message
  static String _generateRecommendationMessage({
    required UserProfile userProfile,
    HealthProfile? healthProfile,
    required double dailyGoalMl,
  }) {
    if (healthProfile == null || healthProfile.conditions.isEmpty) {
      return 'Based on your profile, we recommend ${(dailyGoalMl / 1000).toStringAsFixed(1)}L per day.';
    }

    final conditions = healthProfile.conditions;
    final primaryCondition = conditions.first;

    final conditionMessages = {
      'Kidney Stones':
          'Kidney stone prevention requires frequent hydration. Drink ${(dailyGoalMl / 1000).toStringAsFixed(1)}L daily.',
      'Urinary Tract Infections (UTIs)':
          'For UTI prevention, drink ${(dailyGoalMl / 1000).toStringAsFixed(1)}L daily to flush bacteria.',
      'Athlete / Active Lifestyle':
          'Active lifestyles need extra hydration! Target ${(dailyGoalMl / 1000).toStringAsFixed(1)}L daily.',
      'Kidney Disease':
          'Kidney health benefits from consistent hydration: ${(dailyGoalMl / 1000).toStringAsFixed(1)}L daily.',
      'Pregnancy':
          'Pregnancy increases hydration needs. Aim for ${(dailyGoalMl / 1000).toStringAsFixed(1)}L daily.',
      'Diabetes':
          'Diabetes management includes proper hydration: ${(dailyGoalMl / 1000).toStringAsFixed(1)}L daily.',
      'High Blood Pressure':
          'Maintain healthy hydration for blood pressure: ${(dailyGoalMl / 1000).toStringAsFixed(1)}L daily.',
      'Heart Disease':
          'Heart health supported by hydration: ${(dailyGoalMl / 1000).toStringAsFixed(1)}L daily.',
      'Dry Skin / Dry Climate':
          'Combat dryness with hydration: ${(dailyGoalMl / 1000).toStringAsFixed(1)}L daily.',
    };

    return conditionMessages[primaryCondition] ??
        'Based on your health profile, drink ${(dailyGoalMl / 1000).toStringAsFixed(1)}L daily.';
  }
}

/// Hydration recommendation result
class HydrationRecommendation {
  final double dailyGoalMl;
  final int reminderIntervalMinutes;
  final double amountPerReminderMl;
  final String message;
  final HealthProfile? healthProfile;

  HydrationRecommendation({
    required this.dailyGoalMl,
    required this.reminderIntervalMinutes,
    required this.amountPerReminderMl,
    required this.message,
    this.healthProfile,
  });

  String get dailyGoalFormatted =>
      '${(dailyGoalMl / 1000).toStringAsFixed(1)}L';
  String get intervalFormatted {
    if (reminderIntervalMinutes < 60) {
      return '$reminderIntervalMinutes mins';
    } else {
      final hours = reminderIntervalMinutes / 60;
      return hours == hours.toInt()
          ? '${hours.toInt()} ${hours.toInt() == 1 ? 'hour' : 'hours'}'
          : '${hours.toStringAsFixed(1)} hours';
    }
  }

  String get amountFormatted => '${amountPerReminderMl.round()}ml';
}
