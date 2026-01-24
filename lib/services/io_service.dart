import 'package:uuid/uuid.dart';
import '../models/io_models.dart';

class IOService {
  // Temporary in-memory storage (in production, use Hive or Firebase)
  static final List<IntakeEntry> _intakeEntries = [];
  static final List<OutputEntry> _outputEntries = [];
  static final Map<String, UserFluidRange> _userRanges = {};

  // Add intake entry
  Future<void> addIntakeEntry({
    required String userId,
    required double volume,
    required String fluidType,
    required String notes,
  }) async {
    final now = DateTime.now();
    final shift = _getShift(now);

    final entry = IntakeEntry(
      id: const Uuid().v4(),
      userId: userId,
      volume: volume,
      fluidType: fluidType,
      timestamp: now,
      notes: notes,
      shift: shift,
    );

    _intakeEntries.add(entry);
    // TODO: Sync to Firebase
  }

  // Add output entry
  Future<void> addOutputEntry({
    required String userId,
    required double volume,
    required String outputType,
    required String notes,
  }) async {
    final now = DateTime.now();
    final shift = _getShift(now);

    final entry = OutputEntry(
      id: const Uuid().v4(),
      userId: userId,
      volume: volume,
      outputType: outputType,
      timestamp: now,
      notes: notes,
      shift: shift,
    );

    _outputEntries.add(entry);
    // TODO: Sync to Firebase
  }

  // Get today's entries
  List<IntakeEntry> getTodayIntake(String userId) {
    final today = DateTime.now();
    return _intakeEntries.where((entry) {
      return entry.userId == userId &&
          entry.timestamp.year == today.year &&
          entry.timestamp.month == today.month &&
          entry.timestamp.day == today.day;
    }).toList();
  }

  List<OutputEntry> getTodayOutput(String userId) {
    final today = DateTime.now();
    return _outputEntries.where((entry) {
      return entry.userId == userId &&
          entry.timestamp.year == today.year &&
          entry.timestamp.month == today.month &&
          entry.timestamp.day == today.day;
    }).toList();
  }

  // Get daily summary
  Future<DailyFluidSummary?> getDailySummary({
    required String userId,
    required DateTime date,
  }) async {
    final intakeEntries = _intakeEntries.where((entry) {
      return entry.userId == userId &&
          entry.timestamp.year == date.year &&
          entry.timestamp.month == date.month &&
          entry.timestamp.day == date.day;
    }).toList();

    final outputEntries = _outputEntries.where((entry) {
      return entry.userId == userId &&
          entry.timestamp.year == date.year &&
          entry.timestamp.month == date.month &&
          entry.timestamp.day == date.day;
    }).toList();

    if (intakeEntries.isEmpty && outputEntries.isEmpty) {
      return null;
    }

    // Create summary with estimated output
    return DailyFluidSummary.withEstimatedOutput(
      date: date,
      intakeEntries: intakeEntries,
      userAge: 35, // Default age, should be from user profile
    );
  }

  // Get entries for date range
  Future<List<DailyFluidSummary>> getSummaryForDateRange({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final summaries = <DailyFluidSummary>[];
    var current = startDate;

    while (!current.isAfter(endDate)) {
      final summary = await getDailySummary(userId: userId, date: current);
      if (summary != null) {
        summaries.add(summary);
      }
      current = current.add(const Duration(days: 1));
    }

    return summaries;
  }

  // Delete intake entry
  Future<void> deleteIntakeEntry(String entryId) async {
    _intakeEntries.removeWhere((entry) => entry.id == entryId);
  }

  // Delete output entry
  Future<void> deleteOutputEntry(String entryId) async {
    _outputEntries.removeWhere((entry) => entry.id == entryId);
  }

  // Set user fluid ranges
  void setUserFluidRange(String userId, UserFluidRange range) {
    _userRanges[userId] = range;
  }

  // Get user fluid ranges
  UserFluidRange getUserFluidRange(String userId) {
    return _userRanges[userId] ?? UserFluidRange.defaultRanges(userId);
  }

  // Helper to determine shift based on time
  String _getShift(DateTime dateTime) {
    final hour = dateTime.hour;
    if (hour >= 6 && hour < 14) {
      return 'morning';
    } else if (hour >= 14 && hour < 22) {
      return 'afternoon';
    } else {
      return 'night';
    }
  }

  // Get entries by shift
  List<IntakeEntry> getIntakeByShift(
    String userId,
    DateTime date,
    String shift,
  ) {
    return getTodayIntake(
      userId,
    ).where((entry) => entry.shift == shift).toList();
  }

  List<OutputEntry> getOutputByShift(
    String userId,
    DateTime date,
    String shift,
  ) {
    return getTodayOutput(
      userId,
    ).where((entry) => entry.shift == shift).toList();
  }
}
