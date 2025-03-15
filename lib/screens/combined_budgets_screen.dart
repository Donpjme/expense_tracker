import 'package:flutter/material.dart';
import 'package:expense_tracker/screens/budget_setting_screen.dart';
import 'package:expense_tracker/screens/recurring_budget_screen.dart';

class CombinedBudgetsScreen extends StatefulWidget {
  const CombinedBudgetsScreen({super.key});

  @override
  State<CombinedBudgetsScreen> createState() => _CombinedBudgetsScreenState();
}

class _CombinedBudgetsScreenState extends State<CombinedBudgetsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Budgets'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Regular'),
            Tab(text: 'Recurring'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          // Regular budgets tab
          BudgetSettingScreen(),

          // Recurring budgets tab
          RecurringBudgetScreen(),
        ],
      ),
    );
  }
}
