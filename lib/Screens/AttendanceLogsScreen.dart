import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:html' as html;
import '../api/api_service.dart';

class AttendanceLogsScreen extends StatefulWidget {
  const AttendanceLogsScreen({super.key});

  @override
  State<AttendanceLogsScreen> createState() => _AttendanceLogsScreenState();
}

class _AttendanceLogsScreenState extends State<AttendanceLogsScreen> {
  final ApiService apiService = ApiService();
  final TextEditingController searchController = TextEditingController();

  List<Map<String, dynamic>> attendanceLogs = [];
  bool isLoading = true;
  DateTime selectedDate = DateTime.now();
  String searchQuery = '';
  String? selectedStatus;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    loadAttendanceLogs();
  }

  Future<void> loadAttendanceLogs() async {
    setState(() => isLoading = true);

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
      final response = await apiService.getAttendanceLogs(
        date: dateStr,
        search: searchQuery.isNotEmpty ? searchQuery : null,
        status: selectedStatus,
      );

      setState(() {
        if (response['success'] == true) {
          attendanceLogs = (response['logs'] as List<dynamic>).map((log) => {
            'id': log['id'] ?? '',
            'employeeName': log['employeeName'] ?? 'Unknown',
            'employeeId': log['employeeId'] ?? '',
            'timestamp': log['timestamp'] ?? '',
            'confidence': log['confidence'] ?? '0',
            'method': log['method'] ?? 'face_recognition',
            'status': log['status'] ?? 'on_time',
            'notes': log['notes'] ?? '',
          }).toList();
        }
        isLoading = false;
      });
    } catch (e) {
      print('Error loading attendance logs: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1E3A8A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != selectedDate) {
      setState(() => selectedDate = picked);
      loadAttendanceLogs();
    }
  }

  /// Show export options dialog
  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Attendance'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: const Text('Export as PDF'),
              onTap: () {
                Navigator.pop(context);
                _exportAs('pdf');
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart, color: Colors.green),
              title: const Text('Export as Excel'),
              onTap: () {
                Navigator.pop(context);
                _exportAs('excel');
              },
            ),
            ListTile(
              leading: const Icon(Icons.description, color: Colors.blue),
              title: const Text('Export as CSV'),
              onTap: () {
                Navigator.pop(context);
                _exportAs('csv');
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Export attendance data
  void _exportAs(String format) {
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
      final url = apiService.getAttendanceExportUrl(
        format: format,
        date: dateStr,
      );
      final filename = 'attendance_${dateStr}.${{
        'pdf': 'pdf',
        'excel': 'xlsx',
        'csv': 'csv',
      }[format]}';

      // Trigger download
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', filename)
        ..style.display = 'none';
      html.document.body?.append(anchor);
      anchor.click();
      anchor.remove();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📥 ${format.toUpperCase()} export downloaded!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Export error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Export failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Attendance Logs'),
        backgroundColor: const Color(0xFF1E3A8A),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: selectDate,
            tooltip: 'Select Date',
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _showExportDialog,
            tooltip: 'Export Data',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: loadAttendanceLogs,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Date selector
          Container(
            color: const Color(0xFF1E3A8A),
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Row(
              children: [
                const Icon(Icons.event, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  DateFormat('EEEE, MMMM d, yyyy').format(selectedDate),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Text(
                  '${attendanceLogs.length} records',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          // Search and Filter Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                // Search field
                TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name or employee ID...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              searchController.clear();
                              setState(() => searchQuery = '');
                              loadAttendanceLogs();
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
                        loadAttendanceLogs();
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),
                // Status filter
                Row(
                  children: [
                    const Text('Status:', style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        children: [
                          FilterChip(
                            label: const Text('All'),
                            selected: selectedStatus == null,
                            onSelected: (selected) {
                              setState(() => selectedStatus = null);
                              loadAttendanceLogs();
                            },
                          ),
                          FilterChip(
                            label: const Text('On Time'),
                            selected: selectedStatus == 'on_time',
                            selectedColor: Colors.green[100],
                            onSelected: (selected) {
                              setState(() => selectedStatus = selected ? 'on_time' : null);
                              loadAttendanceLogs();
                            },
                          ),
                          FilterChip(
                            label: const Text('Late'),
                            selected: selectedStatus == 'late',
                            selectedColor: Colors.orange[100],
                            onSelected: (selected) {
                              setState(() => selectedStatus = selected ? 'late' : null);
                              loadAttendanceLogs();
                            },
                          ),
                          FilterChip(
                            label: const Text('Half Day'),
                            selected: selectedStatus == 'half_day',
                            selectedColor: Colors.red[100],
                            onSelected: (selected) {
                              setState(() => selectedStatus = selected ? 'half_day' : null);
                              loadAttendanceLogs();
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Logs list
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : attendanceLogs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'No attendance records for this date',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: selectDate,
                              icon: const Icon(Icons.calendar_today),
                              label: const Text('Select Different Date'),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: loadAttendanceLogs,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(20),
                          itemCount: attendanceLogs.length,
                          itemBuilder: (context, index) {
                            final log = attendanceLogs[index];
                            final time = DateTime.tryParse(log['timestamp'] ?? '');
                            final timeStr = time != null
                                ? DateFormat('h:mm:ss a').format(time)
                                : 'Unknown';

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
                                  radius: 24,
                                  child: Text(
                                    (log['employeeName'] ?? 'U')[0].toUpperCase(),
                                    style: const TextStyle(
                                      color: Color(0xFF1E3A8A),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  log['employeeName'] ?? 'Unknown',
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
                                          log['employeeId'] ?? '',
                                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                                        const SizedBox(width: 4),
                                        Text(
                                          timeStr,
                                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Present',
                                    style: TextStyle(
                                      color: Color(0xFF10B981),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
