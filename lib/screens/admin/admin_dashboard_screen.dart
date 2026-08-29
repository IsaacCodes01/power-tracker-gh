import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';
import '../../models/outage_report.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();

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

          final reports = snapshot.data ?? [];
          final totalReports = reports.length;
          final activeCount = reports
              .where((r) => r.status != OutageStatus.restored)
              .length;
          final resolvedLast24h = reports.where((r) {
            if (r.status != OutageStatus.restored) return false;
            if (r.endTime == null) return false;
            return DateTime.now().difference(r.endTime!).inHours < 24;
          }).length;
          final unverifiedCount = reports.where((r) => !r.verified).length;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Overview',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.4,
                  children: [
                    _statCard(
                      title: 'Total Reports',
                      value: '$totalReports',
                      icon: Icons.list_alt,
                      color: Colors.deepPurple,
                    ),
                    _statCard(
                      title: 'Active Outages',
                      value: '$activeCount',
                      icon: Icons.flash_off,
                      color: Colors.redAccent,
                    ),
                    _statCard(
                      title: 'Past 24H Resolved',
                      value: '$resolvedLast24h',
                      icon: Icons.bolt,
                      color: Colors.green,
                    ),
                    _statCard(
                      title: 'Pending Verification',
                      value: '$unverifiedCount',
                      icon: Icons.verified_outlined,
                      color: Colors.orange,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(20),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withAlpha(30),
            child: Icon(icon, color: color, size: 18),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        ],
      ),
    );
  }
}
