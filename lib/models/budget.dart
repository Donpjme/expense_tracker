class Budget {
  final String id;
  final String category;
  final double budgetLimit;
  final DateTime startDate;
  final DateTime endDate;
  final String currency; // New field

  Budget({
    required this.id,
    required this.category,
    required this.budgetLimit,
    required this.startDate,
    required this.endDate,
    this.currency = 'USD', // Default currency
  });

  // Convert a Budget object to a Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category': category,
      'budgetLimit': budgetLimit,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'currency': currency,
    };
  }

  // Create a Budget object from a Map
  factory Budget.fromMap(Map<String, dynamic> map) {
    return Budget(
      id: map['id'],
      category: map['category'],
      budgetLimit: map['budgetLimit'],
      startDate: DateTime.parse(map['startDate']),
      endDate: DateTime.parse(map['endDate']),
      currency: map['currency'] ?? 'USD', // Default to USD if not specified
    );
  }
}
