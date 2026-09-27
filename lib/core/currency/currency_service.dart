import 'package:intl/intl.dart';
import '../../models/inventory/settings/system_settings_model.dart';

class CurrencyService {
  static String _symbol = 'KSh';
  static String _code = 'KES';
  static String _position = 'BEFORE'; // 'BEFORE' or 'AFTER'
  static int _decimals = 2;

  static String get symbol => _symbol;
  static String get code => _code;
  static String get position => _position;
  static int get decimals => _decimals;

  static bool get _hasSpacing {
    final sym = _symbol.trim();
    if (sym.isEmpty) return false;
    // Single character symbols ($, ₹, £, €, ¥, ৳, ₱, ₩, etc.) have no space
    if (sym.length == 1) return false;
    // Multi-letter currency codes / words (KSh, AED, USD, KES, Rs., etc.) have a space
    return true;
  }

  static void updateFromSettings(SystemSettings settings) {
    _symbol = settings.baseCurrencySymbol.isNotEmpty ? settings.baseCurrencySymbol : 'KSh';
    _code = settings.baseCurrencyCode.isNotEmpty ? settings.baseCurrencyCode : 'KES';
    _position = settings.currencySymbolPosition;
    _decimals = settings.currencyDecimals;
  }

  static NumberFormat get currencyFormat => NumberFormat.currency(
        locale: _code == 'INR' ? 'en_IN' : 'en_US',
        symbol: _position == 'AFTER' ? '' : (_hasSpacing ? '$_symbol ' : _symbol),
        decimalDigits: _decimals,
      );

  static NumberFormat get compactCurrencyFormat => NumberFormat.compactCurrency(
        locale: _code == 'INR' ? 'en_IN' : 'en_US',
        symbol: _hasSpacing ? '$_symbol ' : _symbol,
      );

  static String format(num amount) {
    final formattedAmount = amount.toDouble().toStringAsFixed(_decimals);
    final sym = _symbol.trim();
    final space = _hasSpacing ? ' ' : '';
    if (_position == 'AFTER') {
      return '$formattedAmount$space$sym';
    } else {
      return '$sym$space$formattedAmount';
    }
  }

  static String formatWithSymbol(num amount, String overrideSymbol) {
    final formattedAmount = amount.toDouble().toStringAsFixed(_decimals);
    final sym = overrideSymbol.trim();
    final hasSpace = sym.length > 1;
    final space = hasSpace ? ' ' : '';
    return '$sym$space$formattedAmount';
  }
}
