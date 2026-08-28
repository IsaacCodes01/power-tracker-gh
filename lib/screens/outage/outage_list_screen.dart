import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';
import '../../services/auth_service.dart';
import '../../models/outage_report.dart';
import '../../models/app_user.dart';
import '../../widgets/outage_card.dart';
import '../../widgets/notification_bell.dart';
import '../../widgets/app_snackbar.dart';
import 'location_picker_screen.dart';

enum ReportFilter { all, mine, restored, noLight, confirmed, yourLocation }

class OutageListScreen extends StatefulWidget {
  const OutageListScreen({super.key});

  @override
  State<OutageListScreen> createState() => _OutageListScreenState();
}

class _OutageListScreenState extends State<OutageListScreen> {
  final _firestoreService = FirestoreService();
  final _authService = AuthService();
  final _searchController = TextEditingController();

  ReportFilter _selectedFilter = ReportFilter.all;
  String _searchQuery = '';

  AppUser? _userProfile;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    final uid = _authService.currentUser?.uid;
    if (uid != null) {
      final profile = await _firestoreService.getUserProfile(uid);
      if (mounted) setState(() => _userProfile = profile);
    }
  }

  // Called when the "Your Location" chip is tapped.
  Future<void> _handleYourLocationTap() async {
    // If a default location isn't set yet, send them to the picker first.
    if (_userProfile == null || !_userProfile!.hasDefaultLocation) {
      final result = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(builder: (_) => const LocationPickerScreen()),
      );

      if (result == null) return;

      final uid = _authService.currentUser?.uid;
      if (uid == null) return;

      await _firestoreService.saveDefaultLocation(
        uid,
        result['latitude'],
        result['longitude'],
        result['name'],
      );

      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Default location set: ${result['name']}',
          type: AppMessageType.success,
        );
      }

      await _loadUserProfile();
    }

    setState(() => _selectedFilter = ReportFilter.yourLocation);
  }

  List<OutageReport> _applyFilters(List<OutageReport> reports) {
    var result = reports;

    switch (_selectedFilter) {
      case ReportFilter.mine:
        final uid = _authService.currentUser?.uid;
        result = result.where((r) => r.reporterId == uid).toList();
        break;
      case ReportFilter.restored:
        result = result
            .where((r) => r.status == OutageStatus.restored)
            .toList();
        break;
      case ReportFilter.noLight:
        result = result
            .where((r) => r.status != OutageStatus.restored)
            .toList();
        break;
      case ReportFilter.confirmed:
        result = result.where((r) => r.confirmedByUserIds.isNotEmpty).toList();
        break;
      case ReportFilter.yourLocation:
        final defaultName = _userProfile?.defaultLocationName;
        if (defaultName == null || defaultName.isEmpty) {
          result = [];
        } else {
          // Match against just the first segment of the saved name,
          // e.g. "Madina" from "Madina, Accra", same idea as search.
          final keyword = defaultName.split(',').first.trim().toLowerCase();
          result = result
              .where((r) => r.area.toLowerCase().contains(keyword))
              .toList();
        }
        break;
      case ReportFilter.all:
        break;
    }

    if (_searchQuery.isNotEmpty) {
      result = result
          .where(
            (r) => r.area.toLowerCase().contains(_searchQuery.toLowerCase()),
          )
          .toList();
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Outage Reports'),
        backgroundColor: Colors.deepPurple,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: const [NotificationBell()],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search reports by area...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All', ReportFilter.all),
                  const SizedBox(width: 8),
                  _buildFilterChip('Your Reports', ReportFilter.mine),
                  const SizedBox(width: 8),
                  _buildFilterChip('No Light', ReportFilter.noLight),
                  const SizedBox(width: 8),
                  _buildFilterChip('Restored', ReportFilter.restored),
                  const SizedBox(width: 8),
                  _buildFilterChip('Confirmed', ReportFilter.confirmed),
                  const SizedBox(width: 8),
                  _buildFilterChip('Your Location', ReportFilter.yourLocation),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Expanded(
              child: StreamBuilder<List<OutageReport>>(
                stream: _firestoreService.streamReports(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  final allReports = snapshot.data ?? [];
                  final activeCount = allReports
                      .where((r) => r.status != OutageStatus.restored)
                      .length;
                  final resolvedCount = allReports.where((r) {
                    if (r.status != OutageStatus.restored) return false;
                    if (r.endTime == null) return false;
                    final hoursSinceResolved = DateTime.now()
                        .difference(r.endTime!)
                        .inHours;
                    return hoursSinceResolved < 24;
                  }).length;
                  final filteredReports = _applyFilters(allReports);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildOverviewCard(
                              title: 'Active Outages',
                              value: '$activeCount',
                              icon: Icons.flash_off,
                              color: Colors.redAccent,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildOverviewCard(
                              title: 'Past 24H Resolved',
                              value: '$resolvedCount',
                              icon: Icons.bolt,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      Text(
                        'Recent Reports (${filteredReports.length})',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),

                      Expanded(
                        child: filteredReports.isEmpty
                            ? const Center(
                                child: Text(
                                  'No reports found.',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              )
                            : ListView.builder(
                                itemCount: filteredReports.length,
                                itemBuilder: (context, index) {
                                  final report = filteredReports[index];
                                  return OutageCard(report: report);
                                },
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, ReportFilter filter) {
    final isSelected = _selectedFilter == filter;
    final isYourLocation = filter == ReportFilter.yourLocation;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        if (isYourLocation) {
          _handleYourLocationTap();
          return;
        }
        setState(() => _selectedFilter = filter);
      },
      selectedColor: Colors.deepPurple[100],
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.deepPurple : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildOverviewCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(20),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: color.withAlpha(30),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                title,
                style: TextStyle(color: Colors.grey[600], fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
