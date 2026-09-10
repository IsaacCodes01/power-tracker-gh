import 'package:flutter/material.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../widgets/reauth_dialog.dart';
import '../../widgets/app_snackbar.dart';

class PersonalInformationScreen extends StatefulWidget {
  const PersonalInformationScreen({super.key});

  @override
  State<PersonalInformationScreen> createState() =>
      _PersonalInformationScreenState();
}

class _PersonalInformationScreenState extends State<PersonalInformationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  PhoneNumber number = PhoneNumber(isoCode: 'GH');

  final _authService = AuthService();
  final _firestoreService = FirestoreService();

  bool _isSaving = false;
  bool _isLoadingData = true;
  bool _showPhonePicker = false; // FIX: lazy load picker

  @override
  void initState() {
    super.initState();
    _loadUserProfileData();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfileData() async {
    try {
      final currentUid = _authService.currentUser?.uid ?? '';
      final appUser = await _firestoreService.getUserProfile(currentUid);

      if (appUser != null && mounted) {
        _emailController.text = appUser.email;

        if (appUser.phoneNumber.isNotEmpty) {
          // FAST GHANA-ONLY PARSE: no world lookup
          String phone = appUser.phoneNumber;
          // remove +233 if present
          if (phone.startsWith('+233')) {
            phone = phone.replaceFirst('+233', '');
          } else if (phone.startsWith('233')) {
            phone = phone.replaceFirst('233', '');
          }
          // ensure it starts with 0
          if (!phone.startsWith('0')) {
            phone = '0$phone';
          }

          setState(() {
            number = PhoneNumber(
              isoCode: 'GH',
              dialCode: '+233',
              phoneNumber: '+233${phone.substring(1)}',
            );
            _phoneController.text = phone;
          });
        }
      }
    } catch (e) {
      debugPrint("Error initializing personal info: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoadingData = false);
        // Load picker AFTER data + after frame = instant screen
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) setState(() => _showPhonePicker = true);
          });
        });
      }
    }
  }

  Future<void> _handleSave(String uid) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final navigator = Navigator.of(context);
    try {
      final newEmail = _emailController.text.trim();
      final newPhone = number.phoneNumber?.trim() ?? '';

      final confirmed = await showReauthDialog(context);
      if (!confirmed) {
        setState(() => _isSaving = false);
        return;
      }
      if (newEmail != _authService.currentUser?.email) {
        await _authService.updateEmail(newEmail);
      }
      await _firestoreService.updateUserProfile(uid, {
        'email': newEmail,
        'phoneNumber': newPhone,
      });
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Personal information updated successfully!',
          type: AppMessageType.success,
        );
      }
      navigator.pop();
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Update failed: $e',
          type: AppMessageType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = _authService.currentUser?.uid ?? '';
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Personal Information'),
        backgroundColor: Colors.deepPurple,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Profile Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email Address',
                              prefixIcon: Icon(Icons.email_outlined),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) =>
                                (value == null || value.trim().isEmpty)
                                ? 'Email cannot be left empty'
                                : null,
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            height: 62,
                            child: _showPhonePicker
                                ? InternationalPhoneNumberInput(
                                    countries: const ['GH'],
                                    // GHANA ONLY - super fast
                                    onInputChanged: (PhoneNumber value) {
                                      number = value;
                                    },
                                    textFieldController: _phoneController,
                                    initialValue: number,
                                    selectorConfig: const SelectorConfig(
                                      selectorType:
                                          PhoneInputSelectorType.DROPDOWN,
                                      setSelectorButtonAsPrefixIcon: true,
                                      leadingPadding: 16.0,
                                    ),
                                    ignoreBlank: true,
                                    autoValidateMode:
                                        AutovalidateMode.onUserInteraction,
                                    inputDecoration: const InputDecoration(
                                      labelText: 'Phone Number (Optional)',
                                      border: InputBorder.none,
                                    ),
                                  )
                                : const Row(
                                    children: [
                                      SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Text('Loading phone field...'),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving
                            ? null
                            : () => _handleSave(currentUid),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Save Changes',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
