import 'package:flutter/material.dart';
import '../api/api_service.dart';
import 'QRCodeDisplayScreen.dart';
import 'OnlineRegistrationScreen.dart';

class EmployeeManagementScreen extends StatefulWidget {
  const EmployeeManagementScreen({super.key});

  @override
  State<EmployeeManagementScreen> createState() => _EmployeeManagementScreenState();
}

class _EmployeeManagementScreenState extends State<EmployeeManagementScreen> {
  final ApiService apiService = ApiService();
  final TextEditingController searchController = TextEditingController();

  List<Map<String, dynamic>> employees = [];
  bool isLoading = true;
  String searchQuery = '';

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    loadEmployees();
  }

  Future<void> loadEmployees() async {
    setState(() => isLoading = true);

    try {
      final response = await apiService.getAllEmployees(
        search: searchQuery.isNotEmpty ? searchQuery : null,
      );

      setState(() {
        if (response['success'] == true) {
          employees = (response['employees'] as List<dynamic>).map((emp) => {
            'id': emp['id'] ?? '',
            'name': emp['name'] ?? 'Unknown',
            'employeeId': emp['employeeId'] ?? '',
            'department': emp['department'] ?? '',
            'email': emp['email'] ?? '',
            'createdAt': emp['createdAt'] ?? '',
          }).toList();
        }
        isLoading = false;
      });
    } catch (e) {
      print('Error loading employees: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> deleteEmployee(String employeeId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete $name?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final response = await apiService.deleteEmployee(employeeId);

      if (response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Employee deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        loadEmployees();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Failed to delete employee'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Employee Management'),
        backgroundColor: const Color(0xFF1E3A8A),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: loadEmployees,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Search by name, ID, email, or department...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          searchController.clear();
                          setState(() => searchQuery = '');
                          loadEmployees();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (value) {
                setState(() => searchQuery = value);
                // Debounce search
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (searchQuery == value) {
                    loadEmployees();
                  }
                });
              },
            ),
          ),

          // Employee List
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : employees.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              searchQuery.isNotEmpty
                                  ? 'No employees found matching "$searchQuery"'
                                  : 'No employees registered',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (searchQuery.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              TextButton.icon(
                                onPressed: () {
                                  searchController.clear();
                                  setState(() => searchQuery = '');
                                  loadEmployees();
                                },
                                icon: const Icon(Icons.clear),
                                label: const Text('Clear Search'),
                              ),
                            ],
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: loadEmployees,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(20),
                          itemCount: employees.length,
                          itemBuilder: (context, index) {
                            final employee = employees[index];

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: Colors.grey[200]!),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                leading: CircleAvatar(
                                  backgroundColor: const Color(0xFF1E3A8A).withOpacity(0.1),
                                  radius: 28,
                                  child: Text(
                                    (employee['name'] ?? 'U')[0].toUpperCase(),
                                    style: const TextStyle(
                                      color: Color(0xFF1E3A8A),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 24,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  employee['name'] ?? 'Unknown',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(Icons.badge, size: 14, color: Colors.grey[600]),
                                        const SizedBox(width: 4),
                                        Text(
                                          employee['employeeId'] ?? '',
                                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Icon(Icons.business, size: 14, color: Colors.grey[600]),
                                        const SizedBox(width: 4),
                                        Text(
                                          employee['department'] ?? 'N/A',
                                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.qr_code, color: Color(0xFF1E3A8A)),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => QRCodeDisplayScreen(
                                              employeeId: employee['employeeId'],
                                              employeeName: employee['name'],
                                            ),
                                          ),
                                        );
                                      },
                                      tooltip: 'View QR Code',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                                      onPressed: () => deleteEmployee(
                                        employee['employeeId'],
                                        employee['name'],
                                      ),
                                      tooltip: 'Delete Employee',
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // Navigate to registration screen
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const OnlineRegistrationScreen(),
            ),
          );

          // Reload employees if registration was successful
          if (result == true) {
            loadEmployees();
          }
        },
        backgroundColor: const Color(0xFF1E3A8A),
        icon: const Icon(Icons.person_add),
        label: const Text('Add Employee'),
      ),
    );
  }
}
