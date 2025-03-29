import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';

class CurrencyService {
  static final CurrencyService _instance = CurrencyService._internal();
  factory CurrencyService() => _instance;
  CurrencyService._internal();

  final Logger _logger = Logger();

  // Cache exchange rates
  Map<String, dynamic>? _exchangeRates;
  DateTime? _lastUpdated;

  // Simplified keys for SharedPreferences
  static const String _currencyKey = 'app_currency';
  static const String _exchangeRatesKey = 'exchange_rates';
  static const String _ratesLastUpdatedKey = 'rates_last_updated';

  // List of supported currencies (sorted alphabetically)
  final List<String> supportedCurrencies = [
    'AUD',
    'BRL',
    'CAD',
    'CHF',
    'CNY',
    'EUR',
    'GBP',
    'HKD',
    'INR',
    'JPY',
    'KRW',
    'MXN',
    'NGN',
    'NZD',
    'RUB',
    'SEK',
    'SGD',
    'USD',
    'ZAR',
  ];

  // Currency symbols for formatting
  final Map<String, String> currencySymbols = {
    'USD': '\$',
    'EUR': '€',
    'GBP': '£',
    'JPY': '¥',
    'AUD': 'A\$',
    'CAD': 'C\$',
    'CHF': 'Fr',
    'CNY': '¥',
    'INR': '₹',
    'BRL': 'R\$',
    'MXN': 'Mex\$',
    'SEK': 'kr',
    'SGD': 'S\$',
    'HKD': 'HK\$',
    'NZD': 'NZ\$',
    'ZAR': 'R',
    'RUB': '₽',
    'KRW': '₩',
    'NGN': '₦',
  };

  // App's currency
  String _appCurrency = 'USD';
  String _appCurrencySymbol = '\$';
  bool _isInitialized = false;

  // Initialize and load saved currency preference
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      // Get saved currency or default to USD
      final savedCurrency = prefs.getString(_currencyKey);
      if (savedCurrency != null) {
        final parts = savedCurrency.split('|');
        if (parts.length == 2) {
          _appCurrency = parts[0];
          _appCurrencySymbol = parts[1];
        } else {
          _appCurrency = 'USD';
          _appCurrencySymbol = '\$';
        }
      } else {
        _appCurrency = 'USD';
        _appCurrencySymbol = '\$';
      }

      // Try to load cached exchange rates
      final cachedRates = prefs.getString(_exchangeRatesKey);
      if (cachedRates != null) {
        _exchangeRates = jsonDecode(cachedRates);
        final cachedDate = prefs.getString(_ratesLastUpdatedKey);
        if (cachedDate != null) {
          _lastUpdated = DateTime.parse(cachedDate);
        }
      }

      _isInitialized = true;
      _logger.i(
          'CurrencyService initialized with currency: $_appCurrency ($_appCurrencySymbol)');
    } catch (e) {
      _logger.e('Error initializing CurrencyService: $e');
      // Default to USD if there's an error
      _appCurrency = 'USD';
      _appCurrencySymbol = '\$';
    }
  }

  // Get app's currency code
  Future<String> getCurrencyCode() async {
    await initialize();
    return _appCurrency;
  }

  // Get app's currency symbol
  Future<String> getCurrencySymbol() async {
    await initialize();
    return _appCurrencySymbol;
  }

  // Set the app's currency code and symbol
  Future<bool> setCurrency(String currencyCode, String currencySymbol) async {
    try {
      if (!supportedCurrencies.contains(currencyCode)) {
        throw Exception('Unsupported currency: $currencyCode');
      }

      final prefs = await SharedPreferences.getInstance();

      // Store as "USD|$" format
      final currencyString = '$currencyCode|$currencySymbol';
      await prefs.setString(_currencyKey, currencyString);

      // Update in-memory values
      _appCurrency = currencyCode;
      _appCurrencySymbol = currencySymbol;

      _logger.i('Currency set to: $currencyCode ($currencySymbol)');
      return true;
    } catch (e) {
      _logger.e('Error setting currency: $e');
      return false;
    }
  }

  // Fetch latest exchange rates from an API
  Future<Map<String, dynamic>> getExchangeRates() async {
    try {
      // Check if we have recent rates cached (refresh every 24 hours)
      if (_exchangeRates != null && _lastUpdated != null) {
        final difference = DateTime.now().difference(_lastUpdated!);
        if (difference.inHours < 24) {
          return _exchangeRates!;
        }
      }

      // If not, fetch new rates
      // Note: You'll need to sign up for an API key with a service like Open Exchange Rates
      // or implement a different approach for a real app
      final demoRates = {
        "USD": 1,
        "EUR": 0.92,
        "GBP": 0.78,
        "JPY": 151.20,
        "AUD": 1.52,
        "CAD": 1.36,
        "CHF": 0.89,
        "CNY": 7.21,
        "INR": 83.45,
        "BRL": 5.07,
        "MXN": 17.03,
        "SEK": 10.42,
        "SGD": 1.34,
        "HKD": 7.82,
        "NZD": 1.62,
        "ZAR": 18.42,
        "RUB": 91.30,
        "KRW": 1335.12,
        "NGN": 1520.50
      };

      _exchangeRates = demoRates;
      _lastUpdated = DateTime.now();

      // Cache the rates in shared preferences for offline use
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_exchangeRatesKey, jsonEncode(_exchangeRates));
      await prefs.setString(
          _ratesLastUpdatedKey, _lastUpdated!.toIso8601String());

      _logger.i('Exchange rates updated');
      return _exchangeRates!;
    } catch (e) {
      _logger.e('Error fetching exchange rates: $e');

      // Use fallback if we have no rates
      if (_exchangeRates == null) {
        return {
          "USD": 1,
          "EUR": 0.92,
          "GBP": 0.78,
          "JPY": 151.20,
          "AUD": 1.52,
          "CAD": 1.36,
          "CHF": 0.89,
          "CNY": 7.21,
          "INR": 83.45,
          "BRL": 5.07,
          "MXN": 17.03,
          "SEK": 10.42,
          "SGD": 1.34,
          "HKD": 7.82,
          "NZD": 1.62,
          "ZAR": 18.42,
          "RUB": 91.30,
          "KRW": 1335.12,
          "NGN": 1520.50
        };
      }

      // Otherwise return cached rates
      return _exchangeRates!;
    }
  }

  // Convert amount from one currency to another
  Future<double> convertCurrency(
      double amount, String fromCurrency, String toCurrency) async {
    try {
      // If currencies are the same, no conversion needed
      if (fromCurrency == toCurrency) {
        return amount;
      }

      await initialize();
      final rates = await getExchangeRates();

      // Rates are based on USD as the base currency
      // Convert to USD first, then to target currency
      double amountInUSD;
      if (fromCurrency == 'USD') {
        amountInUSD = amount;
      } else {
        if (!rates.containsKey(fromCurrency)) {
          throw Exception('Unsupported currency: $fromCurrency');
        }
        amountInUSD = amount / (rates[fromCurrency] as double);
      }

      // Convert from USD to target currency
      if (toCurrency == 'USD') {
        return amountInUSD;
      } else {
        if (!rates.containsKey(toCurrency)) {
          throw Exception('Unsupported currency: $toCurrency');
        }
        return amountInUSD * (rates[toCurrency] as double);
      }
    } catch (e) {
      _logger.e('Error converting currency: $e');
      // Return original amount if conversion fails
      return amount;
    }
  }

  // Format currency amount
  Future<String> formatAmount(double amount, String currencyCode) async {
    await initialize();

    try {
      final symbol = currencySymbols[currencyCode] ?? currencyCode;

      // For JPY and KRW, no decimal places
      if (currencyCode == 'JPY' || currencyCode == 'KRW') {
        return '$symbol${amount.round()}';
      }

      // For other currencies, 2 decimal places
      return '$symbol${amount.toStringAsFixed(2)}';
    } catch (e) {
      _logger.e('Error formatting amount: $e');
      return '$currencyCode ${amount.toStringAsFixed(2)}';
    }
  }

  // Format amount using app's currency
  Future<String> formatAmountWithAppCurrency(double amount) async {
    await initialize();
    return formatAmount(amount, _appCurrency);
  }

  // Get exchange rate between two currencies
  Future<double> getExchangeRate(String fromCurrency, String toCurrency) async {
    if (fromCurrency == toCurrency) return 1.0;

    final rates = await getExchangeRates();

    if (fromCurrency == 'USD') {
      return rates[toCurrency] as double;
    } else if (toCurrency == 'USD') {
      return 1.0 / (rates[fromCurrency] as double);
    } else {
      // Convert via USD
      final fromToUSD = 1.0 / (rates[fromCurrency] as double);
      final usdToTarget = rates[toCurrency] as double;
      return fromToUSD * usdToTarget;
    }
  }
}
