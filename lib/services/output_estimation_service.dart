import '../models/io_models.dart';

/// Service for calculating estimated urine output based on fluid intake
/// Uses proven medical formulas and factors affecting fluid balance
class OutputEstimationService {
  /// Estimates urine output based on intake considering various physiological factors
  /// Returns estimated output volume in ml
  ///
  /// Key factors considered:
  /// - Average healthy adult excretes 50-70% of fluid intake as urine
  /// - Age affects kidney function (decreases ~1% per year after 30)
  /// - Time of day affects metabolism rate
  /// - Fluid type affects absorption and excretion rates
  ///
  /// Note: This is a rough estimation for tracking purposes only.
  /// Individual variations exist due to medical conditions, medications,
  /// activity level, temperature, humidity, and other factors.
  static EstimatedOutput calculateEstimatedOutput({
    required List<IntakeEntry> intakeEntries,
    required int userAge,
    required String timeframe, // 'daily', 'shift'
  }) {
    if (intakeEntries.isEmpty) {
      return EstimatedOutput(
        estimatedVolume: 0,
        confidenceLevel: 'N/A',
        factors: ['No intake data available'],
        totalIntake: 0,
      );
    }

    // Calculate total intake
    double totalIntake = 0;
    double adjustedIntake = 0;
    List<String> factors = [];

    for (final entry in intakeEntries) {
      totalIntake += entry.volume;

      // Adjust intake based on fluid type absorption rates
      double absorptionRate = _getFluidAbsorptionRate(entry.fluidType);
      adjustedIntake += entry.volume * absorptionRate;
    }

    // Base urine output percentage (healthy adult: 50-70% of intake)
    double baseOutputPercentage = 0.60; // 60% baseline

    // Age factor: kidney function decreases with age
    double ageFactor = _calculateAgeFactor(userAge);
    factors.add('Age adjustment: ${(ageFactor * 100).toStringAsFixed(0)}%');

    // Time-based metabolic factor
    double timeFactor = _calculateTimeFactor(intakeEntries);
    factors.add('Time-based metabolism factor applied');

    // Fluid variety factor
    double varietyFactor = _calculateVarietyFactor(intakeEntries);
    factors.add('Fluid type variety considered');

    // Calculate estimated output
    double estimatedOutput =
        adjustedIntake *
        baseOutputPercentage *
        ageFactor *
        timeFactor *
        varietyFactor;

    // Determine confidence level
    String confidenceLevel = _getConfidenceLevel(intakeEntries.length, userAge);

    // Add general factors note
    factors.addAll([
      'Individual variations may apply',
      'Medical conditions affect accuracy',
      'Physical activity not factored',
      'Environmental factors not considered',
    ]);

    return EstimatedOutput(
      estimatedVolume: estimatedOutput,
      confidenceLevel: confidenceLevel,
      factors: factors,
      totalIntake: totalIntake,
    );
  }

  /// Get absorption rate for different fluid types
  static double _getFluidAbsorptionRate(String fluidType) {
    switch (fluidType.toLowerCase()) {
      case 'water':
        return 0.95; // Water is absorbed efficiently
      case 'juice':
        return 0.85; // Sugar content slows absorption slightly
      case 'coffee':
      case 'tea':
        return 0.80; // Caffeine has mild diuretic effect
      case 'milk':
        return 0.75; // Fat/protein content affects absorption
      case 'soup':
      case 'broth':
        return 0.70; // Sodium content affects fluid retention
      case 'soda':
      case 'soft drink':
        return 0.80; // Sugar and additives affect processing
      case 'sports drink':
        return 0.85; // Electrolytes improve retention
      case 'alcohol':
        return 1.10; // Alcohol has diuretic effect (more output)
      default:
        return 0.85; // Default for unknown fluids
    }
  }

  /// Calculate age adjustment factor for kidney function
  static double _calculateAgeFactor(int age) {
    if (age <= 30) {
      return 1.0; // Peak kidney function
    } else if (age <= 50) {
      return 0.95; // Slight decrease
    } else if (age <= 70) {
      return 0.90; // Moderate decrease
    } else {
      return 0.85; // More significant decrease
    }
  }

  /// Calculate time-based metabolic factor
  static double _calculateTimeFactor(List<IntakeEntry> entries) {
    // Morning intake is processed more efficiently
    // Evening intake may result in less immediate output
    double morningWeight = 0;
    double afternoonWeight = 0;
    double nightWeight = 0;

    for (final entry in entries) {
      switch (entry.shift) {
        case 'morning':
          morningWeight += entry.volume;
          break;
        case 'afternoon':
          afternoonWeight += entry.volume;
          break;
        case 'night':
          nightWeight += entry.volume;
          break;
      }
    }

    double totalWeight = morningWeight + afternoonWeight + nightWeight;
    if (totalWeight == 0) return 1.0;

    // Morning has highest output efficiency, night has lowest
    double efficiency =
        (morningWeight * 1.1 + afternoonWeight * 1.0 + nightWeight * 0.9) /
        totalWeight;
    return efficiency;
  }

  /// Calculate variety factor based on fluid types
  static double _calculateVarietyFactor(List<IntakeEntry> entries) {
    Set<String> uniqueTypes = entries
        .map((e) => e.fluidType.toLowerCase())
        .toSet();

    if (uniqueTypes.length == 1) {
      return 1.0; // Single fluid type
    } else if (uniqueTypes.length <= 3) {
      return 0.95; // Good variety, slightly more predictable
    } else {
      return 0.90; // High variety, less predictable
    }
  }

  /// Determine confidence level based on data quality
  static String _getConfidenceLevel(int entryCount, int age) {
    int score = 0;

    // Entry count factor
    if (entryCount >= 4)
      score += 2;
    else if (entryCount >= 2)
      score += 1;

    // Age reliability factor
    if (age >= 18 && age <= 65)
      score += 2;
    else
      score += 1;

    switch (score) {
      case 4:
        return 'High';
      case 3:
        return 'Moderate';
      case 2:
        return 'Low';
      default:
        return 'Very Low';
    }
  }
}

/// Result class for estimated output calculations
class EstimatedOutput {
  final double estimatedVolume;
  final String confidenceLevel;
  final List<String> factors;
  final double totalIntake;

  EstimatedOutput({
    required this.estimatedVolume,
    required this.confidenceLevel,
    required this.factors,
    required this.totalIntake,
  });

  /// Get user-friendly explanation text
  String get explanationText {
    return 'Estimated output is ${estimatedVolume.toStringAsFixed(0)} ml '
        '(${((estimatedVolume / totalIntake) * 100).toStringAsFixed(0)}% of ${totalIntake.toStringAsFixed(0)} ml intake). '
        'Confidence: $confidenceLevel. This is a rough estimation considering various factors affecting fluid balance.';
  }
}
