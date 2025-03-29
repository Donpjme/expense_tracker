import 'package:flutter/foundation.dart';
import 'package:expense_tracker/services/currency_service.dart';

/// Provider for app-wide currency settings
class CurrencyProvider with ChangeNotifier {
  final CurrencyService _currencyService = CurrencyService();

  String _currencyCode = 'USD';
  String _currencySymbol = '\$';
  bool _isInitialized = false;

  CurrencyProvider() {
    _initialize();
  }

  String get currencyCode => _currencyCode;
  String get currencySymbol => _currencySymbol;
  bool get isInitialized => _isInitialized;

  /// Initialize the provider with saved currency information
  Future<void> _initialize() async {
    try {
      await _currencyService.initialize();
      _currencyCode = await _currencyService.getCurrencyCode();
      _currencySymbol = await _currencyService.getCurrencySymbol();
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      // Default to USD if there's an error
      _currencyCode = 'USD';
      _currencySymbol = '\$';
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Update the app's currency
  Future<void> setCurrency(String currencyCode, String currencySymbol) async {
    if (_currencyCode == currencyCode && _currencySymbol == currencySymbol) {
      return; // No change
    }

    try {
      final success =
          await _currencyService.setCurrency(currencyCode, currencySymbol);
      if (success) {
        _currencyCode = currencyCode;
        _currencySymbol = currencySymbol;
        notifyListeners();
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Format an amount with the current currency symbol
  String formatAmount(double amount) {
    if (currencyCode == 'JPY' || currencyCode == 'KRW') {
      return '$_currencySymbol${amount.round()}';
    }
    return '$_currencySymbol${amount.toStringAsFixed(2)}';
  }

  /// Convert an amount from one currency to the current app currency
  Future<double> convertToAppCurrency(
      double amount, String fromCurrency) async {
    if (fromCurrency == _currencyCode) return amount;

    return _currencyService.convertCurrency(
        amount, fromCurrency, _currencyCode);
  }

  /// Convert from app currency to another currency
  Future<double> convertFromAppCurrency(
      double amount, String toCurrency) async {
    if (toCurrency == _currencyCode) return amount;

    return _currencyService.convertCurrency(amount, _currencyCode, toCurrency);
  }
}
