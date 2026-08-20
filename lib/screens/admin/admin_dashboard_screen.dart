import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';
import '../../models/outage_report.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _firestoreService = FirestoreService();

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

  Future<void> _confirmDelete(OutageReport report) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Report?'),
        content: Text(
          'This will permanently delete the report for "${report.area}". This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _firestoreService.deleteReport(report.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Report deleted')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
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

          final reports = snapshot.data ?? [];

          if (reports.isEmpty) {
            return const Center(child: Text('No reports to manage.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final report = reports[index];

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              report.area,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
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
                      const SizedBox(height: 6),
                      Text(
                        report.description,
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Confirmed by ${report.confirmedByUserIds.length} user(s)',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          // VERIFY TOGGLE
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: report.verified
                                  ? null
                                  : () async {
                                      await _firestoreService.verifyReport(
                                        report.id,
                                      );
                                    },
                              icon: Icon(
                                report.verified
                                    ? Icons.verified
                                    : Icons.check_circle_outline,
                                color: report.verified
                                    ? Colors.green
                                    : Colors.grey,
                              ),
                              label: Text(
                                report.verified ? 'Verified' : 'Verify',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // DELETE
                          IconButton(
                            onPressed: () => _confirmDelete(report),
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                            tooltip: 'Delete report',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
