import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';
import '../../services/auth_service.dart';
import '../../models/outage_report.dart';

class AdminDashboardScreen extends StatelessWidget {
  final VoidCallback onNavigateToReports;

  const AdminDashboardScreen({super.key, required this.onNavigateToReports});

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();
    final email = AuthService().currentUser?.email ?? 'Admin';

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
                  'Welcome back',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
                Text(
                  email,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),

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
                      onTap: onNavigateToReports,
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
                      onTap: onNavigateToReports,
                    ),
                    StreamBuilder<int>(
                      stream: firestoreService.streamUserCount(),
                      builder: (context, userSnapshot) {
                        return _statCard(
                          title: 'Total Users',
                          value: '${userSnapshot.data ?? '—'}',
                          icon: Icons.people_outline,
                          color: Colors.blue,
                        );
                      },
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
    VoidCallback? onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: color.withAlpha(30),
                  child: Icon(icon, color: color, size: 18),
                ),
                if (onTap != null)
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 12,
                    color: Colors.grey[400],
                  ),
              ],
            ),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              title,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
