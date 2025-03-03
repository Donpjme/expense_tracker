class Category {
  final String id;
  final String name;

  Category({
    required this.id,
    required this.name,
  });

  // Convert a Category object to a Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
    };
  }

  // Create a Category object from a Map
  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'],
      name: map['name'],
    );
  }
}
