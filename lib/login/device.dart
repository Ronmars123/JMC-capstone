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

  void _connectToDevice() async {
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
        setState(() {
          _sensorData = Map<String, dynamic>.from(snapshot.value as Map);
          _isConnected = true;
        });

        // Associate the device with the current user in the database
        final userDevicesRef = _database.ref('user_devices/${widget.uid}');
        await userDevicesRef.update({
          deviceUid: true, // Mark the device as associated with the user
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Device connected successfully!')),
        );
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
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) =>
              DashboardPage(deviceUid: _deviceUidController.text),
        ),
      );
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
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Circular Percent Indicator
                      CircularProgressIndicator(
                        value: (_sensorData?['distance'] ?? 0) / 100.0,
                        strokeWidth: 10.0,
                        backgroundColor: Colors.grey.shade300,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          (_sensorData?['distance'] ?? 0) < 100
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Bin Status: ${_sensorData?['bin_status'] ?? 'N/A'}',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'UID: ${_deviceUidController.text}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _proceedToDashboard,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green, // Changed color to green
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
