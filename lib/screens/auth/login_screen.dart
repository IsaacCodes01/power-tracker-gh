import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/auth_service.dart';
import 'signup_screen.dart';
import 'forgot_password_screen.dart';
import 'verify_email_gate_screen.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/link_google_account_dialog.dart';
import '../../services/connectivity_service.dart';
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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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
