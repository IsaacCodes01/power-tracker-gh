import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';
import '../../models/outage_report.dart';
import '../outage/outage_detail_screen.dart';
import '../../services/connectivity_service.dart';
import '../../widgets/app_snackbar.dart';
import '../../utils/network_guard.dart';

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
  final _firestoreService = FirestoreService();

  bool _isSearching = false;
  String? _searchError;

  // Live suggestions as the user types, same behaviour as
  // location_search_screen.dart's picker in the report flow.
  List<dynamic> _suggestions = [];
  bool _showSuggestions = false;

  // Where the last search actually landed — rendered as its own
  // distinct marker so it's obvious at a glance which pin is "what you
  // searched for" versus the outage report pins already on the map.
  LatLng? _searchedLocation;
  String? _searchedLocationName;
  bool _showLocationInfoBar = false;

  // Created once here instead of inline in build() — recreating the
  // stream on every rebuild (search, map movement, anything that calls
  // setState) was making StreamBuilder drop back to
  // ConnectionState.waiting repeatedly, the same flicker bug Home had.
  late Stream<List<OutageReport>> _reportsStream;

  // Same stream-hang detection as Home: if the first snapshot hasn't
  // arrived within a few seconds, swap the spinner for a "taking a
  // while" state with a manual retry instead of spinning forever.
  bool _reportsTookTooLong = false;
  Timer? _reportsHangTimer;

  void _startReportsHangTimer() {
    _reportsHangTimer?.cancel();
    _reportsHangTimer = Timer(const Duration(seconds: 8), () {
      if (mounted) setState(() => _reportsTookTooLong = true);
    });
  }

  void _retryReportsStream() {
    setState(() {
      _reportsStream = _firestoreService.streamReports();
      _reportsTookTooLong = false;
    });
    _startReportsHangTimer();
  }

  @override
  void initState() {
    super.initState();
    _reportsStream = _firestoreService.streamReports();
    _startReportsHangTimer();
  }

  // Same debounce as location_search_screen.dart — waits for a pause in
  // typing before actually calling Nominatim, since firing one request
  // per keystroke can trip its ~1 request/second rate limit and cause
  // an area that genuinely exists to silently come back as "no
  // suggestions" purely because of timing, not because it's missing.
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchController.dispose();
    _reportsHangTimer?.cancel();
    _searchDebounce?.cancel();
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

  // Fires immediately on every keystroke to clear/gate the dropdown,
  // but the actual Nominatim call is debounced (see _fetchSuggestions)
  // instead of firing on every keystroke — same reasoning as
  // location_search_screen.dart. 300ms feels like the sweet spot
  // between "actually protects the rate limit" and "doesn't feel
  // laggy" — the spinner shows immediately too, so the wait doesn't
  // feel like dead silence even though results take a brief moment.
  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    if (query.trim().length < 3) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
        _isSearching = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _fetchSuggestions(query);
    });
  }

  Future<void> _fetchSuggestions(String query) async {
    try {
      final results = await _locationService.searchAreas(query);
      if (!mounted) return;
      setState(() {
        _suggestions = results;
        _showSuggestions = results.isNotEmpty;
      });
    } catch (_) {
      // Live suggestions are a nicety — if one lookup fails (a blip, a
      // timeout), just don't show a dropdown for it. The explicit
      // search button below still works and reports a proper error if
      // the user submits while genuinely offline.
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _selectSuggestion(dynamic item) {
    final lat = double.tryParse(item['lat']?.toString() ?? '');
    final lon = double.tryParse(item['lon']?.toString() ?? '');
    if (lat == null || lon == null) return;

    _searchDebounce?.cancel();
    FocusScope.of(context).unfocus();
    final name = _locationService.shortenLocationName(
      item['display_name'] ?? '',
    );
    _searchController.text = name;
    setState(() {
      _showSuggestions = false;
      _suggestions = [];
      _searchedLocation = LatLng(lat, lon);
      _searchedLocationName = name;
      _searchError = null;
      _showLocationInfoBar = false;
    });
    _mapController.move(LatLng(lat, lon), 15);
  }

  Future<void> _handleSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    // Cancel any pending live-suggestions lookup from the last
    // keystroke — without this, hitting "Done" right after typing left
    // that debounced request still in flight, firing a SECOND Nominatim
    // call moments after this one. Two near-simultaneous requests can
    // trip Nominatim's rate limit, causing a confusing timeout on the
    // leftover request even though the search you actually see already
    // succeeded.
    _searchDebounce?.cancel();
    setState(() {
      _showSuggestions = false;
      _suggestions = [];
    });

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

    final hasRealAccess = await _connectivityService.hasRealInternetAccess();
    if (!hasRealAccess) {
      if (mounted) {
        setState(() => _isSearching = false);
        AppSnackbar.show(
          context,
          message: const NetworkUnavailableException().toString(),
          type: AppMessageType.error,
        );
      }
      return;
    }

    try {
      final coordinates = await _locationService.getCoordinatesFromArea(query);

      if (coordinates != null) {
        final target = LatLng(
          coordinates['latitude']!,
          coordinates['longitude']!,
        );
        _mapController.move(target, 14);
        setState(() {
          _searchedLocation = target;
          _searchedLocationName = query;
          _showSuggestions = false;
          _showLocationInfoBar = false;
        });
      } else {
        setState(() => _searchError = 'Area not found. Try a different name.');
      }
    } catch (e) {
      // A network timeout/failure here is NOT the same as "area not
      // found" — say so, instead of implying Nominatim doesn't know the
      // place when the real problem was the connection.
      setState(() {
        _searchError =
            (e is NetworkTimeoutException || e is NetworkUnavailableException)
            ? e.toString()
            : 'Search failed. Please try again.';
      });
    }

    if (mounted) setState(() => _isSearching = false);
  }

  // Reports are often submitted using a searched area name (e.g.
  // "Kumasi, Ashanti") rather than a precise GPS pin, so it's genuinely
  // common for two unrelated reports to land on the exact same
  // coordinate. Flutter Map just stacks markers in list order — if two
  // sit on the exact same point, only the topmost one can ever receive
  // a tap, and the one underneath is invisible and unreachable even
  // though it's still there. This groups reports by coordinate and, for
  // any group with more than one, fans them out into a small circle
  // (roughly 15-17 metres wide — imperceptible at normal browsing zoom)
  // so every report gets its own visible, tappable marker. The
  // underlying report.latitude/report.longitude are never changed —
  // only where the marker is drawn shifts, not the actual stored
  // location.
  List<Marker> _buildReportMarkers(List<OutageReport> reports) {
    final Map<String, List<OutageReport>> byLocation = {};
    for (final report in reports) {
      final key =
          '${report.latitude.toStringAsFixed(5)},${report.longitude.toStringAsFixed(5)}';
      byLocation.putIfAbsent(key, () => []).add(report);
    }

    const offsetDegrees = 0.00015; // ~15-17 metres at the equator
    final markers = <Marker>[];

    for (final group in byLocation.values) {
      if (group.length == 1) {
        final report = group.first;
        markers.add(_reportMarker(report, report.latitude, report.longitude));
        continue;
      }
      for (var i = 0; i < group.length; i++) {
        final report = group[i];
        final angle = (2 * math.pi * i) / group.length;
        final lat = report.latitude + offsetDegrees * math.cos(angle);
        final lng = report.longitude + offsetDegrees * math.sin(angle);
        markers.add(_reportMarker(report, lat, lng));
      }
    }
    return markers;
  }

  Marker _reportMarker(OutageReport report, double lat, double lng) {
    return Marker(
      point: LatLng(lat, lng),
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
      appBar: AppBar(
        title: const Text('Outage Map'),
        backgroundColor: Colors.deepPurple,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<OutageReport>>(
        stream: _reportsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            if (_reportsTookTooLong) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.wifi_off_rounded,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'This is taking longer than expected',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Please check your data balance or connection, '
                        'then try again.',
                        style: TextStyle(color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _retryReportsStream,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Retry'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            return const Center(child: CircularProgressIndicator());
          }
          _reportsHangTimer?.cancel();
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
                  MarkerLayer(markers: _buildReportMarkers(mappableReports)),
                  // The searched-for location, drawn as its own layer so
                  // it's unmistakably "what you searched" rather than an
                  // outage report — deep purple isn't used by any status
                  // colour, and it's bigger with a white outline so it
                  // stands out even sitting right next to report pins.
                  if (_searchedLocation != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _searchedLocation!,
                          width: 50,
                          height: 50,
                          child: GestureDetector(
                            onTap: () => setState(
                              () =>
                                  _showLocationInfoBar = !_showLocationInfoBar,
                            ),
                            child: const Icon(
                              Icons.location_pin,
                              color: Colors.deepPurple,
                              size: 50,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),

              // FIXED SEARCH BAR
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: Column(
                  children: [
                    // Tap the purple search-result pin to toggle this —
                    // a quick way to see the exact area name without
                    // having to remember what you typed or re-open the
                    // search box.
                    if (_showLocationInfoBar && _searchedLocationName != null)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
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
                        child: Row(
                          children: [
                            const Icon(
                              Icons.location_pin,
                              color: Colors.deepPurple,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _searchedLocationName!,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            GestureDetector(
                              onTap: () =>
                                  setState(() => _showLocationInfoBar = false),
                              child: Icon(
                                Icons.close,
                                size: 18,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
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
                        onChanged: _onSearchChanged,
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
                    if (_showSuggestions)
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        constraints: const BoxConstraints(maxHeight: 220),
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
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: _suggestions.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = _suggestions[index];
                            return ListTile(
                              dense: true,
                              leading: const Icon(
                                Icons.location_on_outlined,
                                color: Colors.deepPurple,
                              ),
                              title: Text(
                                item['display_name'] ?? 'Unknown area',
                                style: const TextStyle(fontSize: 13.5),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () => _selectSuggestion(item),
                            );
                          },
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
            ],
          );
        },
      ),
    );
  }
}
