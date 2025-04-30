import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../ressourses/colormanager.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../presentation/login/view/login.dart';
import 'edit_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccountSettings extends StatefulWidget {
  const AccountSettings({super.key});

  @override
  State<AccountSettings> createState() => _AccountSettingsState();
}

class _AccountSettingsState extends State<AccountSettings> {
  final _supabase = Supabase.instance.client;
  String _userEmail = '';
  String _userInitials = '';
  String _firstName = '';
  String _lastName = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        // Get user data from profiles table
        final response =
            await _supabase
                .from('profiles')
                .select()
                .eq('id', user.id)
                .single();

        setState(() {
          _userEmail = user.email ?? '';
          _firstName = response['first_name'] ?? '';
          _lastName = response['last_name'] ?? '';
          _userInitials = _getInitials(_firstName, _lastName);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading user data: $e')));
      }
    }
  }

  String _getInitials(String firstName, String lastName) {
    if (firstName.isNotEmpty && lastName.isNotEmpty) {
      return '${firstName[0]}${lastName[0]}'.toUpperCase();
    } else if (firstName.isNotEmpty) {
      return firstName[0].toUpperCase();
    } else if (lastName.isNotEmpty) {
      return lastName[0].toUpperCase();
    }
    return _userEmail.isNotEmpty ? _userEmail[0].toUpperCase() : '';
  }

  Future<void> _signOut() async {
    try {
      // Show confirmation dialog
      final shouldSignOut = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Text(
                'Sign Out',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              content: Text(
                'Are you sure you want to sign out?',
                style: GoogleFonts.poppins(fontSize: 16),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.poppins(
                      color: Colors.black,
                      fontSize: 16,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(
                    'Sign Out',
                    style: GoogleFonts.poppins(
                      color: Colors.red,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
      );

      if (shouldSignOut != true) return;

      // Clear stored project
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('selected_project_id');

      await _supabase.auth.signOut();
      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const Login()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error signing out: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Account Settings',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Profile Section
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EditProfile(),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.only(right: 16, top: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: AppColor.grey,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            _userInitials,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.person_outline,
                                  size: 20,
                                  color: Color(0xFF666666),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '$_firstName $_lastName',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      color: Colors.black,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(
                                  Icons.email_outlined,
                                  size: 20,
                                  color: Color(0xFF666666),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _userEmail,
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: const Color(0xFF666666),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Settings Options
              Text(
                'Preferences',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFF666666),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              _buildSettingItem(
                icon: Icons.download,
                title: 'Storage',
                onTap: () {},
              ),
              const Divider(height: 1, color: Color(0xFFEEEEEE)),
              _buildSettingItem(
                icon: Icons.help_outline,
                title: 'Help Center',
                onTap: () {},
              ),
              const Divider(height: 1, color: Color(0xFFEEEEEE)),
              _buildSettingItem(
                icon: Icons.support_agent,
                title: 'Customer Support',
                onTap: () {},
              ),
              const SizedBox(height: 24),

              Text(
                'Other',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFF666666),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              _buildSettingItem(
                icon: Icons.info_outline,
                title: 'About Us',
                onTap: () {},
              ),
              const Divider(height: 1, color: Color(0xFFEEEEEE)),
              _buildSettingItem(
                icon: Icons.new_releases_outlined,
                title: "What's New",
                onTap: () {},
              ),
              const Divider(height: 1, color: Color(0xFFEEEEEE)),
              _buildSettingItem(
                icon: Icons.find_replace_outlined,
                title: 'Discover Finalcad',
                onTap: () {},
              ),
              const SizedBox(height: 24),

              Text(
                'New Features',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFF666666),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              _buildSettingItem(
                icon: Icons.view_comfortable,
                title: 'Vote for new features',
                onTap: () {},
              ),
              const SizedBox(height: 24),

              Text(
                'Account',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFF666666),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              _buildSettingItem(
                icon: Icons.logout,
                title: 'Sign Out',
                onTap: _signOut,
                isSignOut: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isSignOut = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Row(
          children: [
            Container(
              width: 40,
              decoration: BoxDecoration(
                color: AppColor.secondprimary,
                shape: BoxShape.circle,
              ),
              height: 40,
              child: Icon(
                icon,
                color: isSignOut ? Colors.red : AppColor.primary,
                size: 18,
              ),
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: isSignOut ? Colors.red : Colors.black,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            if (!isSignOut)
              const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Color(0xFF999999),
              ),
          ],
        ),
      ),
    );
  }
}
