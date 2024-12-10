import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class AdminHomePage extends StatelessWidget {
  const AdminHomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Define the bounds of the Philippines
    final LatLngBounds philippinesBounds = LatLngBounds(
      southwest: const LatLng(4.215806, 116.749998), // Southernmost point
      northeast: const LatLng(21.321780, 126.599998), // Northernmost point
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5), // Light background for contrast
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        elevation: 4, // Adds shadow to the AppBar
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              // Handle Logout
              Navigator.pushReplacementNamed(context, '/login');
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            // Welcome Text
            const Text(
              'Welcome, Admin!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Here’s an overview of the application:',
              style: TextStyle(
                fontSize: 16,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 20),
            // Total Devices Card
            _buildStatCard(
              context,
              title: 'Total Devices',
              count: '120',
              icon: Icons.devices,
              color: Colors.blue,
            ),
            const SizedBox(height: 16),
            // Total Trash Full Card
            _buildStatCard(
              context,
              title: 'Total Trash Full',
              count: '45',
              icon: Icons.delete,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 20),
            // Google Map Section
            const Text(
              'Location Overview:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12.0),
                  child: GoogleMap(
                    initialCameraPosition: const CameraPosition(
                      target: LatLng(12.8797, 121.7740), // Philippines Center
                      zoom: 6.0,
                    ),
                    mapType: MapType.normal,
                    myLocationEnabled: true,
                    compassEnabled: true,
                    // Restrict the map to Philippines bounds
                    onCameraMove: (position) {
                      // Optionally log camera position changes if needed
                    },
                    onMapCreated: (GoogleMapController controller) {
                      controller.animateCamera(
                        CameraUpdate.newLatLngBounds(philippinesBounds, 50),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // Function to build statistic cards
  Widget _buildStatCard(BuildContext context,
      {required String title,
      required String count,
      required IconData icon,
      required Color color}) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // Icon
            CircleAvatar(
              radius: 28,
              backgroundColor: color.withOpacity(0.1),
              child: Icon(
                icon,
                size: 30,
                color: color,
              ),
            ),
            const SizedBox(width: 16),
            // Title and Count
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Count: $count',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
