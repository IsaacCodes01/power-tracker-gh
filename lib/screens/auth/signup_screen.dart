import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_snackbar.dart';
import '../../services/connectivity_service.dart';
import '../../utils/network_guard.dart';

const kDeepPurple = Color(0xFF4A148C);
const kDeepPurpleLight = Color(0xFF7B1FA2);
const kFieldFill = Color(0xFFF6F2FB);
const kBackgroundTop = Color(0xFFF3EAFB);
const kBackgroundBottom = Color(0xFFFFFFFF);

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

// Same shape/shadow/elevation as purpleButtonStyle(), but uses
// Colors.deepPurple — the exact color every AppBar in the app already
// uses — instead of kDeepPurple (a different, darker shade only meant
// for the Login button specifically). Used everywhere else so buttons
// visually match the app's own header color.
ButtonStyle appBarButtonStyle() {
  return ElevatedButton.styleFrom(
    backgroundColor: Colors.deepPurple,
    foregroundColor: Colors.white,
    disabledBackgroundColor: Colors.deepPurple.withValues(alpha: 0.5),
    elevation: 4,
    shadowColor: Colors.deepPurple.withValues(alpha: 0.4),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
  );
}

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();
  final _connectivityService = ConnectivityService();

  PhoneNumber number = PhoneNumber(isoCode: 'GH');
  bool _showPhonePicker = false;
  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Same staged "Please wait" -> "Please wait, checking your
  // connection..." pattern as the login screen — plain wording for a
  // normal-speed request, only escalates after a couple seconds if
  // something's genuinely taking a while.
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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 80), () {
        if (mounted) setState(() => _showPhonePicker = true);
      });
    });
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _waitMessageTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleSignup() async {
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
    // Same fast "out of data bundle" check as login — catches it in a
    // few seconds instead of letting account creation hang or fail with
    // a generic error later.
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
      final fullPhoneNumber = number.phoneNumber?.trim() ?? '';
      await _authService.signUp(
        fullName: _fullNameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        phoneNumber: fullPhoneNumber.isNotEmpty ? fullPhoneNumber : '',
      );
      await _authService.signOut();
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: 'Account created! Check your email to verify, then log in.',
        type: AppMessageType.success,
      );
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      String displayError = e.toString();
      if (displayError.contains('NOT_FOUND') ||
          displayError.contains('DEVELOPER_ERROR')) {
        await _authService.signOut();
        if (!mounted) return;
        AppSnackbar.show(
          context,
          message: 'Account registered! Please log in.',
          type: AppMessageType.info,
        );
        await Future.delayed(const Duration(milliseconds: 800));
        if (!mounted) return;
        Navigator.of(context).pop();
        return;
      }
      if (mounted) setState(() => _errorMessage = displayError);
    } finally {
      _resetWaitMessage();
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Create Account'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: kDeepPurple,
      ),
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
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
                          width: 72,
                          height: 72,
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
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.person_add_alt_1_rounded,
                            color: Colors.white,
                            size: 34,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Join Power Tracker GH',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: kDeepPurple,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Get real-time outage updates for your area',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 28),
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
                              controller: _fullNameController,
                              keyboardType: TextInputType.name,
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.next,
                              decoration: purpleInputDecoration(
                                label: 'Full Name',
                                prefixIcon: Icons.badge_outlined,
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Please enter your full name';
                                }

                                if (v.trim().split(' ').length < 2) {
                                  return 'Please enter your first and last name';
                                }

                                return null;
                              },
                            ),
                            const SizedBox(height: 18),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              inputFormatters: [
                                FilteringTextInputFormatter.deny(RegExp(r'\s')),
                              ],
                              decoration: purpleInputDecoration(
                                label: 'Email',
                                prefixIcon: Icons.email_outlined,
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Please enter your email';
                                }

                                if (!v.contains('@')) {
                                  return 'Please enter a valid email';
                                }

                                return null;
                              },
                            ),
                            const SizedBox(height: 18),
                            Container(
                              decoration: BoxDecoration(
                                color: kFieldFill,
                                border: Border.all(
                                  color: kDeepPurple.withValues(alpha: 0.35),
                                  width: 1.2,
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              height: 62,
                              child: _showPhonePicker
                                  ? Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      child: InternationalPhoneNumberInput(
                                        countries: const ['GH'],
                                        // GHANA ONLY - FAST
                                        onInputChanged: (PhoneNumber value) {
                                          number = value;
                                        },
                                        textFieldController: _phoneController,
                                        initialValue: number,
                                        selectorConfig: const SelectorConfig(
                                          selectorType:
                                              PhoneInputSelectorType.DROPDOWN,
                                          setSelectorButtonAsPrefixIcon: true,
                                          leadingPadding: 12.0,
                                        ),
                                        ignoreBlank: true,
                                        autoValidateMode:
                                            AutovalidateMode.onUserInteraction,
                                        selectorTextStyle: const TextStyle(
                                          color: kDeepPurple,
                                        ),
                                        inputDecoration: const InputDecoration(
                                          labelText: 'Phone Number (Optional)',
                                          labelStyle: TextStyle(
                                            color: kDeepPurple,
                                          ),
                                          border: InputBorder.none,
                                          contentPadding: EdgeInsets.symmetric(
                                            vertical: 18,
                                          ),
                                        ),
                                      ),
                                    )
                                  : Row(
                                      children: [
                                        const SizedBox(width: 12),
                                        SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: kDeepPurple.withValues(
                                              alpha: 0.6,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          'Loading phone field...',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                            const SizedBox(height: 18),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.next,
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
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'Please enter a password';
                                }

                                if (v.length < 6) {
                                  return 'Password must be at least 6 characters';
                                }

                                return null;
                              },
                            ),
                            const SizedBox(height: 18),
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: _obscureConfirmPassword,
                              textInputAction: TextInputAction.done,
                              decoration: purpleInputDecoration(
                                label: 'Confirm Password',
                                prefixIcon: Icons.lock_reset_outlined,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirmPassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: kDeepPurple,
                                  ),
                                  onPressed: () => setState(
                                    () => _obscureConfirmPassword =
                                        !_obscureConfirmPassword,
                                  ),
                                ),
                              ),
                              validator: (v) => v != _passwordController.text
                                  ? 'Passwords do not match'
                                  : null,
                            ),
                            const SizedBox(height: 8),
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
                                onPressed: _isLoading ? null : _handleSignup,
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
                                    : const Text('Create Account'),
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
                                      color: kDeepPurple.withValues(alpha: 0.7),
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Already have an account?',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: kDeepPurple,
                            ),
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              'Log In',
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
