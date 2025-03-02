// ignore: file_names
// ignore: file_names
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';
import '../services/database_service.dart';


class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  ReportsScreenState createState() => ReportsScreenState();
}

class ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  List<Expense> _expenses = [];
  List<Expense> _filteredExpenses = [];
  DateTimeRange? _selectedDateRange;
  String? _selectedCategory;
  String _selectedPeriod = 'month'; // 'week', 'month', 'year', 'all'
  // ignore: unused_field
  final bool _isExporting = false;
  bool _isLoading = true;
  // ignore: unused_field
  final String _logMessages = '';

  // Tab controller for switching between different chart views
  late TabController _tabController;

  // Comparison mode
  bool _showComparison = false;
  String _comparisonPeriod = 'previous'; // 'previous', 'same_last_year'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    loadExpenses();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Method to load expenses (made public for refresh from home screen)
  Future<void> loadExpenses() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final expenses = await DatabaseService().getExpenses();

      if (!mounted) return;

      setState(() {
        _expenses = expenses;
        _applyFilters(); // Apply filters to update _filteredExpenses
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load expenses: $e')),
      );
    }
  }

  // Apply all filters to get filtered expenses
  void _applyFilters() {
    setState(() {
      _filteredExpenses = _expenses.where((expense) {
        // Filter by date range
        if (_selectedDateRange != null) {
          if (expense.date.isBefore(_selectedDateRange!.start) ||
              expense.date.isAfter(_selectedDateRange!.end)) {
            return false;
          }
        }

        // Filter by category
        if (_selectedCategory != null && _selectedCategory != 'All') {
          if (expense.category != _selectedCategory) {
            return false;
          }
        }

        // Filter by period (week, month, year)
        if (_selectedPeriod != 'all') {
          final now = DateTime.now();
          DateTime periodStart;

          switch (_selectedPeriod) {
            case 'week':
              // Start of current week (Monday)
              periodStart = DateTime(now.year, now.month, now.day)
                  .subtract(Duration(days: now.weekday - 1));
              break;
            case 'month':
              // Start of current month
              periodStart = DateTime(now.year, now.month, 1);
              break;
            case 'year':
              // Start of current year
              periodStart = DateTime(now.year, 1, 1);
              break;
            default:
              periodStart = DateTime(1900); // Far in the past to include all
          }

          if (expense.date.isBefore(periodStart)) {
            return false;
          }
        }

        return true;
      }).toList();
    });
  }

  // Calculate total spending for a specific period
  double _calculateTotalSpending(List<Expense> expenses) {
    return expenses.fold(0.0, (sum, expense) => sum + expense.amount);
  }

  // Calculate spending by category
  Map<String, double> _calculateSpendingByCategory(List<Expense> expenses) {
    final Map<String, double> spendingByCategory = {};
    for (final expense in expenses) {
      spendingByCategory[expense.category] =
          (spendingByCategory[expense.category] ?? 0) + expense.amount;
    }
    return spendingByCategory;
  }

  // Calculate spending by month
  List<Map<String, dynamic>> _calculateSpendingByMonth(List<Expense> expenses) {
    // Group expenses by month
    final Map<String, double> monthlySpending = {};

    for (final expense in expenses) {
      final monthKey = DateFormat('yyyy-MM').format(expense.date);
      monthlySpending[monthKey] =
          (monthlySpending[monthKey] ?? 0) + expense.amount;
    }

    // Convert to list for chart
    final List<Map<String, dynamic>> result =
        monthlySpending.entries.map((entry) {
      final parts = entry.key.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      return {
        'month': entry.key,
        'label': DateFormat('MMM yy').format(DateTime(year, month)),
        'amount': entry.value,
      };
    }).toList();

    // Sort by date
    result.sort((a, b) => a['month'].compareTo(b['month']));

    return result;
  }

  // Calculate spending by day of week
  List<Map<String, dynamic>> _calculateSpendingByDayOfWeek(
      List<Expense> expenses) {
    // Initialize map with all days of week
    final Map<int, double> dailySpending = {
      1: 0, // Monday
      2: 0, // Tuesday
      3: 0, // Wednesday
      4: 0, // Thursday
      5: 0, // Friday
      6: 0, // Saturday
      7: 0, // Sunday
    };

    for (final expense in expenses) {
      final weekday = expense.date.weekday;
      dailySpending[weekday] = (dailySpending[weekday] ?? 0) + expense.amount;
    }

    // Convert to list for chart
    final List<Map<String, dynamic>> result =
        dailySpending.entries.map((entry) {
      return {
        'day': entry.key,
        'label': _getDayName(entry.key),
        'amount': entry.value,
      };
    }).toList();

    // Sort by day of week
    result.sort((a, b) => a['day'].compareTo(b['day']));

    return result;
  }

  String _getDayName(int day) {
    switch (day) {
      case 1:
        return 'Mon';
      case 2:
        return 'Tue';
      case 3:
        return 'Wed';
      case 4:
        return 'Thu';
      case 5:
        return 'Fri';
      case 6:
        return 'Sat';
      case 7:
        return 'Sun';
      default:
        return '';
    }
  }

  // Get comparison data based on selected period
  List<Expense> _getComparisonData() {
    if (!_showComparison) return [];

    final now = DateTime.now();

    // Determine current period range
    DateTime currentStart;
    DateTime currentEnd = now;

    switch (_selectedPeriod) {
      case 'week':
        // Start of current week (Monday)
        currentStart = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - 1));
        break;
      case 'month':
        // Start of current month
        currentStart = DateTime(now.year, now.month, 1);
        currentEnd =
            DateTime(now.year, now.month + 1, 0); // Last day of current month
        break;
      case 'year':
        // Start of current year
        currentStart = DateTime(now.year, 1, 1);
        currentEnd = DateTime(now.year, 12, 31);
        break;
      default:
        return []; // No comparison for 'all'
    }

    // Determine comparison period
    DateTime comparisonStart;
    DateTime comparisonEnd;

    if (_comparisonPeriod == 'previous') {
      // Previous period
      final duration = currentEnd.difference(currentStart);
      comparisonEnd = currentStart.subtract(const Duration(days: 1));
      comparisonStart = comparisonEnd.subtract(duration);
    } else {
      // Same period last year
      comparisonStart =
          DateTime(currentStart.year - 1, currentStart.month, currentStart.day);
      comparisonEnd =
          DateTime(currentEnd.year - 1, currentEnd.month, currentEnd.day);
    }

    // Filter expenses for comparison period
    return _expenses.where((expense) {
      return expense.date.isAfter(comparisonStart) &&
          expense.date.isBefore(comparisonEnd.add(const Duration(days: 1)));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    // Get list of all categories for filter
    final allCategories = _expenses.map((e) => e.category).toSet().toList();
    allCategories.sort();

    // Get comparison data
    final comparisonExpenses = _getComparisonData();

    // Calculate key metrics
    final currentTotal = _calculateTotalSpending(_filteredExpenses);
    final comparisonTotal = _calculateTotalSpending(comparisonExpenses);
    final spendingByCategory = _calculateSpendingByCategory(_filteredExpenses);
    final spendingByMonth = _calculateSpendingByMonth(_filteredExpenses);
    final spendingByDayOfWeek =
        _calculateSpendingByDayOfWeek(_filteredExpenses);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterBottomSheet(context, allCategories),
            tooltip: 'Filter',
          ),
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                child: const Text('Export as PDF'),
                onTap: () {
                  // Placeholder for PDF export function
                },
              ),
              PopupMenuItem(
                child: const Text('Export as CSV'),
                onTap: () {
                  // Placeholder for CSV export function
                },
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Trends'),
            Tab(text: 'Categories'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // Overview Tab
                _buildOverviewTab(
                    currentTotal, comparisonTotal, spendingByCategory),

                // Trends Tab
                _buildTrendsTab(spendingByMonth, spendingByDayOfWeek),

                // Categories Tab
                _buildCategoriesTab(spendingByCategory),
              ],
            ),
    );
  }

  Widget _buildOverviewTab(double currentTotal, double comparisonTotal,
      Map<String, double> spendingByCategory) {
    // Calculate percentage change
    final percentChange = comparisonTotal > 0
        ? ((currentTotal - comparisonTotal) / comparisonTotal) * 100
        : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter indicators
          _buildActiveFilters(),

          const SizedBox(height: 16),

          // Summary cards
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Total Spending',
                  '\$${currentTotal.toStringAsFixed(2)}',
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
                    '\$${comparisonTotal.toStringAsFixed(2)}',
                    Icons.history,
                    Colors.grey.shade700,
                    percentChange: percentChange,
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 24),

          // Spending pie chart
          const Text(
            'Spending by Category',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
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
                      pieTouchData: PieTouchData(
                        touchCallback: (FlTouchEvent event, pieTouchResponse) {
                          if (event is FlTapUpEvent) {
                            if (pieTouchResponse?.touchedSection != null) {
                              final touchedIndex = pieTouchResponse!
                                  .touchedSection!.touchedSectionIndex;
                              final categories =
                                  spendingByCategory.keys.toList();
                              if (touchedIndex >= 0 &&
                                  touchedIndex < categories.length) {
                                final category = categories[touchedIndex];
                                _showCategoryDetailsDialog(
                                    context,
                                    category,
                                    spendingByCategory[category] ?? 0,
                                    currentTotal);
                              }
                            }
                          }
                        },
                      ),
                    ),
                  ),
          ),

          const SizedBox(height: 24),

          // Top spending categories
          const Text(
            'Top Spending Categories',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          _buildTopCategoriesList(spendingByCategory, currentTotal),
        ],
      ),
    );
  }

  Widget _buildTrendsTab(List<Map<String, dynamic>> spendingByMonth,
      List<Map<String, dynamic>> spendingByDayOfWeek) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter indicators
          _buildActiveFilters(),

          const SizedBox(height: 16),

          // Monthly trend
          const Text(
            'Monthly Spending Trend',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 16),

          Container(
            height: 250,
            padding: const EdgeInsets.all(8),
            child: spendingByMonth.isEmpty
                ? const Center(child: Text('No monthly data available'))
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(show: true),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              if (value.toInt() >= 0 &&
                                  value.toInt() < spendingByMonth.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    spendingByMonth[value.toInt()]['label'],
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                );
                              }
                              return const SizedBox();
                            },
                            reservedSize: 30,
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: Text(
                                  '\$${value.toInt()}',
                                  style: const TextStyle(fontSize: 10),
                                ),
                              );
                            },
                            reservedSize: 40,
                          ),
                        ),
                        topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: true),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spendingByMonth
                              .asMap()
                              .entries
                              .map((entry) => FlSpot(
                                  entry.key.toDouble(), entry.value['amount']))
                              .toList(),
                          isCurved: true,
                          barWidth: 3,
                          color: Theme.of(context).colorScheme.primary,
                          dotData: FlDotData(show: true),
                          belowBarData: BarAreaData(
                            show: true,
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.2),
                          ),
                        ),
                      ],
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                            return touchedBarSpots.map((barSpot) {
                              final index = barSpot.x.toInt();
                              if (index >= 0 &&
                                  index < spendingByMonth.length) {
                                final data = spendingByMonth[index];
                                return LineTooltipItem(
                                  '${data['label']}: \$${data['amount'].toStringAsFixed(2)}',
                                  const TextStyle(color: Colors.white),
                                );
                              }
                              return null;
                            }).toList();
                          },
                        ),
                      ),
                    ),
                  ),
          ),

          const SizedBox(height: 24),

          // Daily trend
          const Text(
            'Spending by Day of Week',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 16),

          Container(
            height: 250,
            padding: const EdgeInsets.all(8),
            child: spendingByDayOfWeek.isEmpty
                ? const Center(child: Text('No daily data available'))
                : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.center,
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final data = spendingByDayOfWeek[groupIndex];
                            return BarTooltipItem(
                              '${data['label']}: \$${data['amount'].toStringAsFixed(2)}',
                              const TextStyle(color: Colors.white),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              if (value.toInt() >= 0 &&
                                  value.toInt() < spendingByDayOfWeek.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    spendingByDayOfWeek[value.toInt()]['label'],
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                );
                              }
                              return const SizedBox();
                            },
                            reservedSize: 30,
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: Text(
                                  '\$${value.toInt()}',
                                  style: const TextStyle(fontSize: 10),
                                ),
                              );
                            },
                            reservedSize: 40,
                          ),
                        ),
                        topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      gridData: FlGridData(show: true),
                      barGroups: spendingByDayOfWeek
                          .asMap()
                          .entries
                          .map((entry) => BarChartGroupData(
                                x: entry.key,
                                barRods: [
                                  BarChartRodData(
                                    toY: entry.value['amount'],
                                    color:
                                        Theme.of(context).colorScheme.secondary,
                                    width: 20,
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(3),
                                      topRight: Radius.circular(3),
                                    ),
                                  ),
                                ],
                              ))
                          .toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesTab(Map<String, double> spendingByCategory) {
    final List<MapEntry<String, double>> sortedCategories =
        spendingByCategory.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    final total =
        spendingByCategory.values.fold(0.0, (sum, amount) => sum + amount);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedCategories.length + 1, // +1 for the header
      itemBuilder: (context, index) {
        if (index == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildActiveFilters(),
              const SizedBox(height: 16),
              const Text(
                'Spending by Category',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
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
                            borderRadius: BorderRadius.circular(2),
                            minHeight: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '\$${categoryEntry.value.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
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
        // Period chip
        ChoiceChip(
          label: Text(_getPeriodLabel()),
          selected: true,
          onSelected: (selected) => _showFilterBottomSheet(context, []),
        ),

        // Date range chip (if selected)
        if (_selectedDateRange != null)
          Chip(
            label: Text(
              '${DateFormat('MMM d').format(_selectedDateRange!.start)} - ${DateFormat('MMM d').format(_selectedDateRange!.end)}',
            ),
            onDeleted: () {
              setState(() {
                _selectedDateRange = null;
                _applyFilters();
              });
            },
          ),

        // Category chip (if selected)
        if (_selectedCategory != null && _selectedCategory != 'All')
          Chip(
            label: Text(_selectedCategory!),
            onDeleted: () {
              setState(() {
                _selectedCategory = null;
                _applyFilters();
              });
            },
          ),

        // Comparison chip
        if (_showComparison)
          Chip(
            label: Text(
              _comparisonPeriod == 'previous' ? 'vs Previous' : 'vs Last Year',
            ),
            onDeleted: () {
              setState(() {
                _showComparison = false;
              });
            },
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
      String title, String value, IconData icon, Color color,
      {double? percentChange}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
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
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (percentChange != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
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
                    const SizedBox(width: 4),
                    Text(
                      percentChange >= 0 ? 'increase' : 'decrease',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<PieChartSectionData> _buildPieChartSections(
      Map<String, double> spendingByCategory, double total) {
    final List<MapEntry<String, double>> sortedEntries =
        spendingByCategory.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    // Only show top 5 categories, group the rest as "Other"
    const int maxCategories = 5;
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
        badgeWidget: _percentage(percentage) >= 5
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

  // Helper to format percentage
  double _percentage(double value) => (value * 10).round() / 10;

  Widget _buildTopCategoriesList(
      Map<String, double> spendingByCategory, double total) {
    final List<MapEntry<String, double>> sortedCategories =
        spendingByCategory.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    // Only show top 3 categories
    final topCategories = sortedCategories.take(3).toList();

    return Column(
      children: topCategories.asMap().entries.map((entry) {
        final index = entry.key;
        final category = entry.value.key;
        final amount = entry.value.value;
        final percentage = (amount / total) * 100;

        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: _getCategoryColor(category, index),
            radius: 18,
            child: Text(
              (index + 1).toString(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Text(
            category,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text('\$${amount.toStringAsFixed(2)}'),
          trailing: Text(
            '${percentage.toStringAsFixed(1)}%',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          onTap: () =>
              _showCategoryDetailsDialog(context, category, amount, total),
        );
      }).toList(),
    );
  }

  Color _getCategoryColor(String category, [int? index]) {
    final Map<String, Color> categoryColors = {
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

    // If category has a predefined color, use it
    if (categoryColors.containsKey(category)) {
      return categoryColors[category]!;
    }

    // Otherwise, use a color from the accent colors based on index or hash
    final List<Color> accentColors = [
      Colors.amber,
      Colors.cyan,
      Colors.indigo,
      Colors.lime,
      Colors.deepOrange,
      Colors.lightBlue,
      Colors.brown,
      Colors.lightGreen,
    ];

    if (index != null) {
      return accentColors[index % accentColors.length];
    }

    // Use hash-based color for consistent coloring
    final hashCode = category.hashCode;
    return accentColors[hashCode % accentColors.length];
  }

  Widget _getCategoryIcon(String category) {
    final Map<String, IconData> categoryIcons = {
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

    final IconData iconData = categoryIcons[category] ?? Icons.category;

    return CircleAvatar(
      backgroundColor: _getCategoryColor(category).withOpacity(0.1),
      radius: 20,
      child: Icon(
        iconData,
        color: _getCategoryColor(category),
        size: 20,
      ),
    );
  }

  void _showCategoryDetailsDialog(
      BuildContext context, String category, double amount, double total) {
    final percentage = (amount / total) * 100;

    // Filter expenses for this category
    final categoryExpenses = _filteredExpenses
        .where((expense) => expense.category == category)
        .toList();

    // Sort by date (most recent first)
    categoryExpenses.sort((a, b) => b.date.compareTo(a.date));

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: double.maxFinite,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
              maxWidth: MediaQuery.of(context).size.width * 0.9,
            ),
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
                            style: TextStyle(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total: \$${amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
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
                          DateFormat('MMM d, yyyy').format(expense.date),
                        ),
                        trailing: Text(
                          '\$${expense.amount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showFilterBottomSheet(BuildContext context, List<String> categories) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              expand: false,
              builder: (context, scrollController) {
                return SingleChildScrollView(
                  controller: scrollController,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Center(
                          child: Text(
                            'Filter Reports',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Time Period',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('This Week'),
                              selected: _selectedPeriod == 'week',
                              onSelected: (selected) {
                                setState(() {
                                  _selectedPeriod = 'week';
                                });
                              },
                            ),
                            ChoiceChip(
                              label: const Text('This Month'),
                              selected: _selectedPeriod == 'month',
                              onSelected: (selected) {
                                setState(() {
                                  _selectedPeriod = 'month';
                                });
                              },
                            ),
                            ChoiceChip(
                              label: const Text('This Year'),
                              selected: _selectedPeriod == 'year',
                              onSelected: (selected) {
                                setState(() {
                                  _selectedPeriod = 'year';
                                });
                              },
                            ),
                            ChoiceChip(
                              label: const Text('All Time'),
                              selected: _selectedPeriod == 'all',
                              onSelected: (selected) {
                                setState(() {
                                  _selectedPeriod = 'all';
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Custom Date Range',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
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
                              setState(() {
                                _selectedDateRange = picked;
                              });
                            }
                          },
                        ),
                        if (_selectedDateRange != null)
                          TextButton(
                            child: const Text('Clear Date Range'),
                            onPressed: () {
                              setState(() {
                                _selectedDateRange = null;
                              });
                            },
                          ),
                        const SizedBox(height: 16),
                        if (categories.isNotEmpty) ...[
                          const Text(
                            'Categories',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              ChoiceChip(
                                label: const Text('All Categories'),
                                selected: _selectedCategory == null ||
                                    _selectedCategory == 'All',
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedCategory = 'All';
                                  });
                                },
                              ),
                              ...categories.map((category) => ChoiceChip(
                                    label: Text(category),
                                    selected: _selectedCategory == category,
                                    onSelected: (selected) {
                                      setState(() {
                                        _selectedCategory =
                                            selected ? category : null;
                                      });
                                    },
                                  )),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],
                        const Text(
                          'Comparison',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Show comparison'),
                          subtitle: const Text(
                              'Compare with previous period or last year'),
                          value: _showComparison,
                          onChanged: (value) {
                            setState(() {
                              _showComparison = value;
                            });
                          },
                        ),
                        if (_showComparison) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              ChoiceChip(
                                label: const Text('Previous Period'),
                                selected: _comparisonPeriod == 'previous',
                                onSelected: (selected) {
                                  setState(() {
                                    _comparisonPeriod = 'previous';
                                  });
                                },
                              ),
                              ChoiceChip(
                                label: const Text('Same Period Last Year'),
                                selected: _comparisonPeriod == 'same_last_year',
                                onSelected: (selected) {
                                  setState(() {
                                    _comparisonPeriod = 'same_last_year';
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            child: const Text('Apply Filters'),
                            onPressed: () {
                              // Apply filters
                              this.setState(() {
                                // Update selection from local state
                                _selectedPeriod = _selectedPeriod;
                                _selectedDateRange = _selectedDateRange;
                                _selectedCategory = _selectedCategory;
                                _showComparison = _showComparison;
                                _comparisonPeriod = _comparisonPeriod;

                                // Apply filters
                                _applyFilters();
                              });

                              Navigator.of(context).pop();
                            },
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
}