import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../services/firestore_service.dart';
import '../../models/outage_report.dart';
import '../outage/outage_detail_screen.dart';

class OutageMapScreen extends StatelessWidget {
  const OutageMapScreen({super.key});

  Color _statusColor(OutageStatus status) {
    switch (status) {
      case OutageStatus.restored:
        return Colors.green;
      case OutageStatus.reported:
        return Colors.redAccent;
      case OutageStatus.investigating:
        return Colors.orange;
      case OutageStatus.repairing:
        return Colors.blue;
    }
  }

  void _showReportPreview(BuildContext context, OutageReport report) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      report.area,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor(report.status).withAlpha(30),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      report.status.name,
                      style: TextStyle(
                        color: _statusColor(report.status),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                report.description,
                style: TextStyle(color: Colors.grey[700]),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // close the bottom sheet
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OutageDetailScreen(report: report),
                      ),
                    );
                  },
                  child: const Text('View Full Details'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();

    // Default view centers on Accra until real report pins load in.
    final defaultCenter = LatLng(5.6037, -0.1870);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Outage Map'),
        backgroundColor: Colors.grey[100],
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: StreamBuilder<List<OutageReport>>(
        stream: firestoreService.streamReports(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final allReports = snapshot.data ?? [];

          // Only show pins for reports that actually have real
          // coordinates — skip any still sitting at the 0,0 fallback.
          final mappableReports = allReports
              .where((r) => r.latitude != 0.0 && r.longitude != 0.0)
              .toList();

          return FlutterMap(
            options: MapOptions(
              initialCenter: mappableReports.isNotEmpty
                  ? LatLng(
                      mappableReports.first.latitude,
                      mappableReports.first.longitude,
                    )
                  : defaultCenter,
              initialZoom: 12,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.isaacotabil.powertrackergh',
              ),
              MarkerLayer(
                markers: mappableReports.map((report) {
                  return Marker(
                    point: LatLng(report.latitude, report.longitude),
                    width: 40,
                    height: 40,
                    child: GestureDetector(
                      onTap: () => _showReportPreview(context, report),
                      child: Icon(
                        Icons.location_on,
                        color: _statusColor(report.status),
                        size: 40,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        },
      ),
    );
  }
}
