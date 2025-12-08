import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api/api_service.dart';

class CreateEventScreen extends StatefulWidget {
  final Map<String, dynamic>? event;

  const CreateEventScreen({super.key, this.event});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final ApiService apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  final PageController _pageController = PageController();

  // Form controllers
  final TextEditingController nameController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController searchController = TextEditingController();

  DateTime selectedDate = DateTime.now();
  TimeOfDay startTime = TimeOfDay.now();
  TimeOfDay endTime = TimeOfDay(hour: DateTime.now().hour + 1, minute: DateTime.now().minute);

  List<Map<String, dynamic>> allEmployees = [];
  List<Map<String, dynamic>> filteredEmployees = [];
  Set<String> selectedParticipants = {};
  List<String> invitationEmails = [];

  bool isLoading = false;
  bool isLoadingEmployees = true;
  int currentStep = 0;
  int participantTabIndex = 0;

  @override
  void initState() {
    super.initState();
    loadEmployees();
    searchController.addListener(_filterEmployees);

    if (widget.event != null) {
      nameController.text = widget.event!['name'] ?? '';
      descriptionController.text = widget.event!['description'] ?? '';
      locationController.text = widget.event!['location'] ?? '';

      if (widget.event!['event_date'] != null) {
        selectedDate = DateTime.parse(widget.event!['event_date']);
      }

      if (widget.event!['start_time'] != null) {
        final parts = widget.event!['start_time'].split(':');
        startTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }

      if (widget.event!['end_time'] != null) {
        final parts = widget.event!['end_time'].split(':');
        endTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    locationController.dispose();
    emailController.dispose();
    searchController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> loadEmployees() async {
    setState(() => isLoadingEmployees = true);

    try {
      final response = await apiService.getAllEmployees();

      setState(() {
        if (response['success'] == true) {
          allEmployees = (response['employees'] as List<dynamic>)
              .map((emp) => emp as Map<String, dynamic>)
              .toList();
          filteredEmployees = List.from(allEmployees);
        }
        isLoadingEmployees = false;
      });
    } catch (e) {
      print('Error loading employees: $e');
      setState(() => isLoadingEmployees = false);
    }
  }

  void _filterEmployees() {
    final query = searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        filteredEmployees = List.from(allEmployees);
      } else {
        filteredEmployees = allEmployees.where((emp) {
          final name = (emp['name'] ?? '').toLowerCase();
          final employeeId = (emp['employeeId'] ?? '').toLowerCase();
          final department = (emp['department'] ?? '').toLowerCase();
          return name.contains(query) || employeeId.contains(query) || department.contains(query);
        }).toList();
      }
    });
  }

  void nextStep() {
    if (currentStep == 0) {
      if (!_formKey.currentState!.validate()) {
        return;
      }
    }

    if (currentStep < 2) {
      setState(() => currentStep++);
      _pageController.animateToPage(
        currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void previousStep() {
    if (currentStep > 0) {
      setState(() => currentStep--);
      _pageController.animateToPage(
        currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void addEmail() {
    final email = emailController.text.trim();
    if (email.isEmpty) return;

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid email address'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (invitationEmails.contains(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email already added'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      invitationEmails.add(email);
      emailController.clear();
    });
  }

  void removeEmail(String email) {
    setState(() => invitationEmails.remove(email));
  }

  Future<void> submitEvent() async {
    setState(() => isLoading = true);

    try {
      final eventDateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
      final startTimeStr = '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
      final endTimeStr = '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';

      final response = await apiService.createEvent(
        name: nameController.text.trim(),
        description: descriptionController.text.trim(),
        eventDate: eventDateStr,
        startTime: startTimeStr,
        endTime: endTimeStr,
        location: locationController.text.trim(),
        participantIds: selectedParticipants.toList(),
      );

      if (response['success'] == true) {
        final eventId = response['data']['id'];
        final eventName = response['data']['name'];

        int successfulInvites = 0;
        int failedInvites = 0;

        if (invitationEmails.isNotEmpty) {
          try {
            String baseUrl = 'http://localhost:8080';
            if (Uri.base.host.isNotEmpty) {
              baseUrl = '${Uri.base.scheme}://${Uri.base.host}${Uri.base.hasPort ? ':${Uri.base.port}' : ''}';
            }

            final inviteResponse = await apiService.sendEventInvitations(
              eventId: eventId,
              emails: invitationEmails,
              baseUrl: baseUrl,
            );

            successfulInvites = (inviteResponse['successful'] as List?)?.length ?? 0;
            failedInvites = (inviteResponse['failed'] as List?)?.length ?? 0;
          } catch (e) {
            failedInvites = invitationEmails.length;
          }
        }

        setState(() => isLoading = false);

        if (mounted) {
          _showSuccessDialog(
            eventName: eventName,
            registeredCount: selectedParticipants.length,
            invitedCount: successfulInvites,
            failedInvites: failedInvites,
          );
        }
      } else {
        setState(() => isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'Failed to create event'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => isLoading = false);
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

  void _showSuccessDialog({
    required String eventName,
    required int registeredCount,
    required int invitedCount,
    required int failedInvites,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: Color(0xFF10B981),
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Event Created Successfully!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              eventName,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildSummaryRow(
                    Icons.people,
                    'Registered Participants',
                    registeredCount.toString(),
                    const Color(0xFF3B82F6),
                  ),
                  if (invitedCount > 0) ...[
                    const SizedBox(height: 12),
                    _buildSummaryRow(
                      Icons.email,
                      'Invitations Sent',
                      invitedCount.toString(),
                      const Color(0xFF10B981),
                    ),
                  ],
                  if (failedInvites > 0) ...[
                    const SizedBox(height: 12),
                    _buildSummaryRow(
                      Icons.error_outline,
                      'Failed Invitations',
                      failedInvites.toString(),
                      const Color(0xFFEF4444),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'You can manage participants and send more invitations from the event details screen.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context, true); // Go back to event list
            },
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context, true); // Go back
              // Could navigate to event details here if needed
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A8A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('View Events'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(widget.event == null ? 'Create New Event' : 'Edit Event'),
        backgroundColor: const Color(0xFF1E3A8A),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Step Indicator
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            child: Row(
              children: [
                _buildStepIndicator(0, 'Details', Icons.event_note),
                Expanded(child: _buildStepLine(0)),
                _buildStepIndicator(1, 'Participants', Icons.people),
                Expanded(child: _buildStepLine(1)),
                _buildStepIndicator(2, 'Review', Icons.check_circle),
              ],
            ),
          ),

          // Page View
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (index) => setState(() => currentStep = index),
              children: [
                _buildStep1EventDetails(),
                _buildStep2Participants(),
                _buildStep3Review(),
              ],
            ),
          ),

          // Navigation Buttons
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                if (currentStep > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: previousStep,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: Color(0xFF1E3A8A)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Back'),
                    ),
                  ),
                if (currentStep > 0) const SizedBox(width: 12),
                Expanded(
                  flex: currentStep == 0 ? 1 : 1,
                  child: ElevatedButton(
                    onPressed: isLoading
                        ? null
                        : currentStep < 2
                            ? nextStep
                            : submitEvent,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: currentStep == 2
                          ? const Color(0xFF10B981)
                          : const Color(0xFF1E3A8A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            currentStep == 2 ? 'Create Event' : 'Next',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(int step, String label, IconData icon) {
    final isActive = currentStep == step;
    final isCompleted = currentStep > step;

    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isCompleted
                ? const Color(0xFF10B981)
                : isActive
                    ? const Color(0xFF1E3A8A)
                    : Colors.grey[300],
            shape: BoxShape.circle,
          ),
          child: Icon(
            isCompleted ? Icons.check : icon,
            color: isCompleted || isActive ? Colors.white : Colors.grey[600],
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? const Color(0xFF1E3A8A) : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(int step) {
    final isCompleted = currentStep > step;
    return Container(
      height: 2,
      margin: const EdgeInsets.only(bottom: 32),
      color: isCompleted ? const Color(0xFF10B981) : Colors.grey[300],
    );
  }

  Widget _buildStep1EventDetails() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Event Details',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Provide the basic information about your event',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),

            TextFormField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Event Name *',
                hintText: 'e.g., Annual Company Meeting',
                prefixIcon: const Icon(Icons.event),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Event name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: descriptionController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Description',
                hintText: 'Tell participants what this event is about...',
                prefixIcon: const Icon(Icons.description),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),

            InkWell(
              onTap: () async {
                final DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: selectedDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) {
                  setState(() => selectedDate = picked);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, color: Color(0xFF1E3A8A)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Event Date *',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('EEEE, MMMM d, yyyy').format(selectedDate),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final TimeOfDay? picked = await showTimePicker(
                        context: context,
                        initialTime: startTime,
                      );
                      if (picked != null) {
                        setState(() => startTime = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Start Time *',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.access_time, size: 18, color: Color(0xFF1E3A8A)),
                              const SizedBox(width: 8),
                              Text(
                                startTime.format(context),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final TimeOfDay? picked = await showTimePicker(
                        context: context,
                        initialTime: endTime,
                      );
                      if (picked != null) {
                        setState(() => endTime = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'End Time *',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.access_time, size: 18, color: Color(0xFF1E3A8A)),
                              const SizedBox(width: 8),
                              Text(
                                endTime.format(context),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: locationController,
              decoration: InputDecoration(
                labelText: 'Location',
                hintText: 'e.g., Conference Room A',
                prefixIcon: const Icon(Icons.location_on),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2Participants() {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(24),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add Participants',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select registered employees or invite new people via email',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),

              // Summary chips
              Wrap(
                spacing: 12,
                children: [
                  Chip(
                    avatar: const Icon(Icons.people, size: 18),
                    label: Text('${selectedParticipants.length} Registered'),
                    backgroundColor: const Color(0xFF3B82F6).withOpacity(0.1),
                  ),
                  Chip(
                    avatar: const Icon(Icons.email, size: 18),
                    label: Text('${invitationEmails.length} Invitations'),
                    backgroundColor: const Color(0xFF10B981).withOpacity(0.1),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Tabs
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => participantTabIndex = 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: participantTabIndex == 0
                              ? const Color(0xFF1E3A8A)
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people,
                          color: participantTabIndex == 0
                              ? const Color(0xFF1E3A8A)
                              : Colors.grey[600],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Registered Employees',
                          style: TextStyle(
                            fontWeight: participantTabIndex == 0
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: participantTabIndex == 0
                                ? const Color(0xFF1E3A8A)
                                : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => participantTabIndex = 1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: participantTabIndex == 1
                              ? const Color(0xFF1E3A8A)
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.email,
                          color: participantTabIndex == 1
                              ? const Color(0xFF1E3A8A)
                              : Colors.grey[600],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Email Invitations',
                          style: TextStyle(
                            fontWeight: participantTabIndex == 1
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: participantTabIndex == 1
                                ? const Color(0xFF1E3A8A)
                                : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Tab Content
        Expanded(
          child: participantTabIndex == 0
              ? _buildRegisteredEmployeesTab()
              : _buildEmailInvitationsTab(),
        ),
      ],
    );
  }

  Widget _buildRegisteredEmployeesTab() {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: 'Search employees...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        searchController.clear();
                        _filterEmployees();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ),

        // Employee list
        Expanded(
          child: isLoadingEmployees
              ? const Center(child: CircularProgressIndicator())
              : filteredEmployees.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            searchController.text.isNotEmpty
                                ? Icons.search_off
                                : Icons.people_outline,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            searchController.text.isNotEmpty
                                ? 'No employees found'
                                : 'No employees registered',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filteredEmployees.length,
                      itemBuilder: (context, index) {
                        final employee = filteredEmployees[index];
                        final employeeId = employee['employeeId'];
                        final isSelected = selectedParticipants.contains(employeeId);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isSelected
                                  ? const Color(0xFF1E3A8A)
                                  : Colors.grey[300]!,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: CheckboxListTile(
                            value: isSelected,
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  selectedParticipants.add(employeeId);
                                } else {
                                  selectedParticipants.remove(employeeId);
                                }
                              });
                            },
                            title: Text(
                              employee['name'] ?? 'Unknown',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text('ID: ${employee['employeeId'] ?? 'N/A'}'),
                                Text('Dept: ${employee['department'] ?? 'N/A'}'),
                              ],
                            ),
                            secondary: CircleAvatar(
                              backgroundColor: isSelected
                                  ? const Color(0xFF1E3A8A)
                                  : Colors.grey[300],
                              child: Icon(
                                Icons.person,
                                color: isSelected ? Colors.white : Colors.grey[600],
                              ),
                            ),
                            activeColor: const Color(0xFF1E3A8A),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildEmailInvitationsTab() {
    return Column(
      children: [
        // Email input
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: emailController,
                  decoration: InputDecoration(
                    hintText: 'Enter email address',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onSubmitted: (_) => addEmail(),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: addEmail,
                icon: const Icon(Icons.add),
                label: const Text('Add'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Email list
        Expanded(
          child: invitationEmails.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.email_outlined, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No email invitations added yet',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Enter an email address above to send invitations',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: invitationEmails.length,
                  itemBuilder: (context, index) {
                    final email = invitationEmails[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF10B981).withOpacity(0.1),
                          child: const Icon(
                            Icons.email,
                            color: Color(0xFF10B981),
                          ),
                        ),
                        title: Text(
                          email,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: const Text('Invitation will be sent after event creation'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => removeEmail(email),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStep3Review() {
    final totalParticipants = selectedParticipants.length + invitationEmails.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Review & Confirm',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please review all details before creating the event',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),

          // Event Details Card
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.event, color: Color(0xFF1E3A8A)),
                      const SizedBox(width: 12),
                      const Text(
                        'Event Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => setState(() => currentStep = 0),
                        child: const Text('Edit'),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  _buildReviewRow('Name', nameController.text, Icons.label),
                  if (descriptionController.text.isNotEmpty)
                    _buildReviewRow('Description', descriptionController.text, Icons.description),
                  _buildReviewRow(
                    'Date',
                    DateFormat('EEEE, MMMM d, yyyy').format(selectedDate),
                    Icons.calendar_today,
                  ),
                  _buildReviewRow(
                    'Time',
                    '${startTime.format(context)} - ${endTime.format(context)}',
                    Icons.access_time,
                  ),
                  if (locationController.text.isNotEmpty)
                    _buildReviewRow('Location', locationController.text, Icons.location_on),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Participants Card
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.people, color: Color(0xFF1E3A8A)),
                      const SizedBox(width: 12),
                      Text(
                        'Participants ($totalParticipants)',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => setState(() => currentStep = 1),
                        child: const Text('Edit'),
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  if (selectedParticipants.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.blue[700], size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Registered Employees (${selectedParticipants.length})',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...selectedParticipants.map((empId) {
                      final emp = allEmployees.firstWhere(
                        (e) => e['employeeId'] == empId,
                        orElse: () => {'name': 'Unknown'},
                      );
                      return Padding(
                        padding: const EdgeInsets.only(left: 28, bottom: 8),
                        child: Text(
                          '• ${emp['name']} (${emp['employeeId']})',
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                      );
                    }).toList(),
                  ],

                  if (selectedParticipants.isNotEmpty && invitationEmails.isNotEmpty)
                    const SizedBox(height: 16),

                  if (invitationEmails.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(Icons.email, color: Colors.green[700], size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Email Invitations (${invitationEmails.length})',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...invitationEmails.map((email) {
                      return Padding(
                        padding: const EdgeInsets.only(left: 28, bottom: 8),
                        child: Text(
                          '• $email',
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                      );
                    }).toList(),
                  ],

                  if (totalParticipants == 0)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'No participants added',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Info box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700], size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'What happens next?',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[900],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• Event will be created immediately\n'
                        '• Registered participants will be added\n'
                        '• Invitation emails will be sent automatically\n'
                        '• You can manage participants later from event details',
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
        ],
      ),
    );
  }

  Widget _buildReviewRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
