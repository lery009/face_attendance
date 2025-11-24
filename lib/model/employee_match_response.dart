import 'employee_match_model.dart';

class EmployeeMatchResponse {
  final EmployeeMatch match;

  EmployeeMatchResponse({required this.match});

  factory EmployeeMatchResponse.fromJson(Map<String, dynamic> json) {
    return EmployeeMatchResponse(
      match: EmployeeMatch.fromJson(json['match']),
    );
  }
}
