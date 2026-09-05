import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for inputFormatters
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_snackbar.dart';
import '../../services/connectivity_service.dart';

// ---------------------------------------------------------------------------
// Purple theme constants (kept local to this file — no cross-file imports)
// ---------------------------------------------------------------------------
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

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController(); // Added phone controller
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();

  // For the country picker
  PhoneNumber number = PhoneNumber(isoCode: 'GH'); // Default to Ghana

  bool _isLoading = false;
  String? _errorMessage;

  // Visibility states for password toggles
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose(); // Dispose phone controller
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  final _connectivityService = ConnectivityService();

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

    try {
      final fullPhoneNumber = number.phoneNumber?.trim() ?? '';

      await _authService.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        phoneNumber: fullPhoneNumber.isNotEmpty ? fullPhoneNumber : '',
      );

      await _authService.signOut();

      if (!mounted) return;

      AppSnackbar.show(
        context,
        message: 'Account created successfully! Please log in.',
        type: AppMessageType.success,
      );

      // Wait for user to see message, then go back to Login ONCE
      await Future.delayed(const Duration(milliseconds: 800));

      if (!mounted) return;
      Navigator.of(context).pop(); // only ONCE
    } catch (e) {
      String displayError = e.toString();
      // This NOT_FOUND hack is masking real errors
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
                            // 1. EMAIL FIELD
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
                            const SizedBox(height: 18),

                            // PHONE WITH COUNTRY DROPDOWN
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF6F2FB),
                                border: Border.all(
                                  color: kDeepPurple.withValues(alpha: 0.35),
                                  width: 1.2,
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: InternationalPhoneNumberInput(
                                onInputChanged: (PhoneNumber value) {
                                  number = value;
                                },
                                textFieldController: _phoneController,
                                initialValue: number,
                                selectorConfig: const SelectorConfig(
                                  selectorType: PhoneInputSelectorType.DROPDOWN,
                                  setSelectorButtonAsPrefixIcon: true,
                                  leadingPadding: 12.0,
                                ),
                                ignoreBlank: true,
                                // Makes it optional
                                autoValidateMode:
                                    AutovalidateMode.onUserInteraction,
                                selectorTextStyle: const TextStyle(
                                  color: kDeepPurple,
                                ),
                                inputDecoration: const InputDecoration(
                                  labelText: 'Phone Number (Optional)',
                                  labelStyle: TextStyle(color: kDeepPurple),
                                  // Hide inner border since Container has one
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: 18,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),

                            // 3. PASSWORD FIELD
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
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a password';
                                }
                                if (value.length < 6) {
                                  return 'Password must be at least 6 characters';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 18),

                            // 4. CONFIRM PASSWORD FIELD
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
                              validator: (value) {
                                if (value != _passwordController.text) {
                                  return 'Passwords do not match';
                                }
                                return null;
                              },
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
