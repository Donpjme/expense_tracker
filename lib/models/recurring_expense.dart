class RecurringExpense {
  final String id;
  final String title;
  final double amount;
  final String category;
  final String startDate;
  final String nextDate;
  final String frequency; // 'Daily', 'Weekly', 'Monthly', 'Quarterly', 'Yearly'
  final String description;

  RecurringExpense({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.startDate,
    required this.nextDate,
    required this.frequency,
    this.description = '',
  });

  // Convert a RecurringExpense object to a Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'category': category,
      'startDate': startDate,
      'nextDate': nextDate,
      'frequency': frequency,
      'description': description,
    };
  }

  // Create a RecurringExpense object from a Map
  factory RecurringExpense.fromMap(Map<String, dynamic> map) {
    return RecurringExpense(
      id: map['id'],
      title: map['title'],
      amount: map['amount'],
      category: map['category'],
      startDate: map['startDate'],
      nextDate: map['nextDate'],
      frequency: map['frequency'],
      description: map['description'] ?? '',
    );
  }

  // Create a copy of this recurring expense with modified fields
  RecurringExpense copyWith({
    String? id,
    String? title,
    double? amount,
    String? category,
    String? startDate,
    String? nextDate,
    String? frequency,
    String? description,
  }) {
    return RecurringExpense(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      startDate: startDate ?? this.startDate,
      nextDate: nextDate ?? this.nextDate,
      frequency: frequency ?? this.frequency,
      description: description ?? this.description,
    );
  }

  @override
  String toString() {
    return 'RecurringExpense{id: $id, title: $title, amount: $amount, category: $category, frequency: $frequency, nextDate: $nextDate}';
  }
}
