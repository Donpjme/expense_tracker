import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/providers/currency_provider.dart';
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
  String _formattedAmount = '';
  String? _formattedOriginalAmount;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _formatAmounts();
  }

  @override
  void didUpdateWidget(ExpenseListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the expense changed, reformat amounts
    if (oldWidget.expense != widget.expense) {
      _formatAmounts();
    }
  }

  Future<void> _formatAmounts() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
      
      // If expense currency matches app currency, just format the amount
      if (widget.expense.currency == currencyProvider.currencyCode) {
        _formattedAmount = currencyProvider.formatAmount(widget.expense.amount);
        _formattedOriginalAmount = null;
      } 
      // If currencies differ, show both the converted and original amount
      else {
        // The amount field should already be stored in the app's currency
        _formattedAmount = currencyProvider.formatAmount(widget.expense.amount);
        
        // Format the original amount if available
        if (widget.expense.originalAmount != null) {
          if (widget.expense.currency == 'JPY' || widget.expense.currency == 'KRW') {
            _formattedOriginalAmount = '${widget.expense.currency} ${widget.expense.originalAmount!.round()}';
          } else {
            _formattedOriginalAmount = '${widget.expense.currency} ${widget.expense.originalAmount!.toStringAsFixed(2)}';
          }
        }
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      // Fallback formatting
      if (mounted) {
        setState(() {
          _formattedAmount = '\$${widget.expense.amount.toStringAsFixed(2)}';
          if (widget.expense.originalAmount != null) {
            _formattedOriginalAmount = '${widget.expense.currency} ${widget.expense.originalAmount!.toStringAsFixed(2)}';
          }
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get the currency provider
    final currencyProvider = Provider.of<CurrencyProvider>(context);
    final isDifferentCurrency = widget.expense.currency != currencyProvider.currencyCode;
    final String formattedDate = _formatDate(widget.expense.date);

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
                  '${widget.expense.category} • $formattedDate',
                  overflow: TextOverflow.ellipsis,
                ),
                // Show original amount if in a different currency
                if (isDifferentCurrency &&
                    widget.expense.originalAmount != null &&
                    _formattedOriginalAmount != null)
                  Text(
                    'Original: $_formattedOriginalAmount',
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
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(
                    _formattedAmount,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: widget.expense.amount > 100
                          ? Colors.red
                          : Colors.green,
                    ),
                  ),
            onTap: widget.onTap,
          ),
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
}
