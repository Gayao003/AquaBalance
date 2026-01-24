import 'package:intl/intl.dart';
import '../services/output_estimation_service.dart';

class IntakeEntry {
  final String id;
  final String userId;
  final double volume; // in ml
  final String fluidType; // water, juice, milk, soup, etc.
  final DateTime timestamp;
  final String? notes;
  final String shift; // morning, afternoon, night

  IntakeEntry({
    required this.id,
    required this.userId,
    required this.volume,
    required this.fluidType,
    required this.timestamp,
    this.notes,
    required this.shift,
  });

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'volume': volume,
      'fluidType': fluidType,
      'timestamp': timestamp.toIso8601String(),
      'notes': notes,
      'shift': shift,
    };
  }

  // Create from JSON
  factory IntakeEntry.fromJson(Map<String, dynamic> json) {
    return IntakeEntry(
      id: json['id'],
      userId: json['userId'],
      volume: (json['volume'] as num).toDouble(),
      fluidType: json['fluidType'],
      timestamp: DateTime.parse(json['timestamp']),
      notes: json['notes'],
      shift: json['shift'],
    );
  }

  String get formattedTime => DateFormat('hh:mm a').format(timestamp);
  String get formattedDate => DateFormat('MMM dd, yyyy').format(timestamp);
}

class OutputEntry {
  final String id;
  final String userId;
  final double volume; // in ml
  final String outputType; // urine, dialysate, other
  final DateTime timestamp;
  final String? notes;
  final String shift; // morning, afternoon, night

  OutputEntry({
    required this.id,
    required this.userId,
    required this.volume,
    required this.outputType,
    required this.timestamp,
    this.notes,
    required this.shift,
  });

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'volume': volume,
      'outputType': outputType,
      'timestamp': timestamp.toIso8601String(),
      'notes': notes,
      'shift': shift,
    };
  }

  // Create from JSON
  factory OutputEntry.fromJson(Map<String, dynamic> json) {
    return OutputEntry(
      id: json['id'],
      userId: json['userId'],
      volume: (json['volume'] as num).toDouble(),
      outputType: json['outputType'],
      timestamp: DateTime.parse(json['timestamp']),
      notes: json['notes'],
      shift: json['shift'],
    );
  }

  String get formattedTime => DateFormat('hh:mm a').format(timestamp);
  String get formattedDate => DateFormat('MMM dd, yyyy').format(timestamp);
}

class ShiftData {
  final double totalIntake;
  final double estimatedOutput;
  final int intakeCount;
  final String estimatedOutputConfidence;

  ShiftData({
    required this.totalIntake,
    required this.estimatedOutput,
    required this.intakeCount,
    required this.estimatedOutputConfidence,
  });

  /// Factory constructor to create ShiftData from intake entries
  factory ShiftData.fromIntakeEntries(
    String shiftName,
    List<IntakeEntry> entries,
    int userAge,
  ) {
    final totalIntake = entries.fold<double>(
      0.0,
      (sum, entry) => sum + entry.volume,
    );

    final estimation = OutputEstimationService.calculateEstimatedOutput(
      intakeEntries: entries,
      userAge: userAge,
      timeframe: 'shift',
    );

    return ShiftData(
      totalIntake: totalIntake,
      estimatedOutput: estimation.estimatedVolume,
      intakeCount: entries.length,
      estimatedOutputConfidence: estimation.confidenceLevel,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalIntake': totalIntake,
      'estimatedOutput': estimatedOutput,
      'intakeCount': intakeCount,
      'estimatedOutputConfidence': estimatedOutputConfidence,
    };
  }

  factory ShiftData.fromJson(Map<String, dynamic> json) {
    return ShiftData(
      totalIntake: (json['totalIntake'] as num).toDouble(),
      estimatedOutput: (json['estimatedOutput'] as num?)?.toDouble() ?? 0.0,
      intakeCount: json['intakeCount'],
      estimatedOutputConfidence: json['estimatedOutputConfidence'] ?? 'Low',
    );
  }
}

class DailyFluidSummary {
  final DateTime date;
  final double totalIntake;
  final double estimatedOutput;
  final String estimatedOutputConfidence;
  final List<String> estimationFactors;
  final FluidStatus intakeStatus;
  final List<IntakeEntry> intakeEntries;
  final ShiftData morningShift;
  final ShiftData afternoonShift;
  final ShiftData nightShift;
  final int userAge;

  DailyFluidSummary({
    required this.date,
    required this.totalIntake,
    required this.estimatedOutput,
    required this.estimatedOutputConfidence,
    required this.estimationFactors,
    required this.intakeStatus,
    required this.intakeEntries,
    required this.morningShift,
    required this.afternoonShift,
    required this.nightShift,
    required this.userAge,
  });

  /// Factory constructor to create summary with estimated output
  factory DailyFluidSummary.withEstimatedOutput({
    required DateTime date,
    required List<IntakeEntry> intakeEntries,
    required int userAge,
  }) {
    final totalIntake = intakeEntries.fold<double>(
      0.0,
      (sum, entry) => sum + entry.volume,
    );

    final estimation = OutputEstimationService.calculateEstimatedOutput(
      intakeEntries: intakeEntries,
      userAge: userAge,
      timeframe: 'daily',
    );

    // Calculate shift data
    final morningEntries = intakeEntries
        .where((e) => e.shift == 'morning')
        .toList();
    final afternoonEntries = intakeEntries
        .where((e) => e.shift == 'afternoon')
        .toList();
    final nightEntries = intakeEntries
        .where((e) => e.shift == 'night')
        .toList();

    return DailyFluidSummary(
      date: date,
      totalIntake: totalIntake,
      estimatedOutput: estimation.estimatedVolume,
      estimatedOutputConfidence: estimation.confidenceLevel,
      estimationFactors: estimation.factors,
      intakeStatus: _calculateIntakeStatus(totalIntake),
      intakeEntries: intakeEntries,
      morningShift: ShiftData.fromIntakeEntries(
        'morning',
        morningEntries,
        userAge,
      ),
      afternoonShift: ShiftData.fromIntakeEntries(
        'afternoon',
        afternoonEntries,
        userAge,
      ),
      nightShift: ShiftData.fromIntakeEntries('night', nightEntries, userAge),
      userAge: userAge,
    );
  }

  static FluidStatus _calculateIntakeStatus(double totalIntake) {
    const double minRecommended = 1500; // 1.5L minimum
    const double maxRecommended = 3000; // 3L maximum

    if (totalIntake < minRecommended) {
      return FluidStatus.below;
    } else if (totalIntake > maxRecommended) {
      return FluidStatus.above;
    }
    return FluidStatus.within;
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'totalIntake': totalIntake,
      'estimatedOutput': estimatedOutput,
      'estimatedOutputConfidence': estimatedOutputConfidence,
      'estimationFactors': estimationFactors,
      'intakeStatus': intakeStatus.index,
      'intakeEntries': intakeEntries.map((e) => e.toJson()).toList(),
      'morningShift': morningShift.toJson(),
      'afternoonShift': afternoonShift.toJson(),
      'nightShift': nightShift.toJson(),
      'userAge': userAge,
    };
  }

  factory DailyFluidSummary.fromJson(Map<String, dynamic> json) {
    return DailyFluidSummary(
      date: DateTime.parse(json['date']),
      totalIntake: (json['totalIntake'] as num).toDouble(),
      estimatedOutput: (json['estimatedOutput'] as num?)?.toDouble() ?? 0.0,
      estimatedOutputConfidence: json['estimatedOutputConfidence'] ?? 'Low',
      estimationFactors: List<String>.from(json['estimationFactors'] ?? []),
      intakeStatus: FluidStatus.values[json['intakeStatus'] ?? 0],
      intakeEntries:
          (json['intakeEntries'] as List?)
              ?.map((e) => IntakeEntry.fromJson(e))
              .toList() ??
          [],
      morningShift: ShiftData.fromJson(json['morningShift'] ?? {}),
      afternoonShift: ShiftData.fromJson(json['afternoonShift'] ?? {}),
      nightShift: ShiftData.fromJson(json['nightShift'] ?? {}),
      userAge: json['userAge'] ?? 35,
    );
  }

  String get formattedDate => DateFormat('MMM dd, yyyy').format(date);
}

enum FluidStatus { within, below, above }

extension FluidStatusExtension on FluidStatus {
  String getStatusText() {
    switch (this) {
      case FluidStatus.within:
        return 'Within Range';
      case FluidStatus.below:
        return 'Below Range';
      case FluidStatus.above:
        return 'Above Range';
    }
  }
}

class UserFluidRange {
  final String userId;
  final double dailyIntakeTarget; // in ml
  final double dailyOutputTarget; // in ml
  final Map<String, double> shiftIntakeRangeMin; // shift -> min ml
  final Map<String, double> shiftIntakeRangeMax; // shift -> max ml
  final Map<String, double> shiftOutputRangeMin; // shift -> min ml
  final Map<String, double> shiftOutputRangeMax; // shift -> max ml

  UserFluidRange({
    required this.userId,
    required this.dailyIntakeTarget,
    required this.dailyOutputTarget,
    required this.shiftIntakeRangeMin,
    required this.shiftIntakeRangeMax,
    required this.shiftOutputRangeMin,
    required this.shiftOutputRangeMax,
  });

  // Default ranges for hemodialysis users
  static UserFluidRange defaultRanges(String userId) {
    return UserFluidRange(
      userId: userId,
      dailyIntakeTarget: 1500, // 1.5L typical
      dailyOutputTarget: 1500,
      shiftIntakeRangeMin: {'morning': 400, 'afternoon': 400, 'night': 300},
      shiftIntakeRangeMax: {'morning': 700, 'afternoon': 700, 'night': 600},
      shiftOutputRangeMin: {'morning': 300, 'afternoon': 300, 'night': 200},
      shiftOutputRangeMax: {'morning': 700, 'afternoon': 700, 'night': 600},
    );
  }

  FluidStatus getIntakeStatus(String shift, double intake) {
    final min = shiftIntakeRangeMin[shift] ?? 0;
    final max = shiftIntakeRangeMax[shift] ?? 999999;

    if (intake < min) {
      return FluidStatus.below;
    } else if (intake > max) {
      return FluidStatus.above;
    }
    return FluidStatus.within;
  }

  FluidStatus getOutputStatus(String shift, double output) {
    final min = shiftOutputRangeMin[shift] ?? 0;
    final max = shiftOutputRangeMax[shift] ?? 999999;

    if (output < min) {
      return FluidStatus.below;
    } else if (output > max) {
      return FluidStatus.above;
    }
    return FluidStatus.within;
  }

  String getStatusText(FluidStatus status) {
    switch (status) {
      case FluidStatus.within:
        return 'Within expected range';
      case FluidStatus.below:
        return 'Below expected range';
      case FluidStatus.above:
        return 'Above expected range';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'dailyIntakeTarget': dailyIntakeTarget,
      'dailyOutputTarget': dailyOutputTarget,
      'shiftIntakeRangeMin': shiftIntakeRangeMin,
      'shiftIntakeRangeMax': shiftIntakeRangeMax,
      'shiftOutputRangeMin': shiftOutputRangeMin,
      'shiftOutputRangeMax': shiftOutputRangeMax,
    };
  }

  factory UserFluidRange.fromJson(Map<String, dynamic> json) {
    return UserFluidRange(
      userId: json['userId'],
      dailyIntakeTarget: (json['dailyIntakeTarget'] as num).toDouble(),
      dailyOutputTarget: (json['dailyOutputTarget'] as num).toDouble(),
      shiftIntakeRangeMin: Map<String, double>.from(
        (json['shiftIntakeRangeMin'] as Map).cast<String, double>(),
      ),
      shiftIntakeRangeMax: Map<String, double>.from(
        (json['shiftIntakeRangeMax'] as Map).cast<String, double>(),
      ),
      shiftOutputRangeMin: Map<String, double>.from(
        (json['shiftOutputRangeMin'] as Map).cast<String, double>(),
      ),
      shiftOutputRangeMax: Map<String, double>.from(
        (json['shiftOutputRangeMax'] as Map).cast<String, double>(),
      ),
    );
  }
}
