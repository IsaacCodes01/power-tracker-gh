import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../models/outage_report.dart';
import 'location_picker_screen.dart';
import '../main_navigation_screen.dart';
import '../../widgets/app_snackbar.dart';

class ReportOutageScreen extends StatefulWidget {
  const ReportOutageScreen({super.key});

  @override
  State<ReportOutageScreen> createState() => _ReportOutageScreenState();
}

class _ReportOutageScreenState extends State<ReportOutageScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();

  final _authService = AuthService();
  final _firestoreService = FirestoreService();

  String? _selectedAreaName;
  double? _selectedLatitude;
  double? _selectedLongitude;

  OutageType _selectedOutageType = OutageType.powerOutage;
  TimeOfDay _selectedTime = TimeOfDay.now();
  OutageSeverity _selectedSeverity = OutageSeverity.minor;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const LocationPickerScreen()),
    );

    if (result != null) {
      setState(() {
        _selectedAreaName = result['name'];
        _selectedLatitude = result['latitude'];
        _selectedLongitude = result['longitude'];
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedAreaName == null ||
        _selectedLatitude == null ||
        _selectedLongitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a location first')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final currentUser = _authService.currentUser;

    final newReport = OutageReport(
      id: '',
      reporterId: currentUser?.uid ?? '',
      area: _selectedAreaName!,
      confirmedByUserIds: currentUser != null ? [currentUser.uid] : [],
      latitude: _selectedLatitude!,
      longitude: _selectedLongitude!,
      startTime: DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
        _selectedTime.hour,
        _selectedTime.minute,
      ),
      status: OutageStatus.reported,
      severity: _selectedSeverity,
      outageType: _selectedOutageType,
      description: _descriptionController.text.trim(),
      createdAt: DateTime.now(),
    );

    try {
      await _firestoreService.createReport(newReport);
      if (!mounted) return;

      AppSnackbar.show(
        context,
        message: 'Report created successfully',
        type: AppMessageType.success,
      );

      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
          (route) => false,
        );
      }
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
      appBar: AppBar(
        title: const Text('Report an Outage'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                InkWell(
                  onTap: _pickLocation,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Area / Location',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.chevron_right),
                    ),
                    child: Text(
                      _selectedAreaName ?? 'Tap to select a location',
                      style: TextStyle(
                        color: _selectedAreaName != null
                            ? Colors.black87
                            : Colors.grey[500],
                      ),
                    ),
                  ),
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

                const Text(
                  'Outage Type',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<OutageType>(
                  initialValue: _selectedOutageType,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  items: OutageType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(outageTypeLabel(type)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedOutageType = value);
                    }
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
                const SizedBox(height: 20),

                const Text(
                  'Outage Time',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _pickTime,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[400]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time, size: 18),
                        const SizedBox(width: 10),
                        Text(_selectedTime.format(context)),
                      ],
                    ),
                  ),
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
