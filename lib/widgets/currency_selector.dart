import 'package:flutter/material.dart';
import '../services/currency_service.dart';

class CurrencySelector extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final currencyService = CurrencyService();

    return DropdownButton<String>(
      value: selectedCurrency,
      onChanged: (String? newValue) {
        if (newValue != null) {
          onCurrencyChanged(newValue);
        }
      },
      items: currencyService.supportedCurrencies
          .map<DropdownMenuItem<String>>((String currency) {
        return DropdownMenuItem<String>(
          value: currency,
          child: Text(
            showSymbol
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

  const CurrencyPickerDialog({
    required this.initialCurrency,
    super.key,
  });

  @override
  State<CurrencyPickerDialog> createState() => _CurrencyPickerDialogState();
}

class _CurrencyPickerDialogState extends State<CurrencyPickerDialog> {
  late String _selectedCurrency;
  String _searchQuery = '';
  final CurrencyService _currencyService = CurrencyService();

  @override
  void initState() {
    super.initState();
    _selectedCurrency = widget.initialCurrency;
  }

  @override
  Widget build(BuildContext context) {
    final filteredCurrencies = _currencyService.supportedCurrencies
        .where((currency) =>
            currency.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    return AlertDialog(
      title: const Text('Select Currency'),
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

                  return RadioListTile<String>(
                    title: Text('$currency ($symbol)'),
                    value: currency,
                    groupValue: _selectedCurrency,
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
          onPressed: () => Navigator.of(context).pop(_selectedCurrency),
          child: const Text('Select'),
        ),
      ],
    );
  }
}
