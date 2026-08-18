import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../models/outage_report.dart';
import '../auth/login_screen.dart';


final firestoreService = FirestoreService();

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

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

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
          // Still waiting on the first batch of data.
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Something went wrong talking to Firestore.
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final reports = snapshot.data ?? [];

          // No reports exist yet.
          if (reports.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No outages reported yet.\nTap the + button to report one.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            );
          }

          // We have data — show it as a scrollable list.
          return ListView.builder(
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
                  trailing: Text('${report.confirmedByUserIds.length} 👥'),
                ),
              );
            },
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