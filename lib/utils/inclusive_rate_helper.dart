class InclusiveRateHelper {
  static double exclusiveFromInclusive(double amount, double taxPercent) {
    if (amount <= 0 || taxPercent <= 0) return amount;
    return amount / (1 + (taxPercent / 100));
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
