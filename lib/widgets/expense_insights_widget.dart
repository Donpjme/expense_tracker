import 'package:flutter/material.dart';
import '../models/expense.dart';
import '../models/budget.dart';

class ExpenseInsightsWidget extends StatelessWidget {
  final List<Expense> expenses;
  final List<Budget> budgets;

  const ExpenseInsightsWidget({
    required this.expenses,
    required this.budgets,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // Generate insights
    final insights = _generateInsights();

    if (insights.isEmpty) {
      return const SizedBox(); // No insights to show
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Text(
            'Your Insights',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
          child: Column(
            children: insights
                .map((insight) => _buildInsightTile(context, insight))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildInsightTile(BuildContext context, Map<String, dynamic> insight) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _getInsightColor(insight['type']).withOpacity(0.1),
        child: Icon(
          _getInsightIcon(insight['type']),
          color: _getInsightColor(insight['type']),
          size: 20,
        ),
      ),
      title: Text(insight['title']),
      subtitle: Text(insight['description']),
      minVerticalPadding: 16,
      isThreeLine: true,
    );
  }

  IconData _getInsightIcon(String type) {
    switch (type) {
      case 'budget_alert':
        return Icons.warning_amber_rounded;
      case 'trend_up':
        return Icons.trending_up;
      case 'trend_down':
        return Icons.trending_down;
      case 'suggestion':
        return Icons.lightbulb_outline;
      case 'achievement':
        return Icons.emoji_events;
      default:
        return Icons.info_outline;
    }
  }

  Color _getInsightColor(String type) {
    switch (type) {
      case 'budget_alert':
        return Colors.orange;
      case 'trend_up':
        return Colors.red;
      case 'trend_down':
        return Colors.green;
      case 'suggestion':
        return Colors.blue;
      case 'achievement':
        return Colors.amber;
      default:
        return Colors.purple;
    }
  }

  List<Map<String, dynamic>> _generateInsights() {
    final insights = <Map<String, dynamic>>[];

    // No expenses, provide starter insight
    if (expenses.isEmpty) {
      insights.add({
        'type': 'suggestion',
        'title': 'Start tracking your expenses',
        'description':
            'Add your first expense to begin getting personalized insights about your spending habits.',
      });
      return insights;
    }

    // 1. Check for categories approaching budget limits
    insights.addAll(_getBudgetAlerts());

    // 2. Detect spending trends
    insights.addAll(_getSpendingTrends());

    // 3. Add achievements
    insights.addAll(_getAchievements());

    // 4. Provide suggestions
    insights.addAll(_getSuggestions());

    // Limit to 3 insights
    return insights.take(3).toList();
  }

  List<Map<String, dynamic>> _getBudgetAlerts() {
    final insights = <Map<String, dynamic>>[];

    // Get current month expenses by category
    final now = DateTime.now();
    final currentMonthExpenses = expenses.where((expense) {
      return expense.date.month == now.month && expense.date.year == now.year;
    }).toList();

    final Map<String, double> spendingByCategory = {};
    for (final expense in currentMonthExpenses) {
      spendingByCategory[expense.category] =
          (spendingByCategory[expense.category] ?? 0) + expense.amount;
    }

    // Check each budget
    for (final budget in budgets) {
      final spent = spendingByCategory[budget.category] ?? 0;
      final limit = budget.budgetLimit;
      final percentage = (spent / limit) * 100;

      if (percentage >= 90 && percentage < 100) {
        insights.add({
          'type': 'budget_alert',
          'title': 'Approaching budget limit',
          'description':
              '${budget.category} spending is at ${percentage.toStringAsFixed(0)}% of your monthly budget. You have \$${(limit - spent).toStringAsFixed(2)} left.',
        });
      } else if (percentage >= 100) {
        insights.add({
          'type': 'budget_alert',
          'title': 'Budget exceeded',
          'description':
              'You have exceeded your ${budget.category} budget by \$${(spent - limit).toStringAsFixed(2)}. Consider adjusting your budget or reducing expenses in this category.',
        });
      }
    }

    return insights;
  }

  List<Map<String, dynamic>> _getSpendingTrends() {
    final insights = <Map<String, dynamic>>[];

    // Need at least 2 months of data
    if (expenses.length < 5) return insights;

    // Get monthly spending
    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1);

    final currentMonthExpenses = expenses.where((expense) {
      return expense.date.month == now.month && expense.date.year == now.year;
    }).toList();

    final lastMonthExpenses = expenses.where((expense) {
      return expense.date.month == lastMonth.month &&
          expense.date.year == lastMonth.year;
    }).toList();

    // Calculate totals
    final currentTotal =
        currentMonthExpenses.fold(0.0, (sum, expense) => sum + expense.amount);
    final lastTotal =
        lastMonthExpenses.fold(0.0, (sum, expense) => sum + expense.amount);

    if (lastTotal > 0 && currentTotal > 0) {
      final percentChange = ((currentTotal - lastTotal) / lastTotal) * 100;

      if (percentChange >= 15) {
        insights.add({
          'type': 'trend_up',
          'title': 'Spending increase detected',
          'description':
              'Your spending this month is ${percentChange.toStringAsFixed(0)}% higher than last month. This might be a good time to review your expenses.',
        });
      } else if (percentChange <= -15) {
        insights.add({
          'type': 'trend_down',
          'title': 'Great job reducing expenses!',
          'description':
              'Your spending this month is ${percentChange.abs().toStringAsFixed(0)}% lower than last month. Keep up the good work!',
        });
      }
    }

    // Check if any category has significant increase
    final Map<String, double> currentCategorySpending = {};
    for (final expense in currentMonthExpenses) {
      currentCategorySpending[expense.category] =
          (currentCategorySpending[expense.category] ?? 0) + expense.amount;
    }

    final Map<String, double> lastCategorySpending = {};
    for (final expense in lastMonthExpenses) {
      lastCategorySpending[expense.category] =
          (lastCategorySpending[expense.category] ?? 0) + expense.amount;
    }

    for (final category in currentCategorySpending.keys) {
      final currentAmount = currentCategorySpending[category] ?? 0;
      final lastAmount = lastCategorySpending[category] ?? 0;

      if (lastAmount > 0 && currentAmount > lastAmount * 1.5) {
        insights.add({
          'type': 'trend_up',
          'title': 'Spending spike in $category',
          'description':
              'Your $category expenses have increased significantly from last month. You spent \$${currentAmount.toStringAsFixed(2)} this month compared to \$${lastAmount.toStringAsFixed(2)} last month.',
        });
        break; // Only show one category spike
      }
    }

    return insights;
  }

  List<Map<String, dynamic>> _getAchievements() {
    final insights = <Map<String, dynamic>>[];

    // Achievement: First expense
    if (expenses.length == 1) {
      insights.add({
        'type': 'achievement',
        'title': 'First expense tracked!',
        'description':
            'You\'ve started your financial tracking journey. Keep adding expenses to get more personalized insights.',
      });
    }

    // Achievement: Consistent tracking
    if (expenses.length >= 10) {
      final now = DateTime.now();
      final oneWeekAgo = now.subtract(const Duration(days: 7));

      final recentExpenses = expenses
          .where((expense) => expense.date.isAfter(oneWeekAgo))
          .toList();

      if (recentExpenses.length >= 5) {
        insights.add({
          'type': 'achievement',
          'title': 'Consistent tracker',
          'description':
              'You\'ve been regularly tracking your expenses. Great job maintaining your financial awareness!',
        });
      }
    }

    // Achievement: Under budget
    if (budgets.isNotEmpty && expenses.isNotEmpty) {
      final now = DateTime.now();
      final currentMonthExpenses = expenses.where((expense) {
        return expense.date.month == now.month && expense.date.year == now.year;
      }).toList();

      final Map<String, double> spendingByCategory = {};
      for (final expense in currentMonthExpenses) {
        spendingByCategory[expense.category] =
            (spendingByCategory[expense.category] ?? 0) + expense.amount;
      }

      int underBudgetCount = 0;
      for (final budget in budgets) {
        final spent = spendingByCategory[budget.category] ?? 0;
        if (spent <= budget.budgetLimit * 0.8) {
          underBudgetCount++;
        }
      }

      if (underBudgetCount >= budgets.length && budgets.isNotEmpty) {
        insights.add({
          'type': 'achievement',
          'title': 'Financial discipline master',
          'description':
              'You\'re staying under budget in all categories. Your financial discipline is paying off!',
        });
      }
    }

    return insights;
  }

  List<Map<String, dynamic>> _getSuggestions() {
    final insights = <Map<String, dynamic>>[];

    // Suggestion: Set up budgets if none exist
    if (budgets.isEmpty && expenses.isNotEmpty) {
      insights.add({
        'type': 'suggestion',
        'title': 'Create your first budget',
        'description':
            'Setting budgets for your top spending categories can help you manage your finances better. Try setting a budget for your largest expense category.',
      });
      return insights; // Return early with just this suggestion
    }

    // Suggestion: Add categories
    final categories = expenses.map((e) => e.category).toSet();
    if (categories.length < 3 && expenses.length > 5) {
      insights.add({
        'type': 'suggestion',
        'title': 'Categorize your expenses better',
        'description':
            'Using more specific categories can help you understand your spending patterns better. Try adding more detailed categories for your expenses.',
      });
    }

    // Suggestion: Regular expense tracking
    if (expenses.isNotEmpty) {
      final now = DateTime.now();
      final oneWeekAgo = now.subtract(const Duration(days: 7));

      final recentExpenses = expenses
          .where((expense) => expense.date.isAfter(oneWeekAgo))
          .toList();

      if (recentExpenses.isEmpty) {
        insights.add({
          'type': 'suggestion',
          'title': 'Update your expense tracking',
          'description':
              'You haven\'t recorded any expenses in the past week. Regular tracking helps maintain an accurate picture of your finances.',
        });
      }
    }

    return insights;
  }
}
