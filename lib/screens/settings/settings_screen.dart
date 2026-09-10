import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../../models/app_user.dart';
import '../auth/login_screen.dart';
import 'personal_information_screen.dart';
import 'change_password_screen.dart';
import 'notifications_screen.dart';
import 'help_support_screen.dart';
import 'about_screen.dart';
import '../../widgets/reauth_dialog.dart';
import '../../widgets/app_snackbar.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _handleLogout(BuildContext context) async {
    await AuthService().signOut();
    if (!context.mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  // ADDED: initials prefer the full name, falling back to the email like
  // before for accounts that don't have a name saved yet.
  String _initials(AppUser? appUser, String email) {
    final name = appUser?.fullName.trim() ?? '';
    if (name.isNotEmpty) return name[0].toUpperCase();
    if (email.isNotEmpty) return email.substring(0, 1).toUpperCase();
    return '?';
  }

  @override
  Widget build(BuildContext context) {
    final email = AuthService().currentUser?.email ?? 'Unknown user';
    final uid = AuthService().currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.deepPurple,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // UPDATED: wrapped in a StreamBuilder so the name and role-based
          // subtitle stay live if either ever changes.
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: uid == null
                ? null
                : FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .snapshots(),
            builder: (context, snapshot) {
              // Still waiting on the very first snapshot: show a skeleton
              // instead of guessing at a value, so nothing flashes and
              // then gets replaced once the real profile arrives.
              final isLoading =
                  snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData;

              AppUser? appUser;
              if (snapshot.hasData &&
                  snapshot.data != null &&
                  snapshot.data!.exists) {
                appUser = AppUser.fromMap(snapshot.data!.data()!);
              }

              final displayName = (appUser?.fullName.trim().isNotEmpty ?? false)
                  ? appUser!.fullName.trim()
                  : email;
              final subtitle = appUser?.roleLabel ?? 'Power Tracker user';

              if (isLoading) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withAlpha(20),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.grey[200],
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _skeletonBar(width: 140, height: 16),
                            const SizedBox(height: 8),
                            _skeletonBar(width: 180, height: 13),
                            const SizedBox(height: 6),
                            _skeletonBar(width: 90, height: 12),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withAlpha(20),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.deepPurple[100],
                      child: Text(
                        _initials(appUser, email),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          // Only show the email as its own line when the
                          // name is actually known — otherwise displayName
                          // already IS the email, so this would duplicate it.
                          if ((appUser?.fullName.trim().isNotEmpty ??
                              false)) ...[
                            const SizedBox(height: 2),
                            Text(
                              email,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 20),

          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: Column(
              children: [
                _navTile(
                  context,
                  icon: Icons.person_outline,
                  title: 'Personal Information',
                  subtitle: 'Update your email and phone number',
                  destination: const PersonalInformationScreen(),
                ),
                const Divider(height: 1),
                _navTile(
                  context,
                  icon: Icons.lock_outline,
                  title: 'Change Password',
                  subtitle: 'Update your account security',
                  destination: const ChangePasswordScreen(),
                ),
                const Divider(height: 1),
                _navTile(
                  context,
                  icon: Icons.notifications_none,
                  title: 'Notifications',
                  subtitle: 'Control alert preferences',
                  destination: const NotificationsScreen(),
                ),
                const Divider(height: 1),
                // ADDED
                _navTile(
                  context,
                  icon: Icons.help_outline,
                  title: 'Help and Support',
                  subtitle: 'Get answers or contact us',
                  destination: const HelpSupportScreen(),
                ),
                const Divider(height: 1),
                // ADDED
                _navTile(
                  context,
                  icon: Icons.info_outline,
                  title: 'About App',
                  subtitle: 'App version and information',
                  destination: const AboutScreen(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text(
                'Delete Account',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text('Permanently remove your account and data'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () => _confirmDeleteAccount(context),
            ),
          ),
          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _handleLogout(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[400],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'Log Out',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Simple grey placeholder bar used while the profile stream has no
  // data yet, so we're never showing a value that's about to be replaced.
  Widget _skeletonBar({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _navTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget destination,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.deepPurple),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => destination));
      },
    );
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account?'),
        content: const Text(
          'This will permanently delete your account and cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final reauthed = await showReauthDialog(context);
      if (!reauthed || !context.mounted) return;

      try {
        await AuthService().deleteAccount();
        if (!context.mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      } catch (e) {
        if (!context.mounted) return;
        AppSnackbar.show(
          context,
          message: 'Failed to delete account: $e',
          type: AppMessageType.error,
        );
      }
    }
  }
}
