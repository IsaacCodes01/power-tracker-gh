import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../models/outage_report.dart';

class ReportOutageScreen extends StatefulWidget {
  const ReportOutageScreen({super.key});

  @override
  State<ReportOutageScreen> createState() => _ReportOutageScreenState();
}

class _ReportOutageScreenState extends State<ReportOutageScreen> {
  final _formKey = GlobalKey<FormState>();
  final _areaController = TextEditingController();
  final _descriptionController = TextEditingController();

  final _authService = AuthService();
  final _firestoreService = FirestoreService();

  OutageSeverity _selectedSeverity = OutageSeverity.minor;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _areaController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final currentUser = _authService.currentUser;

    final newReport = OutageReport(
      id: '',
      // Firestore assigns this automatically, so left blank here.
      reporterId: currentUser?.uid ?? '',
      area: _areaController.text.trim(),
      latitude: 0.0,
      // Placeholder until the map/location picker is built.
      longitude: 0.0,
      startTime: DateTime.now(),
      status: OutageStatus.reported,
      severity: _selectedSeverity,
      description: _descriptionController.text.trim(),
      createdAt: DateTime.now(),
    );

    try {
      await _firestoreService.createReport(newReport);
      if (!mounted) return;

      // Success — close this screen and return to Home,
      // where the new report will now appear in the live feed.
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to submit report: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report an Outage')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                TextFormField(
                  controller: _areaController,
                  decoration: const InputDecoration(
                    labelText: 'Area / Location',
                    hintText: 'e.g. Madina, Accra',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter the affected area';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                const Text(
                  'Severity',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SegmentedButton<OutageSeverity>(
                  segments: const [
                    ButtonSegment(
                      value: OutageSeverity.minor,
                      label: Text('Minor'),
                    ),
                    ButtonSegment(
                      value: OutageSeverity.moderate,
                      label: Text('Moderate'),
                    ),
                    ButtonSegment(
                      value: OutageSeverity.major,
                      label: Text('Major'),
                    ),
                  ],
                  selected: {_selectedSeverity},
                  onSelectionChanged: (newSelection) {
                    setState(() => _selectedSeverity = newSelection.first);
                  },
                ),
                const SizedBox(height: 20),

                TextFormField(
                  controller: _descriptionController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'What happened? When did it start?',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please add a short description';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 28),

                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _handleSubmit,
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Submit Report'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
