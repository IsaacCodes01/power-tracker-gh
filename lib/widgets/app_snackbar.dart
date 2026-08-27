import 'package:flutter/material.dart';

enum AppMessageType { success, error, info }

class AppSnackbar {
  static void show(
    BuildContext context, {
    required String message,
    AppMessageType type = AppMessageType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => _SnackbarWidget(
        message: message,
        type: type,
        duration: duration,
        onDismiss: () => entry.remove(),
      ),
    );

    overlay.insert(entry);
  }
}

class _SnackbarWidget extends StatefulWidget {
  final String message;
  final AppMessageType type;
  final Duration duration;
  final VoidCallback onDismiss;

  const _SnackbarWidget({
    required this.message,
    required this.type,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_SnackbarWidget> createState() => _SnackbarWidgetState();
}

class _SnackbarWidgetState extends State<_SnackbarWidget> {
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.duration, _dismiss);
  }

  void _dismiss() {
    if (_dismissed) return;
    _dismissed = true;
    widget.onDismiss();
  }

  Color get _color {
    switch (widget.type) {
      case AppMessageType.success:
        return Colors.green;
      case AppMessageType.error:
        return Colors.redAccent;
      case AppMessageType.info:
        return Colors.deepPurple;
    }
  }

  IconData get _icon {
    switch (widget.type) {
      case AppMessageType.success:
        return Icons.check_circle;
      case AppMessageType.error:
        return Icons.error;
      case AppMessageType.info:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      right: 16,
      left: 16,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border(left: BorderSide(color: _color, width: 4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(30),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(_icon, color: _color, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.message,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              GestureDetector(
                onTap: _dismiss,
                child: const Icon(Icons.close, size: 18, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
