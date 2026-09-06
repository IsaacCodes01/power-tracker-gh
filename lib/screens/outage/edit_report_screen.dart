import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';
import '../../models/outage_report.dart';
import '../../widgets/app_snackbar.dart';
import 'location_picker_screen.dart';

class EditReportScreen extends StatefulWidget {
  final OutageReport report;

  const EditReportScreen({super.key, required this.report});

  @override
  State<EditReportScreen> createState() => _EditReportScreenState();
}

class _EditReportScreenState extends State<EditReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firestoreService = FirestoreService();
  late final TextEditingController _descriptionController;

  late String _areaName;
  late double _latitude;
  late double _longitude;
  late OutageType _selectedOutageType;
  late OutageSeverity _selectedSeverity;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _areaName = widget.report.area;
    _latitude = widget.report.latitude;
    _longitude = widget.report.longitude;
    _selectedOutageType = widget.report.outageType;
    _selectedSeverity = widget.report.severity;
    _descriptionController = TextEditingController(
      text: widget.report.description,
    );
  }

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
        _areaName = result['name'];
        _latitude = result['latitude'];
        _longitude = result['longitude'];
      });
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      await _firestoreService.updateReport(widget.report.id, {
        'area': _areaName,
        'latitude': _latitude,
        'longitude': _longitude,
        'outageType': _selectedOutageType.name,
        'severity': _selectedSeverity.name,
        'description': _descriptionController.text.trim(),
      });

      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Report updated successfully',
          type: AppMessageType.success,
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Failed to update report: $e',
          type: AppMessageType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Edit Report'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
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
                  child: Text(_areaName),
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
                onSelectionChanged: (s) =>
                    setState(() => _selectedSeverity = s.first),
              ),
              const SizedBox(height: 20),

              const Text(
                'Outage Type',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<OutageType>(
                initialValue: _selectedOutageType,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: OutageType.values
                    .map(
                      (t) => DropdownMenuItem(
                        value: t,
                        child: Text(outageTypeLabel(t)),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedOutageType = v);
                },
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Please add a description'
                    : null,
              ),
              const SizedBox(height: 28),

              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _handleSave,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save Changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
