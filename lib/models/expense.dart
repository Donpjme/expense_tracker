class Expense {
  final String id;
  final String title;
  final double amount;
  final DateTime date;
  final String category;
  final String currency; // New field
  final double? originalAmount; // Optional: store original amount if converted

  Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.category,
    this.currency = 'USD', // Default currency
    this.originalAmount,
  });

  // Convert an Expense object into a Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'date': date.toIso8601String(), // Convert DateTime to String
      'category': category,
      'currency': currency,
      'originalAmount': originalAmount,
    };
  }

  // Create an Expense object from a Map
  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'],
      title: map['title'],
      amount: map['amount'],
      date: DateTime.parse(map['date']), // Convert String to DateTime
      category: map['category'],
      currency: map['currency'] ?? 'USD', // Default to USD if not specified
      originalAmount: map['originalAmount'],
    );
  }
}
