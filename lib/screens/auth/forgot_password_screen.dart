import 'package:flutter/material.dart';
import 'dart:async';
import '../../services/auth_service.dart';
import '../../services/connectivity_service.dart';
import '../../utils/network_guard.dart';
import '../../widgets/app_snackbar.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _authService = AuthService();
  final _connectivityService = ConnectivityService();

  bool _isLoading = false;
  String? _errorMessage;
  bool _emailSent = false;

  // Same staged "Please wait" -> "Please wait, checking your
  // connection..." pattern used on login/signup.
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
    _emailController.dispose();
    _waitMessageTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleReset() async {
    if (!_formKey.currentState!.validate()) return;

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

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    _startWaitMessageTimer();

    final hasRealAccess = await _connectivityService.hasRealInternetAccess();
    if (!hasRealAccess) {
      if (mounted) {
        _resetWaitMessage();
        setState(() => _isLoading = false);
        AppSnackbar.show(
          context,
          message: const NetworkUnavailableException().toString(),
          type: AppMessageType.error,
        );
      }
      return;
    }

    try {
      await _authService.resetPassword(_emailController.text.trim());
      setState(() => _emailSent = true);
    } catch (e) {
      if (!mounted) return;
      final message =
          (e is NetworkTimeoutException || e is NetworkUnavailableException)
          ? e.toString()
          : 'Failed to send link: $e';
      AppSnackbar.show(context, message: message, type: AppMessageType.error);
      setState(() => _errorMessage = e.toString());
    } finally {
      _resetWaitMessage();
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                const SizedBox(height: 20),
                if (_emailSent) ...[
                  const Icon(Icons.check_circle, color: Colors.green, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'Check your email for a link to reset your password.',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Back to Login'),
                  ),
                ] else ...[
                  const Text(
                    'Enter your email and we\'ll send you a link to reset your password.',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!value.contains('@')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleReset,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Send Reset Link'),
                    ),
                  ),
                  if (_isLoading)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Center(
                        child: Text(
                          _showConnectionMessage
                              ? 'Please wait, checking your connection…'
                              : 'Please wait…',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
