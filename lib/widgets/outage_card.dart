import 'package:flutter/material.dart';
import '../models/outage_report.dart';
import '../services/firestore_service.dart';
import '../screens/outage/outage_detail_screen.dart';
import '../screens/map/outage_map_screen.dart';

class OutageCard extends StatelessWidget {
  final OutageReport report;

  const OutageCard({super.key, required this.report});

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

  @override
  Widget build(BuildContext context) {
    final confirmedCount = report.confirmedByUserIds.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, size: 18, color: Colors.red[500]),
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
                Text(
                  _timeAgo(report.createdAt),
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.bolt, size: 16, color: Colors.deepPurple),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Outage Type: ${outageTypeLabel(report.outageType)}',
                    style: const TextStyle(fontSize: 13),
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
            if (report.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 16,
                    color: Colors.black,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      report.description,
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),

            // HOUSEHOLDS AFFECTED + VERIFIED-BY AVATARS, same row.
            // The count always comes directly from the report data,
            // so it's accurate even if the avatar lookup below fails.
            Row(
              children: [
                Icon(Icons.people_outline, size: 16, color: Colors.pink[600]),
                const SizedBox(width: 6),
                Text(
                  '$confirmedCount household${confirmedCount == 1 ? '' : 's'} affected',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
                const Spacer(),
                if (confirmedCount > 0)
                  FutureBuilder<List<String>>(
                    future: FirestoreService().getUserInitials(
                      report.confirmedByUserIds,
                    ),
                    builder: (context, snapshot) {
                      final initials = snapshot.data;
                      // While loading, or if the lookup fails/returns
                      // nothing, still show the correct number of
                      // generic avatar bubbles rather than none at all.
                      final count = confirmedCount;
                      return SizedBox(
                        height: 26,
                        width: count * 16.0 + 14,
                        child: Stack(
                          children: List.generate(count, (i) {
                            final label =
                                (initials != null && i < initials.length)
                                ? initials[i]
                                : '?';
                            return Positioned(
                              left: i * 16.0,
                              child: CircleAvatar(
                                radius: 13,
                                backgroundColor: Colors.deepPurple[200],
                                child: Text(
                                  label,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      );
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // ACTION BUTTONS
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OutageMapScreen(
                            focusLatitude: report.latitude,
                            focusLongitude: report.longitude,
                          ),
                        ),
                      );
                    },
                    child: const Text(
                      'View on map',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OutageDetailScreen(report: report),
                        ),
                      );
                    },
                    child: const Text(
                      'Confirm Outage',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
