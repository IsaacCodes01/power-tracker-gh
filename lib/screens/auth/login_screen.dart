import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../../services/auth_service.dart';
import 'signup_screen.dart';
import 'forgot_password_screen.dart';
import 'verify_email_gate_screen.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/link_google_account_dialog.dart';
import '../../services/connectivity_service.dart';
import '../../utils/network_guard.dart';
import '../main_navigation_screen.dart';

const kDeepPurple = Color(0xFF4A148C);
const kDeepPurpleLight = Color(0xFF7B1FA2);
const kFieldFill = Color(0xFFF6F2FB);
const kBackgroundTop = Color(0xFFF3EAFB);
const kBackgroundBottom = Color(0xFFFFFFFF);

Widget _googleLogo() {
  return Image.asset('assets/google_g.png', width: 22, height: 22);
}

InputDecoration purpleInputDecoration({
  required String label,
  required IconData prefixIcon,
  Widget? suffixIcon,
}) {
  OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: color, width: width),
  );
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: kDeepPurple),
    prefixIcon: Icon(prefixIcon, color: kDeepPurple),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: kFieldFill,
    contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
    border: border(kDeepPurple.withValues(alpha: 0.35), 1.2),
    enabledBorder: border(kDeepPurple.withValues(alpha: 0.35), 1.2),
    focusedBorder: border(kDeepPurple, 2.0),
    errorStyle: const TextStyle(
      color: Colors.redAccent,
      fontSize: 13.0,
      fontWeight: FontWeight.bold,
    ),
    errorBorder: border(Colors.redAccent, 2.0),
    focusedErrorBorder: border(Colors.red, 2.5),
  );
}

ButtonStyle purpleButtonStyle() {
  return ElevatedButton.styleFrom(
    backgroundColor: kDeepPurple,
    foregroundColor: Colors.white,
    disabledBackgroundColor: kDeepPurple.withValues(alpha: 0.5),
    elevation: 4,
    shadowColor: kDeepPurple.withValues(alpha: 0.4),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
  );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  final _connectivityService = ConnectivityService();

  bool _isLoading = false;
  bool _isGoogleLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;

  // Drives the staged "Please wait" -> "Please wait, checking your
  // connection..." caption. Starts false so a fast, healthy request
  // never shows the connection-specific wording at all — only requests
  // that are genuinely still going after a couple seconds escalate to it.
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
    _passwordController.dispose();
    _waitMessageTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    final hasConnection = await _connectivityService.hasConnection();
    if (!hasConnection) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'No internet connection. Please check your network.',
          type: AppMessageType.error,
        );
      }
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    _startWaitMessageTimer();
    // Catches "registered on the network but no data bundle" fast (a few
    // seconds) rather than letting the real sign-in call hang or fail
    // with a confusing generic error later.
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
      final user = await _authService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (user == null) return;

      await user.reload();
      final verified = _authService.currentUser?.emailVerified ?? false;

      if (!mounted) return;

      if (!verified) {
        if (mounted) {
          // Route to the dedicated verification screen (with its own
          // resend button / instructions) instead of just blocking here.
          // User stays signed in so that screen can call
          // sendEmailVerification() and check status without asking for
          // credentials again.
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const VerifyEmailGateScreen()),
            (route) => false,
          );
        }
        return;
      }

      // EMERGENCY FIX: push forward immediately instead of waiting on
      // AppGatekeeper's stream, which was leaving the button stuck on
      // its loading spinner. AppGatekeeper still exists and will simply
      // agree once its stream catches up — this doesn't fight it, it
      // just stops the UI from hanging in the meantime.
      AppSnackbar.show(
        context,
        message: 'Login successful',
        type: AppMessageType.success,
      );
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
        (route) => false,
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      _resetWaitMessage();
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    final hasConnection = await _connectivityService.hasConnection();
    if (!hasConnection) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'No internet connection.',
          type: AppMessageType.error,
        );
      }
      return;
    }
    setState(() {
      _isGoogleLoading = true;
      _errorMessage = null;
    });
    _startWaitMessageTimer();
    // Check BEFORE opening the native Google account picker — this is
    // what was causing the picker to pop up, let the user choose an
    // account, then immediately bail with a confusing native error when
    // data was exhausted. Catching it here means we never open the
    // picker at all in that case, and show a message that actually
    // explains what happened.
    final hasRealAccess = await _connectivityService.hasRealInternetAccess();
    if (!hasRealAccess) {
      if (mounted) {
        _resetWaitMessage();
        setState(() => _isGoogleLoading = false);
        AppSnackbar.show(
          context,
          message: const NetworkUnavailableException().toString(),
          type: AppMessageType.error,
        );
      }
      return;
    }
    try {
      final userCred = await _authService.signInWithGoogle();

      // User cancelled the Google sheet - silent return
      if (userCred == null) {
        if (mounted) setState(() => _isGoogleLoading = false);
        return;
      }

      if (!mounted) return;

      AppSnackbar.show(
        context,
        message: 'Signed in with Google',
        type: AppMessageType.success,
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
        (route) => false,
      );
    } on AccountExistsException catch (e) {
      // This email already has a password-based account. Ask for that
      // password and link the two instead of just failing.
      if (!mounted) return;

      final linked = await showLinkGoogleAccountDialog(
        context,
        email: e.email,
        pendingCredential: e.pendingCredential,
      );

      if (!mounted) return;
      setState(() => _isGoogleLoading = false);

      if (linked != null) {
        AppSnackbar.show(
          context,
          message: 'Google account linked. Signed in.',
          type: AppMessageType.success,
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
          (route) => false,
        );
      }
      // linked == null means they cancelled the dialog — stay on login.
      return;
    } catch (e) {
      if (!mounted) return;

      if (e is NetworkTimeoutException || e is NetworkUnavailableException) {
        AppSnackbar.show(
          context,
          message: e.toString(),
          type: AppMessageType.error,
        );
        setState(() => _isGoogleLoading = false);
        return;
      }

      final msg = e.toString().toLowerCase();
      // Cancelled - show NOTHING
      if (msg.contains('cancel') ||
          msg.contains('closed_by_user') ||
          msg.contains('popup_closed') ||
          msg.contains('12501')) {
        setState(() => _isGoogleLoading = false);
        return;
      }

      // Real error - simple message only
      AppSnackbar.show(
        context,
        message: 'Unable to sign in. Please try again.',
        type: AppMessageType.error,
      );
    } finally {
      _resetWaitMessage();
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [kBackgroundTop, kBackgroundBottom],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [kDeepPurple, kDeepPurpleLight],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: kDeepPurple.withValues(alpha: 0.35),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.bolt_rounded,
                            color: Colors.white,
                            size: 42,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Power Tracker GH',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: kDeepPurple,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sign in to check outages near you',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 36),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: kDeepPurple.withValues(alpha: 0.08),
                              blurRadius: 24,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              inputFormatters: [
                                FilteringTextInputFormatter.deny(RegExp(r'\s')),
                              ],
                              onChanged: (value) {
                                if (value.contains(' ')) {
                                  final clean = value.replaceAll(' ', '');
                                  _emailController.value = _emailController
                                      .value
                                      .copyWith(
                                        text: clean,
                                        selection: TextSelection.collapsed(
                                          offset: clean.length,
                                        ),
                                      );
                                }
                              },
                              autofillHints: const [AutofillHints.email],
                              textInputAction: TextInputAction.next,
                              decoration: purpleInputDecoration(
                                label: 'Email',
                                prefixIcon: Icons.email_outlined,
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter your email';
                                }

                                final emailRegex = RegExp(
                                  r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                                );
                                if (!emailRegex.hasMatch(value.trim())) {
                                  return 'Please enter a valid email address';
                                }

                                return null;
                              },
                            ),
                            const SizedBox(height: 18),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              decoration: purpleInputDecoration(
                                label: 'Password',
                                prefixIcon: Icons.lock_outline,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: kDeepPurple,
                                  ),
                                  onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                ),
                              ),
                              validator: (value) =>
                                  (value == null || value.isEmpty)
                                  ? 'Please enter your password'
                                  : null,
                            ),
                            const SizedBox(height: 4),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: kDeepPurple,
                                ),
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const ForgotPasswordScreen(),
                                  ),
                                ),
                                child: const Text('Forgot password?'),
                              ),
                            ),
                            if (_errorMessage != null)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 4,
                                  bottom: 12,
                                ),
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ),

                            const SizedBox(height: 8),
                            SizedBox(
                              height: 52,
                              child: ElevatedButton(
                                style: purpleButtonStyle(),
                                onPressed: _isLoading || _isGoogleLoading
                                    ? null
                                    : _handleLogin,
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 22,
                                        width: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.4,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                    : const Text('Log In'),
                              ),
                            ),

                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: Divider(
                                    color: kDeepPurple.withValues(alpha: 0.2),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: Text(
                                    'OR',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    color: kDeepPurple.withValues(alpha: 0.2),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // GOOGLE BUTTON
                            SizedBox(
                              height: 52,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: kDeepPurple.withValues(alpha: 0.4),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  backgroundColor: Colors.white,
                                ),
                                onPressed: _isLoading || _isGoogleLoading
                                    ? null
                                    : _handleGoogleSignIn,
                                icon: _isGoogleLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : _googleLogo(),
                                label: Text(
                                  _isGoogleLoading
                                      ? 'Please wait...'
                                      : 'Continue with Google',
                                  style: const TextStyle(
                                    color: kDeepPurple,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),

                            // Small caption under the buttons so it's
                            // obvious the app is still working and not
                            // frozen. Starts plain, and only escalates to
                            // mentioning the connection after ~2s — so a
                            // normal, fast sign-in never flashes wording
                            // that implies something's wrong.
                            if (_isLoading || _isGoogleLoading)
                              Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Center(
                                  child: Text(
                                    _showConnectionMessage
                                        ? 'Please wait, checking your connection…'
                                        : 'Please wait…',
                                    style: TextStyle(
                                      color: kDeepPurple.withValues(alpha: 0.7),
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don't have an account?",
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: kDeepPurple,
                            ),
                            onPressed: () {
                              Navigator.of(context).push(
                                PageRouteBuilder(
                                  transitionDuration: const Duration(
                                    milliseconds: 120,
                                  ),
                                  pageBuilder: (_, _, _) =>
                                      const SignupScreen(),
                                  transitionsBuilder: (_, anim, _, child) =>
                                      FadeTransition(
                                        opacity: anim,
                                        child: child,
                                      ),
                                ),
                              );
                            },
                            child: const Text(
                              'Sign Up',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
