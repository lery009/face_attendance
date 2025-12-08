import 'package:flutter/material.dart';
import '../api/api_service.dart';
import '../services/auth_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  final ApiService apiService = ApiService();
  final AuthService authService = AuthService();
  final TextEditingController testEmailController = TextEditingController();

  bool isLoading = true;
  bool emailEnabled = false;
  Map<String, dynamic> settings = {};
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadNotificationStatus();
  }

  @override
  void dispose() {
    testEmailController.dispose();
    super.dispose();
  }

  Future<void> loadNotificationStatus() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await apiService.getNotificationStatus();

      if (response['success'] == true) {
        setState(() {
          emailEnabled = response['email_enabled'] ?? false;
          settings = response['settings'] ?? {};
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = response['message'] ?? 'Failed to load notification settings';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error: $e';
        isLoading = false;
      });
    }
  }

  Future<void> sendTestEmail() async {
    final email = testEmailController.text.trim();
    if (email.isEmpty) {
      _showErrorDialog('Please enter an email address');
      return;
    }

    if (!emailEnabled) {
      _showErrorDialog('Email notifications are not enabled. Please configure SMTP settings in the backend .env file first.');
      return;
    }

    setState(() => isLoading = true);

    try {
      final response = await apiService.sendTestEmail(email);

      setState(() => isLoading = false);

      if (response['success'] == true) {
        if (!mounted) return;
        _showSuccessDialog('Test email sent successfully to $email!');
        testEmailController.clear();
      } else {
        _showErrorDialog(response['message'] ?? 'Failed to send test email');
      }
    } catch (e) {
      setState(() => isLoading = false);
      _showErrorDialog('Error: $e');
    }
  }

  Future<void> sendDailySummary() async {
    if (!emailEnabled) {
      _showErrorDialog('Email notifications are not enabled. Please configure SMTP settings first.');
      return;
    }

    // Ask for admin email
    final emailController = TextEditingController(text: authService.userEmail);
    final email = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Daily Summary'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter the admin email address to receive the daily summary:'),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Admin Email',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, emailController.text.trim()),
            child: const Text('Send'),
          ),
        ],
      ),
    );

    if (email == null || email.isEmpty) return;

    setState(() => isLoading = true);

    try {
      final response = await apiService.sendDailySummary(email);

      setState(() => isLoading = false);

      if (response['success'] == true) {
        if (!mounted) return;
        _showSuccessDialog('Daily summary sent successfully to $email!');
      } else {
        _showErrorDialog(response['message'] ?? 'Failed to send daily summary');
      }
    } catch (e) {
      setState(() => isLoading = false);
      _showErrorDialog('Error: $e');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 8),
            Text('Error'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.green),
            SizedBox(width: 8),
            Text('Success'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Email Notification Settings'),
        backgroundColor: const Color(0xFF1E3A8A),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: loadNotificationStatus,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Text(
                        errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: loadNotificationStatus,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: loadNotificationStatus,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status Card
                        _buildStatusCard(),
                        const SizedBox(height: 20),

                        // Configuration Details
                        if (emailEnabled) ...[
                          _buildSectionTitle('SMTP Configuration'),
                          const SizedBox(height: 12),
                          _buildConfigCard(),
                          const SizedBox(height: 20),

                          _buildSectionTitle('Notification Preferences'),
                          const SizedBox(height: 12),
                          _buildPreferencesCard(),
                          const SizedBox(height: 20),
                        ],

                        // Admin Actions
                        _buildSectionTitle('Admin Actions'),
                        const SizedBox(height: 12),
                        _buildTestEmailCard(),
                        const SizedBox(height: 12),
                        _buildDailySummaryCard(),
                        const SizedBox(height: 20),

                        // Setup Instructions (if not enabled)
                        if (!emailEnabled) ...[
                          _buildSetupInstructionsCard(),
                        ],
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      width: double.infinity,
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
        children: [
          Icon(
            emailEnabled ? Icons.notifications_active : Icons.notifications_off,
            size: 64,
            color: emailEnabled ? Colors.green : Colors.orange,
          ),
          const SizedBox(height: 16),
          Text(
            emailEnabled ? 'Email Notifications Enabled' : 'Email Notifications Disabled',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: emailEnabled ? Colors.green : Colors.orange,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            emailEnabled
                ? 'The system is configured to send email notifications'
                : 'Configure SMTP settings in backend/.env to enable',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigCard() {
    return Container(
      width: double.infinity,
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
        children: [
          _buildConfigRow('SMTP Host', settings['smtp_host'] ?? 'N/A', Icons.dns),
          _buildConfigRow('SMTP Port', settings['smtp_port']?.toString() ?? 'N/A', Icons.numbers),
          _buildConfigRow('Username', settings['smtp_username'] ?? 'N/A', Icons.person),
          _buildConfigRow('From Email', settings['from_email'] ?? 'N/A', Icons.email),
          _buildConfigRow('From Name', settings['from_name'] ?? 'N/A', Icons.badge),
        ],
      ),
    );
  }

  Widget _buildConfigRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF1E3A8A)),
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
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
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

  Widget _buildPreferencesCard() {
    return Container(
      width: double.infinity,
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
        children: [
          _buildPreferenceRow(
            'Notify on Late Arrival',
            settings['notify_on_late'] ?? false,
            Icons.schedule,
          ),
          _buildPreferenceRow(
            'Notify on Absent',
            settings['notify_on_absent'] ?? false,
            Icons.person_off,
          ),
          _buildPreferenceRow(
            'Daily Summary Enabled',
            settings['daily_summary_enabled'] ?? false,
            Icons.summarize,
          ),
          if (settings['daily_summary_enabled'] == true)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const SizedBox(width: 32),
                  Expanded(
                    child: Text(
                      'Summary Time: ${settings['daily_summary_time'] ?? 'N/A'}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
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

  Widget _buildPreferenceRow(String label, bool enabled, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF1E3A8A)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: enabled ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              enabled ? 'Enabled' : 'Disabled',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: enabled ? Colors.green : Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestEmailCard() {
    return Container(
      width: double.infinity,
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
          Row(
            children: [
              Icon(Icons.email, color: const Color(0xFF1E3A8A)),
              const SizedBox(width: 12),
              const Text(
                'Send Test Email',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Send a test notification email to verify your SMTP configuration',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: testEmailController,
            decoration: const InputDecoration(
              labelText: 'Test Email Address',
              hintText: 'Enter email address',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.email_outlined),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: emailEnabled ? sendTestEmail : null,
              icon: const Icon(Icons.send),
              label: const Text('Send Test Email'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                disabledBackgroundColor: Colors.grey[300],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailySummaryCard() {
    return Container(
      width: double.infinity,
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
          Row(
            children: [
              Icon(Icons.summarize, color: const Color(0xFF1E3A8A)),
              const SizedBox(width: 12),
              const Text(
                'Send Daily Summary',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Manually trigger a daily attendance summary email with statistics and late arrivals',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: emailEnabled ? sendDailySummary : null,
              icon: const Icon(Icons.analytics),
              label: const Text('Send Daily Summary Now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                disabledBackgroundColor: Colors.grey[300],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetupInstructionsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange[700]),
              const SizedBox(width: 12),
              Text(
                'Setup Instructions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'To enable email notifications:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          _buildInstructionStep('1', 'Open backend/.env file'),
          _buildInstructionStep('2', 'Set EMAIL_ENABLED=true'),
          _buildInstructionStep('3', 'Configure SMTP settings (host, port, username, password)'),
          _buildInstructionStep('4', 'For Gmail: Enable 2FA and generate App Password'),
          _buildInstructionStep('5', 'Restart the backend server'),
          _buildInstructionStep('6', 'Refresh this page to verify'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gmail App Password:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'https://myaccount.google.com/apppasswords',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue[700],
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.grey[800],
      ),
    );
  }
}
