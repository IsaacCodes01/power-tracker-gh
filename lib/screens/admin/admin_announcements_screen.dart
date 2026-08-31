import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';
import '../../widgets/app_snackbar.dart';

class AdminAnnouncementsScreen extends StatefulWidget {
  const AdminAnnouncementsScreen({super.key});

  @override
  State<AdminAnnouncementsScreen> createState() =>
      _AdminAnnouncementsScreenState();
}

class _AdminAnnouncementsScreenState extends State<AdminAnnouncementsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  final _additionalAreasController = TextEditingController();

  bool _sendToAll = true;
  bool _isSending = false;
  bool _isLoadingAreas = true;

  List<String> _availableAreas = [];
  final Set<String> _selectedAreas = {};

  final _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _loadAreas();
  }

  Future<void> _loadAreas() async {
    final areas = await _firestoreService.getDistinctAreas();
    if (mounted) {
      setState(() {
        _availableAreas = areas;
        _isLoadingAreas = false;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _additionalAreasController.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    if (!_formKey.currentState!.validate()) return;

    final typedAreas = _additionalAreasController.text
        .split(',')
        .map((a) => a.trim())
        .where((a) => a.isNotEmpty)
        .toSet();

    final allTargetAreas = {..._selectedAreas, ...typedAreas};

    if (!_sendToAll && allTargetAreas.isEmpty) {
      AppSnackbar.show(
        context,
        message:
            'Select at least one area, add one manually, or choose "Send to all users".',
        type: AppMessageType.error,
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      final title = _titleController.text.trim();
      final message = _messageController.text.trim();

      List<String> targetUserIds;

      if (_sendToAll) {
        targetUserIds = await _firestoreService.getAllUserIds();
      } else {
        final allReports = await _firestoreService.streamReports().first;
        final idSet = <String>{};

        for (final report in allReports) {
          final matchesAnyArea = allTargetAreas.any(
            (area) => report.area.toLowerCase().contains(area.toLowerCase()),
          );
          if (matchesAnyArea) {
            idSet.add(report.reporterId);
            idSet.addAll(report.confirmedByUserIds);
          }
        }
        targetUserIds = idSet.toList();
      }

      if (targetUserIds.isEmpty) {
        if (mounted) {
          AppSnackbar.show(
            context,
            message: 'No matching users found for this announcement.',
            type: AppMessageType.error,
          );
        }
        return;
      }

      for (final uid in targetUserIds) {
        await _firestoreService.createNotification(
          userId: uid,
          title: title,
          message: message,
        );
      }

      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Announcement sent to ${targetUserIds.length} user(s).',
          type: AppMessageType.success,
        );
        _titleController.clear();
        _messageController.clear();
        _additionalAreasController.clear();
        setState(() => _selectedAreas.clear());
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Failed to send announcement: $e',
          type: AppMessageType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const Text(
                'Post an official update, such as scheduled maintenance or a general notice.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'e.g. Scheduled Maintenance',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Please enter a title'
                    : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _messageController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  hintText:
                      'e.g. Power will be off in these areas from 6-8pm today.',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Please enter a message'
                    : null,
              ),
              const SizedBox(height: 20),

              const Text(
                'Audience',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              RadioGroup<bool>(
                groupValue: _sendToAll,
                onChanged: (value) => setState(() => _sendToAll = value!),
                child: Column(
                  children: [
                    RadioListTile<bool>(
                      value: true,
                      activeColor: Colors.deepPurple[900],
                      title: Text('Send to all users'),
                    ),
                    RadioListTile<bool>(
                      value: false,
                      activeColor: Colors.deepPurple[900],
                      title: Text('Send to specific area(s)'),
                    ),
                  ],
                ),
              ),

              if (!_sendToAll) ...[
                const SizedBox(height: 8),
                const Text(
                  'Select known areas',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 8),
                if (_isLoadingAreas)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_availableAreas.isEmpty)
                  Text(
                    'No areas found yet.',
                    style: TextStyle(color: Colors.grey[500]),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _availableAreas.map((area) {
                      final isSelected = _selectedAreas.contains(area);
                      return FilterChip(
                        label: Text(area),
                        selected: isSelected,
                        selectedColor: Colors.deepPurple[100],
                        backgroundColor: Colors.white,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedAreas.add(area);
                            } else {
                              _selectedAreas.remove(area);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _additionalAreasController,
                  decoration: const InputDecoration(
                    labelText: 'Add other areas (comma separated)',
                    hintText: 'e.g. Tema, Adenta',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
              ],

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSending ? null : _handleSend,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple[900],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _isSending
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Send Announcement'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
