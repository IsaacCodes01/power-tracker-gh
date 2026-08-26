import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../services/location_service.dart';
import 'location_search_screen.dart';

enum LocationChoice { current, different }

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final _locationService = LocationService();

  LocationChoice? _selectedChoice;
  bool _isLoadingCurrent = false;
  String? _currentLocationError;

  double? _resultLat;
  double? _resultLon;
  String? _resultName;

  Future<void> _useCurrentLocation() async {
    setState(() {
      _selectedChoice = LocationChoice.current;
      _isLoadingCurrent = true;
      _currentLocationError = null;
    });

    try {
      final position = await _locationService.getCurrentPosition();
      final name = await _locationService.reverseGeocode(
        position.latitude,
        position.longitude,
      );

      setState(() {
        _resultLat = position.latitude;
        _resultLon = position.longitude;
        _resultName = name != null
            ? _locationService.shortenLocationName(name)
            : 'Current location';
      });
    } catch (e) {
      setState(() => _currentLocationError = e.toString());
    } finally {
      if (mounted) setState(() => _isLoadingCurrent = false);
    }
  }

  Future<void> _selectDifferentLocation() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const LocationSearchScreen()),
    );

    if (result != null) {
      setState(() {
        _selectedChoice = LocationChoice.different;
        _resultLat = result['latitude'];
        _resultLon = result['longitude'];
        _resultName = result['name'];
      });
    }
  }

  void _confirmSelection() {
    if (_resultLat == null || _resultLon == null || _resultName == null) {
      return;
    }
    Navigator.pop(context, {
      'name': _resultName,
      'latitude': _resultLat,
      'longitude': _resultLon,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Set Your Location'),
        backgroundColor: Colors.grey[100],
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // MY CURRENT LOCATION OPTION
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _selectedChoice == LocationChoice.current
                      ? Colors.deepPurple
                      : Colors.grey.shade300,
                  width: _selectedChoice == LocationChoice.current ? 1.5 : 1,
                ),
              ),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: _isLoadingCurrent ? null : _useCurrentLocation,
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.deepPurple[50],
                          child: const Icon(
                            Icons.my_location,
                            color: Colors.deepPurple,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'My Current Location',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _selectedChoice == LocationChoice.current &&
                                        _resultName != null
                                    ? _resultName!
                                    : 'Use GPS to detect your location',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        if (_isLoadingCurrent)
                          const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          Icon(
                            _selectedChoice == LocationChoice.current
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: _selectedChoice == LocationChoice.current
                                ? Colors.deepPurple
                                : Colors.grey,
                          ),
                      ],
                    ),
                  ),
                  if (_currentLocationError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _currentLocationError!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),

                  // SMALL MAP PREVIEW — only shows once a real position
                  // has been found for the "current location" choice.
                  if (_selectedChoice == LocationChoice.current &&
                      _resultLat != null &&
                      !_isLoadingCurrent) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        height: 130,
                        child: IgnorePointer(
                          child: FlutterMap(
                            options: MapOptions(
                              initialCenter: LatLng(_resultLat!, _resultLon!),
                              initialZoom: 15,
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName:
                                    'com.isaacotabil.powertrackergh',
                              ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: LatLng(_resultLat!, _resultLon!),
                                    width: 36,
                                    height: 36,
                                    child: const Icon(
                                      Icons.location_pin,
                                      color: Colors.red,
                                      size: 36,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // SELECT A DIFFERENT LOCATION OPTION
            InkWell(
              onTap: _selectDifferentLocation,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _selectedChoice == LocationChoice.different
                        ? Colors.deepPurple
                        : Colors.grey.shade300,
                    width: _selectedChoice == LocationChoice.different
                        ? 1.5
                        : 1,
                  ),
                ),
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.deepPurple[50],
                      child: const Icon(Icons.search, color: Colors.deepPurple),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Select a Different Location',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _selectedChoice == LocationChoice.different &&
                                    _resultName != null
                                ? _resultName!
                                : 'Search for an area',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
              ),
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _resultLat != null ? _confirmSelection : null,
                child: const Text('Use This Location'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
