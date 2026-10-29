/// Utility functions for safe JSON type parsing to prevent runtime type cast exceptions.

double asDouble(dynamic val, [double defaultVal = 0.0]) {
  if (val == null) return defaultVal;
  if (val is num) return val.toDouble();
  if (val is String) {
    final cleaned = val.replaceAll(',', '').trim();
    return double.tryParse(cleaned) ?? defaultVal;
  }
  return defaultVal;
}

double? asDoubleOrNull(dynamic val) {
  if (val == null) return null;
  if (val is num) return val.toDouble();
  if (val is String) {
    final cleaned = val.replaceAll(',', '').trim();
    return double.tryParse(cleaned);
  }
  return null;
}

int asInt(dynamic val, [int defaultVal = 0]) {
  if (val == null) return defaultVal;
  if (val is int) return val;
  if (val is num) return val.toInt();
  if (val is String) {
    final cleaned = val.replaceAll(',', '').trim();
    return int.tryParse(cleaned) ?? (double.tryParse(cleaned)?.toInt() ?? defaultVal);
  }
  return defaultVal;
}
