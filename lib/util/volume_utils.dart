class VolumeUtils {
  static const double _mlPerOz = 29.5735;
  static const double _mlPerL = 1000.0;

  static String normalizeUnit(String unit) {
    final normalized = unit.trim();
    if (normalized.toLowerCase() == 'l') return 'L';
    if (normalized.toLowerCase() == 'oz') return 'oz';
    return 'ml';
  }

  static double toMl(double value, String unit) {
    final normalized = normalizeUnit(unit);
    if (normalized == 'oz') return value * _mlPerOz;
    if (normalized == 'L') return value * _mlPerL;
    return value;
  }

  static double fromMl(double ml, String unit) {
    final normalized = normalizeUnit(unit);
    if (normalized == 'oz') return ml / _mlPerOz;
    if (normalized == 'L') return ml / _mlPerL;
    return ml;
  }

  static String format(double ml, String unit, {int? decimals}) {
    final normalized = normalizeUnit(unit);
    final value = fromMl(ml, normalized);
    final places =
        decimals ??
        (normalized == 'ml'
            ? 0
            : normalized == 'oz'
            ? 1
            : 2);
    return '${value.toStringAsFixed(places)} $normalized';
  }
}
