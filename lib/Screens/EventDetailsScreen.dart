import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api/api_service.dart';
import 'EventInvitationScreen.dart';
import 'LiveMonitoringScreen.dart';

class EventDetailsScreen extends StatefulWidget {
  final String eventId;

  const EventDetailsScreen({super.key, required this.eventId});

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  final ApiService apiService = ApiService();

  Map<String, dynamic>? event;
  List<Map<String, dynamic>> participants = [];
  List<Map<String, dynamic>> linkedCameras = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadEventDetails();
  }

  Future<void> loadEventDetails() async {
    setState(() => isLoading = true);

    try {
      final response = await apiService.getEventDetails(widget.eventId);
      final camerasResponse = await apiService.getEventCameras(widget.eventId);

      setState(() {
        if (response['success'] == true) {
          event = response['event'];
          participants = (response['participants'] as List<dynamic>)
              .map((p) => p as Map<String, dynamic>)
              .toList();
        }
        if (camerasResponse['success'] == true) {
          linkedCameras = (camerasResponse['cameras'] as List<dynamic>)
              .map((c) => c as Map<String, dynamic>)
              .toList();
        }
        isLoading = false;
      });
    } catch (e) {
      print('Error loading event details: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> showCameraManagementDialog() async {
    await showDialog(
      context: context,
      builder: (context) => EventCameraDialog(
        eventId: widget.eventId,
        linkedCameras: linkedCameras,
        onCamerasUpdated: loadEventDetails,
      ),
    );
  }

  Future<void> markAttendance(String employeeId, String employeeName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark Attendance'),
        content: Text('Mark $employeeName as attended?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
            ),
            child: const Text('Mark Attended'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final response = await apiService.markEventAttendance(
        eventId: widget.eventId,
        employeeId: employeeId,
      );

      if (response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Attendance marked successfully'),
            backgroundColor: Colors.green,
          ),
        );
        loadEventDetails();  // Refresh the list
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Failed to mark attendance'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getStatusColor(String status) {
    switch (status) {
      case 'attended':
        return '0xFF10B981'; // Green
      case 'confirmed':
        return '0xFF3B82F6'; // Blue
      case 'invited':
        return '0xFF6B7280'; // Gray
      case 'absent':
        return '0xFFEF4444'; // Red
      default:
        return '0xFF6B7280'; // Gray
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: const Text('Event Details'),
          backgroundColor: const Color(0xFF1E3A8A),
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (event == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: const Text('Event Details'),
          backgroundColor: const Color(0xFF1E3A8A),
          elevation: 0,
        ),
        body: const Center(child: Text('Event not found')),
      );
    }

    final eventDate = DateTime.tryParse(event!['event_date'] ?? '');
    final dateStr = eventDate != null
        ? DateFormat('EEEE, MMMM d, yyyy').format(eventDate)
        : 'No date';

    final attendedCount = participants.where((p) => p['status'] == 'attended').length;
    final totalParticipants = participants.length;
    final attendanceRate = totalParticipants > 0
        ? (attendedCount / totalParticipants * 100).toStringAsFixed(1)
        : '0.0';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Event Details'),
        backgroundColor: const Color(0xFF1E3A8A),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam),
            onPressed: showCameraManagementDialog,
            tooltip: 'Manage Cameras',
          ),
          if (linkedCameras.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.monitor),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LiveMonitoringScreen(eventId: widget.eventId),
                  ),
                );
              },
              tooltip: 'Live Monitoring',
            ),
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EventInvitationScreen(event: event!),
                ),
              ).then((_) => loadEventDetails()); // Refresh after returning
            },
            tooltip: 'Manage Participants & Invitations',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: loadEventDetails,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: loadEventDetails,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Event Info Card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              event!['name'] ?? 'Unnamed Event',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              (event!['status'] ?? 'upcoming').toUpperCase(),
                              style: const TextStyle(
                                color: Color(0xFF3B82F6),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (event!['description'] != null &&
                          event!['description'].toString().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          event!['description'],
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 15,
                          ),
                        ),
                      ],
                      const Divider(height: 32),
                      _buildInfoRow(Icons.calendar_today, 'Date', dateStr),
                      if (event!['start_time'] != null &&
                          event!['end_time'] != null) ...[
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          Icons.access_time,
                          'Time',
                          '${event!['start_time']} - ${event!['end_time']}',
                        ),
                      ],
                      if (event!['location'] != null &&
                          event!['location'].toString().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          Icons.location_on,
                          'Location',
                          event!['location'],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Attendance Stats
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Total Participants',
                      totalParticipants.toString(),
                      Icons.people,
                      const Color(0xFF3B82F6),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      'Attended',
                      attendedCount.toString(),
                      Icons.check_circle,
                      const Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      'Attendance Rate',
                      '$attendanceRate%',
                      Icons.pie_chart,
                      const Color(0xFFF59E0B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Participants Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Participants',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  Text(
                    '$attendedCount of $totalParticipants attended',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Participants List
              if (participants.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'No participants added',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: participants.length,
                  itemBuilder: (context, index) {
                    final participant = participants[index];
                    return _buildParticipantCard(participant);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF1E3A8A)),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
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
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantCard(Map<String, dynamic> participant) {
    final status = participant['status'] ?? 'invited';
    final isAttended = status == 'attended';
    final attendedAt = participant['attended_at'];

    String attendanceTime = '';
    if (isAttended && attendedAt != null) {
      final time = DateTime.tryParse(attendedAt);
      if (time != null) {
        attendanceTime = DateFormat('h:mm a').format(time);
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: Color(int.parse(_getStatusColor(status)))
              .withOpacity(0.1),
          radius: 24,
          child: Text(
            (participant['employee_name'] ?? 'U')[0].toUpperCase(),
            style: TextStyle(
              color: Color(int.parse(_getStatusColor(status))),
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        title: Text(
          participant['employee_name'] ?? 'Unknown',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${participant['employee_id']} • ${participant['department'] ?? 'N/A'}',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            if (isAttended && attendanceTime.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Attended at $attendanceTime',
                style: const TextStyle(
                  color: Color(0xFF10B981),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Color(int.parse(_getStatusColor(status)))
                    .withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                status.toUpperCase(),
                style: TextStyle(
                  color: Color(int.parse(_getStatusColor(status))),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (!isAttended) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.check_circle_outline, color: Color(0xFF10B981)),
                onPressed: () => markAttendance(
                  participant['employee_id'],
                  participant['employee_name'],
                ),
                tooltip: 'Mark as Attended',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Event Camera Management Dialog
class EventCameraDialog extends StatefulWidget {
  final String eventId;
  final List<Map<String, dynamic>> linkedCameras;
  final VoidCallback onCamerasUpdated;

  const EventCameraDialog({
    super.key,
    required this.eventId,
    required this.linkedCameras,
    required this.onCamerasUpdated,
  });

  @override
  State<EventCameraDialog> createState() => _EventCameraDialogState();
}

class _EventCameraDialogState extends State<EventCameraDialog> {
  final ApiService apiService = ApiService();

  List<Map<String, dynamic>> allCameras = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    loadAllCameras();
  }

  Future<void> loadAllCameras() async {
    setState(() => isLoading = true);

    try {
      final response = await apiService.getCameras();
      if (response['success'] == true && mounted) {
        setState(() {
          allCameras = List<Map<String, dynamic>>.from(response['cameras'] ?? []);
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading cameras: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> linkCamera(String cameraId, String cameraName) async {
    final response = await apiService.linkCameraToEvent(
      eventId: widget.eventId,
      cameraId: cameraId,
    );

    if (response['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$cameraName linked to event'),
          backgroundColor: Colors.green,
        ),
      );
      widget.onCamerasUpdated();
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response['message'] ?? 'Failed to link camera'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> unlinkCamera(String cameraId, String cameraName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unlink Camera'),
        content: Text('Remove "$cameraName" from this event?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Unlink'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final response = await apiService.unlinkCameraFromEvent(
        eventId: widget.eventId,
        cameraId: cameraId,
      );

      if (response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$cameraName unlinked from event'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onCamerasUpdated();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Failed to unlink camera'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'online':
        return const Color(0xFF10B981);
      case 'offline':
        return const Color(0xFF6B7280);
      case 'error':
        return const Color(0xFFEF4444);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final linkedCameraIds = widget.linkedCameras.map((c) => c['id']).toSet();
    final availableCameras = allCameras.where((c) => !linkedCameraIds.contains(c['id'])).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.videocam, color: Color(0xFF1E3A8A)),
                const SizedBox(width: 12),
                const Text(
                  'Manage Event Cameras',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Linked Cameras Section
            Text(
              'Linked Cameras (${widget.linkedCameras.length})',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            if (widget.linkedCameras.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    'No cameras linked to this event',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              )
            else
              ...widget.linkedCameras.map((camera) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF1E3A8A).withOpacity(0.1),
                        child: const Icon(Icons.videocam, color: Color(0xFF1E3A8A)),
                      ),
                      title: Text(camera['name'] ?? 'Unnamed'),
                      subtitle: Row(
                        children: [
                          Text((camera['camera_type'] ?? 'Unknown').toUpperCase()),
                          const SizedBox(width: 8),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _getStatusColor(camera['status'] ?? 'offline'),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            camera['status'] ?? 'offline',
                            style: TextStyle(
                              color: _getStatusColor(camera['status'] ?? 'offline'),
                              fontSize: 12,
                            ),
                          ),
                          if (camera['is_primary'] == true) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'PRIMARY',
                                style: TextStyle(
                                  color: Color(0xFFF59E0B),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.link_off, color: Colors.red),
                        onPressed: () => unlinkCamera(camera['id'], camera['name']),
                      ),
                    ),
                  )),

            const SizedBox(height: 24),

            // Available Cameras Section
            Text(
              'Available Cameras (${availableCameras.length})',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else if (availableCameras.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    'All cameras are linked or no cameras available',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              )
            else
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView(
                  shrinkWrap: true,
                  children: availableCameras.map((camera) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.grey[200],
                            child: const Icon(Icons.videocam, color: Colors.grey),
                          ),
                          title: Text(camera['name'] ?? 'Unnamed'),
                          subtitle: Row(
                            children: [
                              Text((camera['camera_type'] ?? 'Unknown').toUpperCase()),
                              if (camera['location'] != null && camera['location'].toString().isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Text('• ${camera['location']}'),
                              ],
                            ],
                          ),
                          trailing: ElevatedButton.icon(
                            onPressed: () => linkCamera(camera['id'], camera['name']),
                            icon: const Icon(Icons.link, size: 16),
                            label: const Text('Link'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E3A8A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ),
                      )).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
