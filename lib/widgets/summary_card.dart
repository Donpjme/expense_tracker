import 'package:flutter/material.dart';
import 'package:expense_tracker/services/currency_service.dart';

class SummaryCard extends StatefulWidget {
  final String title;
  final double value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
    super.key,
  });

  @override
  State<SummaryCard> createState() => _SummaryCardState();
}

class _SummaryCardState extends State<SummaryCard> {
  final CurrencyService _currencyService = CurrencyService();
  String _formattedValue = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _formatValue();
  }

  @override
  void didUpdateWidget(SummaryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _formatValue();
    }
  }

  Future<void> _formatValue() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Format using the currency service
      _formattedValue = await _currencyService.formatCurrency(widget.value);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      // Fallback to basic formatting
      if (mounted) {
        setState(() {
          _formattedValue = '\$${widget.value.toStringAsFixed(2)}';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    widget.icon,
                    color: widget.color,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _formattedValue,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
