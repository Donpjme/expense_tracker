class RecurringExpense {
  final String id;
  final String title;
  final double amount;
  final String category;
  final DateTime startDate;
  final DateTime nextDate;
  final String frequency; // e.g., 'daily', 'weekly', 'monthly'
  final bool isActive;
  final String currency; // New field

  RecurringExpense({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.startDate,
    required this.nextDate,
    required this.frequency,
    this.isActive = true, // Default to active
    this.currency = 'USD', // Default currency
  });

  // Convert a RecurringExpense object to a Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'category': category,
      'startDate': startDate.toIso8601String(),
      'nextDate': nextDate.toIso8601String(),
      'frequency': frequency,
      'isActive': isActive ? 1 : 0, // Store as 1 (true) or 0 (false) for SQLite
      'currency': currency,
    };
  }

  // Create a RecurringExpense object from a Map retrieved from the database
  factory RecurringExpense.fromMap(Map<String, dynamic> map) {
    return RecurringExpense(
      id: map['id'],
      title: map['title'],
      amount: map['amount'],
      category: map['category'],
      startDate: DateTime.parse(map['startDate']),
      nextDate: DateTime.parse(map['nextDate']),
      frequency: map['frequency'],
      isActive: map['isActive'] == null
          ? true
          : map['isActive'] == 1, // Handle null case
      currency: map['currency'] ?? 'USD', // Default to USD if not specified
    );
  }
}
