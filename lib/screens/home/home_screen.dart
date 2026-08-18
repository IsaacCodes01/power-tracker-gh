import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../models/outage_report.dart';
import '../auth/login_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Color _statusColor(OutageStatus status) {
    switch (status) {
      case OutageStatus.restored:
        return Colors.green;
      case OutageStatus.reported:
        return Colors.red;
      case OutageStatus.investigating:
      case OutageStatus.repairing:
        return Colors.orange;
    }
  }

  String _statusLabel(OutageStatus status) {
    switch (status) {
      case OutageStatus.restored:
        return 'Power Available';
      case OutageStatus.reported:
        return 'Outage Reported';
      case OutageStatus.investigating:
        return 'Under Investigation';
      case OutageStatus.repairing:
        return 'Repair in Progress';
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final firestoreService = FirestoreService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Power Tracker GH'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () async {
              await authService.signOut();
              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            },
          ),
        ],
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

          final reports = snapshot.data ?? [];
          // Most recent report overall, used to color the summary strip.
          final latestReport = reports.isNotEmpty ? reports.first : null;

          return Column(
            children: [
              // STATUS SUMMARY STRIP
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                color: latestReport != null
                    ? _statusColor(latestReport.status)
                    : Colors.grey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      latestReport != null
                          ? _statusLabel(latestReport.status)
                          : 'No Reports Yet',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (latestReport != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        latestReport.area,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // QUICK ACTION BUTTONS
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // Will open report_outage_screen.dart once built.
                        },
                        icon: const Icon(Icons.report),
                        label: const Text('Report Outage'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // Will open outage_map_screen.dart once built.
                        },
                        icon: const Icon(Icons.map),
                        label: const Text('View Map'),
                      ),
                    ),
                  ],
                ),
              ),

              // COMMUNITY FEED (unchanged from before, just moved into Column)
              Expanded(
                child: reports.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'No outages reported yet.\nTap the + button to report one.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: reports.length,
                        itemBuilder: (context, index) {
                          final report = reports[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _statusColor(report.status),
                              ),
                              title: Text(report.area),
                              subtitle: Text(
                                '${report.status.name} • ${report.severity.name}\n'
                                '${report.description}',
                              ),
                              isThreeLine: true,
                              trailing: Text(
                                '${report.confirmedByUserIds.length} 👥',
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // We'll wire this to the report screen shortly.
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
