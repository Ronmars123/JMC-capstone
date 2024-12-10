import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'device.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({Key? key, required this.deviceUid}) : super(key: key);

  final String deviceUid;

  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _auth = FirebaseAuth.instance;
  final _database = FirebaseDatabase(
    databaseURL:
        'https://jmc-capstone-default-rtdb.asia-southeast1.firebasedatabase.app',
  );

  Map<String, dynamic>? _userDevices;
  Map<String, dynamic>? _deviceData = {};
  List<String> _notifications = [];
  bool _isLoading = true;

  final LatLng _initialCameraPosition = const LatLng(12.8797, 121.7740); // Philippines Center
  final LatLngBounds _philippinesBounds = LatLngBounds(
    southwest: const LatLng(4.215806, 116.749998), // Southernmost point
    northeast: const LatLng(21.321780, 126.599998), // Northernmost point
  );

  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _fetchUserDevices();
  }

  @override
  void dispose() {
    _detachListeners();
    super.dispose();
  }

  void _attachListeners() {
    _userDevices?.keys.forEach((deviceUid) {
      final deviceRef = _database.ref('sensor_data/$deviceUid');
      deviceRef.onValue.listen((event) {
        if (event.snapshot.exists) {
          final updatedData =
              Map<String, dynamic>.from(event.snapshot.value as Map);
          setState(() {
            _deviceData![deviceUid] = updatedData;
          });
        }
      });
    });
  }

  void _detachListeners() {
    _userDevices?.keys.forEach((deviceUid) {
      final deviceRef = _database.ref('sensor_data/$deviceUid');
      deviceRef.onValue.drain();
    });
  }

  Future<void> _fetchUserDevices() async {
    try {
      final userId = _auth.currentUser?.uid;

      if (userId == null) {
        throw 'User not logged in.';
      }

      final userDevicesRef = _database.ref('user_devices/$userId');
      final userDevicesSnapshot = await userDevicesRef.get();

      if (userDevicesSnapshot.exists) {
        setState(() {
          _userDevices =
              Map<String, dynamic>.from(userDevicesSnapshot.value as Map);
        });

        _attachListeners();
      } else {
        setState(() {
          _userDevices = null;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching user devices: $e')),
      );
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(_philippinesBounds, 50),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Dashboard',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await _auth.signOut();
                Navigator.pushReplacementNamed(context, '/login');
              },
            ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'Device Overview',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: GoogleMap(
                      onMapCreated: _onMapCreated,
                      initialCameraPosition: CameraPosition(
                        target: _initialCameraPosition,
                        zoom: 6.0,
                      ),
                      mapType: MapType.normal,
                      markers: _buildMarkers(),
                      myLocationEnabled: true,
                      compassEnabled: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: _userDevices != null
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: _userDevices!.keys.map((deviceUid) {
                              final deviceData = _deviceData?[deviceUid];
                              return ListTile(
                                title: Text(
                                  'Device $deviceUid',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  'Distance: ${deviceData?['distance'] ?? 'N/A'}%',
                                ),
                              );
                            }).toList(),
                          )
                        : const Text('No devices found.'),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
      ),
    );
  }

  Set<Marker> _buildMarkers() {
    final Set<Marker> markers = {};

    _userDevices?.forEach((deviceUid, data) {
      final location = data['location'] as Map?;
      if (location != null) {
        final latitude = location['lat'];
        final longitude = location['lng'];
        if (latitude != null && longitude != null) {
          markers.add(
            Marker(
              markerId: MarkerId(deviceUid),
              position: LatLng(latitude, longitude),
              infoWindow: InfoWindow(
                title: 'Device $deviceUid',
                snippet: 'Distance: ${_deviceData?[deviceUid]?['distance']}%',
              ),
            ),
          );
        }
      }
    });

    return markers;
  }
}
