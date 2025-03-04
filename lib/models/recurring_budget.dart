class RecurringBudget {
  final String id;
  final String category;
  final double budgetLimit;
  final String frequency; // 'Monthly', 'Quarterly', 'Yearly'
  final String startDate;
  final String nextStartDate;
  final String nextEndDate;

  RecurringBudget({
    required this.id,
    required this.category,
    required this.budgetLimit,
    required this.frequency,
    required this.startDate,
    required this.nextStartDate,
    required this.nextEndDate,
  });

  // Convert a RecurringBudget object to a Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category': category,
      'budgetLimit': budgetLimit,
      'frequency': frequency,
      'startDate': startDate,
      'nextStartDate': nextStartDate,
      'nextEndDate': nextEndDate,
    };
  }

  // Create a RecurringBudget object from a Map
  factory RecurringBudget.fromMap(Map<String, dynamic> map) {
    return RecurringBudget(
      id: map['id'],
      category: map['category'],
      budgetLimit: map['budgetLimit'],
      frequency: map['frequency'],
      startDate: map['startDate'],
      nextStartDate: map['nextStartDate'],
      nextEndDate: map['nextEndDate'],
    );
  }

  // Create a copy of this recurring budget with modified fields
  RecurringBudget copyWith({
    String? id,
    String? category,
    double? budgetLimit,
    String? frequency,
    String? startDate,
    String? nextStartDate,
    String? nextEndDate,
  }) {
    return RecurringBudget(
      id: id ?? this.id,
      category: category ?? this.category,
      budgetLimit: budgetLimit ?? this.budgetLimit,
      frequency: frequency ?? this.frequency,
      startDate: startDate ?? this.startDate,
      nextStartDate: nextStartDate ?? this.nextStartDate,
      nextEndDate: nextEndDate ?? this.nextEndDate,
    );
  }

  @override
  String toString() {
    return 'RecurringBudget{id: $id, category: $category, budgetLimit: $budgetLimit, frequency: $frequency, nextStartDate: $nextStartDate}';
  }
}
