import 'package:flutter/material.dart';
import 'package:expense_tracker/services/currency_service.dart';

class BudgetProgressCard extends StatefulWidget {
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

  @override
  State<BudgetProgressCard> createState() => _BudgetProgressCardState();
}

class _BudgetProgressCardState extends State<BudgetProgressCard> {
  final CurrencyService _currencyService = CurrencyService();
  String _formattedBudget = '';
  String _formattedSpent = '';
  String _formattedOver = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _formatCurrencies();
  }

  @override
  void didUpdateWidget(BudgetProgressCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.budgetAmount != widget.budgetAmount ||
        oldWidget.spentAmount != widget.spentAmount) {
      _formatCurrencies();
    }
  }

  Future<void> _formatCurrencies() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Format the budget amount
      _formattedBudget =
          await _currencyService.formatCurrency(widget.budgetAmount);

      // Format the spent amount
      _formattedSpent =
          await _currencyService.formatCurrency(widget.spentAmount);

      // Format the over budget amount if applicable
      if (widget.isOverBudget) {
        _formattedOver = await _currencyService
            .formatCurrency(widget.spentAmount - widget.budgetAmount);
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      // Use fallback formatting if there's an error
      if (mounted) {
        setState(() {
          _formattedBudget = '\$${widget.budgetAmount.toStringAsFixed(2)}';
          _formattedSpent = '\$${widget.spentAmount.toStringAsFixed(2)}';
          if (widget.isOverBudget) {
            _formattedOver =
                '\$${(widget.spentAmount - widget.budgetAmount).toStringAsFixed(2)}';
          }
          _isLoading = false;
        });
      }
    }
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
                  backgroundColor: widget.categoryColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.category,
                    style: Theme.of(context).textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${(widget.progressPercentage * 100).toInt()}%',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: widget.progressColor,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: widget.progressPercentage,
              color: widget.progressColor,
              backgroundColor: Colors.grey.shade200,
              minHeight: 8,
              borderRadius: const BorderRadius.all(Radius.circular(4)),
            ),
            const SizedBox(height: 8),
            _isLoading
                ? const SizedBox(
                    height: 10,
                    width: double.infinity,
                    child: LinearProgressIndicator(
                      backgroundColor: Colors.transparent,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Spent amount
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '$_formattedSpent spent',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Budget amount
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            'of $_formattedBudget',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ),
                    ],
                  ),
            if (widget.isOverBudget && !_isLoading)
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
                        'Over by $_formattedOver',
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
