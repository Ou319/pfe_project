import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../ressourses/colormanager.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../presentation/login/view/login.dart';

class EditProfile extends StatefulWidget {
  const EditProfile({super.key});

  @override
  State<EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends State<EditProfile> {
  final _supabase = Supabase.instance.client;
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  String _userEmail = '';
  String _userInitials = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final response =
            await _supabase
                .from('profiles')
                .select()
                .eq('id', user.id)
                .single();

        String firstName = response['first_name'] ?? '';
        String lastName = response['last_name'] ?? '';

        // If no names exist, create default ones from email
        if (firstName.isEmpty && lastName.isEmpty) {
          final emailParts = user.email?.split('@')[0].split('.') ?? [];
          firstName = emailParts.isNotEmpty ? emailParts[0] : 'User';
          lastName = emailParts.length > 1 ? emailParts[1] : 'Name';

          // Update the profile with default names
          await _supabase
              .from('profiles')
              .update({'first_name': firstName, 'last_name': lastName})
              .eq('id', user.id);
        }

        setState(() {
          _userEmail = user.email ?? '';
          _firstNameController.text = firstName;
          _lastNameController.text = lastName;
          _userInitials = _getInitials(firstName, lastName);
          _isLoading = false;
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

  Future<void> _updateProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        await _supabase
            .from('profiles')
            .update({
              'first_name': _firstNameController.text,
              'last_name': _lastNameController.text,
            })
            .eq('id', user.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully')),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating profile: $e')));
      }
    }
  }

  Future<void> _deleteAccount() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        // Show confirmation dialog
        final shouldDelete = await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Text(
                  'Delete Account',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                content: Text(
                  'Are you sure you want to delete your account? This action cannot be undone.',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: const Color(0xFF666666),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.poppins(
                        color: AppColor.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(
                      'Delete',
                      style: GoogleFonts.poppins(
                        color: Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
        );

        if (shouldDelete == true) {
          // Delete user data from profiles table
          await _supabase.from('profiles').delete().eq('id', user.id);

          // Sign out and delete account
          await _supabase.auth.signOut();

          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const Login()),
              (route) => false,
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting account: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Edit Profile',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Profile Picture Section
                      Center(
                        child: Column(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
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
                                    fontSize: 24,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _userEmail,
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: const Color(0xFF666666),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Edit Form
                      Text(
                        'Personal Information',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _firstNameController,
                        label: 'First Name',
                        hint: 'Enter your first name',
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _lastNameController,
                        label: 'Last Name',
                        hint: 'Enter your last name',
                      ),
                      const SizedBox(height: 32),

                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _updateProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColor.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            'Save Changes',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Delete Account Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _deleteAccount,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.red,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(color: AppColor.primary),
                            ),
                          ),
                          child: Text(
                            'Delete Account',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: const Color(0xFF666666),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.poppins(
              color: const Color(0xFF999999),
              fontSize: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColor.primary),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          style: GoogleFonts.poppins(fontSize: 14, color: Colors.black),
        ),
      ],
    );
  }
}
