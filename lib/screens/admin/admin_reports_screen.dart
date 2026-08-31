import 'package:flutter/material.dart';
import '../../models/outage_report.dart';
import '../../widgets/admin_report_card.dart';
import '../../services/firestore_service.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

IconData outageTypeIcon(OutageType type) {
  switch (type) {
    case OutageType.powerOutage:
      return Icons.power_off;
    case OutageType.flickeringLights:
      return Icons.lightbulb_outline;
    case OutageType.voltageFluctuation:
      return Icons.bolt;
    case OutageType.poleFault:
      return Icons.report_problem_outlined;
  }
}

Color outageTypeColor(OutageType type) {
  switch (type) {
    case OutageType.powerOutage:
      return Colors.redAccent;
    case OutageType.flickeringLights:
      return Colors.amber[800]!;
    case OutageType.voltageFluctuation:
      return Colors.blue;
    case OutageType.poleFault:
      return Colors.deepOrange;
  }
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  OutageType? _selectedType; // null means "All"
  late final Stream<List<OutageReport>> _reportsStream;

  @override
  void initState() {
    super.initState();
    _reportsStream = FirestoreService().streamReports();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: StreamBuilder<List<OutageReport>>(
        stream: _reportsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final reports = snapshot.data ?? [];

          final filtered = _selectedType == null
              ? reports
              : reports.where((r) => r.outageType == _selectedType).toList();

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Overview',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                _buildOverview(reports),
                const SizedBox(height: 16),

                SingleChildScrollView(
                  key: const PageStorageKey('admin_type_filter_chips'),
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _filterChip('All', null, reports),
                      const SizedBox(width: 8),
                      ...OutageType.values.map(
                        (type) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _filterChip(
                            outageTypeLabel(type),
                            type,
                            reports,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                Expanded(
                  child: filtered.isEmpty
                      ? const Center(child: Text('No reports found.'))
                      : ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            return AdminReportCard(report: filtered[index]);
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

  Widget _buildOverview(List<OutageReport> reports) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.2,
      children: [
        _overviewTile(
          'Total Reports',
          '${reports.length}',
          Icons.list_alt,
          Colors.deepPurple,
        ),
        ...OutageType.values.map((type) {
          final count = reports.where((r) => r.outageType == type).length;
          return _overviewTile(
            outageTypeLabel(type),
            '$count',
            outageTypeIcon(type),
            outageTypeColor(type),
          );
        }),
      ],
    );
  }

  Widget _overviewTile(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(20),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: color.withAlpha(30),
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(color: Colors.grey[600], fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(
    String label,
    OutageType? type,
    List<OutageReport> reports,
  ) {
    final isSelected = _selectedType == type;

    // Count of NOT-resolved reports matching this filter.
    final count = reports.where((r) {
      final matchesType = type == null || r.outageType == type;
      return matchesType && r.status != OutageStatus.restored;
    }).length;

    return ChoiceChip(
      label: Text('$label ($count)'),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedType = type),
      selectedColor: Colors.deepPurple[100],
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.deepPurple : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}
