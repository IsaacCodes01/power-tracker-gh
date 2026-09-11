import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/location_service.dart';
import '../../services/connectivity_service.dart';
import '../../widgets/app_snackbar.dart';

class LocationSearchScreen extends StatefulWidget {
  const LocationSearchScreen({super.key});

  @override
  State<LocationSearchScreen> createState() => _LocationSearchScreenState();
}

class _LocationSearchScreenState extends State<LocationSearchScreen> {
  final _searchController = TextEditingController();
  List<dynamic> _results = [];
  bool _isSearching = false;

  // Waits for a pause in typing before actually calling Nominatim,
  // instead of firing one request per keystroke — Nominatim's free API
  // is limited to ~1 request/second and can silently rate-limit or drop
  // requests that come in faster than that, which looked like "this
  // area just isn't found" even though it genuinely exists.
  Timer? _debounce;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  final _connectivityService = ConnectivityService();

  void _onChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 3) {
      setState(() {
        _results = [];
        _isSearching = false;
      });
      return;
    }
    // Show the spinner immediately, not just once the network call
    // starts — there's a real 300ms gap before the debounced request
    // actually fires, and leaving that silent feels laggier than it is.
    setState(() => _isSearching = true);
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _search(query);
    });
  }

  Future<void> _search(String query) async {
    if (query.trim().length < 3) {
      setState(() => _results = []);
      return;
    }

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

    setState(() => _isSearching = true);

    final encoded = Uri.encodeComponent('$query, Ghana');
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search?q=$encoded&format=json&limit=8',
    );

    try {
      final response = await http
          .get(url, headers: {'User-Agent': 'PowerTrackerGH/1.0'})
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        setState(() => _results = jsonDecode(response.body));
      }
    } catch (e) {
      // Silently keep an empty list — no need for a scary error
      // just because one search attempt failed to load.
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Search Different Location'),
        backgroundColor: Colors.deepPurple,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: _onChanged,
              decoration: InputDecoration(
                hintText: 'Search for an area...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _results.isEmpty
                  ? Center(
                      child: Text(
                        _searchController.text.length < 3
                            ? 'Type at least 3 letters to search'
                            : 'No matches found',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _results.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = _results[index];
                        return ListTile(
                          leading: const Icon(
                            Icons.location_on_outlined,
                            color: Colors.grey,
                          ),
                          title: Text(
                            item['display_name'] ?? 'Unknown area',
                            style: const TextStyle(fontSize: 14),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () {
                            final locationService = LocationService();
                            Navigator.pop(context, {
                              'name': locationService.shortenLocationName(
                                item['display_name'],
                              ),
                              'latitude': double.parse(item['lat']),
                              'longitude': double.parse(item['lon']),
                            });
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
