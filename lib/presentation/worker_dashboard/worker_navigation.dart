import 'package:flutter/material.dart';
import 'package:flutter_pfe/presentation/ressourses/colormanager.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'worker_problems_page.dart';
import 'worker_meetings_page.dart';
import 'worker_problems_to_solve_page.dart';
import 'package:flutter_pfe/presentation/worker_dashboard/worker_projects_page.dart';

class WorkerNavigationBar extends StatefulWidget {
  final Map<String, dynamic> selectedProject;

  const WorkerNavigationBar({super.key, required this.selectedProject});

  @override
  State<WorkerNavigationBar> createState() => _WorkerNavigationBarState();
}

class _WorkerNavigationBarState extends State<WorkerNavigationBar> {
  int _selectedIndex = 0;
  bool _isLoading = true;
  String _userEmail = '';
  late List<Widget> _pages;

  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _pages = [
      WorkerProblemsPage(selectedProject: widget.selectedProject),
      WorkerProblemsToSolvePage(selectedProject: widget.selectedProject),
      WorkerMeetingsPage(selectedProject: widget.selectedProject),
    ];
    _getUserEmail();
  }

  Future<void> _getUserEmail() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      setState(() {
        _userEmail = user.email ?? '';
      });
    }
    setState(() {
      _isLoading = false;
    });
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

    return Scaffold(
     
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: Container(
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
              GButton(icon: Icons.warning, text: 'Report'),
              GButton(icon: Icons.task, text: 'To Solve'),
              GButton(icon: Icons.calendar_today, text: 'Meetings'),
            ],
          ),
        ),
      ),
    );
  }
} 