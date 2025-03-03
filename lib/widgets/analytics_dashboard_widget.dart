import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';
import '../models/budget.dart';
import '../screens/reports_screen.dart';

class AnalyticsDashboardWidget extends StatelessWidget {
  final List<Expense> expenses;
  final List<Budget> budgets;
  final VoidCallback? onSeeMorePressed;

  const AnalyticsDashboardWidget({
    required this.expenses,
    required this.budgets,
    this.onSeeMorePressed,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // Get current month expenses
    final currentMonthExpenses = _getCurrentMonthExpenses();

    // Calculate spending over time (last 6 months)
    final spendingTrend = _calculateSpendingTrend();

    // Calculate top spending categories
    final spendingByCategory =
        _calculateSpendingByCategory(currentMonthExpenses);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          context,
          'Analytics Overview',
          onSeeMorePressed ??
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const ReportsScreen()),
                );
              },
        ),

        const SizedBox(height: 16),

        // Monthly spending trend
        _buildSpendingTrendCard(context, spendingTrend),

        const SizedBox(height: 16),

        // Top spending categories
        _buildTopCategoriesCard(context, spendingByCategory),
      ],
    );
  }

  Widget _buildSectionHeader(
      BuildContext context, String title, VoidCallback onPressed) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        TextButton(
          onPressed: onPressed,
          child: const Text('See More'),
        ),
      ],
    );
  }

  Widget _buildSpendingTrendCard(
      BuildContext context, List<Map<String, dynamic>> spendingTrend) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Monthly Spending Trend',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 180,
              child: spendingTrend.isEmpty
                  ? const Center(child: Text('Not enough data to show trend'))
                  : LineChart(
                      LineChartData(
                        gridData:
                            const FlGridData(show: true, drawVerticalLine: false),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: Text(
                                    '\$${value.toInt()}',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 10,
                                    ),
                                  ),
                                );
                              },
                              reservedSize: 40,
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                if (value.toInt() >= 0 &&
                                    value.toInt() < spendingTrend.length) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      spendingTrend[value.toInt()]['month'],
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 10,
                                      ),
                                    ),
                                  );
                                }
                                return const SizedBox();
                              },
                              reservedSize: 30,
                            ),
                          ),
                          rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: spendingTrend
                                .asMap()
                                .entries
                                .map((entry) => FlSpot(entry.key.toDouble(),
                                    entry.value['amount']))
                                .toList(),
                            isCurved: true,
                            barWidth: 3,
                            color: Theme.of(context).colorScheme.primary,
                            dotData: const FlDotData(show: true),
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
                          enabled: true,
                          touchTooltipData: LineTouchTooltipData(
                              getTooltipItems:
                                  (List<LineBarSpot> touchedBarSpots) {
                            return touchedBarSpots.map((barSpot) {
                              return LineTooltipItem(
                                '\$${barSpot.y.toStringAsFixed(2)}',
                                const TextStyle(color: Colors.white),
                              );
                            }).toList();
                          }),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopCategoriesCard(
      BuildContext context, Map<String, double> spendingByCategory) {
    // Sort categories by amount
    final sortedCategories = spendingByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Take top 3 categories
    final topCategories = sortedCategories.take(3).toList();

    // Calculate total
    final total =
        spendingByCategory.values.fold(0.0, (sum, amount) => sum + amount);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top Spending Categories',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            topCategories.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('No categories to show'),
                    ),
                  )
                : Column(
                    children: topCategories.asMap().entries.map((entry) {
                      final index = entry.key;
                      final category = entry.value.key;
                      final amount = entry.value.value;
                      final percentage = total > 0 ? (amount / total) * 100 : 0;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: _getCategoryColor(category, index),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    category,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  LinearProgressIndicator(
                                    value: percentage / 100,
                                    backgroundColor: Colors.grey.shade200,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      _getCategoryColor(category, index),
                                    ),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '\$${amount.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '${percentage.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ],
        ),
      ),
    );
  }

  // Helper methods

  List<Expense> _getCurrentMonthExpenses() {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);

    return expenses.where((expense) {
      return expense.date
              .isAfter(startOfMonth.subtract(const Duration(days: 1))) &&
          expense.date.isBefore(endOfMonth.add(const Duration(days: 1)));
    }).toList();
  }

  List<Map<String, dynamic>> _calculateSpendingTrend() {
    // Get the last 6 months
    final now = DateTime.now();
    final result = <Map<String, dynamic>>[];

    for (int i = 5; i >= 0; i--) {
      final month = now.month - i;
      final year = now.year + (month <= 0 ? -1 : 0);
      final adjustedMonth = month <= 0 ? month + 12 : month;

      final startOfMonth = DateTime(year, adjustedMonth, 1);
      final endOfMonth = DateTime(year, adjustedMonth + 1, 0);

      final monthExpenses = expenses.where((expense) {
        return expense.date
                .isAfter(startOfMonth.subtract(const Duration(days: 1))) &&
            expense.date.isBefore(endOfMonth.add(const Duration(days: 1)));
      }).toList();

      final total =
          monthExpenses.fold(0.0, (sum, expense) => sum + expense.amount);

      result.add({
        'year': year,
        'month': DateFormat('MMM').format(DateTime(year, adjustedMonth)),
        'amount': total,
      });
    }

    return result;
  }

  Map<String, double> _calculateSpendingByCategory(List<Expense> expenses) {
    final result = <String, double>{};

    for (final expense in expenses) {
      result[expense.category] =
          (result[expense.category] ?? 0) + expense.amount;
    }

    return result;
  }

  Color _getCategoryColor(String category, int index) {
    final Map<String, Color> categoryColors = {
      'Food': Colors.orange,
      'Transport': Colors.blue,
      'Entertainment': Colors.purple,
      'Utilities': Colors.teal,
      'Health': Colors.red,
      'Education': Colors.green,
      'Shopping': Colors.pink,
      'Miscellaneous': Colors.grey,
    };

    if (categoryColors.containsKey(category)) {
      return categoryColors[category]!;
    }

    final List<Color> fallbackColors = [
      Colors.amber,
      Colors.cyan,
      Colors.indigo,
      Colors.lime,
      Colors.deepOrange,
      Colors.lightBlue,
      Colors.brown,
    ];

    return fallbackColors[index % fallbackColors.length];
  }
}
