import 'package:flutter/material.dart';
import 'package:flutter_pfe/presentation/navigationbottombar/view/navigationbottombar.dart';
import 'package:flutter_pfe/presentation/pages/oraginisation.dart';
import 'package:flutter_pfe/presentation/project/project.dart';
import 'package:flutter_pfe/presentation/ressourses/assetsmanager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_pfe/presentation/worker_dashboard/worker_projects_page.dart';
import 'package:flutter_pfe/presentation/worker_dashboard/worker_onboarding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../ressourses/colormanager.dart';
import '../../ressourses/valuesmanager.dart';
import '../../ressourses/stringmanager.dart';

// Extension to capitalize first letter of string
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isFormValid = false;

  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_validateForm);
    _passwordController.addListener(_validateForm);
  }

  void _validateForm() {
    final isEmailNotEmpty = _emailController.text.trim().isNotEmpty;
    final isPasswordNotEmpty = _passwordController.text.trim().isNotEmpty;
    final isValid = isEmailNotEmpty && isPasswordNotEmpty;

    if (_isFormValid != isValid) {
      setState(() {
        _isFormValid = isValid;
      });
    }
  }

  Future<void> _signIn() async {
    try {
      setState(() => _isLoading = true);

      final response = await _supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (response.user != null) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Login successful")));

          // Validate and add user to profiles table if needed
          await _validateAndAddUserProfile(response.user!);

          // Check user role and profile completeness
          final profileResponse =
              await _supabase
                  .from('profiles')
                  .select()
                  .eq('id', response.user!.id)
                  .single();

          if (!mounted) return;

          // Check if profile is complete
          if (profileResponse['first_name'] == null || 
              profileResponse['first_name'].toString().isEmpty ||
              profileResponse['last_name'] == null || 
              profileResponse['last_name'].toString().isEmpty) {
            // Show profile completion form
            await _showProfileCompletionForm(profileResponse);
            return;
          }

          // Navigate based on user role
          if (profileResponse['is_admin'] == true) {
            // Admin user - go to Project page
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const Project()),
            );
          } else {
            // Worker user - check if they need onboarding
            final prefs = await SharedPreferences.getInstance();
            final hasCompletedOnboarding = prefs.getBool('worker_onboarding_completed') ?? false;
            
            if (!hasCompletedOnboarding) {
              // Show onboarding for first-time worker login
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const WorkerOnboarding()),
              );
            } else {
              // Worker has completed onboarding - go to Worker Projects page
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => const WorkerProjectsPage(selectedProject: {}),
              ),
            );
            }
          }
        }
      }
    } on AuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An unexpected error occurred: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showProfileCompletionForm(Map<String, dynamic> profile) async {
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Complete Your Profile'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: firstNameController,
                decoration: const InputDecoration(
                  labelText: 'First Name',
                  hintText: 'Enter your first name',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your first name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: lastNameController,
                decoration: const InputDecoration(
                  labelText: 'Last Name',
                  hintText: 'Enter your last name',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your last name';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                try {
                  await _supabase
                      .from('profiles')
                      .update({
                        'first_name': firstNameController.text.trim(),
                        'last_name': lastNameController.text.trim(),
                      })
                      .eq('id', profile['id']);

                  if (mounted) {
                    Navigator.pop(context);
                    // Navigate based on role after profile completion
                    if (profile['is_admin'] == true) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const Project()),
                      );
                    } else {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const WorkerProjectsPage(selectedProject: {}),
                        ),
                      );
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error updating profile: $e')),
                    );
                  }
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // Function to validate and add user to profiles table
  Future<void> _validateAndAddUserProfile(User user) async {
    try {
      print('Checking profile for user: ${user.id}');

      // Check if user exists in profiles table
      final profileResponse =
          await _supabase
              .from('profiles')
              .select()
              .eq('id', user.id)
              .maybeSingle();

      print('Profile response: $profileResponse');

      // If user doesn't exist in profiles table or has no name
      if (profileResponse == null || 
          profileResponse['first_name'] == null || 
          profileResponse['first_name'].toString().isEmpty ||
          profileResponse['last_name'] == null || 
          profileResponse['last_name'].toString().isEmpty) {
        
        print('No profile found or incomplete profile, creating/updating profile...');

        // Show profile completion form
        final firstNameController = TextEditingController();
        final lastNameController = TextEditingController();
        final formKey = GlobalKey<FormState>();

        // If existing profile, pre-fill the form
        if (profileResponse != null) {
          firstNameController.text = profileResponse['first_name'] ?? '';
          lastNameController.text = profileResponse['last_name'] ?? '';
        }

        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Complete Your Profile'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: firstNameController,
                    decoration: const InputDecoration(
                      labelText: 'First Name',
                      hintText: 'Enter your first name',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your first name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: lastNameController,
                    decoration: const InputDecoration(
                      labelText: 'Last Name',
                      hintText: 'Enter your last name',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your last name';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    try {
                      final profileData = {
                        'id': user.id,
                        'first_name': firstNameController.text.trim(),
                        'last_name': lastNameController.text.trim(),
                        'mission': 'Member',
                        'is_admin': false,
                      };

                      if (profileResponse == null) {
                        // Insert new profile
                        profileData['created_at'] = DateTime.now().toIso8601String();
                        await _supabase.from('profiles').insert(profileData);
                      } else {
                        // Update existing profile
                        await _supabase
                            .from('profiles')
                            .update(profileData)
                            .eq('id', user.id);
                      }

                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Profile updated successfully')),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error updating profile: $e')),
                        );
                      }
                    }
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
        );
      } else {
        print('Profile already exists and is complete');
      }
    } catch (e, stackTrace) {
      print('Error handling profile: $e');
      print('Stack trace: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error handling profile: $e')));
      }
    }
  }

  @override
  void dispose() {
    _emailController.removeListener(_validateForm);
    _passwordController.removeListener(_validateForm);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppPadding.p24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(AppImg.logo, width: 200, height: 200),
                const Text(
                  AppStrings.welcomeBack,
                  style: TextStyle(
                    fontSize: AppFontsize.s28,
                    fontWeight: FontWhightmanager.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: AppMargine.m8),
                const Text(
                  AppStrings.signInToContinue,
                  style: TextStyle(
                    fontSize: AppFontsize.s16,
                    color: AppColor.grey,
                  ),
                ),
                const SizedBox(height: AppMargine.m34),

                // Email Input
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    hintText: AppStrings.email,
                    prefixIcon: const Icon(
                      Icons.email_outlined,
                      color: Colors.black,
                    ),
                    filled: true,
                    fillColor: Colors.transparent,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: AppPadding.p16,
                      horizontal: AppPadding.p16,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.black),
                      borderRadius: BorderRadius.circular(Appsize.a10),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(
                        color: Colors.black,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(Appsize.a10),
                    ),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.black),
                ),
                const SizedBox(height: AppMargine.m20),

                // Password Input
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: AppStrings.password,
                    prefixIcon: const Icon(
                      Icons.lock_outline,
                      color: Colors.black,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.black,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    filled: true,
                    fillColor: Colors.transparent,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: AppPadding.p16,
                      horizontal: AppPadding.p16,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.black),
                      borderRadius: BorderRadius.circular(Appsize.a10),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(
                        color: Colors.black,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(Appsize.a10),
                    ),
                  ),
                  style: const TextStyle(color: Colors.black),
                ),
                const SizedBox(height: AppMargine.m24),

                // Login Button
                SizedBox(
                  width: double.infinity,
                  height: Appsize.a48,
                  child: ElevatedButton(
                    onPressed: (_isLoading || !_isFormValid) ? null : _signIn,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Appsize.a10),
                      ),
                      elevation: 2,
                    ),
                    child:
                        _isLoading
                            ? const CircularProgressIndicator(
                              color: Colors.white,
                            )
                            : const Text(
                              AppStrings.login,
                              style: TextStyle(
                                fontSize: AppFontsize.s16,
                                fontWeight: FontWhightmanager.bold,
                              ),
                            ),
                  ),
                ),
                const SizedBox(height: AppMargine.m20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
