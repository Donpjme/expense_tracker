import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;

  AuthService._internal();

  final Logger _logger = Logger();
  static const String _pinKey = 'user_pin';
  static const String _pinEnabledKey = 'pin_auth_enabled';

  // Check if PIN authentication is enabled
  Future<bool> isPinAuthEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_pinEnabledKey) ?? false;
    } catch (e) {
      _logger.e('Error checking if PIN auth is enabled: $e');
      return false;
    }
  }

  // Enable or disable PIN authentication
  Future<void> setPinAuthEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_pinEnabledKey, enabled);
    } catch (e) {
      _logger.e('Error setting PIN auth enabled: $e');
    }
  }

  // Set a new PIN
  Future<bool> setPin(String pin) async {
    if (pin.length < 4) {
      return false;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pinKey, pin);
      await prefs.setBool(_pinEnabledKey, true);
      return true;
    } catch (e) {
      _logger.e('Error setting PIN: $e');
      return false;
    }
  }

  // Verify if entered PIN matches stored PIN
  Future<bool> verifyPin(String pin) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedPin = prefs.getString(_pinKey);

      if (storedPin == null) {
        return false;
      }

      return pin == storedPin;
    } catch (e) {
      _logger.e('Error verifying PIN: $e');
      return false;
    }
  }

  // Check if PIN is set
  Future<bool> isPinSet() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pin = prefs.getString(_pinKey);
      return pin != null && pin.isNotEmpty;
    } catch (e) {
      _logger.e('Error checking if PIN is set: $e');
      return false;
    }
  }

  // Clear PIN
  Future<void> clearPin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pinKey);
      await prefs.setBool(_pinEnabledKey, false);
    } catch (e) {
      _logger.e('Error clearing PIN: $e');
    }
  }
}
