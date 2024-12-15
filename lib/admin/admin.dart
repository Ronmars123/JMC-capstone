import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_database/firebase_database.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({Key? key}) : super(key: key);

  @override
  _AdminHomePageState createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage>
    with SingleTickerProviderStateMixin {
  late GoogleMapController _mapController;
  late AnimationController _animationController;
  late Animation<double> _animation;

  final LatLng davaoCityCenter = const LatLng(7.207573, 125.395874);
  final double maxDistance = 50000; // Maximum distance threshold (50 km)
  MapType _currentMapType = MapType.normal;
  Set<Marker> _markers = {};
  final _database = FirebaseDatabase(
    databaseURL:
        'https://jmc-capstone-default-rtdb.asia-southeast1.firebasedatabase.app',
  );

  List<Map<String, dynamic>> _deviceDetails = [];
  int totalTrashNotFull = 0;
  int totalTrashFull = 0;
  bool _showDeviceDetails = true; // Toggle for showing/hiding device details

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _listenToSensorData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _listenToSensorData() {
    final sensorDataRef = _database.ref('sensor_data');
    sensorDataRef.onValue.listen((event) {
      final dataSnapshot = event.snapshot;
      if (dataSnapshot.exists) {
        final Map<String, dynamic> sensorData =
            Map<String, dynamic>.from(dataSnapshot.value as Map);

        final updatedMarkers = <Marker>{};
        final updatedDetails = <Map<String, dynamic>>[];
        int notFullCount = 0;
        int fullCount = 0;

        sensorData.forEach((deviceUid, deviceData) {
          final data = Map<String, dynamic>.from(deviceData);

          if (data['Address'] != null &&
              data['Address'].startsWith('Coordinates:')) {
            final coordinates = data['Address']
                .replaceFirst('Coordinates:', '')
                .split(',')
                .map((e) => double.tryParse(e.trim()))
                .toList();

            if (coordinates.length == 2 &&
                coordinates[0] != null &&
                coordinates[1] != null) {
              final LatLng position = LatLng(coordinates[0]!, coordinates[1]!);

              final String binStatus = data['bin_status'] ?? 'Unknown';
              final String fullName = data['Fullname'] ?? 'No Name';
              final String remarks = data['remarks'] ?? 'No remarks provided';

              // Fetch distance directly from the database
              final double distance = data['distance'] != null
                  ? double.tryParse(data['distance'].toString()) ?? 0
                  : 0;

              // Increment counters based on bin status
              if (binStatus.toLowerCase() == 'not full') {
                notFullCount++;
              } else if (binStatus.toLowerCase() == 'full') {
                fullCount++;
              }

              // Add marker for each device
              updatedMarkers.add(
                Marker(
                  markerId: MarkerId(deviceUid),
                  position: position,
                  infoWindow: InfoWindow(
                    title: fullName,
                    snippet:
                        'UID: $deviceUid\nStatus: $binStatus\nDistance: ${distance.toStringAsFixed(2)} m',
                  ),
                ),
              );

              // Add device details to the list
              updatedDetails.add({
                'deviceUid': deviceUid,
                'fullName': fullName,
                'binStatus': binStatus,
                'distance': distance,
                'remarks': remarks,
                'position': position,
              });
            }
          }
        });

        setState(() {
          _markers = updatedMarkers;
          _deviceDetails = updatedDetails; // Update device details list
          totalTrashNotFull = notFullCount;
          totalTrashFull = fullCount;
        });
      }
    });
  }

  // Utility to calculate distance between two LatLng points in meters
  double _calculateDistance(LatLng start, LatLng end) {
    const double earthRadius = 6371000;
    final double dLat = _degreesToRadians(end.latitude - start.latitude);
    final double dLng = _degreesToRadians(end.longitude - start.longitude);

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(start.latitude)) *
            cos(_degreesToRadians(end.latitude)) *
            sin(dLng / 2) *
            sin(dLng / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  void _toggleMapType() {
    setState(() {
      _currentMapType = _currentMapType == MapType.normal
          ? MapType.satellite
          : MapType.normal;
    });
  }

  void _toggleDeviceDetails() {
    setState(() {
      _showDeviceDetails = !_showDeviceDetails;
      if (_showDeviceDetails) {
        _animationController.reverse();
      } else {
        _animationController.forward();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'BINSENSE',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        elevation: 4,
        backgroundColor: Colors.green.shade700,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              Navigator.pushReplacementNamed(context, '/login');
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Column(
        children: [
          // Top Stats Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context,
                    title: 'Total Trash Not Full',
                    count: '$totalTrashNotFull',
                    icon: Icons.check_circle,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    context,
                    title: 'Total Trash Full',
                    count: '$totalTrashFull',
                    icon: Icons.delete,
                    color: Colors.redAccent,
                  ),
                ),
              ],
            ),
          ),
          // Map Section
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: davaoCityCenter,
                    zoom: 7.0,
                  ),
                  mapType: _currentMapType,
                  myLocationEnabled: true,
                  compassEnabled: true,
                  markers: _markers,
                  onMapCreated: (GoogleMapController controller) {
                    _mapController = controller;
                  },
                ),
                Positioned(
                  bottom: 80,
                  right: 16,
                  child: FloatingActionButton(
                    backgroundColor: Colors.blue,
                    onPressed: () {
                      _mapController.animateCamera(
                        CameraUpdate.newCameraPosition(
                          CameraPosition(
                            target: davaoCityCenter,
                            zoom: 6.0,
                          ),
                        ),
                      );
                    },
                    tooltip: 'Focus on Davao City',
                    child: const Icon(Icons.location_on),
                  ),
                ),
              ],
            ),
          ),
          // Slide Animation for Device Details
          SizeTransition(
            sizeFactor: _animation,
            axisAlignment: -1.0,
            child: _showDeviceDetails
                ? Container(
                    height: 200,
                    color: Colors.white,
                    child: ListView.builder(
                      itemCount: _deviceDetails.length,
                      itemBuilder: (context, index) {
                        final device = _deviceDetails[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16.0, vertical: 8.0),
                          child: ListTile(
                            leading:
                                const Icon(Icons.devices, color: Colors.green),
                            title: Text(
                              'Device: ${device['fullName']}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('UID: ${device['deviceUid']}'),
                                Text('Status: ${device['binStatus']}'),
                                Text('Remarks: ${device['remarks']}'),
                              ],
                            ),
                            onTap: () {
                              _mapController.animateCamera(
                                CameraUpdate.newCameraPosition(
                                  CameraPosition(
                                    target: device['position'],
                                    zoom: 17.0,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  )
                : Container(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.green,
        onPressed: _toggleDeviceDetails,
        tooltip: _showDeviceDetails ? 'Hide Details' : 'Show Details',
        child: Icon(
          _showDeviceDetails
              ? Icons.delete_outline
              : Icons.delete, // Trash bin icons
        ),
      ),
    );
  }

  Widget _buildStatCard(BuildContext context,
      {required String title,
      required String count,
      required IconData icon,
      required Color color}) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      elevation: 4,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.1), color.withOpacity(0.3)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: color.withOpacity(0.2),
                child: Icon(
                  icon,
                  size: 26,
                  color: color,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      count,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
