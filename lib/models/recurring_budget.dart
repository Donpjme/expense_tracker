/// A model representing a recurring budget that automatically repeats based on frequency
class RecurringBudget {
  final String id;
  final String category;
  final double budgetLimit;
  final DateTime startDate;
  final DateTime nextDate;
  final String frequency; // 'Monthly', 'Quarterly', 'Yearly'
  final String currency; // New field

  RecurringBudget({
    required this.id,
    required this.category,
    required this.budgetLimit,
    required this.startDate,
    required this.nextDate,
    required this.frequency,
    this.currency = 'USD', // Default currency
  });

  /// Convert a RecurringBudget object to a Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category': category,
      'budgetLimit': budgetLimit,
      'startDate': startDate.toIso8601String(),
      'nextDate': nextDate.toIso8601String(),
      'frequency': frequency,
      'currency': currency,
    };
  }

  /// Create a RecurringBudget object from a Map retrieved from the database
  factory RecurringBudget.fromMap(Map<String, dynamic> map) {
    return RecurringBudget(
      id: map['id'],
      category: map['category'],
      budgetLimit: map['budgetLimit'],
      startDate: DateTime.parse(map['startDate']),
      nextDate: DateTime.parse(map['nextDate']),
      frequency: map['frequency'],
      currency: map['currency'] ?? 'USD', // Default to USD if not specified
    );
  }
}
