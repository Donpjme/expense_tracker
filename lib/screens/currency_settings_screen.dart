import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../services/currency_service.dart';

class CurrencySettingsScreen extends StatefulWidget {
  const CurrencySettingsScreen({super.key});

  @override
  State<CurrencySettingsScreen> createState() => _CurrencySettingsScreenState();
}

class _CurrencySettingsScreenState extends State<CurrencySettingsScreen> {
  final CurrencyService _currencyService = CurrencyService();
  final Logger _logger = Logger();

  String _selectedCurrency = 'USD';
  String _currencySymbol = '\$';
  bool _isLoading = true;

  final List<Map<String, String>> _currencies = [
    {'code': 'USD', 'name': 'US Dollar', 'symbol': '\$'},
    {'code': 'EUR', 'name': 'Euro', 'symbol': '€'},
    {'code': 'GBP', 'name': 'British Pound', 'symbol': '£'},
    {'code': 'JPY', 'name': 'Japanese Yen', 'symbol': '¥'},
    {'code': 'CAD', 'name': 'Canadian Dollar', 'symbol': 'CA\$'},
    {'code': 'AUD', 'name': 'Australian Dollar', 'symbol': 'A\$'},
    {'code': 'INR', 'name': 'Indian Rupee', 'symbol': '₹'},
    {'code': 'CNY', 'name': 'Chinese Yuan', 'symbol': '¥'},
    {'code': 'BRL', 'name': 'Brazilian Real', 'symbol': 'R\$'},
    {'code': 'MXN', 'name': 'Mexican Peso', 'symbol': 'Mex\$'},
    {'code': 'NGN', 'name': 'Nigerian Naira', 'symbol': '₦'},
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentCurrency();
  }

  Future<void> _loadCurrentCurrency() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final currencyCode = await _currencyService.getCurrencyCode();
      final currencySymbol = await _currencyService.getCurrencySymbol();

      // Only update state if the widget is still mounted
      if (mounted) {
        setState(() {
          _selectedCurrency = currencyCode;
          _currencySymbol = currencySymbol;
          _isLoading = false;
        });
      }
    } catch (e) {
      _logger.e('Error loading currency settings: $e');
      // Only update state if the widget is still mounted
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateCurrency(String currencyCode) async {
    if (currencyCode == _selectedCurrency) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Find the selected currency's symbol
      final selectedCurrency = _currencies.firstWhere(
        (currency) => currency['code'] == currencyCode,
        orElse: () => {'code': 'USD', 'name': 'US Dollar', 'symbol': '\$'},
      );

      final symbol = selectedCurrency['symbol'] ?? '\$';

      // Update preferences
      await _currencyService.setCurrency(currencyCode, symbol);

      // Check if widget is still mounted before updating state
      if (!mounted) return;

      setState(() {
        _selectedCurrency = currencyCode;
        _currencySymbol = symbol;
        _isLoading = false;
      });

      // Only show SnackBar if widget is still mounted
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Currency updated to $currencyCode'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      _logger.e('Error updating currency: $e');

      // Check if widget is still mounted before updating state
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      // Show error message if widget is still mounted
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update currency: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _resetCurrency() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Reset to defaults
      await _currencyService.setCurrency('USD', '\$');

      // Check if widget is still mounted before updating state
      if (!mounted) return;

      setState(() {
        _selectedCurrency = 'USD';
        _currencySymbol = '\$';
        _isLoading = false;
      });

      // Only show SnackBar if widget is still mounted
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Currency reset to USD'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      _logger.e('Error resetting currency: $e');

      // Check if widget is still mounted before updating state
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      // Show error message if widget is still mounted
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to reset currency: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Currency Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current Currency',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                _currencySymbol,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _selectedCurrency,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Select Currency',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _currencies.length,
                      itemBuilder: (context, index) {
                        final currency = _currencies[index];
                        final isSelected =
                            currency['code'] == _selectedCurrency;

                        return Card(
                          elevation: isSelected ? 2 : 0,
                          color: isSelected
                              ? Theme.of(context).colorScheme.primaryContainer
                              : null,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context)
                                      .colorScheme
                                      .surfaceVariant,
                              child: Text(
                                currency['symbol'] ?? '',
                                style: TextStyle(
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                ),
                              ),
                            ),
                            title: Text(currency['name'] ?? ''),
                            subtitle: Text(currency['code'] ?? ''),
                            trailing: isSelected
                                ? Icon(
                                    Icons.check_circle,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  )
                                : null,
                            onTap: () =>
                                _updateCurrency(currency['code'] ?? 'USD'),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Center(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reset to Default (USD)'),
                        onPressed: _resetCurrency,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
