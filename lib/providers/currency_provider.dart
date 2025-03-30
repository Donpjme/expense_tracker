import 'package:flutter/foundation.dart';
import 'package:expense_tracker/services/currency_service.dart';
import 'package:expense_tracker/services/currency_lock_service.dart';
import 'package:logger/logger.dart';

/// Provider for app-wide currency settings
class CurrencyProvider with ChangeNotifier {
  final CurrencyService _currencyService = CurrencyService();
  final CurrencyLockService _lockService = CurrencyLockService();
  final Logger _logger = Logger();

  String _currencyCode = 'USD';
  String _currencySymbol = '\$';
  bool _isInitialized = false;
  bool _isCurrencyLocked = false;

  CurrencyProvider() {
    _initialize();
  }

  String get currencyCode => _currencyCode;
  String get currencySymbol => _currencySymbol;
  bool get isInitialized => _isInitialized;
  bool get isCurrencyLocked => _isCurrencyLocked;

  /// Initialize the provider with saved currency information
  Future<void> _initialize() async {
    try {
      await _currencyService.initialize();
      _currencyCode = await _currencyService.getCurrencyCode();
      _currencySymbol = await _currencyService.getCurrencySymbol();

      // Check if currency is locked using the dedicated service
      _isCurrencyLocked = await _lockService.isCurrencyLocked();

      _isInitialized = true;
      _logger.i(
          'CurrencyProvider initialized: $_currencyCode ($_currencySymbol), locked: $_isCurrencyLocked');
      notifyListeners();
    } catch (e) {
      _logger.e('Error initializing CurrencyProvider: $e');
      // Default to USD if there's an error
      _currencyCode = 'USD';
      _currencySymbol = '\$';
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Update the app's currency - respects currency lock
  Future<void> setCurrency(String currencyCode, String currencySymbol) async {
    try {
      // Check if currency is locked before making changes
      _isCurrencyLocked = await _lockService.isCurrencyLocked();

      if (_isCurrencyLocked) {
        _logger.w(
            'Attempted to change locked currency from $_currencyCode to $currencyCode');
        return; // Do nothing if currency is locked
      }

      if (_currencyCode == currencyCode && _currencySymbol == currencySymbol) {
        return; // No change needed
      }

      final success =
          await _currencyService.setCurrency(currencyCode, currencySymbol);

      if (success) {
        _currencyCode = currencyCode;
        _currencySymbol = currencySymbol;
        _logger.i('Currency updated to: $currencyCode ($currencySymbol)');
        notifyListeners();
      } else {
        _logger.e('Failed to update currency to $currencyCode');
      }
    } catch (e) {
      _logger.e('Error setting currency to $currencyCode: $e');
      rethrow;
    }
  }

  /// Lock the currency to prevent future changes
  Future<bool> lockCurrency() async {
    try {
      final success = await _lockService.lockCurrency();
      if (success) {
        _isCurrencyLocked = true;
        _logger.i('Currency locked: $_currencyCode');
        notifyListeners();
      }
      return success;
    } catch (e) {
      _logger.e('Error locking currency: $e');
      return false;
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

    try {
      final converted = await _currencyService.convertCurrency(
          amount, fromCurrency, _currencyCode);
      _logger.i(
          'Converted $amount $fromCurrency to ${converted.toStringAsFixed(2)} $_currencyCode');
      return converted;
    } catch (e) {
      _logger.e('Error converting from $fromCurrency to $_currencyCode: $e');
      // Return the original amount if conversion fails
      return amount;
    }
  }

  /// Convert from app currency to another currency
  Future<double> convertFromAppCurrency(
      double amount, String toCurrency) async {
    if (toCurrency == _currencyCode) return amount;

    try {
      final converted = await _currencyService.convertCurrency(
          amount, _currencyCode, toCurrency);
      _logger.i(
          'Converted $amount $_currencyCode to ${converted.toStringAsFixed(2)} $toCurrency');
      return converted;
    } catch (e) {
      _logger.e('Error converting from $_currencyCode to $toCurrency: $e');
      // Return the original amount if conversion fails
      return amount;
    }
  }

  /// Force refresh currency data (useful after major changes)
  Future<void> refreshCurrencyData() async {
    try {
      await _currencyService.initialize();
      final newCode = await _currencyService.getCurrencyCode();
      final newSymbol = await _currencyService.getCurrencySymbol();
      final isLocked = await _lockService.isCurrencyLocked();

      if (_currencyCode != newCode ||
          _currencySymbol != newSymbol ||
          _isCurrencyLocked != isLocked) {
        _currencyCode = newCode;
        _currencySymbol = newSymbol;
        _isCurrencyLocked = isLocked;
        _logger.i(
            'Currency data refreshed: $_currencyCode ($_currencySymbol), locked: $_isCurrencyLocked');
        notifyListeners();
      }
    } catch (e) {
      _logger.e('Error refreshing currency data: $e');
    }
  }
}
