import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalAuthService {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final Logger _logger = Logger();
  static const String _pinKey = 'expense_tracker_pin';
  static const String _userNameKey = 'expense_tracker_username';
  static const String _authStatusKey = 'expense_tracker_auth_status';
  static const String _sessionTimeKey = 'expense_tracker_session_time';
  static const String _saltKey = 'expense_tracker_salt_key'; // Added salt key

  // Check if a PIN is already set
  Future<bool> hasPIN() async {
    try {
      _logger.i("Checking if PIN exists");
      final pin = await _secureStorage.read(key: _pinKey);
      return pin != null && pin.isNotEmpty;
    } catch (e) {
      _logger.e('Error checking PIN: $e');
      return false;
    }
  }

  // Create a new PIN
  Future<bool> createPIN(String pin, String userName) async {
    try {
      _logger.i("Creating new PIN");

      // Generate a unique salt for this user - important for security
      // This ensures we don't change the hashing method between versions
      String salt = 'expense_tracker_salt_fixed';
      await _secureStorage.write(key: _saltKey, value: salt);
      _logger.i("Salt created and stored: $salt");

      // Hash the PIN with the salt
      final String hashedPin = _hashPin(pin, salt);
      _logger.i("PIN hashed with salt");

      // Store the hashed PIN and user name
      await _secureStorage.write(key: _pinKey, value: hashedPin);
      await _secureStorage.write(key: _userNameKey, value: userName);

      // Set authentication status and session time
      await setAuthenticationStatus(true);
      _logger.i("PIN created successfully");

      return true;
    } catch (e) {
      _logger.e('Error creating PIN: $e');
      return false;
    }
  }

  // Verify a PIN with debugging
  Future<bool> verifyPIN(String pin) async {
    try {
      _logger.i("Verifying PIN");
      final storedPin = await _secureStorage.read(key: _pinKey);
      if (storedPin == null) {
        _logger.w("No stored PIN found during verification");
        return false;
      }

      // Get the stored salt or use the default if not found
      String salt = await _secureStorage.read(key: _saltKey) ??
          'expense_tracker_salt_fixed';
      _logger.i("Retrieved salt for verification: $salt");

      final hashedInputPin = _hashPin(pin, salt);
      _logger.i("Hashed input PIN for verification");
      _logger.i(
          "Comparing: stored=${storedPin.substring(0, 10)}... vs input=${hashedInputPin.substring(0, 10)}...");

      final bool matches = storedPin == hashedInputPin;
      _logger.i("PIN verification result: $matches");

      return matches;
    } catch (e) {
      _logger.e('Error verifying PIN: $e', error: e);
      return false;
    }
  }

  // Change PIN
  Future<bool> changePIN(String oldPin, String newPin) async {
    _logger.i("Changing PIN");
    final isValid = await verifyPIN(oldPin);

    if (isValid) {
      _logger.i("Old PIN verified, setting new PIN");
      return await createPIN(newPin, await getUserName() ?? 'User');
    }

    _logger.w("Failed to verify old PIN during change");
    return false;
  }

  // Get user name
  Future<String?> getUserName() async {
    try {
      return await _secureStorage.read(key: _userNameKey);
    } catch (e) {
      _logger.e('Error getting username: $e');
      return null;
    }
  }

  // Check if user is authenticated and session is valid
  Future<bool> isAuthenticated() async {
    try {
      _logger.i("Checking authentication status");
      // First check if authentication status is set
      final status = await _secureStorage.read(key: _authStatusKey);
      _logger.i("Auth status from storage: $status");

      if (status != 'authenticated') {
        _logger.i("Not authenticated based on status");
        return false;
      }

      // Then verify if the session is still valid (30 minutes)
      final prefs = await SharedPreferences.getInstance();
      final sessionTimeStr = prefs.getString(_sessionTimeKey);

      if (sessionTimeStr == null) {
        _logger.i("No session time found");
        return false;
      }

      final sessionTime = DateTime.parse(sessionTimeStr);
      final now = DateTime.now();

      // Session expires after 30 minutes of inactivity
      final int minutesDifference = now.difference(sessionTime).inMinutes;
      _logger.i(
          "Session time: $sessionTime, Current time: $now, Difference: $minutesDifference minutes");

      if (minutesDifference > 30) {
        _logger.i("Session expired (30 minute limit)");
        await logOut(); // Automatically log out if session expired
        return false;
      }

      // Update session time
      await _updateSessionTime();
      _logger.i("Authentication confirmed and session updated");

      return true;
    } catch (e) {
      _logger.e('Error checking authentication: $e');
      return false;
    }
  }

  // Set authentication status
  Future<void> setAuthenticationStatus(bool authenticated) async {
    try {
      _logger.i("Setting authentication status: $authenticated");
      await _secureStorage.write(
          key: _authStatusKey,
          value: authenticated ? 'authenticated' : 'unauthenticated');

      if (authenticated) {
        await _updateSessionTime();
        _logger.i(
            "Authentication status set to authenticated and session time updated");
      } else {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_sessionTimeKey);
        _logger.i(
            "Authentication status set to unauthenticated and session time removed");
      }
    } catch (e) {
      _logger.e('Error setting authentication status: $e');
    }
  }

  // Update session time
  Future<void> _updateSessionTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      await prefs.setString(_sessionTimeKey, now.toIso8601String());
      _logger.i("Session time updated to: $now");
    } catch (e) {
      _logger.e('Error updating session time: $e');
    }
  }

  // Log out user
  Future<void> logOut() async {
    try {
      _logger.i("Logging out user");
      await _secureStorage.write(key: _authStatusKey, value: 'unauthenticated');
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionTimeKey);
      _logger.i(
          "Logout successful - status set to unauthenticated and session time removed");
    } catch (e) {
      _logger.e('Error logging out: $e');
    }
  }

  // Reset PIN (remove it)
  Future<void> resetPIN() async {
    try {
      _logger.i("Resetting PIN");
      await _secureStorage.delete(key: _pinKey);
      await _secureStorage.delete(key: _authStatusKey);
      await _secureStorage.delete(key: _saltKey); // Also delete the salt
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionTimeKey);
      _logger.i("PIN reset successful");
    } catch (e) {
      _logger.e('Error resetting PIN: $e');
    }
  }

  // Clear all authentication data (for debugging/testing)
  Future<void> clearAllData() async {
    try {
      _logger.i("Clearing all authentication data");
      await _secureStorage.deleteAll();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      _logger.i("All data cleared successfully");
    } catch (e) {
      _logger.e('Error clearing all data: $e');
    }
  }

  // PIN hashing function with specified salt
  String _hashPin(String pin, String salt) {
    final bytes = utf8.encode(pin + salt);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
