import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'WebRecognitionScreen.dart';
import 'WebRegistrationScreen.dart';
import 'AttendanceLogsScreen.dart';
import 'ReportsScreen.dart';
import 'EmployeeManagementScreen.dart';
import 'OnlineRegistrationScreen.dart';
import 'EventManagementScreen.dart';
import 'AnalyticsDashboardScreen.dart';
import 'UserManagementScreen.dart';
import 'LoginScreen.dart';
import 'QRCodeScannerScreen.dart';
import 'LocationManagementScreen.dart';
import 'NotificationSettingsScreen.dart';
import 'BulkImportScreen.dart';
import 'SendInvitationScreen.dart';
import 'CameraManagementScreen.dart';
import 'LiveMonitoringScreen.dart';
import '../api/api_service.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService apiService = ApiService();
  final AuthService authService = AuthService();
  final ThemeService themeService = ThemeService();

  int todayAttendanceCount = 0;
  int totalEmployees = 0;
  List<Map<String, dynamic>> recentAttendance = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadDashboardData();
  }

  Future<void> loadDashboardData() async {
    setState(() => isLoading = true);

    try {
      // Get today's date
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // Fetch attendance logs for today
      final attendanceResponse = await apiService.getAttendanceLogs(date: today);

      // Fetch all employees
      final employeesResponse = await apiService.getAllEmployees();

      setState(() {
        if (attendanceResponse['success'] == true) {
          final logs = attendanceResponse['logs'] as List<dynamic>;
          todayAttendanceCount = logs.length;
          recentAttendance = logs.take(5).map((log) => {
            'employeeName': log['employeeName'] ?? 'Unknown',
            'time': log['timestamp'] ?? '',
            'confidence': log['confidence'] ?? '0',
          }).toList();
        }

        if (employeesResponse['success'] == true) {
          totalEmployees = employeesResponse['count'] ?? 0;
        }

        isLoading = false;
      });
    } catch (e) {
      print('Error loading dashboard: $e');
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Face Recognition Attendance',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
            ),
            Text(
              'Welcome, ${authService.userName}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w300),
            ),
          ],
        ),
        actions: [
          // User role badge
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  authService.isAdmin
                      ? Icons.admin_panel_settings
                      : authService.isManager
                          ? Icons.supervisor_account
                          : Icons.person,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  authService.userRole?.toUpperCase() ?? 'USER',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: loadDashboardData,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: Icon(themeService.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () {
              themeService.toggleTheme();
            },
            tooltip: themeService.isDarkMode ? 'Switch to Light Mode' : 'Switch to Dark Mode',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle),
            tooltip: 'Account Menu',
            onSelected: (value) async {
              if (value == 'logout') {
                await authService.logout();
                if (!mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      authService.userName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      authService.userEmail,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20),
                    SizedBox(width: 12),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: loadDashboardData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome Section
                    Text(
                      'Dashboard',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    Text(
                      DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Stats Cards
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Today\'s Attendance',
                            todayAttendanceCount.toString(),
                            Icons.check_circle_outline,
                            const Color(0xFF10B981), // Green
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildStatCard(
                            'Total Employees',
                            totalEmployees.toString(),
                            Icons.people_outline,
                            const Color(0xFF3B82F6), // Blue
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Quick Actions
                    Text(
                      'Quick Actions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionButton(
                            'Mark Attendance',
                            Icons.face_retouching_natural,
                            const Color(0xFF1E3A8A),
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const WebRecognitionScreen()),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildActionButton(
                            'Register Employee',
                            Icons.person_add_outlined,
                            const Color(0xFF059669),
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const WebRegistrationScreen()),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Recent Attendance
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Recent Attendance',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AttendanceLogsScreen()),
                          ),
                          child: const Text('View All'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildRecentAttendanceList(),
                    const SizedBox(height: 32),

                    // Navigation Cards
                    Text(
                      'More Options',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildNavigationCard(
                      'Attendance Logs',
                      'View detailed attendance records',
                      Icons.list_alt,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AttendanceLogsScreen()),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildNavigationCard(
                      'QR Code Scanner',
                      'Scan QR codes to mark attendance',
                      Icons.qr_code_scanner,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const QRCodeScannerScreen()),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildNavigationCard(
                      'Analytics Dashboard',
                      'View detailed charts and statistics',
                      Icons.analytics,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AnalyticsDashboardScreen()),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildNavigationCard(
                      'Reports & Analytics',
                      'Generate attendance reports',
                      Icons.bar_chart,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ReportsScreen()),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildNavigationCard(
                      'Employee Management',
                      'Manage registered employees',
                      Icons.manage_accounts,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const EmployeeManagementScreen()),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildNavigationCard(
                      'Bulk Import Employees',
                      'Import multiple employees from CSV file',
                      Icons.cloud_upload,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const BulkImportScreen()),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildNavigationCard(
                      'Send Invitation',
                      'Invite employees to register via email',
                      Icons.mail_outline,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SendInvitationScreen()),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildNavigationCard(
                      'Event Management',
                      'Create and manage events with attendance tracking',
                      Icons.event_note,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const EventManagementScreen()),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildNavigationCard(
                      'Online Registration',
                      'Public self-registration portal',
                      Icons.how_to_reg,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const OnlineRegistrationScreen()),
                      ),
                    ),
                    // Admin-only: User Management, Location Management & Notification Settings
                    if (authService.isAdmin) ...[
                      const SizedBox(height: 12),
                      _buildNavigationCard(
                        'User Management',
                        'Manage system users and permissions',
                        Icons.people,
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const UserManagementScreen()),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildNavigationCard(
                        'Location Management',
                        'Configure GPS geofencing locations',
                        Icons.map,
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const LocationManagementScreen()),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildNavigationCard(
                        'Notification Settings',
                        'Configure email notifications and SMTP settings',
                        Icons.notifications_active,
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildNavigationCard(
                        'Camera Management',
                        'Manage IP cameras for event monitoring',
                        Icons.videocam,
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CameraManagementScreen()),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildNavigationCard(
                        'Live Monitoring',
                        'View live camera feeds with face recognition',
                        Icons.monitor,
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const LiveMonitoringScreen()),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String title, IconData icon, Color color, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      label: Text(title),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: 0,
      ),
    );
  }

  Widget _buildRecentAttendanceList() {
    if (recentAttendance.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.event_busy, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 12),
              Text(
                'No attendance records today',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: recentAttendance.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey[200]),
        itemBuilder: (context, index) {
          final record = recentAttendance[index];
          final time = DateTime.tryParse(record['time'] ?? '');
          final localTime = time?.toLocal();  // Convert to local timezone
          final timeStr = localTime != null ? DateFormat('h:mm a').format(localTime) : 'Unknown';

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF1E3A8A).withOpacity(0.1),
              child: Icon(Icons.person, color: const Color(0xFF1E3A8A)),
            ),
            title: Text(
              record['employeeName'] ?? 'Unknown',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(timeStr),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Present',
                style: const TextStyle(
                  color: Color(0xFF10B981),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNavigationCard(String title, String subtitle, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A8A).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: const Color(0xFF1E3A8A), size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}
