import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api/api_service.dart';

class EventInvitationScreen extends StatefulWidget {
  final Map<String, dynamic> event;

  const EventInvitationScreen({super.key, required this.event});

  @override
  State<EventInvitationScreen> createState() => _EventInvitationScreenState();
}

class _EventInvitationScreenState extends State<EventInvitationScreen> {
  final ApiService apiService = ApiService();
  final TextEditingController emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  List<Map<String, dynamic>> participants = [];
  bool isLoading = false;
  bool isSending = false;

  @override
  void initState() {
    super.initState();
    loadParticipants();
  }

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  Future<void> loadParticipants() async {
    setState(() => isLoading = true);

    try {
      final response = await apiService.getEventParticipants(widget.event['id']);
      if (response['success'] == true && mounted) {
        setState(() {
          participants = List<Map<String, dynamic>>.from(response['participants'] ?? []);
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading participants: $e')),
        );
      }
    }
  }

  Future<void> sendInvitation() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isSending = true);

    try {
      // Get base URL for invitation links
      String baseUrl = 'http://localhost:8080';
      if (Uri.base.host.isNotEmpty) {
        baseUrl = '${Uri.base.scheme}://${Uri.base.host}${Uri.base.hasPort ? ':${Uri.base.port}' : ''}';
      }

      // Use sendEventInvitations which only requires authentication (not admin role)
      final response = await apiService.sendEventInvitations(
        eventId: widget.event['id'],
        emails: [emailController.text.trim()],
        baseUrl: baseUrl,
      );

      setState(() => isSending = false);

      if (response['success'] == true && mounted) {
        final successful = response['successful'] as List? ?? [];
        final failed = response['failed'] as List? ?? [];

        if (successful.isNotEmpty) {
          emailController.clear();

          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.check_circle, color: Color(0xFF10B981), size: 28),
                  SizedBox(width: 12),
                  Text('Invitation Sent!'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Invitation email sent successfully!'),
                  SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'When they register:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '✓ They\'ll be automatically added to this event\n'
                          '✓ Their face will be recognized during attendance\n'
                          '✓ You\'ll see them in the participants list',
                          style: TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {});  // Refresh to show pending invitation
                  },
                  child: Text('Send Another'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF1E3A8A),
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Close'),
                ),
              ],
            ),
          );

          // Reload participants to show updated status
          await loadParticipants();
        } else if (failed.isNotEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to send invitation'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'Failed to send invitation'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => isSending = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text('Manage Event Participants'),
        backgroundColor: Color(0xFF1E3A8A),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Event Info Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.event, color: Colors.white, size: 32),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.event['name'] ?? 'Event',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                if (widget.event['description'] != null) ...[
                  SizedBox(height: 8),
                  Text(
                    widget.event['description'],
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
                SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.people, color: Colors.white70, size: 18),
                    SizedBox(width: 8),
                    Text(
                      '${participants.length} Participants',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(24),
              child: Column(
                children: [
                  // Add Participant Section
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.person_add, color: Color(0xFF1E3A8A)),
                                SizedBox(width: 12),
                                Text(
                                  'Invite Participant',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16),

                            Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue[200]!),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.info_outline, color: Colors.blue[700], size: 24),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'How it works:',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: Colors.blue[900],
                                          ),
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          '• Enter employee email address below\n'
                                          '• They receive invitation with event details\n'
                                          '• After registration, they\'re auto-added to event\n'
                                          '• Their face will be recognized during attendance',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.blue[800],
                                            height: 1.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 20),

                            TextFormField(
                              controller: emailController,
                              keyboardType: TextInputType.emailAddress,
                              enabled: !isSending,
                              decoration: InputDecoration(
                                labelText: 'Employee Email Address *',
                                hintText: 'employee@example.com',
                                prefixIcon: Icon(Icons.email_outlined),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Email address is required';
                                }
                                if (!value.contains('@') || !value.contains('.')) {
                                  return 'Please enter a valid email address';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: 20),

                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton.icon(
                                onPressed: isSending ? null : sendInvitation,
                                icon: isSending
                                    ? SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Icon(Icons.send),
                                label: Text(
                                  isSending ? 'Sending Invitation...' : 'Send Invitation',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFF1E3A8A),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 24),

                  // Participants List
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.people, color: Color(0xFF1E3A8A)),
                              SizedBox(width: 12),
                              Text(
                                'Participants (${participants.length})',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Spacer(),
                              IconButton(
                                icon: Icon(Icons.refresh),
                                onPressed: loadParticipants,
                                tooltip: 'Refresh list',
                              ),
                            ],
                          ),
                          SizedBox(height: 16),

                          if (isLoading)
                            Center(child: CircularProgressIndicator())
                          else if (participants.isEmpty)
                            Center(
                              child: Padding(
                                padding: EdgeInsets.all(32),
                                child: Column(
                                  children: [
                                    Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                                    SizedBox(height: 16),
                                    Text(
                                      'No participants yet',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Send invitations to get started',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: NeverScrollableScrollPhysics(),
                              itemCount: participants.length,
                              separatorBuilder: (context, index) => Divider(),
                              itemBuilder: (context, index) {
                                final participant = participants[index];
                                final employee = participant['employee'];
                                final status = participant['status'] ?? 'registered';

                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: _getStatusColor(status).withOpacity(0.2),
                                    child: Icon(
                                      _getStatusIcon(status),
                                      color: _getStatusColor(status),
                                    ),
                                  ),
                                  title: Text(
                                    employee != null
                                        ? '${employee['firstname'] ?? ''} ${employee['lastname'] ?? ''}'.trim()
                                        : 'Unknown',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (employee != null && employee['email'] != null)
                                        Text(employee['email']),
                                      SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Container(
                                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: _getStatusColor(status).withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: _getStatusColor(status).withOpacity(0.3),
                                              ),
                                            ),
                                            child: Text(
                                              _getStatusLabel(status),
                                              style: TextStyle(
                                                color: _getStatusColor(status),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  isThreeLine: true,
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return Color(0xFF10B981);
      case 'absent':
        return Color(0xFFEF4444);
      case 'late':
        return Color(0xFFF59E0B);
      case 'registered':
        return Color(0xFF3B82F6);
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return Icons.check_circle;
      case 'absent':
        return Icons.cancel;
      case 'late':
        return Icons.access_time;
      case 'registered':
        return Icons.how_to_reg;
      default:
        return Icons.help_outline;
    }
  }

  String _getStatusLabel(String status) {
    return status[0].toUpperCase() + status.substring(1).toLowerCase();
  }
}
