import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';

/// Service class to handle currency locking functionality
class CurrencyLockService {
  // Singleton instance
  static final CurrencyLockService _instance = CurrencyLockService._internal();
  factory CurrencyLockService() => _instance;
  CurrencyLockService._internal();

  // Keys for shared preferences
  static const String _currencyLockedKey = 'currency_locked';

  // Logger instance
  final Logger _logger = Logger();

  // In-memory cache of lock status
  bool? _isCurrencyLocked;

  /// Check if currency is locked
  Future<bool> isCurrencyLocked() async {
    try {
      // Return cached value if available
      if (_isCurrencyLocked != null) {
        return _isCurrencyLocked!;
      }

      final prefs = await SharedPreferences.getInstance();
      final lockStatus = prefs.getBool(_currencyLockedKey) ?? false;

      // Update cache
      _isCurrencyLocked = lockStatus;

      _logger.i('Currency lock status: ${lockStatus ? "Locked" : "Unlocked"}');
      return lockStatus;
    } catch (e) {
      _logger.e('Error checking currency lock status: $e');
      // Default to unlocked if there's an error
      return false;
    }
  }

  /// Lock the currency to prevent future changes
  Future<bool> lockCurrency() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_currencyLockedKey, true);
      _isCurrencyLocked = true;
      _logger.i('Currency has been locked');
      return true;
    } catch (e) {
      _logger.e('Error locking currency: $e');
      return false;
    }
  }

  /// Unlock the currency (for administrative purposes only)
  /// This should not be exposed to regular users
  Future<bool> unlockCurrency() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_currencyLockedKey, false);
      _isCurrencyLocked = false;
      _logger.i('Currency has been unlocked');
      return true;
    } catch (e) {
      _logger.e('Error unlocking currency: $e');
      return false;
    }
  }

  /// Clear the in-memory cache (useful for testing)
  void clearCache() {
    _isCurrencyLocked = null;
    _logger.d('Currency lock cache cleared');
  }
}
