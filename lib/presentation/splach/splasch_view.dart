import 'package:flutter/material.dart';
import 'package:flutter_pfe/presentation/login/view/login.dart';
import 'package:flutter_pfe/presentation/navigationbottombar/view/navigationbottombar.dart';
import 'package:flutter_pfe/presentation/pages/oraginisation.dart';
import 'package:flutter_pfe/presentation/project/project.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../ressourses/colormanager.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    try {
      developer.log('Checking authentication status...');

      // Wait for 2 seconds to show the splash screen
      await Future.delayed(const Duration(seconds: 2));

      final user = _supabase.auth.currentUser;
      if (user == null) {
        developer.log('No user found, navigating to login');
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const Login()),
        );
        return;
      }

      // Check for stored project
      final prefs = await SharedPreferences.getInstance();
      final storedProjectId = prefs.getString('selected_project_id');

      if (storedProjectId != null) {
        developer.log('Found stored project ID: $storedProjectId');
        try {
          // Get project details
          final projectResponse =
              await _supabase
                  .from('projects')
                  .select()
                  .eq('id', int.parse(storedProjectId))
                  .single();

          if (projectResponse != null) {
            developer.log('Project found, navigating to project page');
            if (!mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder:
                    (_) =>
                        NavigationBottomBar(selectedProject: projectResponse),
              ),
            );
            return;
          }
        } catch (e) {
          developer.log('Error loading stored project: $e');
          // If there's an error loading the stored project, clear it and continue
          await prefs.remove('selected_project_id');
        }
      }

      developer.log('User found, checking organization...');
      final orgResponse =
          await _supabase
              .from('organisations')
              .select()
              .eq('user_id', user.id)
              .maybeSingle();

      if (orgResponse == null) {
        developer.log(
          'No organization found, navigating to organization creation',
        );
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const Organisation()),
        );
      } else {
        developer.log('Organization found, navigating to project page');
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const Project()),
        );
      }
    } catch (e, stackTrace) {
      developer.log(
        'Error in splash screen: $e',
        error: e,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/logo.jpg',
              width: 200,
              height: 200,
              errorBuilder: (context, error, stackTrace) {
                developer.log(
                  'Error loading logo: $error',
                  error: error,
                  stackTrace: stackTrace,
                );
                return const Icon(
                  Icons.error,
                  size: 100,
                  color: AppColor.primary,
                );
              },
            ),
            const SizedBox(height: 20),
            if (_isLoading)
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColor.primary),
              ),
            if (_errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      _errorMessage,
                      style: GoogleFonts.poppins(
                        color: Colors.red,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _isLoading = true;
                          _errorMessage = '';
                        });
                        _checkAuthAndNavigate();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColor.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Retry',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
