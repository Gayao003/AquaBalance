import 'package:intl/intl.dart';

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
  final double totalOutput;
  final int intakeCount;
  final int outputCount;

  ShiftData({
    required this.totalIntake,
    required this.totalOutput,
    required this.intakeCount,
    required this.outputCount,
  });

  Map<String, dynamic> toJson() {
    return {
      'totalIntake': totalIntake,
      'totalOutput': totalOutput,
      'intakeCount': intakeCount,
      'outputCount': outputCount,
    };
  }

  factory ShiftData.fromJson(Map<String, dynamic> json) {
    return ShiftData(
      totalIntake: (json['totalIntake'] as num).toDouble(),
      totalOutput: (json['totalOutput'] as num).toDouble(),
      intakeCount: json['intakeCount'],
      outputCount: json['outputCount'],
    );
  }
}

class DailyFluidSummary {
  final DateTime date;
  final double totalIntake;
  final double totalOutput;
  final FluidStatus intakeStatus;
  final FluidStatus outputStatus;
  final List<IntakeEntry> intakeEntries;
  final List<OutputEntry> outputEntries;
  final ShiftData morningShift;
  final ShiftData afternoonShift;
  final ShiftData nightShift;

  DailyFluidSummary({
    required this.date,
    required this.totalIntake,
    required this.totalOutput,
    required this.intakeStatus,
    required this.outputStatus,
    required this.intakeEntries,
    required this.outputEntries,
    required this.morningShift,
    required this.afternoonShift,
    required this.nightShift,
  });

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'totalIntake': totalIntake,
      'totalOutput': totalOutput,
      'intakeStatus': intakeStatus.index,
      'outputStatus': outputStatus.index,
      'intakeEntries': intakeEntries.map((e) => e.toJson()).toList(),
      'outputEntries': outputEntries.map((e) => e.toJson()).toList(),
      'morningShift': morningShift.toJson(),
      'afternoonShift': afternoonShift.toJson(),
      'nightShift': nightShift.toJson(),
    };
  }

  factory DailyFluidSummary.fromJson(Map<String, dynamic> json) {
    return DailyFluidSummary(
      date: DateTime.parse(json['date']),
      totalIntake: (json['totalIntake'] as num).toDouble(),
      totalOutput: (json['totalOutput'] as num).toDouble(),
      intakeStatus: FluidStatus.values[json['intakeStatus']],
      outputStatus: FluidStatus.values[json['outputStatus']],
      intakeEntries: (json['intakeEntries'] as List)
          .map((e) => IntakeEntry.fromJson(e))
          .toList(),
      outputEntries: (json['outputEntries'] as List)
          .map((e) => OutputEntry.fromJson(e))
          .toList(),
      morningShift: ShiftData.fromJson(json['morningShift']),
      afternoonShift: ShiftData.fromJson(json['afternoonShift']),
      nightShift: ShiftData.fromJson(json['nightShift']),
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
