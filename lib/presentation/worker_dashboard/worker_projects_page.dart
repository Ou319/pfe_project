import 'package:flutter/material.dart';
import 'package:flutter_pfe/presentation/ressourses/colormanager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_pfe/presentation/worker_dashboard/worker_navigation.dart';

class WorkerProjectsPage extends StatefulWidget {
  final Map<String, dynamic> selectedProject;

  const WorkerProjectsPage({super.key, required this.selectedProject});

  @override
  State<WorkerProjectsPage> createState() => _WorkerProjectsPageState();
}

class _WorkerProjectsPageState extends State<WorkerProjectsPage> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _projects = [];
  bool _isLoading = true;
  Set<String> _projectMemberIds = {};

  @override
  void initState() {
    super.initState();
    _loadProjects();
    _loadProjectMemberships();
  }

  Future<void> _loadProjectMemberships() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final response = await _supabase
          .from('project_members')
          .select('project_id')
          .eq('user_id', user.id);

      setState(() {
        _projectMemberIds = Set<String>.from(
          response.map((member) => member['project_id'].toString()),
        );
      });
    } catch (e) {
      print('Error loading project memberships: $e');
    }
  }

  Future<void> _loadProjects() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final response = await _supabase
          .from('project_members')
          .select('projects(*)')
          .eq('user_id', user.id);

      setState(() {
        _projects = List<Map<String, dynamic>>.from(
          response.map((item) => item['projects']),
        );
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading projects: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.white,
      appBar: AppBar(
        title: const Text(
          'My Projects',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
        backgroundColor: AppColor.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _projects.isEmpty
              ? _buildEmptyProjectsState()
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ListView.builder(
                    itemCount: _projects.length,
                    itemBuilder: (context, index) {
                      final project = _projects[index];
                      final isMember = _projectMemberIds.contains(project['id'].toString());
                      return _buildProjectCard(context, project, isMember);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyProjectsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_off_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          const Text(
            'No projects assigned',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'You currently have no projects assigned to you',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectCard(BuildContext context, Map<String, dynamic> project, bool isMember) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.grey.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            spreadRadius: 2,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => WorkerNavigationBar(selectedProject: project),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Project name and status
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        project['name'] ?? 'No name',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getProjectStatusColor(project['status']),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        project['status'] ?? 'Unknown',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Project description
                Text(
                  project['description'] ?? 'No description available.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 16),

                // Progress bar
                _buildProjectTimeline(project),

                const SizedBox(height: 20),

                // Dates and member badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDateInfo(
                          Icons.calendar_today_outlined,
                          "Start: ${_formatDate(project['start_date'])}",
                        ),
                        const SizedBox(height: 6),
                        _buildDateInfo(
                          Icons.event_outlined,
                          "End: ${_formatDate(project['end_date'])}",
                        ),
                      ],
                    ),
                    if (isMember)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.green.shade300,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.check_circle_outline, color: Colors.green, size: 16),
                            SizedBox(width: 5),
                            Text(
                              'Member',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProjectTimeline(Map<String, dynamic> project) {
    double progress = 0.5;
    try {
      final startDate = DateTime.parse(project['start_date']);
      final endDate = DateTime.parse(project['end_date']);
      final today = DateTime.now();

      if (today.isBefore(startDate)) {
        progress = 0;
      } else if (today.isAfter(endDate)) {
        progress = 1;
      } else {
        final totalDuration = endDate.difference(startDate).inDays;
        final elapsedDuration = today.difference(startDate).inDays;
        progress = totalDuration > 0 ? elapsedDuration / totalDuration : 0;
        progress = progress.clamp(0.0, 1.0);
      }
    } catch (e) {}

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Progress",
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[200],
            color: _getProgressColor(progress),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildDateInfo(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: Colors.grey[600],
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  String _formatDate(String? date) {
    if (date == null) return 'No date';
    try {
      final dateObj = DateTime.parse(date);
      return '${dateObj.day}/${dateObj.month}/${dateObj.year}';
    } catch (e) {
      return 'Invalid date';
    }
  }

  Color _getProjectStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'planning':
        return Colors.blue;
      case 'in progress':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'on hold':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getProgressColor(double progress) {
    if (progress < 0.3) return Colors.red;
    if (progress < 0.7) return Colors.orange;
    return Colors.green;
  }
}
