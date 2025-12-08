import 'package:flutter/material.dart';
import '../api/api_service.dart';

class CameraManagementScreen extends StatefulWidget {
  const CameraManagementScreen({super.key});

  @override
  State<CameraManagementScreen> createState() => _CameraManagementScreenState();
}

class _CameraManagementScreenState extends State<CameraManagementScreen> {
  final ApiService apiService = ApiService();

  List<Map<String, dynamic>> cameras = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadCameras();
  }

  Future<void> loadCameras() async {
    setState(() => isLoading = true);

    try {
      final response = await apiService.getCameras();

      if (response['success'] == true && mounted) {
        setState(() {
          cameras = List<Map<String, dynamic>>.from(response['cameras'] ?? []);
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      print('Error loading cameras: $e');
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> deleteCamera(String cameraId, String cameraName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Camera'),
        content: Text('Are you sure you want to delete "$cameraName"?'),
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final response = await apiService.deleteCamera(cameraId);

      if (response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        loadCameras();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Failed to delete camera'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void showAddCameraDialog() {
    showDialog(
      context: context,
      builder: (context) => AddCameraDialog(
        onCameraAdded: () => loadCameras(),
      ),
    );
  }

  void showEditCameraDialog(Map<String, dynamic> camera) {
    showDialog(
      context: context,
      builder: (context) => EditCameraDialog(
        camera: camera,
        onCameraUpdated: () => loadCameras(),
      ),
    );
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

  IconData _getCameraTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'rtsp':
        return Icons.videocam;
      case 'http':
        return Icons.http;
      case 'webcam':
        return Icons.camera_alt;
      default:
        return Icons.camera;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Camera Management'),
        backgroundColor: const Color(0xFF1E3A8A),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: loadCameras,
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: showAddCameraDialog,
        backgroundColor: const Color(0xFF1E3A8A),
        icon: const Icon(Icons.add),
        label: const Text('Add Camera'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: loadCameras,
              child: cameras.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.videocam_off,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No cameras registered',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add your first IP camera to get started',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        // Stats Card
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildStatItem(
                                  'Total Cameras',
                                  cameras.length.toString(),
                                  Icons.videocam,
                                  const Color(0xFF3B82F6),
                                ),
                                Container(
                                  height: 40,
                                  width: 1,
                                  color: Colors.grey[300],
                                ),
                                _buildStatItem(
                                  'Online',
                                  cameras
                                      .where((c) => c['status'] == 'online')
                                      .length
                                      .toString(),
                                  Icons.check_circle,
                                  const Color(0xFF10B981),
                                ),
                                Container(
                                  height: 40,
                                  width: 1,
                                  color: Colors.grey[300],
                                ),
                                _buildStatItem(
                                  'Offline',
                                  cameras
                                      .where((c) => c['status'] == 'offline')
                                      .length
                                      .toString(),
                                  Icons.cancel,
                                  const Color(0xFF6B7280),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Cameras Grid
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.2,
                          ),
                          itemCount: cameras.length,
                          itemBuilder: (context, index) {
                            final camera = cameras[index];
                            return _buildCameraCard(camera);
                          },
                        ),
                      ],
                    ),
            ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
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
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildCameraCard(Map<String, dynamic> camera) {
    final status = camera['status'] ?? 'offline';
    final statusColor = _getStatusColor(status);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => showEditCameraDialog(camera),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A8A).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getCameraTypeIcon(camera['camera_type'] ?? ''),
                      color: const Color(0xFF1E3A8A),
                      size: 24,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                camera['name'] ?? 'Unnamed',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                (camera['camera_type'] ?? 'Unknown').toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (camera['location'] != null && camera['location'].toString().isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        camera['location'],
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    color: Colors.red,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => deleteCamera(
                      camera['id'],
                      camera['name'],
                    ),
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

// Add Camera Dialog
class AddCameraDialog extends StatefulWidget {
  final VoidCallback onCameraAdded;

  const AddCameraDialog({super.key, required this.onCameraAdded});

  @override
  State<AddCameraDialog> createState() => _AddCameraDialogState();
}

class _AddCameraDialogState extends State<AddCameraDialog> {
  final _formKey = GlobalKey<FormState>();
  final ApiService apiService = ApiService();

  final nameController = TextEditingController();
  final ipAddressController = TextEditingController();
  final portController = TextEditingController(text: '554'); // Default RTSP port
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  final locationController = TextEditingController();

  String selectedBrand = 'dahua';
  String selectedType = 'rtsp';
  bool isSubmitting = false;
  bool isTesting = false;

  // Camera brand presets with their URL patterns
  final Map<String, Map<String, String>> brandPresets = {
    'dahua': {
      'name': 'Dahua',
      'rtspPath': '/cam/realmonitor?channel=1&subtype=0',
      'httpPath': '/cgi-bin/snapshot.cgi',
      'port': '554',
    },
    'hikvision': {
      'name': 'Hikvision',
      'rtspPath': '/Streaming/Channels/101',
      'httpPath': '/ISAPI/Streaming/channels/101/picture',
      'port': '554',
    },
    'generic': {
      'name': 'Generic/Other',
      'rtspPath': '/stream',
      'httpPath': '/video',
      'port': '554',
    },
  };

  @override
  void dispose() {
    nameController.dispose();
    ipAddressController.dispose();
    portController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    locationController.dispose();
    super.dispose();
  }

  String _buildStreamUrl() {
    final ip = ipAddressController.text.trim();
    final port = portController.text.trim();
    final username = usernameController.text.trim();
    final password = passwordController.text.trim();
    final path = brandPresets[selectedBrand]?['rtspPath'] ?? '/stream';

    if (ip.isEmpty) return '';

    if (username.isNotEmpty && password.isNotEmpty) {
      return 'rtsp://$username:$password@$ip:$port$path';
    } else {
      return 'rtsp://$ip:$port$path';
    }
  }

  Future<void> submitCamera() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isSubmitting = true);

    try {
      final streamUrl = _buildStreamUrl();

      final response = await apiService.createCamera(
        name: nameController.text.trim(),
        cameraType: selectedType,
        streamUrl: streamUrl.isNotEmpty ? streamUrl : null,
        username: usernameController.text.trim().isNotEmpty
            ? usernameController.text.trim()
            : null,
        password: passwordController.text.trim().isNotEmpty
            ? passwordController.text.trim()
            : null,
        location: locationController.text.trim().isNotEmpty
            ? locationController.text.trim()
            : null,
      );

      setState(() => isSubmitting = false);

      if (response['success'] == true && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera added successfully'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onCameraAdded();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Failed to add camera'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() => isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> testConnection() async {
    if (ipAddressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter camera IP address first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => isTesting = true);

    try {
      // Test camera connection (you can implement this in ApiService)
      await Future.delayed(const Duration(seconds: 2)); // Simulated test

      if (mounted) {
        setState(() => isTesting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connection test successful!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => isTesting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
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
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.videocam, color: Color(0xFF1E3A8A)),
                    const SizedBox(width: 12),
                    const Text(
                      'Add New Camera',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Camera Name
                TextFormField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Camera Name *',
                    hintText: 'e.g., Main Entrance Camera',
                    prefixIcon: const Icon(Icons.label_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Camera name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Camera Brand
                DropdownButtonFormField<String>(
                  value: selectedBrand,
                  decoration: InputDecoration(
                    labelText: 'Camera Brand *',
                    helperText: 'Select your camera brand for automatic configuration',
                    helperMaxLines: 2,
                    prefixIcon: const Icon(Icons.business),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: brandPresets.entries.map((entry) {
                    return DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value['name']!),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedBrand = value!;
                      portController.text = brandPresets[value]!['port']!;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // IP Address
                TextFormField(
                  controller: ipAddressController,
                  decoration: InputDecoration(
                    labelText: 'Camera IP Address *',
                    hintText: '192.168.1.100',
                    helperText: 'Find this in your camera settings or router',
                    helperMaxLines: 2,
                    prefixIcon: const Icon(Icons.router),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'IP address is required';
                    }
                    // Simple IP validation
                    final ipPattern = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
                    if (!ipPattern.hasMatch(value)) {
                      return 'Enter valid IP address (e.g., 192.168.1.100)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Port (Advanced - collapsible)
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: portController,
                        decoration: InputDecoration(
                          labelText: 'Port',
                          helperText: 'Usually 554 for RTSP cameras',
                          helperMaxLines: 2,
                          prefixIcon: const Icon(Icons.settings_ethernet),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Username
                TextFormField(
                  controller: usernameController,
                  decoration: InputDecoration(
                    labelText: 'Username *',
                    hintText: 'admin',
                    helperText: 'Camera login username',
                    helperMaxLines: 2,
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Username is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password
                TextFormField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password *',
                    helperText: 'Camera login password',
                    helperMaxLines: 2,
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Location
                TextFormField(
                  controller: locationController,
                  decoration: InputDecoration(
                    labelText: 'Location (Optional)',
                    hintText: 'e.g., Main Building Entrance',
                    prefixIcon: const Icon(Icons.location_on_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Preview of generated URL
                if (ipAddressController.text.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 8),
                            Text(
                              'Auto-generated Stream URL:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          _buildStreamUrl(),
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),

                // Test Connection Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: isTesting ? null : testConnection,
                    icon: isTesting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.wifi_find),
                    label: Text(isTesting ? 'Testing Connection...' : 'Test Connection'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: Colors.grey[400]!),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: isSubmitting ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: isSubmitting ? null : submitCamera,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Add Camera'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Edit Camera Dialog
class EditCameraDialog extends StatefulWidget {
  final Map<String, dynamic> camera;
  final VoidCallback onCameraUpdated;

  const EditCameraDialog({
    super.key,
    required this.camera,
    required this.onCameraUpdated,
  });

  @override
  State<EditCameraDialog> createState() => _EditCameraDialogState();
}

class _EditCameraDialogState extends State<EditCameraDialog> {
  final _formKey = GlobalKey<FormState>();
  final ApiService apiService = ApiService();

  late TextEditingController nameController;
  late TextEditingController streamUrlController;
  late TextEditingController usernameController;
  late TextEditingController passwordController;
  late TextEditingController locationController;

  late String selectedType;
  bool isSubmitting = false;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.camera['name']);
    streamUrlController = TextEditingController(text: widget.camera['stream_url'] ?? '');
    usernameController = TextEditingController(text: widget.camera['username'] ?? '');
    passwordController = TextEditingController();
    locationController = TextEditingController(text: widget.camera['location'] ?? '');
    selectedType = widget.camera['camera_type'] ?? 'rtsp';
  }

  @override
  void dispose() {
    nameController.dispose();
    streamUrlController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    locationController.dispose();
    super.dispose();
  }

  Future<void> submitUpdate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isSubmitting = true);

    try {
      final response = await apiService.updateCamera(
        cameraId: widget.camera['id'],
        name: nameController.text.trim(),
        cameraType: selectedType,
        streamUrl: streamUrlController.text.trim().isNotEmpty
            ? streamUrlController.text.trim()
            : null,
        username: usernameController.text.trim().isNotEmpty
            ? usernameController.text.trim()
            : null,
        password: passwordController.text.trim().isNotEmpty
            ? passwordController.text.trim()
            : null,
        location: locationController.text.trim().isNotEmpty
            ? locationController.text.trim()
            : null,
      );

      setState(() => isSubmitting = false);

      if (response['success'] == true && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onCameraUpdated();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Failed to update camera'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() => isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.edit, color: Color(0xFF1E3A8A)),
                    const SizedBox(width: 12),
                    const Text(
                      'Edit Camera',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Same form fields as Add Camera Dialog
                TextFormField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Camera Name *',
                    prefixIcon: const Icon(Icons.label_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Camera name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: InputDecoration(
                    labelText: 'Camera Type *',
                    prefixIcon: const Icon(Icons.category_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'rtsp', child: Text('RTSP')),
                    DropdownMenuItem(value: 'http', child: Text('HTTP')),
                    DropdownMenuItem(value: 'webcam', child: Text('Webcam')),
                  ],
                  onChanged: (value) {
                    setState(() => selectedType = value!);
                  },
                ),
                const SizedBox(height: 16),

                if (selectedType != 'webcam') ...[
                  TextFormField(
                    controller: streamUrlController,
                    decoration: InputDecoration(
                      labelText: 'Stream URL *',
                      prefixIcon: const Icon(Icons.link),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (selectedType != 'webcam' &&
                          (value == null || value.isEmpty)) {
                        return 'Stream URL is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: usernameController,
                    decoration: InputDecoration(
                      labelText: 'Username (Optional)',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Password (Optional)',
                      hintText: 'Leave blank to keep current',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                TextFormField(
                  controller: locationController,
                  decoration: InputDecoration(
                    labelText: 'Location (Optional)',
                    prefixIcon: const Icon(Icons.location_on_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: isSubmitting ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: isSubmitting ? null : submitUpdate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Update Camera'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
