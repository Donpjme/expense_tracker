import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/currency_service.dart';
import '../services/currency_lock_service.dart';
import '../providers/currency_provider.dart';

class CurrencySelector extends StatefulWidget {
  final String selectedCurrency;
  final ValueChanged<String> onCurrencyChanged;
  final bool showSymbol;

  const CurrencySelector({
    required this.selectedCurrency,
    required this.onCurrencyChanged,
    this.showSymbol = true,
    super.key,
  });

  @override
  State<CurrencySelector> createState() => _CurrencySelectorState();
}

class _CurrencySelectorState extends State<CurrencySelector> {
  final currencyService = CurrencyService();
  bool _isCurrencyLocked = false;

  @override
  void initState() {
    super.initState();
    _checkCurrencyLock();
  }

  Future<void> _checkCurrencyLock() async {
    final lockService = CurrencyLockService();
    final currencyLocked = await lockService.isCurrencyLocked();

    if (mounted) {
      setState(() {
        _isCurrencyLocked = currencyLocked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // If currency is locked, display a read-only text field
    if (_isCurrencyLocked) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.showSymbol
                ? '${widget.selectedCurrency} (${currencyService.currencySymbols[widget.selectedCurrency] ?? widget.selectedCurrency})'
                : widget.selectedCurrency,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: 'Currency cannot be changed after initial setup',
            child: Icon(
              Icons.lock,
              size: 16,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      );
    }

    // Normal dropdown when currency is not locked
    return DropdownButton<String>(
      value: widget.selectedCurrency,
      onChanged: (String? newValue) {
        if (newValue != null) {
          widget.onCurrencyChanged(newValue);
        }
      },
      items: currencyService.supportedCurrencies
          .map<DropdownMenuItem<String>>((String currency) {
        return DropdownMenuItem<String>(
          value: currency,
          child: Text(
            widget.showSymbol
                ? '$currency (${currencyService.currencySymbols[currency] ?? currency})'
                : currency,
          ),
        );
      }).toList(),
    );
  }
}

class CurrencyPickerDialog extends StatefulWidget {
  final String initialCurrency;
  final bool allowChangingGlobalCurrency;

  const CurrencyPickerDialog({
    required this.initialCurrency,
    this.allowChangingGlobalCurrency = false,
    super.key,
  });

  @override
  State<CurrencyPickerDialog> createState() => _CurrencyPickerDialogState();
}

class _CurrencyPickerDialogState extends State<CurrencyPickerDialog> {
  late String _selectedCurrency;
  String _searchQuery = '';
  final CurrencyService _currencyService = CurrencyService();
  bool _isCurrencyLocked = false;

  @override
  void initState() {
    super.initState();
    _selectedCurrency = widget.initialCurrency;
    _checkCurrencyLock();
  }

  Future<void> _checkCurrencyLock() async {
    if (widget.allowChangingGlobalCurrency) {
      final prefs = await SharedPreferences.getInstance();
      final currencyLocked = prefs.getBool('currency_locked') ?? false;

      if (mounted) {
        setState(() {
          _isCurrencyLocked = currencyLocked;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredCurrencies = _currencyService.supportedCurrencies
        .where((currency) =>
            currency.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    // Show a notice if the currency is locked globally
    if (_isCurrencyLocked && widget.allowChangingGlobalCurrency) {
      return AlertDialog(
        title: const Text('Currency Locked'),
        content: const Text(
          'The app currency cannot be changed after initial setup to ensure '
          'consistency in your financial records.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      );
    }

    return AlertDialog(
      title: Text(widget.allowChangingGlobalCurrency
          ? 'Select App Currency'
          : 'Select Currency'),
      content: Container(
        width: double.maxFinite,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Search field
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
            const SizedBox(height: 16),

            // Currency list
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: filteredCurrencies.length,
                itemBuilder: (context, index) {
                  final currency = filteredCurrencies[index];
                  final symbol =
                      _currencyService.currencySymbols[currency] ?? currency;
                  final isSelected = _selectedCurrency == currency;

                  return RadioListTile<String>(
                    title: Text('$currency ($symbol)'),
                    value: currency,
                    groupValue: _selectedCurrency,
                    selected: isSelected,
                    activeColor: Theme.of(context).colorScheme.primary,
                    onChanged: (String? value) {
                      if (value != null) {
                        setState(() {
                          _selectedCurrency = value;
                        });
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (widget.allowChangingGlobalCurrency) {
              // Change the app's global currency
              final currencyProvider =
                  Provider.of<CurrencyProvider>(context, listen: false);
              final symbol =
                  _currencyService.currencySymbols[_selectedCurrency] ??
                      _selectedCurrency;
              currencyProvider.setCurrency(_selectedCurrency, symbol);
            }
            Navigator.of(context).pop(_selectedCurrency);
          },
          child: Text(widget.allowChangingGlobalCurrency ? 'Apply' : 'Select'),
        ),
      ],
    );
  }
}
