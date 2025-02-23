class RecurringExpense {
  final String id;
  final String title;
  final double amount;
  final String category;
  final DateTime startDate;
  final DateTime nextDate;
  final String frequency; // e.g., 'daily', 'weekly', 'monthly'

  RecurringExpense({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.startDate,
    required this.nextDate,
    required this.frequency,
  });

  // Convert a RecurringExpense object to a Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'category': category,
      'startDate': startDate.toIso8601String(),
      'nextDate': nextDate.toIso8601String(),
      'frequency': frequency,
    };
  }

  // Create a RecurringExpense object from a Map
  factory RecurringExpense.fromMap(Map<String, dynamic> map) {
    return RecurringExpense(
      id: map['id'],
      title: map['title'],
      amount: map['amount'],
      category: map['category'],
      startDate: DateTime.parse(map['startDate']),
      nextDate: DateTime.parse(map['nextDate']),
      frequency: map['frequency'],
    );
  }
}
