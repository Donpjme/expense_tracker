import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/expense.dart';
import '../services/database_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  _ReportsScreenState createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  List<Expense> _expenses = [];
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    final expenses = await DatabaseService().getExpenses();
    setState(() {
      _expenses = expenses;
    });
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _selectedDateRange,
    );
    if (picked != null && picked != _selectedDateRange) {
      setState(() {
        _selectedDateRange = picked;
      });
      _loadExpenses(); // Reload expenses for the selected date range
    }
  }

  Map<String, double> _calculateSpendingByCategory(List<Expense> expenses) {
    final Map<String, double> spendingByCategory = {};
    for (final expense in expenses) {
      if (spendingByCategory.containsKey(expense.category)) {
        spendingByCategory[expense.category] =
            spendingByCategory[expense.category]! + expense.amount;
      } else {
        spendingByCategory[expense.category] = expense.amount;
      }
    }
    return spendingByCategory;
  }

  @override
  Widget build(BuildContext context) {
    final spendingByCategory = _calculateSpendingByCategory(_expenses);

    return Scaffold(
      appBar: AppBar(
        title: Text('Financial Reports'),
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_today),
            onPressed: () => _selectDateRange(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                sections: spendingByCategory.entries.map((entry) {
                  return PieChartSectionData(
                    value: entry.value,
                    title: entry.key,
                    color: Colors.primaries[
                        spendingByCategory.keys.toList().indexOf(entry.key) %
                            Colors.primaries.length],
                  );
                }).toList(),
              ),
            ),
          ),
          Expanded(
            child: BarChart(
              BarChartData(
                barGroups: spendingByCategory.entries.map((entry) {
                  return BarChartGroupData(
                    x: spendingByCategory.keys.toList().indexOf(entry.key),
                    barRods: [
                      BarChartRodData(
                        toY: entry.value, // Add the required `toY` parameter
                        color: Colors.blue,
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
