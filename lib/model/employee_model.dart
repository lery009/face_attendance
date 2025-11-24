class Employee {
  final String id;
  final String createdAt;
  final String name;
  final String firstname;
  final String lastname;
  final String department;
  final String email;
  final String profile;
  final List<double> embeddings;

  Employee({
    required this.id,
    required this.createdAt,
    required this.name,
    required this.firstname,
    required this.lastname,
    required this.department,
    required this.email,
    required this.profile,
    required this.embeddings,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      id: json['ID'],
      createdAt: json['createdAt'],
      name: json['name'],
      firstname: json['firstname'],
      lastname: json['lastname'],
      department: json['department'],
      email: json['email'],
      profile: json['profile'],
      embeddings: (json['embeddings'] as List<dynamic>)
          .map((e) => (e as num).toDouble())
          .toList(),
    );
  }
}
