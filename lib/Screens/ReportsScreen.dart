import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:html' as html;
import '../api/api_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final ApiService apiService = ApiService();

  String selectedPeriod = 'Today';
  DateTime selectedDate = DateTime.now();
  bool isLoading = false;

  Map<String, int> reportData = {
    'totalAttendance': 0,
    'uniqueEmployees': 0,
    'totalEmployees': 0,
  };

  Map<String, dynamic> eventStats = {
    'total_events': 0,
    'upcoming_events': 0,
    'completed_events': 0,
    'average_attendance_rate': 0.0,
  };

  @override
  void initState() {
    super.initState();
    generateReport();
  }

  Future<void> generateReport() async {
    setState(() => isLoading = true);

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
      final attendanceResponse = await apiService.getAttendanceLogs(date: dateStr);
      final employeesResponse = await apiService.getAllEmployees();
      final eventsStatsResponse = await apiService.getEventStats();

      setState(() {
        if (attendanceResponse['success'] == true) {
          final logs = attendanceResponse['logs'] as List<dynamic>;
          reportData['totalAttendance'] = logs.length;
          reportData['uniqueEmployees'] = logs
              .map((log) => log['employeeId'])
              .toSet()
              .length;
        }

        if (employeesResponse['success'] == true) {
          reportData['totalEmployees'] = employeesResponse['count'] ?? 0;
        }

        if (eventsStatsResponse['success'] == true) {
          eventStats = eventsStatsResponse['stats'];
        }

        isLoading = false;
      });
    } catch (e) {
      print('Error generating report: $e');
      setState(() => isLoading = false);
    }
  }

  /// Download file for web
  void _downloadFile(String url, String filename) {
    print('📥 Downloading: $url');
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..style.display = 'none';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
  }

  /// Export attendance as PDF
  Future<void> _exportAsPdf() async {
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
      final url = apiService.getAttendanceExportUrl(
        format: 'pdf',
        date: dateStr,
      );
      final filename = 'attendance_report_${dateStr}.pdf';
      _downloadFile(url, filename);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📄 PDF report downloaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Export error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Export failed: $e')),
        );
      }
    }
  }

  /// Export attendance as Excel
  Future<void> _exportAsExcel() async {
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
      final url = apiService.getAttendanceExportUrl(
        format: 'excel',
        date: dateStr,
      );
      final filename = 'attendance_report_${dateStr}.xlsx';
      _downloadFile(url, filename);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📊 Excel report downloaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Export error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Export failed: $e')),
        );
      }
    }
  }

  /// Export attendance as CSV
  Future<void> _exportAsCsv() async {
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
      final url = apiService.getAttendanceExportUrl(
        format: 'csv',
        date: dateStr,
      );
      final filename = 'attendance_report_${dateStr}.csv';
      _downloadFile(url, filename);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📋 CSV report downloaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Export error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Export failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final attendanceRate = reportData['totalEmployees']! > 0
        ? (reportData['uniqueEmployees']! / reportData['totalEmployees']! * 100).toStringAsFixed(1)
        : '0.0';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Reports & Analytics'),
        backgroundColor: const Color(0xFF1E3A8A),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportAsPdf,
            tooltip: 'Download PDF Report',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Period Selector
            Text(
              'Select Period',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedPeriod,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    items: ['Today', 'Yesterday', 'This Week', 'This Month']
                        .map((period) => DropdownMenuItem(
                              value: period,
                              child: Text(period),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() => selectedPeriod = value!);
                      if (value == 'Today') {
                        selectedDate = DateTime.now();
                      } else if (value == 'Yesterday') {
                        selectedDate = DateTime.now().subtract(const Duration(days: 1));
                      }
                      generateReport();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: generateReport,
                  icon: const Icon(Icons.analytics, size: 20),
                  label: const Text('Generate'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Report Stats
            Text(
              'Summary',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),

            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Total Check-ins',
                          reportData['totalAttendance'].toString(),
                          Icons.event_available,
                          const Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Unique Employees',
                          reportData['uniqueEmployees'].toString(),
                          Icons.people,
                          const Color(0xFF3B82F6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Attendance Rate',
                          '$attendanceRate%',
                          Icons.pie_chart,
                          const Color(0xFFF59E0B),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Total Employees',
                          reportData['totalEmployees'].toString(),
                          Icons.group,
                          const Color(0xFF8B5CF6),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

            const SizedBox(height: 32),

            // Event Statistics
            Text(
              'Event Statistics',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),

            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Total Events',
                          eventStats['total_events'].toString(),
                          Icons.event,
                          const Color(0xFF6366F1),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Upcoming Events',
                          eventStats['upcoming_events'].toString(),
                          Icons.schedule,
                          const Color(0xFF3B82F6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Completed Events',
                          eventStats['completed_events'].toString(),
                          Icons.check_circle,
                          const Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Avg Event Attendance',
                          '${eventStats['average_attendance_rate']}%',
                          Icons.bar_chart,
                          const Color(0xFFF59E0B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

            const SizedBox(height: 32),

            // Export Options
            Text(
              'Export Options',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            _buildExportOption('Export as PDF', Icons.picture_as_pdf, _exportAsPdf),
            const SizedBox(height: 8),
            _buildExportOption('Export as Excel', Icons.table_chart, _exportAsExcel),
            const SizedBox(height: 8),
            _buildExportOption('Export as CSV', Icons.description, _exportAsCsv),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportOption(String title, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF1E3A8A)),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}
