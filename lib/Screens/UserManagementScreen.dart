import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api/api_service.dart';
import '../services/auth_service.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final ApiService apiService = ApiService();
  final AuthService authService = AuthService();

  List<Map<String, dynamic>> users = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadUsers();
  }

  Future<void> loadUsers() async {
    setState(() => isLoading = true);

    try {
      final response = await apiService.getAllUsers();

      setState(() {
        if (response['success'] == true) {
          users = (response['users'] as List<dynamic>).map((user) => {
            'id': user['id'] ?? '',
            'username': user['username'] ?? 'Unknown',
            'email': user['email'] ?? '',
            'full_name': user['full_name'] ?? '',
            'role': user['role'] ?? 'viewer',
            'is_active': user['is_active'] ?? true,
            'created_at': user['created_at'] ?? '',
            'last_login': user['last_login'],
          }).toList();
        }
        isLoading = false;
      });
    } catch (e) {
      print('Error loading users: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> showCreateUserDialog() async {
    final usernameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final fullNameController = TextEditingController();
    String selectedRole = 'viewer';

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create New User'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: fullNameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name (Optional)',
                    prefixIcon: Icon(Icons.badge),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    prefixIcon: Icon(Icons.admin_panel_settings),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'viewer', child: Text('Viewer - Read-only access')),
                    DropdownMenuItem(value: 'manager', child: Text('Manager - Manage employees')),
                    DropdownMenuItem(value: 'admin', child: Text('Admin - Full access')),
                  ],
                  onChanged: (value) {
                    setState(() => selectedRole = value!);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (usernameController.text.isEmpty ||
                    emailController.text.isEmpty ||
                    passwordController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill all required fields'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                final response = await apiService.createUser(
                  username: usernameController.text.trim(),
                  email: emailController.text.trim(),
                  password: passwordController.text,
                  role: selectedRole,
                  fullName: fullNameController.text.isNotEmpty
                      ? fullNameController.text.trim()
                      : null,
                );

                if (!mounted) return;
                Navigator.pop(context);

                if (response['success'] == true) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('User created successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  loadUsers();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(response['message'] ?? 'Failed to create user'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> showEditUserDialog(Map<String, dynamic> user) async {
    final emailController = TextEditingController(text: user['email']);
    final fullNameController = TextEditingController(text: user['full_name']);
    String selectedRole = user['role'];
    bool isActive = user['is_active'];

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Edit User: ${user['username']}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: fullNameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.badge),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    prefixIcon: Icon(Icons.admin_panel_settings),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'viewer', child: Text('Viewer')),
                    DropdownMenuItem(value: 'manager', child: Text('Manager')),
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  ],
                  onChanged: (value) {
                    setState(() => selectedRole = value!);
                  },
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Active'),
                  subtitle: const Text('User can login'),
                  value: isActive,
                  onChanged: (value) {
                    setState(() => isActive = value);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final response = await apiService.updateUser(
                  userId: user['id'],
                  email: emailController.text.trim(),
                  fullName: fullNameController.text.trim(),
                  role: selectedRole,
                  isActive: isActive,
                );

                if (!mounted) return;
                Navigator.pop(context);

                if (response['success'] == true) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('User updated successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  loadUsers();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(response['message'] ?? 'Failed to update user'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> deleteUser(String userId, String username) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete user "$username"?'),
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
      final response = await apiService.deleteUser(userId);

      if (!mounted) return;

      if (response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        loadUsers();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Failed to delete user'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Color getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Colors.red;
      case 'manager':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData getRoleIcon(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Icons.admin_panel_settings;
      case 'manager':
        return Icons.supervisor_account;
      default:
        return Icons.person;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('User Management'),
        backgroundColor: const Color(0xFF1E3A8A),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: loadUsers,
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: showCreateUserDialog,
        icon: const Icon(Icons.person_add),
        label: const Text('Add User'),
        backgroundColor: const Color(0xFF1E3A8A),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : users.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No users found',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: loadUsers,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      final isCurrentUser = user['id'] == authService.currentUser?['id'];
                      final lastLogin = user['last_login'] != null
                          ? DateTime.tryParse(user['last_login'])
                          : null;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isCurrentUser
                                ? const Color(0xFF1E3A8A)
                                : Colors.grey[200]!,
                            width: isCurrentUser ? 2 : 1,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: CircleAvatar(
                            backgroundColor: getRoleColor(user['role']).withOpacity(0.1),
                            radius: 28,
                            child: Icon(
                              getRoleIcon(user['role']),
                              color: getRoleColor(user['role']),
                              size: 28,
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(
                                user['username'] ?? 'Unknown',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              if (isCurrentUser) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E3A8A),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'You',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.email, size: 14, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Text(
                                    user['email'] ?? '',
                                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(getRoleIcon(user['role']), size: 14, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Text(
                                    user['role'].toString().toUpperCase(),
                                    style: TextStyle(
                                      color: getRoleColor(user['role']),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (!user['is_active']) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.red[100],
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'Inactive',
                                        style: TextStyle(
                                          color: Colors.red,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (lastLogin != null) ...[
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Last login: ${DateFormat('MMM d, h:mm a').format(lastLogin)}',
                                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, color: Color(0xFF1E3A8A)),
                                onPressed: () => showEditUserDialog(user),
                                tooltip: 'Edit User',
                              ),
                              if (!isCurrentUser)
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  onPressed: () => deleteUser(user['id'], user['username']),
                                  tooltip: 'Delete User',
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
