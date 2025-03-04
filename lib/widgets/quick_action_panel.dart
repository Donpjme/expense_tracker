import 'package:flutter/material.dart';
import '../screens/add_expense_screen.dart';
import '../screens/recurring_expense_screen.dart';
import '../screens/recurring_budget_screen.dart';
import '../screens/budget_setting_screen.dart';

class QuickActionPanel extends StatelessWidget {
  final VoidCallback? onActionCompleted;

  const QuickActionPanel({
    this.onActionCompleted,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildActionButton(
                    context,
                    'Add Expense',
                    Icons.add_circle,
                    Colors.blue,
                    () => _navigateTo(
                      context,
                      const AddExpenseScreen(),
                    ),
                  ),
                  _buildActionButton(
                    context,
                    'Set Budget',
                    Icons.account_balance_wallet,
                    Colors.green,
                    () => _navigateTo(
                      context,
                      BudgetSettingScreen(onBudgetAdded: onActionCompleted),
                    ),
                  ),
                  _buildActionButton(
                    context,
                    'Recurring\nExpense',
                    Icons.repeat,
                    Colors.orange,
                    () => _navigateTo(
                      context,
                      const RecurringExpenseScreen(),
                    ),
                  ),
                  _buildActionButton(
                    context,
                    'Recurring\nBudget',
                    Icons.repeat_one,
                    Colors.purple,
                    () => _navigateTo(
                      context,
                      RecurringBudgetScreen(onBudgetAdded: onActionCompleted),
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

  Widget _buildActionButton(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: 16.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 100,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _navigateTo(BuildContext context, Widget screen) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );

    if (result == true && onActionCompleted != null) {
      onActionCompleted!();
    }
  }
}
