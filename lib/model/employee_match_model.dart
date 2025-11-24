class EmployeeMatch {
  final String id;
  final String name;
  final String firstname;
  final String lastname;
  final String department;
  final String email;
  final String profile;
  final double score;
  final bool isMatch;

  EmployeeMatch({
    required this.id,
    required this.name,
    required this.firstname,
    required this.lastname,
    required this.department,
    required this.email,
    required this.profile,
    required this.score,
    required this.isMatch,
  });

  factory EmployeeMatch.fromJson(Map<String, dynamic> json) {
    return EmployeeMatch(
      id: json['id'],
      name: json['name'],
      firstname: json['firstname'],
      lastname: json['lastname'],
      department: json['department'],
      email: json['email'],
      profile: json['profile'],
      score: (json['score'] as num).toDouble(),
      isMatch: json['isMatch'],
    );
  }
}
