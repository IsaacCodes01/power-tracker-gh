import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';
import '../../models/outage_report.dart';
import '../outage/outage_detail_screen.dart';
import '../../services/connectivity_service.dart';
import '../../widgets/app_snackbar.dart';

class OutageMapScreen extends StatefulWidget {
  final double? focusLatitude;
  final double? focusLongitude;

  const OutageMapScreen({super.key, this.focusLatitude, this.focusLongitude});

  @override
  State<OutageMapScreen> createState() => _OutageMapScreenState();
}

class _OutageMapScreenState extends State<OutageMapScreen> {
  final _mapController = MapController();
  final _locationService = LocationService();
  final _searchController = TextEditingController();

  bool _isSearching = false;
  String? _searchError;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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

  final _connectivityService = ConnectivityService();

  Future<void> _handleSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    final hasConnection = await _connectivityService.hasConnection();
    if (!hasConnection) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'No internet connection. Please check your network.',
          type: AppMessageType.error,
        );
      }
      return;
    }

    setState(() {
      _isSearching = true;
      _searchError = null;
    });

    final coordinates = await _locationService.getCoordinatesFromArea(query);

    if (coordinates != null) {
      _mapController.move(
        LatLng(coordinates['latitude']!, coordinates['longitude']!),
        14,
      );
    } else {
      setState(() => _searchError = 'Area not found. Try a different name.');
    }

    if (mounted) setState(() => _isSearching = false);
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
                    Navigator.pop(context);
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
    final defaultCenter = LatLng(5.6037, -0.1870);

    // If this screen was opened with a specific report's coordinates
    // (e.g. from "View on map"), center there. Otherwise use the
    // first report's location, or fall back to Accra.
    final initialCenter =
        (widget.focusLatitude != null && widget.focusLongitude != null)
        ? LatLng(widget.focusLatitude!, widget.focusLongitude!)
        : null;

    return Scaffold(
      backgroundColor: Colors.grey[100],
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
          final mappableReports = allReports
              .where((r) => r.latitude != 0.0 && r.longitude != 0.0)
              .toList();

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter:
                      initialCenter ??
                      (mappableReports.isNotEmpty
                          ? LatLng(
                              mappableReports.first.latitude,
                              mappableReports.first.longitude,
                            )
                          : defaultCenter),
                  initialZoom: initialCenter != null ? 15 : 12,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
              ),

              // FIXED SEARCH BAR
              Positioned(
                top: widget.focusLatitude != null ? 70 : 16,
                left: 16,
                right: 16,
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(25),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        onSubmitted: (_) => _handleSearch(),
                        decoration: InputDecoration(
                          hintText: 'Search an area on the map...',
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Colors.deepPurple,
                          ),
                          suffixIcon: _isSearching
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : IconButton(
                                  icon: const Icon(Icons.arrow_forward),
                                  onPressed: _handleSearch,
                                ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                    if (_searchError != null)
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _searchError!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 13,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // BACK BUTTON — only shown when this screen was pushed
              // directly (e.g. from "View on map"), since in that case
              // there's no bottom nav bar to rely on for navigation.
              if (widget.focusLatitude != null)
                Positioned(
                  top: 16,
                  left: 16,
                  child: CircleAvatar(
                    backgroundColor: Colors.white,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.black87),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
