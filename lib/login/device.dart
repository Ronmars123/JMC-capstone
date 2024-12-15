import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dashboard.dart';

class DevicePage extends StatefulWidget {
  final String uid;

  const DevicePage({Key? key, required this.uid}) : super(key: key);

  @override
  _DevicePageState createState() => _DevicePageState();
}

class _DevicePageState extends State<DevicePage> {
  final _auth = FirebaseAuth.instance;
  final _deviceUidController = TextEditingController();
  final _database = FirebaseDatabase(
    databaseURL:
        'https://jmc-capstone-default-rtdb.asia-southeast1.firebasedatabase.app',
  );

  Map<String, dynamic>? _sensorData;
  bool _isConnected = false;

  Future<void> _connectToDevice() async {
    final deviceUid = _deviceUidController.text.trim();
    if (deviceUid.isEmpty || widget.uid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid UID or log in.')),
      );
      return;
    }

    try {
      final sensorRef = _database.ref('sensor_data/$deviceUid');
      final snapshot = await sensorRef.get();

      if (snapshot.exists) {
        final sensorData = Map<String, dynamic>.from(snapshot.value as Map);

        // Check if the device is already connected
        if (sensorData['device_connected'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text('This device is already connected to another user.')),
          );
          return;
        }

        // Retrieve the user's profile details
        final userRef = _database.ref('users/${widget.uid}');
        final userSnapshot = await userRef.get();

        if (userSnapshot.exists) {
          final userProfile =
              Map<String, dynamic>.from(userSnapshot.value as Map);

          // Update the device's data with the user's details and set `device_connected`
          await sensorRef.update({
            'Fullname': userProfile['full_name'] ?? 'Unknown',
            'Address': userProfile['address'] ?? 'Unknown',
            'Connected': true,
            'device_connected': true, // Set this flag to true
          });

          setState(() {
            _sensorData = Map<String, dynamic>.from(sensorData);
            _sensorData?['Fullname'] = userProfile['full_name'] ?? 'Unknown';
            _sensorData?['Address'] = userProfile['address'] ?? 'Unknown';
            _isConnected = true;
          });

          // Associate the device with the current user in `user_devices`
          final userDevicesRef = _database.ref('user_devices/${widget.uid}');
          await userDevicesRef.update({
            deviceUid: true, // Mark the device as associated with the user
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Device connected successfully!')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User profile not found.')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No data found for this UID')),
        );
        setState(() {
          _sensorData = null;
          _isConnected = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error connecting to device: $e')),
      );
    }
  }

  void _proceedToDashboard() {
    if (_isConnected) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              DashboardPage(deviceUid: _deviceUidController.text),
        ),
      ).then((_) {
        // Optionally, handle post-navigation actions here if needed
        setState(() {}); // Refresh the current page if required
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please connect to a device first.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect to Device'),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_isConnected) ...[
              const Text(
                'Enter Device UID:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _deviceUidController,
                decoration: InputDecoration(
                  hintText: 'UID-XXXXXXXXXX',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _connectToDevice,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
                child: const Text(
                  'Connect',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ] else ...[
              const Text(
                'Connected Device Data:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                elevation: 4,
                margin: const EdgeInsets.symmetric(vertical: 10),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.shade50, Colors.green.shade100],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Row with UID
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Device Details',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 4,
                                horizontal: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade300,
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              child: Text(
                                'UID: ${_deviceUidController.text}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Bin Status
                        Row(
                          children: [
                            Icon(
                              Icons.delete,
                              color: (_sensorData?['bin_status'] == "Full")
                                  ? Colors.red
                                  : Colors.green,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Bin Status: ${_sensorData?['bin_status'] ?? 'N/A'}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Full Name
                        Row(
                          children: [
                            const Icon(
                              Icons.person,
                              color: Colors.green,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Full Name: ${_sensorData?['Fullname'] ?? 'N/A'}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Address
                        Row(
                          children: [
                            const Icon(
                              Icons.home,
                              color: Colors.green,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Address: ${_sensorData?['Address'] ?? 'N/A'}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _proceedToDashboard,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
                child: const Text(
                  'Proceed to Dashboard',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
