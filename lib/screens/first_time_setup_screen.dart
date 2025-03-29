import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/currency_provider.dart';
import '../services/currency_service.dart';

class FirstTimeSetupScreen extends StatefulWidget {
  final VoidCallback onCurrencySelected;

  const FirstTimeSetupScreen({
    required this.onCurrencySelected,
    super.key,
  });

  @override
  State<FirstTimeSetupScreen> createState() => _FirstTimeSetupScreenState();
}

class _FirstTimeSetupScreenState extends State<FirstTimeSetupScreen> {
  final CurrencyService _currencyService = CurrencyService();
  String _selectedCurrency = 'USD';
  bool _isLoading = false;
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // List of common currencies (top 5 most used)
  final List<Map<String, String>> _commonCurrencies = [
    {'code': 'USD', 'name': 'US Dollar', 'symbol': '\$'},
    {'code': 'EUR', 'name': 'Euro', 'symbol': '€'},
    {'code': 'GBP', 'name': 'British Pound', 'symbol': '£'},
    {'code': 'JPY', 'name': 'Japanese Yen', 'symbol': '¥'},
    {'code': 'CNY', 'name': 'Chinese Yuan', 'symbol': '¥'},
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrencies();
  }

  Future<void> _loadCurrencies() async {
    await _currencyService.initialize();
  }

  Future<void> _saveCurrency() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final currency = _selectedCurrency;
      final symbol = _currencyService.currencySymbols[currency] ?? currency;

      // Use CurrencyProvider instead of direct CurrencyService
      final currencyProvider =
          Provider.of<CurrencyProvider>(context, listen: false);
      await currencyProvider.setCurrency(currency, symbol);

      if (mounted) {
        // Call the callback to advance to the next setup step
        widget.onCurrencySelected();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving currency: $e')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _selectCurrency(String currencyCode) {
    setState(() {
      _selectedCurrency = currencyCode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentPage = index;
          });
        },
        children: [
          // Welcome page
          _buildWelcomePage(),

          // Currency selection page
          _buildCurrencySelectionPage(),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Back button (hidden on first page)
              _currentPage > 0
                  ? TextButton(
                      onPressed: () {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: const Text('Back'),
                    )
                  : const SizedBox(width: 80),

              // Page indicator
              Row(
                children: List.generate(2, (index) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentPage == index
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey.shade300,
                    ),
                  );
                }),
              ),

              // Next/Continue button
              _currentPage == 0
                  ? TextButton(
                      onPressed: () {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: const Text('Next'),
                    )
                  : ElevatedButton(
                      onPressed: _isLoading ? null : _saveCurrency,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Continue'),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomePage() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App logo or icon
            Icon(
              Icons.account_balance_wallet,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 40),

            // Welcome title
            Text(
              'Welcome to Expense Tracker',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // App description
            Text(
              'Take control of your finances with our easy-to-use expense tracking app.',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),

            // Features highlight
            ...['Track expenses', 'Set budgets', 'Generate reports']
                .map((feature) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      feature,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrencySelectionPage() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Your Currency',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Text(
              'This will be used as your default currency for all transactions.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 32),

            // Common currencies section
            Text(
              'Common Currencies',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),

            // Common currencies list
            Expanded(
              child: ListView.builder(
                itemCount: _commonCurrencies.length,
                itemBuilder: (context, index) {
                  final currency = _commonCurrencies[index];
                  final isSelected = _selectedCurrency == currency['code'];

                  return Card(
                    elevation: isSelected ? 2 : 0,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.surfaceVariant,
                        child: Text(
                          currency['symbol']!,
                          style: TextStyle(
                            color: isSelected
                                ? Theme.of(context).colorScheme.onPrimary
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                          ),
                        ),
                      ),
                      title: Text(currency['name']!),
                      subtitle: Text(currency['code']!),
                      trailing: isSelected
                          ? Icon(
                              Icons.check_circle,
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : null,
                      onTap: () => _selectCurrency(currency['code']!),
                    ),
                  );
                },
              ),
            ),

            // All currencies button
            TextButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (context) => _buildAllCurrenciesSheet(),
                );
              },
              child: const Text('See All Currencies'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllCurrenciesSheet() {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'All Currencies',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: _currencyService.supportedCurrencies.length,
                itemBuilder: (context, index) {
                  final currencyCode =
                      _currencyService.supportedCurrencies[index];
                  final symbol =
                      _currencyService.currencySymbols[currencyCode] ??
                          currencyCode;
                  final isSelected = _selectedCurrency == currencyCode;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.surfaceVariant,
                      child: Text(
                        symbol,
                        style: TextStyle(
                          color: isSelected
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    title: Text(currencyCode),
                    trailing: isSelected
                        ? Icon(
                            Icons.check_circle,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : null,
                    onTap: () {
                      _selectCurrency(currencyCode);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}
