import 'package:flutter/material.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/services/currency_service.dart';
import 'package:intl/intl.dart';

class ExpenseListItem extends StatefulWidget {
  final Expense expense;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const ExpenseListItem({
    required this.expense,
    this.onTap,
    this.onEdit,
    this.onDelete,
    super.key,
  });

  @override
  State<ExpenseListItem> createState() => _ExpenseListItemState();
}

class _ExpenseListItemState extends State<ExpenseListItem> {
  final CurrencyService _currencyService = CurrencyService();
  bool _isLoading = true;
  String _formattedAmount = '';
  String? _formattedOriginalAmount;
  String _defaultCurrency = '';
  bool _showOriginalAmount = false;

  @override
  void initState() {
    super.initState();
    _loadCurrencyData();
  }

  @override
  void didUpdateWidget(ExpenseListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expense.amount != widget.expense.amount ||
        oldWidget.expense.currency != widget.expense.currency ||
        oldWidget.expense.originalAmount != widget.expense.originalAmount) {
      _loadCurrencyData();
    }
  }

  Future<void> _loadCurrencyData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Get default currency code
      _defaultCurrency = await _currencyService.getCurrencyCode();

      // Format the amount
      _formattedAmount =
          await _currencyService.formatCurrency(widget.expense.amount);

      // Format original amount if it exists and is different from default currency
      _showOriginalAmount = widget.expense.originalAmount != null &&
          widget.expense.currency != _defaultCurrency;

      if (_showOriginalAmount) {
        final originalSymbol =
            _currencyService.currencySymbols[widget.expense.currency] ??
                widget.expense.currency;
        _formattedOriginalAmount =
            '$originalSymbol${widget.expense.originalAmount!.toStringAsFixed(2)}';
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      // Fallback to basic formatting
      if (mounted) {
        setState(() {
          _formattedAmount = '\$${widget.expense.amount.toStringAsFixed(2)}';
          _isLoading = false;
        });
      }
    }
  }

  // Helper method to format date
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final expenseDate = DateTime(date.year, date.month, date.day);

    if (expenseDate == today) {
      return 'Today';
    } else if (expenseDate == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color textColor =
        widget.expense.amount > 100 ? Colors.red : Colors.green;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          ListTile(
            title: Text(
              widget.expense.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.expense.category} • ${_formatDate(widget.expense.date)}',
                  overflow: TextOverflow.ellipsis,
                ),
                if (_showOriginalAmount && _formattedOriginalAmount != null)
                  Text(
                    'Original: $_formattedOriginalAmount (${widget.expense.currency})',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
            leading: CircleAvatar(
              backgroundColor:
                  Theme.of(context).colorScheme.primary.withOpacity(0.1),
              child: Icon(
                Icons.receipt,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            trailing: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : RichText(
                    textAlign: TextAlign.right,
                    text: TextSpan(
                      style: DefaultTextStyle.of(context).style,
                      children: [
                        TextSpan(
                          text: _formattedAmount,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: textColor,
                          ),
                        ),
                        if (widget.expense.currency != _defaultCurrency)
                          TextSpan(
                            text: '\n$_defaultCurrency',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
            onTap: widget.onTap,
          ),
          // Action buttons row
          Padding(
            padding: const EdgeInsets.only(right: 8, bottom: 8, left: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Edit button
                TextButton.icon(
                  icon: Icon(
                    Icons.edit,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  label: Text(
                    'Edit',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  onPressed: widget.onEdit,
                ),
                const SizedBox(width: 8),
                // Delete button
                TextButton.icon(
                  icon: const Icon(
                    Icons.delete,
                    size: 20,
                    color: Colors.red,
                  ),
                  label: const Text(
                    'Delete',
                    style: TextStyle(
                      color: Colors.red,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  onPressed: widget.onDelete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
