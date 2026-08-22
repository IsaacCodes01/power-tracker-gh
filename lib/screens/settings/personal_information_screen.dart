import 'package:flutter/material.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';

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
  bool _isLoadingData = true; // Tracks initial database profile load cleanly

  @override
  void initState() {
    super.initState();
    _loadUserProfileData(); // Loads the profile packet once right on boot up
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // FIXED: Asynchronously handles database pulling and country parsing upfront
  Future<void> _loadUserProfileData() async {
    try {
      final currentUid = _authService.currentUser?.uid ?? '';
      final appUser = await _firestoreService.getUserProfile(currentUid);

      if (appUser != null && mounted) {
        _emailController.text = appUser.email;

        if (appUser.phoneNumber.isNotEmpty) {
          // Wait for the international number tool to unpack the country prefix
          final parsedNumber = await PhoneNumber.getRegionInfoFromPhoneNumber(
            appUser.phoneNumber,
          );
          if (mounted) {
            setState(() {
              number = parsedNumber;
              _phoneController.text = appUser.phoneNumber.replaceFirst(
                parsedNumber.dialCode ?? '',
                '',
              );
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Error initializing personal info data tracks: $e");
    } finally {
      if (mounted) {
        setState(
          () => _isLoadingData = false,
        ); // Turns off loading spinner safely
      }
    }
  }

  Future<void> _handleSave(String uid) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final newEmail = _emailController.text.trim();
      final newPhone = number.phoneNumber?.trim() ?? '';

      if (newEmail != _authService.currentUser?.email) {
        await _authService.updateEmail(newEmail);
      }

      await _firestoreService.updateUserProfile(uid, {
        'email': newEmail,
        'phoneNumber': newPhone,
      });

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Personal information updated successfully! ✅'),
          backgroundColor: Colors.green,
        ),
      );
      navigator.pop();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Update failed: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = _authService.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Personal Information'),
        backgroundColor: Colors.grey[100],
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      // FIXED: Swapped out FutureBuilder for a clean, deterministic local state check
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
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Email cannot be left empty';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(8),
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
                                leadingPadding: 16.0,
                              ),
                              ignoreBlank: true,
                              autoValidateMode:
                                  AutovalidateMode.onUserInteraction,
                              inputDecoration: const InputDecoration(
                                labelText: 'Phone Number (Optional)',
                                border: InputBorder.none,
                              ),
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
