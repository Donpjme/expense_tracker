import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:csv/csv.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/expense.dart';
import '../services/database_service.dart';
import '../services/currency_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  ReportsScreenState createState() => ReportsScreenState();
}

class ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  final CurrencyService _currencyService = CurrencyService();
  final DatabaseService _databaseService = DatabaseService();
  String _currencyCode = 'USD';
  String _currencySymbol = '\$';

  List<Expense> _expenses = [];
  List<Expense> _filteredExpenses = [];
  DateTimeRange? _selectedDateRange;
  String? _selectedCategory;
  String _selectedPeriod = 'month';
  bool _isLoading = true;
  late TabController _tabController;
  bool _showComparison = false;
  String _comparisonPeriod = 'previous';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      await _currencyService.initialize();
      _currencyCode = await _currencyService.getCurrencyCode();
      _currencySymbol = await _currencyService.getCurrencySymbol();

      final expenses = await _databaseService.getExpenses();
      if (!mounted) return;

      setState(() {
        _expenses = expenses;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load data: $e')),
      );
    }
  }

  void _applyFilters() {
    final now = DateTime.now();
    DateTime? periodStart;

    switch (_selectedPeriod) {
      case 'week':
        periodStart = now.subtract(Duration(days: now.weekday - 1));
        break;
      case 'month':
        periodStart = DateTime(now.year, now.month, 1);
        break;
      case 'year':
        periodStart = DateTime(now.year, 1, 1);
        break;
    }

    setState(() {
      _filteredExpenses = _expenses.where((expense) {
        // Date range filter
        if (_selectedDateRange != null &&
            (expense.date.isBefore(_selectedDateRange!.start) ||
                expense.date.isAfter(_selectedDateRange!.end))) {
          return false;
        }

        // Period filter
        if (_selectedPeriod != 'all' &&
            periodStart != null &&
            expense.date.isBefore(periodStart)) {
          return false;
        }

        // Category filter
        if (_selectedCategory != null &&
            _selectedCategory != 'All' &&
            expense.category != _selectedCategory) {
          return false;
        }

        return true;
      }).toList();
    });
  }

  double _calculateTotalSpending(List<Expense> expenses) {
    return expenses.fold(0.0, (sum, expense) => sum + expense.amount);
  }

  Map<String, double> _calculateSpendingByCategory(List<Expense> expenses) {
    final Map<String, double> result = {};
    for (final expense in expenses) {
      result[expense.category] =
          (result[expense.category] ?? 0) + expense.amount;
    }
    return result;
  }

  List<Expense> _getComparisonData() {
    if (!_showComparison) return [];

    final now = DateTime.now();
    DateTime currentStart, currentEnd = now;

    switch (_selectedPeriod) {
      case 'week':
        currentStart = now.subtract(Duration(days: now.weekday - 1));
        break;
      case 'month':
        currentStart = DateTime(now.year, now.month, 1);
        currentEnd = DateTime(now.year, now.month + 1, 0);
        break;
      case 'year':
        currentStart = DateTime(now.year, 1, 1);
        currentEnd = DateTime(now.year, 12, 31);
        break;
      default:
        return [];
    }

    DateTime comparisonStart, comparisonEnd;

    if (_comparisonPeriod == 'previous') {
      final duration = currentEnd.difference(currentStart);
      comparisonEnd = currentStart.subtract(const Duration(days: 1));
      comparisonStart = comparisonEnd.subtract(duration);
    } else {
      comparisonStart =
          DateTime(currentStart.year - 1, currentStart.month, currentStart.day);
      comparisonEnd =
          DateTime(currentEnd.year - 1, currentEnd.month, currentEnd.day);
    }

    return _expenses.where((expense) {
      return expense.date.isAfter(comparisonStart) &&
          expense.date.isBefore(comparisonEnd.add(const Duration(days: 1)));
    }).toList();
  }

  Future<void> _exportAsPDF() async {
    final pdf = pw.Document();
    final total = _calculateTotalSpending(_filteredExpenses);
    final spendingByCategory = _calculateSpendingByCategory(_filteredExpenses);

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Expense Report', style: pw.TextStyle(fontSize: 24)),
              pw.SizedBox(height: 20),
              pw.Text(
                'Total Expenses: $_currencySymbol${total.toStringAsFixed(2)}',
                style: pw.TextStyle(fontSize: 18),
              ),
              pw.SizedBox(height: 20),
              pw.Text('Expenses by Category:',
                  style: pw.TextStyle(fontSize: 16)),
              pw.SizedBox(height: 10),
              ...spendingByCategory.entries.map((entry) {
                return pw.Text(
                  '${entry.key}: $_currencySymbol${entry.value.toStringAsFixed(2)}',
                  style: pw.TextStyle(fontSize: 14),
                );
              }),
            ],
          );
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File('${output.path}/expense_report.pdf');
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)], text: 'Expense Report');
  }

  Future<void> _exportAsCSV() async {
    final csvData = [
      ['Title', 'Category', 'Amount ($_currencyCode)', 'Date']
    ];

    for (final expense in _filteredExpenses) {
      csvData.add([
        expense.title,
        expense.category,
        expense.amount.toString(), // Convert double to string
        DateFormat('yyyy-MM-dd').format(expense.date),
      ]);
    }

    final output = await getTemporaryDirectory();
    final file = File('${output.path}/expense_report.csv');
    await file.writeAsString(const ListToCsvConverter().convert(csvData));
    await Share.shareXFiles([XFile(file.path)], text: 'Expense Report');
  }

  void _showFilterBottomSheet(BuildContext context, List<String> categories) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              builder: (context, scrollController) {
                return SingleChildScrollView(
                  controller: scrollController,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Center(
                          child: Text(
                            'Filter Reports',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Time Period',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('This Week'),
                              selected: _selectedPeriod == 'week',
                              onSelected: (selected) =>
                                  setState(() => _selectedPeriod = 'week'),
                            ),
                            ChoiceChip(
                              label: const Text('This Month'),
                              selected: _selectedPeriod == 'month',
                              onSelected: (selected) =>
                                  setState(() => _selectedPeriod = 'month'),
                            ),
                            ChoiceChip(
                              label: const Text('This Year'),
                              selected: _selectedPeriod == 'year',
                              onSelected: (selected) =>
                                  setState(() => _selectedPeriod = 'year'),
                            ),
                            ChoiceChip(
                              label: const Text('All Time'),
                              selected: _selectedPeriod == 'all',
                              onSelected: (selected) =>
                                  setState(() => _selectedPeriod = 'all'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Custom Date Range',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today),
                          label: Text(
                            _selectedDateRange == null
                                ? 'Select Date Range'
                                : '${DateFormat('MMM d').format(_selectedDateRange!.start)} - ${DateFormat('MMM d').format(_selectedDateRange!.end)}',
                          ),
                          onPressed: () async {
                            final DateTimeRange? picked =
                                await showDateRangePicker(
                              context: context,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                              initialDateRange: _selectedDateRange,
                            );
                            if (picked != null) {
                              setState(() => _selectedDateRange = picked);
                            }
                          },
                        ),
                        if (_selectedDateRange != null)
                          TextButton(
                            onPressed: () =>
                                setState(() => _selectedDateRange = null),
                            child: const Text('Clear Date Range'),
                          ),
                        if (categories.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Text(
                            'Categories',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              ChoiceChip(
                                label: const Text('All Categories'),
                                selected: _selectedCategory == null ||
                                    _selectedCategory == 'All',
                                onSelected: (selected) =>
                                    setState(() => _selectedCategory = 'All'),
                              ),
                              ...categories.map((category) => ChoiceChip(
                                    label: Text(category),
                                    selected: _selectedCategory == category,
                                    onSelected: (selected) => setState(() =>
                                        _selectedCategory =
                                            selected ? category : null),
                                  )),
                            ],
                          ),
                        ],
                        const SizedBox(height: 16),
                        const Text(
                          'Comparison',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Show comparison'),
                          value: _showComparison,
                          onChanged: (value) =>
                              setState(() => _showComparison = value),
                        ),
                        if (_showComparison) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              ChoiceChip(
                                label: const Text('Previous Period'),
                                selected: _comparisonPeriod == 'previous',
                                onSelected: (selected) => setState(
                                    () => _comparisonPeriod = 'previous'),
                              ),
                              ChoiceChip(
                                label: const Text('Same Period Last Year'),
                                selected: _comparisonPeriod == 'same_last_year',
                                onSelected: (selected) => setState(
                                    () => _comparisonPeriod = 'same_last_year'),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              this.setState(() {
                                _applyFilters();
                                Navigator.pop(context);
                              });
                            },
                            child: const Text('Apply Filters'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final allCategories = _expenses.map((e) => e.category).toSet().toList()
      ..sort();
    final comparisonExpenses = _getComparisonData();
    final currentTotal = _calculateTotalSpending(_filteredExpenses);
    final comparisonTotal = _calculateTotalSpending(comparisonExpenses);
    final spendingByCategory = _calculateSpendingByCategory(_filteredExpenses);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterBottomSheet(context, allCategories),
          ),
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                child: const Text('Export as PDF'),
                onTap: () => _exportAsPDF(),
              ),
              PopupMenuItem(
                child: const Text('Export as CSV'),
                onTap: () => _exportAsCSV(),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Categories'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(
                    currentTotal, comparisonTotal, spendingByCategory),
                _buildCategoriesTab(spendingByCategory),
              ],
            ),
    );
  }

  Widget _buildOverviewTab(double currentTotal, double comparisonTotal,
      Map<String, double> spendingByCategory) {
    final percentChange = comparisonTotal > 0
        ? ((currentTotal - comparisonTotal) / comparisonTotal) * 100
        : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildActiveFilters(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Total Spending',
                  currentTotal,
                  Icons.account_balance_wallet,
                  Theme.of(context).colorScheme.primary,
                ),
              ),
              if (_showComparison) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSummaryCard(
                    _comparisonPeriod == 'previous'
                        ? 'Previous Period'
                        : 'Last Year',
                    comparisonTotal,
                    Icons.history,
                    Colors.grey.shade700,
                    percentChange: percentChange,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Spending by Category',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Container(
            height: 250,
            padding: const EdgeInsets.all(8),
            child: spendingByCategory.isEmpty
                ? const Center(child: Text('No expenses data available'))
                : PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: _buildPieChartSections(
                          spendingByCategory, currentTotal),
                    ),
                  ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Top Spending Categories',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildTopCategoriesList(spendingByCategory, currentTotal),
        ],
      ),
    );
  }

  Widget _buildCategoriesTab(Map<String, double> spendingByCategory) {
    final sortedCategories = spendingByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total =
        spendingByCategory.values.fold(0.0, (sum, amount) => sum + amount);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedCategories.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildActiveFilters(),
              const SizedBox(height: 16),
              const Text(
                'Spending by Category',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Divider(),
            ],
          );
        }

        final categoryEntry = sortedCategories[index - 1];
        final percentage = (categoryEntry.value / total) * 100;

        return InkWell(
          onTap: () => _showCategoryDetailsDialog(
              context, categoryEntry.key, categoryEntry.value, total),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Column(
              children: [
                Row(
                  children: [
                    _getCategoryIcon(categoryEntry.key),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            categoryEntry.key,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: categoryEntry.value /
                                (sortedCategories[0].value * 1.1),
                            backgroundColor: Colors.grey.shade200,
                            color: _getCategoryColor(categoryEntry.key),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        FutureBuilder<String>(
                          future: _currencyService
                              .formatCurrency(categoryEntry.value),
                          builder: (context, snapshot) {
                            return Text(
                              snapshot.hasData
                                  ? snapshot.data!
                                  : '$_currencySymbol${categoryEntry.value.toStringAsFixed(2)}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            );
                          },
                        ),
                        Text(
                          '${percentage.toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActiveFilters() {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        ChoiceChip(
          label: Text(_getPeriodLabel()),
          selected: true,
          onSelected: (selected) => _showFilterBottomSheet(context, []),
        ),
        if (_selectedDateRange != null)
          Chip(
            label: Text(
              '${DateFormat('MMM d').format(_selectedDateRange!.start)} - ${DateFormat('MMM d').format(_selectedDateRange!.end)}',
            ),
            onDeleted: () => setState(() {
              _selectedDateRange = null;
              _applyFilters();
            }),
          ),
        if (_selectedCategory != null && _selectedCategory != 'All')
          Chip(
            label: Text(_selectedCategory!),
            onDeleted: () => setState(() {
              _selectedCategory = null;
              _applyFilters();
            }),
          ),
        if (_showComparison)
          Chip(
            label: Text(_comparisonPeriod == 'previous'
                ? 'vs Previous'
                : 'vs Last Year'),
            onDeleted: () => setState(() => _showComparison = false),
          ),
      ],
    );
  }

  String _getPeriodLabel() {
    switch (_selectedPeriod) {
      case 'week':
        return 'This Week';
      case 'month':
        return 'This Month';
      case 'year':
        return 'This Year';
      case 'all':
        return 'All Time';
      default:
        return 'Custom Period';
    }
  }

  Widget _buildSummaryCard(
      String title, double amount, IconData icon, Color color,
      {double? percentChange}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FutureBuilder<String>(
              future: _currencyService.formatCurrency(amount),
              builder: (context, snapshot) {
                return Text(
                  snapshot.hasData
                      ? snapshot.data!
                      : '$_currencySymbol${amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
            if (percentChange != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    percentChange >= 0
                        ? Icons.arrow_upward
                        : Icons.arrow_downward,
                    size: 14,
                    color: percentChange >= 0 ? Colors.red : Colors.green,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${percentChange.abs().toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 12,
                      color: percentChange >= 0 ? Colors.red : Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<PieChartSectionData> _buildPieChartSections(
      Map<String, double> spendingByCategory, double total) {
    final sortedEntries = spendingByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    const maxCategories = 5;
    double otherAmount = 0;

    if (sortedEntries.length > maxCategories) {
      for (int i = maxCategories; i < sortedEntries.length; i++) {
        otherAmount += sortedEntries[i].value;
      }
      sortedEntries.removeRange(maxCategories, sortedEntries.length);
      if (otherAmount > 0) {
        sortedEntries.add(MapEntry('Other', otherAmount));
      }
    }

    return sortedEntries.asMap().entries.map((entry) {
      final index = entry.key;
      final category = entry.value.key;
      final amount = entry.value.value;
      final percentage = (amount / total) * 100;

      return PieChartSectionData(
        value: amount,
        title: '${percentage.toStringAsFixed(1)}%',
        radius: 100,
        titleStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        color: _getCategoryColor(category, index),
        badgeWidget: percentage >= 5
            ? Text(
                category,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              )
            : null,
        badgePositionPercentageOffset: 1.5,
      );
    }).toList();
  }

  Widget _buildTopCategoriesList(
      Map<String, double> spendingByCategory, double total) {
    final topCategories = spendingByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value))
      ..take(3);

    return Column(
      children: topCategories.map((entry) {
        final category = entry.key;
        final amount = entry.value;
        final percentage = (amount / total) * 100;

        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: _getCategoryColor(category),
            radius: 18,
            child: Text(
              (topCategories.indexOf(entry) + 1).toString(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Text(
            category,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: FutureBuilder<String>(
            future: _currencyService.formatCurrency(amount),
            builder: (context, snapshot) {
              return Text(
                snapshot.hasData
                    ? snapshot.data!
                    : '$_currencySymbol${amount.toStringAsFixed(2)}',
              );
            },
          ),
          trailing: Text(
            '${percentage.toStringAsFixed(1)}%',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          onTap: () =>
              _showCategoryDetailsDialog(context, category, amount, total),
        );
      }).toList(),
    );
  }

  Color _getCategoryColor(String category, [int? index]) {
    const categoryColors = {
      'Food': Colors.orange,
      'Transport': Colors.blue,
      'Entertainment': Colors.purple,
      'Utilities': Colors.teal,
      'Health': Colors.red,
      'Education': Colors.green,
      'Shopping': Colors.pink,
      'Miscellaneous': Colors.grey,
      'Other': Colors.blueGrey,
    };

    if (categoryColors.containsKey(category)) {
      return categoryColors[category]!;
    }

    final accentColors = [
      Colors.amber,
      Colors.cyan,
      Colors.indigo,
      Colors.lime,
      Colors.deepOrange,
      Colors.lightBlue,
      Colors.brown,
      Colors.lightGreen,
    ];

    return accentColors[index ?? category.hashCode % accentColors.length];
  }

  Widget _getCategoryIcon(String category) {
    const categoryIcons = {
      'Food': Icons.restaurant,
      'Transport': Icons.directions_car,
      'Entertainment': Icons.movie,
      'Utilities': Icons.power,
      'Health': Icons.medical_services,
      'Education': Icons.school,
      'Shopping': Icons.shopping_bag,
      'Miscellaneous': Icons.more_horiz,
      'Other': Icons.category,
    };

    return CircleAvatar(
      backgroundColor: _getCategoryColor(category).withOpacity(0.1),
      radius: 20,
      child: Icon(
        categoryIcons[category] ?? Icons.category,
        color: _getCategoryColor(category),
        size: 20,
      ),
    );
  }

  void _showCategoryDetailsDialog(
      BuildContext context, String category, double amount, double total) {
    final percentage = (amount / total) * 100;
    final categoryExpenses = _filteredExpenses
        .where((expense) => expense.category == category)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
            maxWidth: MediaQuery.of(context).size.width * 0.9,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _getCategoryIcon(category),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${percentage.toStringAsFixed(1)}% of total spending',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    FutureBuilder<String>(
                      future: _currencyService.formatCurrency(amount),
                      builder: (context, snapshot) {
                        return Text(
                          'Total: ${snapshot.hasData ? snapshot.data! : '$_currencySymbol${amount.toStringAsFixed(2)}'}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                    Text(
                      '${categoryExpenses.length} transactions',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: ListView.builder(
                    itemCount: categoryExpenses.length,
                    itemBuilder: (context, index) {
                      final expense = categoryExpenses[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(expense.title),
                        subtitle: Text(
                            DateFormat('MMM d, yyyy').format(expense.date)),
                        trailing: FutureBuilder<String>(
                          future:
                              _currencyService.formatCurrency(expense.amount),
                          builder: (context, snapshot) {
                            return Text(
                              snapshot.hasData
                                  ? snapshot.data!
                                  : '$_currencySymbol${expense.amount.toStringAsFixed(2)}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
