import 'package:flutter/material.dart';
import '../../models/outage_report.dart';

class OutageDetailScreen extends StatelessWidget {
  final OutageReport report;

  const OutageDetailScreen({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(report.area)),
      body: Center(
        child: Text(
          'Full detail screen coming in the next step.\n\nStatus: ${report.status.name}',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
