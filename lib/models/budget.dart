class Budget {
  final String id;
  final String category;
  final double budgetLimit; // Renamed from 'limit' to 'budgetLimit'
  final DateTime startDate;
  final DateTime endDate;

  Budget({
    required this.id,
    required this.category,
    required this.budgetLimit, // Updated field name
    required this.startDate,
    required this.endDate,
  });

  // Convert a Budget object to a Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category': category,
      'budgetLimit': budgetLimit, // Updated field name
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
    };
  }

  // Create a Budget object from a Map
  factory Budget.fromMap(Map<String, dynamic> map) {
    return Budget(
      id: map['id'],
      category: map['category'],
      budgetLimit: map['budgetLimit'], // Updated field name
      startDate: DateTime.parse(map['startDate']),
      endDate: DateTime.parse(map['endDate']),
    );
  }
}
