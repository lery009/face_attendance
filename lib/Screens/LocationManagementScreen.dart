import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../api/api_service.dart';

class LocationManagementScreen extends StatefulWidget {
  const LocationManagementScreen({super.key});

  @override
  State<LocationManagementScreen> createState() => _LocationManagementScreenState();
}

class _LocationManagementScreenState extends State<LocationManagementScreen> {
  final ApiService apiService = ApiService();
  List<Map<String, dynamic>> locations = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadLocations();
  }

  Future<void> loadLocations() async {
    setState(() => isLoading = true);

    try {
      final response = await apiService.getLocations(includeInactive: true);

      setState(() {
        if (response['success'] == true) {
          locations = (response['locations'] as List<dynamic>).map((loc) => {
            'id': loc['id'] ?? '',
            'name': loc['name'] ?? '',
            'address': loc['address'] ?? '',
            'latitude': loc['latitude'] ?? 0.0,
            'longitude': loc['longitude'] ?? 0.0,
            'radius_meters': loc['radius_meters'] ?? 100.0,
            'is_active': loc['is_active'] ?? true,
          }).toList();
        }
        isLoading = false;
      });
    } catch (e) {
      print('Error loading locations: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> deleteLocation(String locationId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete "$name"?'),
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
      final response = await apiService.deleteLocation(locationId);

      if (response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        loadLocations();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Failed to delete location'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void showLocationDialog({Map<String, dynamic>? location}) {
    final isEdit = location != null;
    final nameController = TextEditingController(text: location?['name'] ?? '');
    final addressController = TextEditingController(text: location?['address'] ?? '');
    final latController = TextEditingController(text: location?['latitude']?.toString() ?? '');
    final lonController = TextEditingController(text: location?['longitude']?.toString() ?? '');
    final radiusController = TextEditingController(
        text: location?['radius_meters']?.toString() ?? '100');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdit ? 'Edit Location' : 'Add New Location'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Location Name *',
                  hintText: 'e.g., Main Office',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(
                  labelText: 'Address (Optional)',
                  hintText: 'Full address',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: latController,
                decoration: const InputDecoration(
                  labelText: 'Latitude *',
                  hintText: 'e.g., 14.5995',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: lonController,
                decoration: const InputDecoration(
                  labelText: 'Longitude *',
                  hintText: 'e.g., 120.9842',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: radiusController,
                decoration: const InputDecoration(
                  labelText: 'Radius (meters) *',
                  hintText: 'e.g., 100',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () async {
                  try {
                    Position position = await Geolocator.getCurrentPosition(
                      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
                    );
                    latController.text = position.latitude.toString();
                    lonController.text = position.longitude.toString();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Current location captured!')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error getting location: $e')),
                    );
                  }
                },
                icon: const Icon(Icons.my_location),
                label: const Text('Use Current Location'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty ||
                  latController.text.isEmpty ||
                  lonController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill required fields')),
                );
                return;
              }

              final latitude = double.tryParse(latController.text);
              final longitude = double.tryParse(lonController.text);
              final radius = double.tryParse(radiusController.text) ?? 100.0;

              if (latitude == null || longitude == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invalid coordinates')),
                );
                return;
              }

              Navigator.pop(context);

              final response = isEdit
                  ? await apiService.updateLocation(
                      locationId: location['id'],
                      name: nameController.text,
                      address: addressController.text.isNotEmpty
                          ? addressController.text
                          : null,
                      latitude: latitude,
                      longitude: longitude,
                      radiusMeters: radius,
                    )
                  : await apiService.createLocation(
                      name: nameController.text,
                      latitude: latitude,
                      longitude: longitude,
                      radiusMeters: radius,
                      address: addressController.text.isNotEmpty
                          ? addressController.text
                          : null,
                    );

              if (response['success'] == true) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        isEdit ? 'Location updated successfully' : 'Location created successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
                loadLocations();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(response['message'] ?? 'Operation failed'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text(isEdit ? 'Update' : 'Create'),
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
        title: const Text('Location Management'),
        backgroundColor: const Color(0xFF1E3A8A),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: loadLocations,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : locations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.location_off, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No locations configured',
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Add locations to enable GPS verification',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: locations.length,
                  itemBuilder: (context, index) {
                    final location = locations[index];

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
                          backgroundColor: location['is_active']
                              ? const Color(0xFF1E3A8A).withValues(alpha: 0.1)
                              : Colors.grey.withValues(alpha: 0.1),
                          radius: 28,
                          child: Icon(
                            Icons.location_on,
                            color: location['is_active']
                                ? const Color(0xFF1E3A8A)
                                : Colors.grey,
                            size: 28,
                          ),
                        ),
                        title: Text(
                          location['name'] ?? 'Unknown',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (location['address'] != null &&
                                location['address'].toString().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.place, size: 14, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      location['address'],
                                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.gps_fixed, size: 14, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text(
                                  '${location['latitude']?.toStringAsFixed(6)}, ${location['longitude']?.toStringAsFixed(6)}',
                                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(Icons.radar, size: 14, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text(
                                  'Radius: ${location['radius_meters']?.toInt()}m',
                                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: location['is_active']
                                        ? Colors.green.withValues(alpha: 0.1)
                                        : Colors.red.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    location['is_active'] ? 'Active' : 'Inactive',
                                    style: TextStyle(
                                      color: location['is_active'] ? Colors.green : Colors.red,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Color(0xFF1E3A8A)),
                              onPressed: () => showLocationDialog(location: location),
                              tooltip: 'Edit Location',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () =>
                                  deleteLocation(location['id'], location['name']),
                              tooltip: 'Delete Location',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showLocationDialog(),
        icon: const Icon(Icons.add_location),
        label: const Text('Add Location'),
        backgroundColor: const Color(0xFF1E3A8A),
      ),
    );
  }
}
