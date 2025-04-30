import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../ressourses/colormanager.dart';
import '../ressourses/valuesmanager.dart';
import 'worker_onboarding.dart';

class WorkerDashboard extends StatefulWidget {
  const WorkerDashboard({Key? key}) : super(key: key);

  @override
  State<WorkerDashboard> createState() => _WorkerDashboardState();
}

class _WorkerDashboardState extends State<WorkerDashboard> {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? _userProfile;

  @override
  void initState() {
    super.initState();
    _checkFirstLogin();
  }

  Future<void> _checkFirstLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final hasCompletedOnboarding = prefs.getBool('worker_onboarding_completed') ?? false;
    
    if (!hasCompletedOnboarding) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const WorkerOnboarding()),
        );
        return;
      }
    }
    
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      final response =
          await _supabase.from('profiles').select().eq('id', user.id).single();
      setState(() {
        _userProfile = response;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Worker Dashboard'),
        backgroundColor: AppColor.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _supabase.auth.signOut();
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),
      body:
          _userProfile == null
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                padding: const EdgeInsets.all(AppPadding.p16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome, ${_userProfile!['first_name']} ${_userProfile!['last_name']}',
                      style: const TextStyle(
                        fontSize: AppFontSize.s24,
                        fontWeight: FontWeightManager.bold,
                      ),
                    ),
                    const SizedBox(height: AppMargin.m16),
                    const Text(
                      'Your Role: Worker',
                      style: TextStyle(
                        fontSize: AppFontSize.s16,
                        color: AppColor.grey,
                      ),
                    ),
                    // Add more worker-specific content here
                  ],
                ),
              ),
    );
  }
}
