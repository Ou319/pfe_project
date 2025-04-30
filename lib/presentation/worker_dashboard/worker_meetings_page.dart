import 'package:flutter/material.dart';
import 'package:flutter_pfe/presentation/ressourses/colormanager.dart';

class WorkerMeetingsPage extends StatefulWidget {
  final Map<String, dynamic> selectedProject;

  const WorkerMeetingsPage({super.key, required this.selectedProject});

  @override
  State<WorkerMeetingsPage> createState() => _WorkerMeetingsPageState();
}

class _WorkerMeetingsPageState extends State<WorkerMeetingsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No meetings scheduled for this week',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check back later for updates',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }
} 