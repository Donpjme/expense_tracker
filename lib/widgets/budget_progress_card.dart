import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BudgetProgressCard extends StatelessWidget {
  final String category;
  final double budgetAmount;
  final double spentAmount;
  final Color categoryColor;

  const BudgetProgressCard({
    required this.category,
    required this.budgetAmount,
    required this.spentAmount,
    required this.categoryColor,
    super.key,
  });

  double get progressPercentage =>
      budgetAmount > 0 ? (spentAmount / budgetAmount).clamp(0.0, 1.0) : 0.0;

  bool get isOverBudget => spentAmount > budgetAmount;

  Color get progressColor {
    final percentage = progressPercentage;
    if (percentage < 0.5) return Colors.green;
    if (percentage < 0.75) return Colors.orange;
    return Colors.red;
  }

  // Format currency in a consistent way
  String formatAmount(double amount) {
    final formatter = NumberFormat.currency(
      symbol: '\$',
      decimalDigits: 0, // Use 0 digits for cleaner display
    );

    if (amount >= 10000) {
      return NumberFormat.compactCurrency(
        symbol: '\$',
        decimalDigits: 1,
      ).format(amount);
    }

    return formatter.format(amount);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: categoryColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    category,
                    style: Theme.of(context).textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${(progressPercentage * 100).toInt()}%',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: progressColor,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progressPercentage,
              color: progressColor,
              backgroundColor: Colors.grey.shade200,
              minHeight: 8,
              borderRadius: const BorderRadius.all(Radius.circular(4)),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Use fitted box for better text scaling
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${formatAmount(spentAmount)} spent',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Use fitted box for better text scaling
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      'of ${formatAmount(budgetAmount)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
              ],
            ),
            if (isOverBudget)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.red,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Over by ${formatAmount(spentAmount - budgetAmount)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.red,
                            ),
                        overflow: TextOverflow.ellipsis,
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
}
