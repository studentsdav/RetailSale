class InclusiveRateHelper {
  static double exclusiveFromInclusive(double amount, double taxPercent) {
    if (amount <= 0 || taxPercent <= 0) return amount;
    final result = amount / (1 + (taxPercent / 100));
    // Round to 2 decimal places to avoid floating-point noise (e.g. 730.3559322...)
    return double.parse(result.toStringAsFixed(2));
  }

  static String previewText({
    required String label,
    required double inclusiveAmount,
    required double taxPercent,
  }) {
    final exclusive = exclusiveFromInclusive(inclusiveAmount, taxPercent);
    return '$label exclusive: ${exclusive.toStringAsFixed(2)}';
  }
}
