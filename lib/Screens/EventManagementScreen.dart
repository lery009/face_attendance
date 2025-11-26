import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api/api_service.dart';
import 'CreateEventScreen.dart';
import 'EventDetailsScreen.dart';

class EventManagementScreen extends StatefulWidget {
  const EventManagementScreen({super.key});

  @override
  State<EventManagementScreen> createState() => _EventManagementScreenState();
}

class _EventManagementScreenState extends State<EventManagementScreen> {
  final ApiService apiService = ApiService();
  List<Map<String, dynamic>> events = [];
  bool isLoading = true;
  String selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    loadEvents();
  }

  Future<void> loadEvents() async {
    setState(() => isLoading = true);

    try {
      final response = selectedFilter == 'all'
          ? await apiService.getAllEvents()
          : await apiService.getAllEvents(status: selectedFilter);

      setState(() {
        if (response['success'] == true) {
          events = (response['events'] as List<dynamic>)
              .map((event) => event as Map<String, dynamic>)
              .toList();
        }
        isLoading = false;
      });
    } catch (e) {
      print('Error loading events: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> deleteEvent(String eventId, String eventName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete "$eventName"?'),
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
      final response = await apiService.deleteEvent(eventId);

      if (response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Event deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        loadEvents();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Failed to delete event'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getStatusColor(String status) {
    switch (status) {
      case 'upcoming':
        return '0xFF3B82F6'; // Blue
      case 'ongoing':
        return '0xFFF59E0B'; // Orange
      case 'completed':
        return '0xFF10B981'; // Green
      case 'cancelled':
        return '0xFFEF4444'; // Red
      default:
        return '0xFF6B7280'; // Gray
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Event Management'),
        backgroundColor: const Color(0xFF1E3A8A),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: loadEvents,
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateEventScreen()),
          );
          if (result == true) {
            loadEvents();
          }
        },
        backgroundColor: const Color(0xFF1E3A8A),
        icon: const Icon(Icons.add),
        label: const Text('Create Event'),
      ),
      body: Column(
        children: [
          // Filter chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All', 'all'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Upcoming', 'upcoming'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Ongoing', 'ongoing'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Completed', 'completed'),
                ],
              ),
            ),
          ),

          // Events list
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : events.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'No events found',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const CreateEventScreen()),
                                );
                                if (result == true) {
                                  loadEvents();
                                }
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Create First Event'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E3A8A),
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: loadEvents,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(20),
                          itemCount: events.length,
                          itemBuilder: (context, index) {
                            final event = events[index];
                            return _buildEventCard(event);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = selectedFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          selectedFilter = value;
        });
        loadEvents();
      },
      selectedColor: const Color(0xFF1E3A8A),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      backgroundColor: Colors.white,
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    final eventDate = DateTime.tryParse(event['event_date'] ?? '');
    final dateStr = eventDate != null
        ? DateFormat('MMM dd, yyyy').format(eventDate)
        : 'No date';
    final timeStr = event['start_time'] != null && event['end_time'] != null
        ? '${event['start_time']} - ${event['end_time']}'
        : '';

    final totalParticipants = event['total_participants'] ?? 0;
    final attendedCount = event['attended_count'] ?? 0;
    final attendanceRate = totalParticipants > 0
        ? (attendedCount / totalParticipants * 100).toStringAsFixed(0)
        : '0';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EventDetailsScreen(eventId: event['id']),
            ),
          );
          if (result == true) {
            loadEvents();
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      event['name'] ?? 'Unnamed Event',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Color(int.parse(_getStatusColor(event['status'] ?? 'upcoming')))
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      (event['status'] ?? 'upcoming').toUpperCase(),
                      style: TextStyle(
                        color: Color(int.parse(_getStatusColor(event['status'] ?? 'upcoming'))),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              if (event['description'] != null && event['description'].toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    event['description'],
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    dateStr,
                    style: TextStyle(color: Colors.grey[700], fontSize: 13),
                  ),
                  if (timeStr.isNotEmpty) ...[
                    const SizedBox(width: 16),
                    Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Text(
                      timeStr,
                      style: TextStyle(color: Colors.grey[700], fontSize: 13),
                    ),
                  ],
                ],
              ),
              if (event['location'] != null && event['location'].toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          event['location'],
                          style: TextStyle(color: Colors.grey[700], fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.people, size: 18, color: Colors.grey[600]),
                        const SizedBox(width: 6),
                        Text(
                          '$attendedCount/$totalParticipants attended',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '($attendanceRate%)',
                          style: TextStyle(
                            color: const Color(0xFF10B981),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    onPressed: () => deleteEvent(event['id'], event['name']),
                    tooltip: 'Delete Event',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
