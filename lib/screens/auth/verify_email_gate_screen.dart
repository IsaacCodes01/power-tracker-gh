import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_snackbar.dart';
import '../main_navigation_screen.dart';
import 'login_screen.dart' show LoginScreen;
import 'signup_screen.dart'
    show kDeepPurple, kDeepPurpleLight, purpleButtonStyle;

/// Shown by AppGatekeeper whenever a user is signed in but has not yet
/// verified their email. This is the single, stable place that owns the
/// "please verify" dialog — because it only renders once the app has
/// already committed to this branch (AppGatekeeper made that decision
/// based on the current auth state), there's no race with the login
/// screen being torn down mid-check, which is what caused the previous
/// "flashes in and out" bug.
class VerifyEmailGateScreen extends StatefulWidget {
  const VerifyEmailGateScreen({super.key});

  @override
  State<VerifyEmailGateScreen> createState() => _VerifyEmailGateScreenState();
}

class _VerifyEmailGateScreenState extends State<VerifyEmailGateScreen> {
  final _authService = AuthService();
  bool _isSending = false;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    // Show the dialog automatically as soon as this screen appears —
    // this IS the "right after they click sign in" moment now, since
    // AppGatekeeper only reaches this screen once, deliberately.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showVerifyDialog();
    });
  }

  Future<void> _resend() async {
    setState(() => _isSending = true);
    try {
      await _authService.sendEmailVerification();
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: 'Verification email sent.',
        type: AppMessageType.success,
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: e.toString(),
        type: AppMessageType.error,
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _checkVerified() async {
    setState(() => _isChecking = true);
    try {
      final verified = await _authService.reloadAndCheckVerified();
      if (!mounted) return;
      if (verified) {
        // reload() does not re-fire authStateChanges, so AppGatekeeper
        // (an ancestor widget) won't automatically know to re-route just
        // from a rebuild here. Navigate directly instead — simple and
        // reliable, and AppGatekeeper will naturally agree on the next
        // real auth event (e.g. a future app restart) anyway.
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
        );
      } else {
        AppSnackbar.show(
          context,
          message: 'Still not verified — check your inbox and try again.',
          type: AppMessageType.info,
        );
      }
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  // FIXED: previously this only called signOut() and did nothing else,
  // leaving the user stuck on this screen (stale email text, dead
  // buttons) since AppGatekeeper is no longer in the route stack by the
  // time someone reaches this screen — every other screen in the app
  // navigates directly via Navigator instead of relying on its stream.
  Future<void> _handleSignOut() async {
    await _authService.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _showVerifyDialog() async {
    final email = _authService.currentUser?.email ?? '';
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogBuilderContext, setDialogState) {
            return AlertDialog(
              title: const Text('Verify Your Email'),
              content: Text(
                'Please verify your email address ($email) before continuing. '
                'Check your inbox for the verification link we sent.',
              ),
              actions: [
                TextButton(
                  onPressed: _isSending
                      ? null
                      : () async {
                          setDialogState(() {});
                          await _resend();
                          setDialogState(() {});
                        },
                  child: _isSending
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Resend Email'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF3EAFB), Colors.white],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [kDeepPurple, kDeepPurpleLight],
                      ),
                    ),
                    child: const Icon(
                      Icons.mark_email_unread_outlined,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Verify your email to continue',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: kDeepPurple,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _authService.currentUser?.email ?? '',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: purpleButtonStyle(),
                      onPressed: _isChecking ? null : _checkVerified,
                      child: _isChecking
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text("I've verified — Continue"),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _isSending ? null : _resend,
                    child: const Text('Resend verification email'),
                  ),
                  TextButton(
                    onPressed: _handleSignOut,
                    child: Text(
                      'Sign out',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
