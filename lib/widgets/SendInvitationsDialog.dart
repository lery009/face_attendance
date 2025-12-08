import 'package:flutter/material.dart';
import '../api/api_service.dart';

class SendInvitationsDialog extends StatefulWidget {
  final String eventId;
  final String eventName;

  const SendInvitationsDialog({
    Key? key,
    required this.eventId,
    required this.eventName,
  }) : super(key: key);

  @override
  State<SendInvitationsDialog> createState() => _SendInvitationsDialogState();
}

class _SendInvitationsDialogState extends State<SendInvitationsDialog> {
  final ApiService apiService = ApiService();
  final TextEditingController emailController = TextEditingController();
  List<String> emails = [];
  bool isSending = false;

  void addEmail() {
    final email = emailController.text.trim();
    if (email.isEmpty) return;

    // Basic email validation
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address')),
      );
      return;
    }

    if (emails.contains(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email already added')),
      );
      return;
    }

    setState(() {
      emails.add(email);
      emailController.clear();
    });
  }

  void removeEmail(String email) {
    setState(() {
      emails.remove(email);
    });
  }

  Future<void> sendInvitations() async {
    if (emails.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one email address')),
      );
      return;
    }

    setState(() {
      isSending = true;
    });

    try {
      // Get current URL for base_url (for web)
      String baseUrl = 'http://localhost:8080';
      if (Uri.base.host.isNotEmpty) {
        baseUrl = '${Uri.base.scheme}://${Uri.base.host}${Uri.base.hasPort ? ':${Uri.base.port}' : ''}';
      }

      final response = await apiService.sendEventInvitations(
        eventId: widget.eventId,
        emails: emails,
        baseUrl: baseUrl,
      );

      if (response['success'] == true) {
        if (mounted) {
          final successful = response['successful'] as List? ?? [];
          final failed = response['failed'] as List? ?? [];

          String message = '${successful.length} invitation(s) sent successfully';
          if (failed.isNotEmpty) {
            message += '\n${failed.length} failed to send';
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );

          Navigator.of(context).pop(true); // Return true to indicate success
        }
      } else {
        throw Exception(response['message'] ?? 'Failed to send invitations');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.email, color: Colors.blue, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Send Invitations',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.eventName,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Email input
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      hintText: 'Enter email address',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => addEmail(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: addEmail,
                  child: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Email list
            if (emails.isNotEmpty) ...[
              const Text(
                'Recipients:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: emails.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final email = emails[index];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.person, size: 20),
                      title: Text(email),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle_outline, size: 20),
                        onPressed: () => removeEmail(email),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Info text
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Recipients will receive an email with a registration link to join this event.',
                      style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: isSending ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: isSending ? null : sendInvitations,
                  icon: isSending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  label: Text(isSending ? 'Sending...' : 'Send Invitations'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }
}
