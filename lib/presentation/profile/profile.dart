import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_pfe/presentation/ressourses/colormanager.dart';
import 'package:flutter_pfe/presentation/ressourses/routesmanager.dart';

class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  final _supabase = Supabase.instance.client;
  String? _firstName;
  String? _lastName;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  Future<void> _fetchUserProfile() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        final response =
            await _supabase.from('profiles').select().eq('id', userId).single();

        setState(() {
          _firstName = response['first_name'];
          _lastName = response['last_name'];
          _isLoading = false;
        });
      }
    } catch (error) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error fetching profile data')),
        );
      }
    }
  }

  Future<void> _signOut() async {
    try {
      await _supabase.auth.signOut();
      if (mounted) {
        Navigator.pushReplacementNamed(context, Routes.loginRoutes);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Error signing out')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: AppColor.primary,
        foregroundColor: AppColor.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircleAvatar(radius: 50, child: Icon(Icons.person, size: 50)),
            const SizedBox(height: 20),
            if (_isLoading)
              const CircularProgressIndicator()
            else ...[
              Text(
                '${_firstName ?? ''} ${_lastName ?? ''}',
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(height: 10),
              Text(
                _supabase.auth.currentUser?.email ?? 'User',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: _signOut,
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColor.primary,
                foregroundColor: AppColor.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
