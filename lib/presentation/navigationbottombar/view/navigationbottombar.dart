import 'package:flutter/material.dart';
import 'package:flutter_pfe/presentation/home/home.dart';
import 'package:flutter_pfe/presentation/meething/meething.dart';
import 'package:flutter_pfe/presentation/pages/oraginisation.dart';
import 'package:flutter_pfe/presentation/problemsmanage/problem.dart';
import 'package:flutter_pfe/presentation/project/account_settings.dart';

import 'package:flutter_pfe/presentation/ressourses/colormanager.dart';
import 'package:flutter_pfe/presentation/usersmange/users.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class NavigationBottomBar extends StatefulWidget {
  final Map<String, dynamic> selectedProject;

  const NavigationBottomBar({super.key, required this.selectedProject});

  @override
  State<NavigationBottomBar> createState() => _NavigationBottomBarState();
}

class _NavigationBottomBarState extends State<NavigationBottomBar> {
  int _selectedIndex = 0;
  bool _isLoading = true;
  bool _hasOrganization = false;
  String _userEmail = '';
  late List<Widget> _pages;

  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    print('Selected Project Data: ${widget.selectedProject}');
    _pages = [
      HomePage(onNavigate: _onItemTapped),
      Users(selectedProject: widget.selectedProject),
      const Problem(),
      const Meething(),
      const AccountSettings(),
    ];
    _getUserEmail();
    _checkUserOrganization();
  }

  Future<void> _getUserEmail() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      setState(() {
        _userEmail = user.email ?? '';
      });
    }
  }

  Future<void> _checkUserOrganization() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const Organisation()),
          );
        }
        return;
      }

      final response =
          await _supabase
              .from('organisations')
              .select()
              .eq('user_id', user.id)
              .maybeSingle();

      if (response == null) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const Organisation()),
          );
        }
      } else {
        setState(() {
          _hasOrganization = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error checking organization: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  bool isWideScreen(BuildContext context) {
    return MediaQuery.of(context).size.width >= 800;
  }

  String _getInitials(String email) {
    List<String> parts = email.split('@');
    if (parts.isNotEmpty) {
      String namePart = parts[0];
      return namePart.length >= 2
          ? namePart.substring(0, 2).toUpperCase()
          : namePart.toUpperCase();
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_hasOrganization) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body:
          isWideScreen(context)
              ? Row(
                children: [
                  Container(
                    width: 90,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: const Border(
                        right: BorderSide(color: Color(0xFFCCCCCC), width: 1),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GNav(
                          gap: 8,
                          backgroundColor: Colors.white,
                          color: AppColor.textmd,
                          activeColor: AppColor.primary,
                          tabBackgroundColor: AppColor.primary.withOpacity(0.1),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 16,
                          ),
                          selectedIndex: _selectedIndex,
                          onTabChange: _onItemTapped,
                          tabs: [
                            GButton(icon: Icons.home, text: 'Home'),
                            GButton(icon: Icons.people, text: 'Users'),
                            GButton(icon: Icons.warning, text: 'Problems'),
                            GButton(
                              icon: Icons.calendar_today,
                              text: 'Meetings',
                            ),
                            GButton(
                              icon: Icons.person,
                              text: 'Profile',
                              leading: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: AppColor.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    _getInitials(_userEmail),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: IndexedStack(
                      index: _selectedIndex,
                      children: _pages,
                    ),
                  ),
                ],
              )
              : IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar:
          isWideScreen(context)
              ? null
              : Container(
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                  border: const Border(
                    top: BorderSide(color: Color(0xFFCCCCCC), width: 1),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10.0,
                    vertical: 10,
                  ),
                  child: GNav(
                    gap: 8,
                    backgroundColor: Colors.white,
                    color: AppColor.textmd,
                    activeColor: AppColor.primary,
                    tabBackgroundColor: AppColor.primary.withOpacity(0.1),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    selectedIndex: _selectedIndex,
                    onTabChange: _onItemTapped,
                    tabs: [
                      GButton(icon: Icons.home, text: 'Home'),
                      GButton(icon: Icons.people, text: 'Users'),
                      GButton(icon: Icons.warning, text: 'Problems'),
                      GButton(icon: Icons.calendar_today, text: 'Meetings'),
                      GButton(
                        icon: Icons.person,
                        text: 'Profile',
                        leading: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: AppColor.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              _getInitials(_userEmail),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
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
}
