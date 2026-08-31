import 'package:flutter/material.dart';
import '../models/outage_report.dart';
import '../screens/admin/admin_report_detail_screen.dart';

class AdminReportCard extends StatelessWidget {
  final OutageReport report;

  const AdminReportCard({super.key, required this.report});

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

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200, width: 1.2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AdminReportDetailScreen(report: report),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.location_on, size: 18, color: Colors.grey[500]),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      report.area,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor(report.status).withAlpha(30),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _statusLabel(report.status),
                      style: TextStyle(
                        color: _statusColor(report.status),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    outageTypeIcon(report.outageType),
                    size: 16,
                    color: Colors.deepPurple,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    outageTypeLabel(report.outageType),
                    style: const TextStyle(fontSize: 13),
                  ),
                  const Spacer(),
                  Text(
                    _timeAgo(report.createdAt),
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ],
              ),
              if (report.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  report.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.people_outline, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${report.confirmedByUserIds.length} confirmed',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  if (report.verified) ...[
                    const SizedBox(width: 10),
                    const Icon(Icons.verified, size: 14, color: Colors.green),
                    const SizedBox(width: 3),
                    const Text(
                      'Verified',
                      style: TextStyle(fontSize: 12, color: Colors.green),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
