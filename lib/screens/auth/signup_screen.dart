import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for inputFormatters
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import '../../services/auth_service.dart';

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

  // Reusable helper to keep the UI code clean and consistent with Login Screen
  InputDecoration _buildInputDecoration({
    required String label,
    required IconData prefixIcon,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onToggle,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(prefixIcon),
      suffixIcon: isPassword
          ? IconButton(
              icon: Icon(obscureText ? Icons.visibility_off : Icons.visibility),
              onPressed: onToggle,
            )
          : null,
      border: const OutlineInputBorder(),
      // Custom Error Styling from Login Screen
      errorStyle: const TextStyle(
        color: Colors.redAccent,
        fontSize: 13.0,
        fontWeight: FontWeight.bold,
      ),
      errorBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Colors.redAccent, width: 2.0),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Colors.red, width: 2.5),
      ),
    );
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // 1. FIXED: Pre-capture your UI states before the async operations run!
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      // 2. FIXED: Pull the full formatted value out of your country flag selection model
      // (e.g. If Ghana flag is picked and they type 241234567, this evaluates to "+233241234567")
      final fullPhoneNumber = number.phoneNumber?.trim() ?? '';

      await _authService.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        // 3. FIXED: Passes your clean data payload directly down to your updated service!
        phoneNumber: fullPhoneNumber.isNotEmpty ? fullPhoneNumber : '',
      );

      await _authService.signOut();

      // 4. FIXED: Safe execution trail using your clean pre-loaded instances!
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Account created successfully! Please log in.'),
          backgroundColor: Colors.green,
        ),
      );

      navigator.pop();
    } catch (e) {
      String displayError = e.toString();
      if (displayError.contains('NOT_FOUND') ||
          displayError.contains('DEVELOPER_ERROR')) {
        await _authService.signOut();

        // 5. FIXED: Safe custom developer error display handlers
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Account registered! Please log in to your dashboard.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        navigator.pop();
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
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                const SizedBox(height: 20),
                const Text(
                  'Join Power Tracker GH',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Get real-time outage updates for your area',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 32),

                // 1. EMAIL FIELD
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'\s')),
                  ],
                  decoration: _buildInputDecoration(
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
                const SizedBox(height: 16),

                // PHONE WITH COUNTRY DROPDOWN
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  // Fixed syntax
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey), // Fixed syntax
                    borderRadius: BorderRadius.circular(8), // Fixed syntax
                  ),
                  child: InternationalPhoneNumberInput(
                    onInputChanged: (PhoneNumber value) {
                      number = value;
                    },
                    textFieldController: _phoneController,
                    initialValue: number,
                    selectorConfig: const SelectorConfig(
                      selectorType: PhoneInputSelectorType.DROPDOWN,
                      // Fixed syntax
                      setSelectorButtonAsPrefixIcon: true,
                      leadingPadding: 16.0, // Added necessary value
                    ),
                    ignoreBlank: true,
                    // Makes it optional
                    autoValidateMode: AutovalidateMode.onUserInteraction,
                    // Fixed syntax
                    inputDecoration: const InputDecoration(
                      labelText: 'Phone Number (Optional)',
                      border: InputBorder
                          .none, // Hide inner border since Container has one
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 3. PASSWORD FIELD
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  decoration: _buildInputDecoration(
                    label: 'Password',
                    prefixIcon: Icons.lock_outline,
                    isPassword: true,
                    obscureText: _obscurePassword,
                    onToggle: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
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
                const SizedBox(height: 16),

                // 4. CONFIRM PASSWORD FIELD
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  textInputAction: TextInputAction.done,
                  decoration: _buildInputDecoration(
                    label: 'Confirm Password',
                    prefixIcon: Icons.lock_reset_outlined,
                    isPassword: true,
                    obscureText: _obscureConfirmPassword,
                    onToggle: () => setState(
                      () => _obscureConfirmPassword = !_obscureConfirmPassword,
                    ),
                  ),
                  validator: (value) {
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
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
                    onPressed: _isLoading ? null : _handleSignup,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Create Account'),
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Already have an account?'),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Log In'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
