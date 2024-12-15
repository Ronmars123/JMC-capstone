import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'device.dart';
import 'edit_profile.dart';
import 'edit_profiles.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({Key? key, required String deviceUid}) : super(key: key);

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
  Map<String, bool> _toggleDetails = {};
  List<String> _notifications = [];
  bool _isLoading = true;
  Map<String, bool> _shownNotifications = {};

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

          final binStatus = updatedData['bin_status'] ?? 'Not Full';
          final remarks = updatedData['remarks'] ?? 'No remarks provided';

          // Add a "bin full" notification if bin_status is "Full"
          if (binStatus == 'Full' &&
              (_shownNotifications[deviceUid] ?? false) == false) {
            final timestamp =
                DateFormat('MM-dd-yy HH:mm:ss').format(DateTime.now());
            final fullNotification =
                'Device $deviceUid: Your bin is FULL! Please empty it immediately. ($timestamp)\nRemarks: $remarks';
            setState(() {
              _notifications.add(fullNotification);
              _shownNotifications[deviceUid] =
                  true; // Mark notification as shown
            });

            // Automatically display the notifications modal
            _showNotifications();
          } else if (binStatus == 'Not Full') {
            // Reset the notification state when the bin is not full
            setState(() {
              _shownNotifications[deviceUid] = false;
            });
          }
        }
      });
    });
  }

  void _showBinFullDialog(String deviceUid, VoidCallback onClose) {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent manual closing
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          title: const Text(
            'Bin Full Alert!',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          content: Text(
            'Device $deviceUid: Your bin is full!',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'The dialog will automatically close when the bin is less than 80% full.',
                    ),
                    backgroundColor: Colors.blue,
                  ),
                );
              },
              child: const Text(
                'OK',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    ).then((_) {
      onClose(); // Reset the dialog state when closed
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
          _toggleDetails = {
            for (var key in _userDevices!.keys) key: true,
          };
        });

        for (var deviceId in _userDevices!.keys) {
          await _fetchDeviceData(deviceId);
        }

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

  Future<void> _fetchDeviceData(String deviceUid) async {
    try {
      final deviceRef = _database.ref('sensor_data/$deviceUid');
      final snapshot = await deviceRef.get();

      if (snapshot.exists) {
        final deviceInfo = Map<String, dynamic>.from(snapshot.value as Map);
        setState(() {
          _deviceData![deviceUid] = deviceInfo;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error fetching device data for $deviceUid: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showNotifications() {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent manual closing
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              title: const Row(
                children: [
                  Icon(Icons.notifications, color: Colors.green),
                  SizedBox(width: 8),
                  Text(
                    'Notifications',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: _notifications.isEmpty
                    ? const Center(
                        child: Text(
                          'No notifications at the moment.',
                          style: TextStyle(color: Colors.black54),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _notifications.length,
                        itemBuilder: (context, index) {
                          return Card(
                            color: Colors.red.shade50,
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            child: ListTile(
                              leading: const Icon(
                                Icons.warning,
                                color: Colors.red,
                              ),
                              title: Text(
                                _notifications[index],
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _notifications.clear(); // Clear all notifications
                    });
                    Navigator.pop(context); // Close modal
                  },
                  child: const Text(
                    'Clear All',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); // Close modal
                  },
                  child: const Text(
                    'Close',
                    style: TextStyle(color: Colors.green),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    return "${timestamp.hour.toString().padLeft(2, '0')}:"
        "${timestamp.minute.toString().padLeft(2, '0')}:"
        "${timestamp.second.toString().padLeft(2, '0')}";
  }

  void _logout() async {
    try {
      await _auth.signOut();
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error logging out: $e')),
      );
    }
  }

  Future<void> _confirmDeleteDevice(String deviceUid) async {
    final confirmation = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Device'),
          content: const Text('Are you sure you want to delete this device?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false); // User cancels deletion
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, true); // User confirms deletion
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirmation == true) {
      await _removeDevice(deviceUid); // Proceed to remove the device
    }
  }

  Future<void> _removeDevice(String deviceUid) async {
    try {
      final userId = _auth.currentUser?.uid;

      if (userId == null) {
        throw 'User not logged in.';
      }

      // Remove the device association from the user's `user_devices`
      final userDevicesRef = _database.ref('user_devices/$userId/$deviceUid');
      await userDevicesRef.remove();

      // Update the `sensor_data` for the deleted device
      final deviceRef = _database.ref('sensor_data/$deviceUid');
      await deviceRef.update({
        'Fullname': '',
        'Address': '',
        'device_connected': false,
      });

      // Remove the device from the local state
      setState(() {
        _userDevices!.remove(deviceUid);
        _deviceData!.remove(deviceUid);
      });

      // Show a success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Device $deviceUid removed successfully!')),
      );
    } catch (e) {
      // Handle errors and display a message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error removing device: $e')),
      );
    }
  }

  void _addRemarks(String deviceUid) {
    final TextEditingController remarksController = TextEditingController();
    final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          title: const Row(
            children: [
              Icon(Icons.note_add, color: Colors.green),
              SizedBox(width: 8),
              Text(
                'Add Remarks',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: remarksController,
                    decoration: InputDecoration(
                      labelText: 'Enter your remarks',
                      labelStyle: const TextStyle(color: Colors.green),
                      hintText: 'Write Remarks About The Device...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.green),
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      prefixIcon:
                          const Icon(Icons.edit_note, color: Colors.green),
                    ),
                    maxLines: 2, // Adjusted to make the box smaller
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Remarks cannot be empty.';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog without saving
              },
              child: const Text(
                'Cancel',
                style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
              ),
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  final remarks = remarksController.text;
                  try {
                    final deviceRef = _database.ref('sensor_data/$deviceUid');
                    await deviceRef.update({'remarks': remarks});

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Remarks added successfully!',
                          style: TextStyle(color: Colors.white),
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                    Navigator.pop(context); // Close dialog after saving
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error adding remarks: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalDevices = _userDevices?.length ?? 0;
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'BINSENSE',
            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5),
          ),
          backgroundColor: Colors.green.shade700,
          automaticallyImplyLeading: false, // This removes the back button
          actions: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.person),
                  tooltip: 'Profile',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const EditProfilePages()),
                    );
                  },
                ),
                Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications),
                      onPressed: () {
                        _showNotifications();
                      },
                    ),
                    if (_notifications.isNotEmpty)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: CircleAvatar(
                          radius: 10,
                          backgroundColor: Colors.red,
                          child: Text(
                            _notifications.length.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.logout),
                  tooltip: 'Logout',
                  onPressed: _logout,
                ),
              ],
            ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Connected Devices',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        IconButton(
                          icon:
                              const Icon(Icons.add_circle, color: Colors.green),
                          tooltip: 'Add Device',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DevicePage(
                                    uid: _auth.currentUser?.uid ?? ''),
                              ),
                            ).then((_) {
                              setState(() {
                                _isLoading = true;
                              });
                              _fetchUserDevices();
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    totalDevices > 0
                        ? Expanded(
                            child: ListView.builder(
                              itemCount: totalDevices,
                              itemBuilder: (context, index) {
                                final deviceUid =
                                    _userDevices!.keys.elementAt(index);
                                final deviceData = _deviceData?[deviceUid];

                                return Card(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12.0),
                                  ),
                                  elevation: 3,
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 8.0),
                                  child: Container(
                                    color: Colors.grey.shade50,
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text(
                                                'Device Details',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                              Row(
                                                children: [
                                                  Switch(
                                                    activeColor: Colors.green,
                                                    value: _toggleDetails[
                                                        deviceUid]!,
                                                    onChanged: (value) {
                                                      setState(() {
                                                        _toggleDetails[
                                                            deviceUid] = value;
                                                      });
                                                    },
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(
                                                        Icons.delete,
                                                        color:
                                                            Colors.redAccent),
                                                    tooltip: 'Delete Device',
                                                    onPressed: () {
                                                      _confirmDeleteDevice(
                                                          deviceUid);
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Center(
                                            child: Icon(
                                              Icons.delete, // Trash bin icon
                                              size: 100.0, // Size of the icon
                                              color: (deviceData?[
                                                              'bin_status'] ??
                                                          'Not Full') ==
                                                      'Not Full'
                                                  ? Colors
                                                      .green // Green for "Not Full"
                                                  : Colors
                                                      .red, // Red for "Full"
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          if (_toggleDetails[deviceUid]!) ...[
                                            const Divider(),
                                            Text(
                                              'Bin Status: ${deviceData?['bin_status'] ?? 'N/A'}',
                                              style: TextStyle(
                                                fontSize: 17,
                                                fontWeight: FontWeight.w600,
                                                color: (deviceData?[
                                                                'bin_status'] ??
                                                            'N/A') ==
                                                        'Not Full'
                                                    ? Colors
                                                        .green // Green for "Not Full"
                                                    : (deviceData?['bin_status'] ??
                                                                'N/A') ==
                                                            'Full'
                                                        ? Colors
                                                            .red // Red for "Full"
                                                        : Colors
                                                            .black, // Default color for "N/A" or unknown status
                                              ),
                                            ),
                                            const SizedBox(height: 5),
                                            Text(
                                              'Serial Number: $deviceUid',
                                              style: const TextStyle(
                                                fontSize: 17,
                                                color: Colors.black54,
                                              ),
                                            ),
                                            if (deviceData?['remarks'] !=
                                                    null &&
                                                (deviceData?['remarks']
                                                        as String)
                                                    .isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 5.0),
                                                child: Text(
                                                  'Remarks: ${deviceData?['remarks']}',
                                                  style: const TextStyle(
                                                    fontSize: 17,
                                                    color: Colors.blueGrey,
                                                    fontStyle: FontStyle.italic,
                                                  ),
                                                ),
                                              ),
                                          ],
                                          const SizedBox(height: 10),
                                          Center(
                                            child: ElevatedButton(
                                              onPressed: () {
                                                _addRemarks(
                                                    deviceUid); // Call the function to add remarks
                                              },
                                              style: ElevatedButton.styleFrom(
                                                primary: Colors
                                                    .green, // Button color
                                              ),
                                              child: const Text('Add Remarks'),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          )
                        : const Expanded(
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'No devices connected.',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 10),
                                ],
                              ),
                            ),
                          ),
                  ],
                ),
              ),
      ),
    );
  }
}
