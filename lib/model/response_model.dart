import 'employee_model.dart';

class EmployeeResponse {
  final Employee employee;
  final String message;

  EmployeeResponse({
    required this.employee,
    required this.message,
  });

  factory EmployeeResponse.fromJson(Map<String, dynamic> json) {
    return EmployeeResponse(
      employee: Employee.fromJson(json['employee']),
      message: json['message'],
    );
  }
}
