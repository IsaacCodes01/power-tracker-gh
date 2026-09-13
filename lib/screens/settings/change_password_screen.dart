import 'package:flutter/material.dart';
import 'dart:async';
import '../../services/auth_service.dart';
import '../../services/connectivity_service.dart';
import '../../utils/network_guard.dart';
import '../../widgets/app_snackbar.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _authService = AuthService();
  final _connectivityService = ConnectivityService();
  bool _isSending = false;
  bool _sent = false;

  bool _showConnectionMessage = false;
  Timer? _waitMessageTimer;

  void _startWaitMessageTimer() {
    _waitMessageTimer?.cancel();
    _showConnectionMessage = false;
    _waitMessageTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showConnectionMessage = true);
    });
  }

  void _resetWaitMessage() {
    _waitMessageTimer?.cancel();
    _showConnectionMessage = false;
  }

  @override
  void dispose() {
    _waitMessageTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleSendLink() async {
    final email = _authService.currentUser?.email;
    if (email == null) return;

    final hasConnection = await _connectivityService.hasConnection();
    if (!hasConnection) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: 'No internet connection. Please check your network.',
        type: AppMessageType.error,
      );
      return;
    }

    setState(() => _isSending = true);
    _startWaitMessageTimer();

    final hasRealAccess = await _connectivityService.hasRealInternetAccess();
    if (!hasRealAccess) {
      if (mounted) {
        _resetWaitMessage();
        setState(() => _isSending = false);
        AppSnackbar.show(
          context,
          message: const NetworkUnavailableException().toString(),
          type: AppMessageType.error,
        );
      }
      return;
    }

    try {
      await _authService.resetPassword(email);
      setState(() => _sent = true);
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message:
            (e is NetworkTimeoutException || e is NetworkUnavailableException)
            ? e.toString()
            : 'Failed to send link: $e',
        type: AppMessageType.error,
      );
    } finally {
      _resetWaitMessage();
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = _authService.currentUser?.email ?? '';

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Change Password'),
        backgroundColor: Colors.deepPurple,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_sent) ...[
              const Icon(Icons.check_circle, color: Colors.green, size: 48),
              const SizedBox(height: 16),
              Text(
                'A password reset link was sent to $email. Follow the link to set a new password.',
                style: const TextStyle(fontSize: 15),
              ),
            ] else ...[
              Text(
                'We\'ll send a password reset link to $email.',
                style: const TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSending ? null : _handleSendLink,
                  child: _isSending
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Send Link'),
                ),
              ),
              if (_isSending)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Center(
                    child: Text(
                      _showConnectionMessage
                          ? 'Please wait, checking your connection…'
                          : 'Please wait…',
                      style: TextStyle(
                        color: Colors.deepPurple.withValues(alpha: 0.7),
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
