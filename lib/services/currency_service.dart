import 'dart:convert';
import 'package:http/http.dart' as http;
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

  // Keys for SharedPreferences
  static const String _currencyCodeKey = 'currency_code';
  static const String _currencySymbolKey = 'currency_symbol';
  static const String _defaultCurrencyKey = 'defaultCurrency';

  // List of supported currencies
  final List<String> supportedCurrencies = [
    'USD', 'EUR', 'GBP', 'JPY', 'AUD', 'CAD', 'CHF', 'CNY', 'INR',
    'BRL', 'MXN', 'SEK', 'SGD', 'HKD', 'NZD', 'ZAR', 'RUB', 'KRW', 'NGN'
    // Added NGN (Nigerian Naira)
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
    'NGN': '₦', // Added Nigerian Naira symbol
  };

  // User's default currency (stored in shared preferences)
  String _defaultCurrency = 'USD';

  // Initialize and load saved currency preference
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _defaultCurrency = prefs.getString(_defaultCurrencyKey) ?? 'USD';

      // Try to load cached exchange rates
      final cachedRates = prefs.getString('exchangeRates');
      if (cachedRates != null) {
        _exchangeRates = jsonDecode(cachedRates);
        final cachedDate = prefs.getString('ratesLastUpdated');
        if (cachedDate != null) {
          _lastUpdated = DateTime.parse(cachedDate);
        }
      }

      _logger.i(
          'CurrencyService initialized with default currency: $_defaultCurrency');
    } catch (e) {
      _logger.e('Error initializing CurrencyService: $e');
      // Default to USD if there's an error
      _defaultCurrency = 'USD';
    }
  }

  // Get user's preferred currency
  String get defaultCurrency => _defaultCurrency;

  // Set user's preferred currency
  Future<void> setDefaultCurrency(String currency) async {
    if (!supportedCurrencies.contains(currency)) {
      throw Exception('Unsupported currency: $currency');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_defaultCurrencyKey, currency);
      _defaultCurrency = currency;
      _logger.i('Default currency set to: $currency');
    } catch (e) {
      _logger.e('Error setting default currency: $e');
      rethrow;
    }
  }

  // ADDED: Get the current currency code (e.g., 'USD')
  Future<String> getCurrencyCode() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      return preferences.getString(_currencyCodeKey) ?? _defaultCurrency;
    } catch (e) {
      _logger.e('Error getting currency code: $e');
      return _defaultCurrency; // Return default on error
    }
  }

  // ADDED: Get the current currency symbol (e.g., '$')
  Future<String> getCurrencySymbol() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      String symbol = preferences.getString(_currencySymbolKey) ?? '';

      if (symbol.isEmpty) {
        // If no symbol is saved, get the symbol for the current currency code
        final code = await getCurrencyCode();
        symbol = currencySymbols[code] ?? '\$';
      }

      return symbol;
    } catch (e) {
      _logger.e('Error getting currency symbol: $e');
      return '\$'; // Return default on error
    }
  }

  // ADDED: Set the currency code and symbol - needed by CurrencySettingsScreen
  Future<bool> setCurrency(String currencyCode, String currencySymbol) async {
    try {
      final preferences = await SharedPreferences.getInstance();

      // Save both values
      await preferences.setString(_currencyCodeKey, currencyCode);
      await preferences.setString(_currencySymbolKey, currencySymbol);
      // Also update default currency for compatibility
      await preferences.setString(_defaultCurrencyKey, currencyCode);
      _defaultCurrency = currencyCode;

      _logger.i('Currency updated: $currencyCode ($currencySymbol)');
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
      // For demonstration, replace YOUR_API_KEY with your actual API key
      const apiKey = 'YOUR_API_KEY';
      final response = await http.get(
        Uri.parse(
            'https://openexchangerates.org/api/latest.json?app_id=$apiKey'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _exchangeRates = data['rates'];
        _lastUpdated = DateTime.now();

        // Cache the rates in shared preferences for offline use
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('exchangeRates', jsonEncode(_exchangeRates));
        await prefs.setString(
            'ratesLastUpdated', _lastUpdated!.toIso8601String());

        _logger.i('Exchange rates updated successfully');
        return _exchangeRates!;
      } else {
        // Try to use cached rates if available
        if (_exchangeRates != null) {
          _logger.w(
              'Failed to fetch new rates, using cached rates from: ${_lastUpdated?.toIso8601String()}');
          return _exchangeRates!;
        }

        throw Exception(
            'Failed to load exchange rates. Status code: ${response.statusCode}');
      }
    } catch (e) {
      _logger.e('Error fetching exchange rates: $e');

      // Use demo exchange rates if we can't fetch from API
      // These are approximate rates as of early 2025 and should be updated
      // with real data in production
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
        "NGN": 1520.50 // Added Nigerian Naira exchange rate
      };
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

      final rates = await getExchangeRates();

      // Rates are typically based on USD as the base currency
      // So we need to convert to USD first, then to the target currency

      // Convert amount to USD
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

  // Get historical exchange rate (for a specific date)
  Future<double> getHistoricalRate(
      DateTime date, String fromCurrency, String toCurrency) async {
    try {
      // Format date as YYYY-MM-DD
      final formattedDate =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      // Note: Replace YOUR_API_KEY with your actual API key
      const apiKey = 'YOUR_API_KEY';
      final response = await http.get(
        Uri.parse(
            'https://openexchangerates.org/api/historical/$formattedDate.json?app_id=$apiKey'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rates = data['rates'];

        // Convert using historical rates (same logic as convertCurrency)
        if (fromCurrency == toCurrency) return 1.0;

        if (fromCurrency == 'USD') {
          return rates[toCurrency];
        } else if (toCurrency == 'USD') {
          return 1 / rates[fromCurrency];
        } else {
          return rates[toCurrency] / rates[fromCurrency];
        }
      } else {
        _logger.w('Failed to fetch historical rates, using current rates');
        // Fallback to current rates
        return await getRateBetween(fromCurrency, toCurrency);
      }
    } catch (e) {
      _logger.e('Error getting historical rate: $e');
      // Fallback to current rates
      return await getRateBetween(fromCurrency, toCurrency);
    }
  }

  // Get the exchange rate between two currencies
  Future<double> getRateBetween(String fromCurrency, String toCurrency) async {
    try {
      final rates = await getExchangeRates();

      if (fromCurrency == toCurrency) return 1.0;

      if (fromCurrency == 'USD') {
        return rates[toCurrency];
      } else if (toCurrency == 'USD') {
        return 1 / rates[fromCurrency];
      } else {
        // Convert via USD
        return rates[toCurrency] / rates[fromCurrency];
      }
    } catch (e) {
      _logger.e('Error getting rate between currencies: $e');
      return 1.0; // Default to 1:1 rate if error
    }
  }

  // ENHANCED: Format amount with currency code from params or stored preference
  Future<String> formatCurrency(double amount, [String? currency]) async {
    try {
      // Use provided currency or get saved currency
      final String currencyCode = currency ?? await getCurrencyCode();
      final symbol = currencySymbols[currencyCode] ?? currencyCode;

      // For JPY and some other currencies, no decimal places
      if (currencyCode == 'JPY' || currencyCode == 'KRW') {
        return '$symbol${amount.round()}';
      }

      // Format with 2 decimal places for most currencies
      return '$symbol${amount.toStringAsFixed(2)}';
    } catch (e) {
      _logger.e('Error formatting currency: $e');
      final currencyToUse = currency ?? 'USD';
      return '$currencyToUse${amount.toStringAsFixed(2)}';
    }
  }
}
