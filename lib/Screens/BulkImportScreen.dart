import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import '../api/api_service.dart';

class BulkImportScreen extends StatefulWidget {
  const BulkImportScreen({super.key});

  @override
  State<BulkImportScreen> createState() => _BulkImportScreenState();
}

class _BulkImportScreenState extends State<BulkImportScreen> {
  final ApiService apiService = ApiService();

  bool isUploading = false;
  String? selectedFileName;
  List<int>? selectedFileBytes;
  Map<String, dynamic>? importResult;

  Future<void> pickCSVFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null && result.files.single.bytes != null) {
        setState(() {
          selectedFileName = result.files.single.name;
          selectedFileBytes = result.files.single.bytes!;
          importResult = null;  // Clear previous results
        });
      }
    } catch (e) {
      _showErrorDialog('Failed to pick file: $e');
    }
  }

  Future<void> downloadTemplate() async {
    try {
      setState(() => isUploading = true);

      final response = await apiService.downloadBulkImportTemplate();

      setState(() => isUploading = false);

      if (response['success'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Template downloaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        _showErrorDialog(response['message'] ?? 'Failed to download template');
      }
    } catch (e) {
      setState(() => isUploading = false);
      _showErrorDialog('Error downloading template: $e');
    }
  }

  Future<void> uploadCSV() async {
    if (selectedFileBytes == null) {
      _showErrorDialog('Please select a CSV file first');
      return;
    }

    setState(() {
      isUploading = true;
      importResult = null;
    });

    try {
      // Convert bytes to base64
      final base64Data = base64Encode(selectedFileBytes!);

      final response = await apiService.bulkImportEmployees(base64Data);

      setState(() {
        isUploading = false;
        importResult = response;
      });

      if (response['success'] == true) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('Import Complete'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Imported: ${response['imported_count'] ?? 0} employees'),
                  Text('Skipped: ${response['skipped_count'] ?? 0} employees'),
                  const SizedBox(height: 16),
                  if (response['errors'] != null && (response['errors'] as List).isNotEmpty) ...[
                    const Text(
                      'Errors:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...(response['errors'] as List).map((error) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '• $error',
                            style: const TextStyle(fontSize: 12, color: Colors.red),
                          ),
                        )),
                  ],
                  if (response['note'] != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'ℹ️ ${response['note']}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    selectedFileName = null;
                    selectedFileBytes = null;
                  });
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        _showErrorDialog(response['message'] ?? 'Import failed');
      }
    } catch (e) {
      setState(() => isUploading = false);
      _showErrorDialog('Error uploading CSV: $e');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Bulk Employee Import'),
        backgroundColor: const Color(0xFF1E3A8A),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Instructions Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700]),
                      const SizedBox(width: 12),
                      Text(
                        'How to Import Employees',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildInstructionStep('1', 'Download the CSV template'),
                  _buildInstructionStep('2', 'Fill in employee details (ID, name, email, etc.)'),
                  _buildInstructionStep('3', 'Save the file and upload it here'),
                  _buildInstructionStep('4', 'Review import results'),
                  _buildInstructionStep('5', 'Register face images separately for each employee'),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '⚠️ Note: CSV import only creates employee profiles. Face images must be added separately via the registration screen.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Download Template Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isUploading ? null : downloadTemplate,
                icon: const Icon(Icons.download),
                label: const Text('Download CSV Template'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Upload Section
            Text(
              'Upload CSV File',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),

            // File Picker Container
            InkWell(
              onTap: isUploading ? null : pickCSVFile,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selectedFileName != null ? Colors.green : Colors.grey[300]!,
                    width: 2,
                    style: BorderStyle.solid,
                  ),
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
                      selectedFileName != null ? Icons.check_circle : Icons.upload_file,
                      size: 64,
                      color: selectedFileName != null ? Colors.green : Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      selectedFileName ?? 'Click to select CSV file',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: selectedFileName != null ? FontWeight.w600 : FontWeight.normal,
                        color: selectedFileName != null ? Colors.green : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Supported format: .csv',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Upload Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (selectedFileName != null && !isUploading) ? uploadCSV : null,
                icon: isUploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.cloud_upload),
                label: Text(isUploading ? 'Importing...' : 'Import Employees'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  disabledBackgroundColor: Colors.grey[300],
                ),
              ),
            ),

            // Import Results
            if (importResult != null) ...[
              const SizedBox(height: 32),
              Text(
                'Import Results',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 12),
              Container(
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.check_circle, color: Colors.green),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Imported Successfully',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                '${importResult!['imported_count'] ?? 0} employees',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if ((importResult!['skipped_count'] ?? 0) > 0) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.warning, color: Colors.orange),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Skipped',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  '${importResult!['skipped_count'] ?? 0} employees',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
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
              color: Colors.blue,
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
}
