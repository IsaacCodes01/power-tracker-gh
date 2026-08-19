import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';
import '../../services/auth_service.dart';
import '../../models/outage_report.dart';
import 'outage_detail_screen.dart';

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

  String _statusLabel(OutageStatus status) {
    switch (status) {
      case OutageStatus.restored:
        return 'Resolved';
      case OutageStatus.reported:
        return 'Reported';
      case OutageStatus.investigating:
        return 'Investigating';
      case OutageStatus.repairing:
        return 'Fixing';
    }
  }

  String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    return '${diff.inDays} days ago';
  }

  // Applies the currently selected chip AND the search box together.
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
        // Placeholder for now — needs the user's saved area, which we
        // haven't built a way to set yet (that's a future step).
        result = [];
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
        backgroundColor: Colors.grey[100],
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: StreamBuilder<List<OutageReport>>(
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
          final resolvedCount = allReports
              .where((r) => r.status == OutageStatus.restored)
              .length;
          final filteredReports = _applyFilters(allReports);

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // SEARCH BAR
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

                // FILTER CHIPS
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
                      _buildFilterChip(
                        'Your Location',
                        ReportFilter.yourLocation,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // OVERVIEW CARDS
                const Text(
                  'Overview',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
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
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildOverviewCard(
                        title: 'Resolved',
                        value: '$resolvedCount',
                        icon: Icons.bolt,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // FILTERED LIST
                Text(
                  'Reports (${filteredReports.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

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
                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                leading: Icon(
                                  Icons.location_on,
                                  color: Colors.grey[400],
                                ),
                                title: Text(
                                  report.area,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(_timeAgo(report.createdAt)),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _statusColor(
                                      report.status,
                                    ).withAlpha(25),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _statusLabel(report.status),
                                    style: TextStyle(
                                      color: _statusColor(report.status),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          OutageDetailScreen(report: report),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(String label, ReportFilter filter) {
    final isSelected = _selectedFilter == filter;
    final isComingSoon = filter == ReportFilter.yourLocation;

    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (isComingSoon) ...[
            const SizedBox(width: 4),
            const Icon(Icons.lock_clock, size: 14),
          ],
        ],
      ),
      selected: isSelected,
      onSelected: (_) {
        if (isComingSoon) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location filtering is coming soon!'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
        setState(() => _selectedFilter = filter);
      },
      selectedColor: Colors.deepPurple[100],
      backgroundColor: isComingSoon ? Colors.grey[200] : Colors.white,
      labelStyle: TextStyle(
        color: isComingSoon
            ? Colors.grey
            : (isSelected ? Colors.deepPurple : Colors.black87),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(20),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
