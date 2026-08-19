import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class OutageMapScreen extends StatelessWidget {
  const OutageMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Accra's approximate coordinates, used as a test pin for now.
    final testLocation = LatLng(5.6037, -0.1870);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Outage Map'),
        backgroundColor: Colors.grey[100],
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: FlutterMap(
        options: MapOptions(initialCenter: testLocation, initialZoom: 12),
        children: [
          // The actual map tiles/imagery, pulled from OpenStreetMap's
          // free public servers.
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.isaacotabil.powertrackergh',
          ),

          // A single test pin, just to confirm markers render correctly.
          MarkerLayer(
            markers: [
              Marker(
                point: testLocation,
                width: 40,
                height: 40,
                child: const Icon(
                  Icons.location_on,
                  color: Colors.red,
                  size: 40,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
