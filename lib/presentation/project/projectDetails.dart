import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../ressourses/colormanager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProjectDetails extends StatefulWidget {
  final Map<String, dynamic> project;

  const ProjectDetails({
    Key? key,
    required this.project,
  }) : super(key: key);

  @override
  State<ProjectDetails> createState() => _ProjectDetailsState();
}

class _ProjectDetailsState extends State<ProjectDetails> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _teamMembers = [];
  List<Map<String, dynamic>> _problems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
    
    _fetchProjectData();
  }

  Future<void> _fetchProjectData() async {
    try {
      // Fetch team members for this project
      final membersResponse = await _supabase
          .from('project_members')
          .select('project_id, user_id, role')
          .eq('project_id', widget.project['id']);
      
      print('Found ${membersResponse.length} team members for project ${widget.project['id']}');
      
      // Get profile information for each team member
      List<Map<String, dynamic>> teamMembersWithProfiles = [];
      for (var member in membersResponse) {
        try {
          // Try to fetch from profiles table where id matches user_id
          final profileResponse = await _supabase
              .from('profiles')
              .select('id, username, full_name, avatar_url, is_online')
              .eq('id', member['user_id'])
              .maybeSingle();
          
          print('Profile for user ${member['user_id']}: $profileResponse');
          
          // If profileResponse is null, try to get a human-readable user identifier
          if (profileResponse == null) {
            // We don't have access to auth.admin in client-side code, so let's make a user-friendly ID
            teamMembersWithProfiles.add({
              ...member,
              'profiles': {
                'username': 'User ${member['user_id'].toString().substring(0, 6)}',
                'id': member['user_id'],
              }
            });
          } else {
            teamMembersWithProfiles.add({
              ...member,
              'profiles': profileResponse,
            });
          }
        } catch (e) {
          print('Error fetching profile for user ${member['user_id']}: $e');
          teamMembersWithProfiles.add({
            ...member,
            'profiles': {'username': 'User #${member['user_id'].toString().substring(0, 8)}', 'id': member['user_id']},
          });
        }
      }
      
      // Fetch all problems 
      final allProblems = await _supabase
          .from('proplemes')
          .select('*');
          
      print('Fetched ${allProblems.length} total problems');
      
      // Filter problems related to this project or via relations
      List<Map<String, dynamic>> projectProblems = [];
      for (var problem in allProblems) {
        // Check if problem has project_id attribute matching current project
        if (problem['project_id'] != null && problem['project_id'].toString() == widget.project['id'].toString()) {
          projectProblems.add(problem);
          continue;
        }
        
        // If not matched directly, check problem relations to see if this problem is linked to the project
        try {
          final relations = await _supabase
              .from('propleme_relation')
              .select('*')
              .eq('id_propleme', problem['id'])
              .eq('project_id', widget.project['id']);
              
          if (relations.length > 0) {
            projectProblems.add(problem);
          }
        } catch (e) {
          print('Error checking relations for problem ${problem['id']}: $e');
        }
      }
      
      print('Found ${projectProblems.length} problems for this project');
      
      // Fetch problem relations for each problem
      List<Map<String, dynamic>> problemsWithAssignees = [];
      for (var problem in projectProblems) {
        try {
          final relationsResponse = await _supabase
              .from('propleme_relation')
              .select('*')
              .eq('id_propleme', problem['id']);
          
          print('Found ${relationsResponse.length} relations for problem ${problem['id']}');
          
          List<Map<String, dynamic>> assignees = [];
          for (var relation in relationsResponse) {
            if (relation['id_user'] != null) {
              try {
                final userResponse = await _supabase
                    .from('profiles')
                    .select('*')
                    .eq('id', relation['id_user'])
                    .maybeSingle();
                
                final userName = userResponse?['full_name'] ?? userResponse?['username'] ?? 'User #${relation['id_user'].toString().substring(0, 8)}';
                
                print('User for relation: $userName');
                
                assignees.add({
                  ...relation,
                  'user_name': userName,
                });
              } catch (e) {
                print('Error fetching profile for problem relation: $e');
                assignees.add({
                  ...relation,
                  'user_name': 'User #${relation['id_user'].toString().substring(0, 8)}',
                });
              }
            }
          }
          
          problemsWithAssignees.add({
            ...problem,
            'assignees': assignees,
          });
        } catch (e) {
          print('Error fetching relations for problem ${problem['id']}: $e');
          problemsWithAssignees.add({
            ...problem,
            'assignees': [],
          });
        }
      }
      
      setState(() {
        _teamMembers = teamMembersWithProfiles;
        _problems = problemsWithAssignees;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching project data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserList() {
    if (_teamMembers.isEmpty) {
      return Center(
        child: Text(
          'No team members yet',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      );
    }
    
    return Container(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _teamMembers.length,
        itemBuilder: (context, index) {
          final member = _teamMembers[index];
          final profile = member['profiles'] ?? {};
          final name = profile['full_name'] ?? profile['username'] ?? 'Unknown';
          final avatarUrl = profile['avatar_url'];
          final role = member['role'] ?? 'member';
          
          return Container(
            width: 80,
            margin: const EdgeInsets.only(right: 16),
            child: Column(
              children: [
                Stack(
                  children: [
                    avatarUrl != null
                        ? CircleAvatar(
                            radius: 30,
                            backgroundImage: NetworkImage(avatarUrl),
                          )
                        : Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColor.primary.withOpacity(0.1),
                            ),
                            child: Center(
                              child: Text(
                                _getInitials(name),
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: AppColor.primary,
                                ),
                              ),
                            ),
                          ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getRoleColor(role),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          role[0].toUpperCase(),
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    if (profile['is_online'] == true)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  name,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProblemList() {
    if (_problems.isEmpty) {
      return Center(
        child: Text(
          'No problems reported yet',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      );
    }
    
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _problems.length,
      itemBuilder: (context, index) {
        final problem = _problems[index];
        final assignees = problem['assignees'] ?? [];
        final assignedTo = assignees.isNotEmpty ? assignees[0]['user_name'] : 'Unassigned';
        final isFixed = assignees.isNotEmpty ? assignees[0]['is_fixed'] ?? false : false;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      problem['title'] ?? 'Untitled Problem',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(problem['status'] ?? 'pending').withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      problem['status'] ?? 'pending',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: _getStatusColor(problem['status'] ?? 'pending'),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                problem['description'] ?? 'No description provided',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    isFixed ? Icons.check_circle : Icons.person,
                    size: 16,
                    color: isFixed ? Colors.green : Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isFixed
                        ? 'Fixed by $assignedTo'
                        : 'Assigned to $assignedTo',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: isFixed ? Colors.green : Colors.blue,
                    ),
                  ),
                ],
              ),
              if (assignees.isNotEmpty && assignees[0]['start_date'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Start: ${_formatDate(assignees[0]['start_date'])}',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.event,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Due: ${assignees[0]['end_date'] != null ? _formatDate(assignees[0]['end_date']) : 'Not set'}',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'Not set';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Colors.red;
      case 'manager':
        return Colors.blue;
      case 'worker':
      case 'member':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'in_progress':
        return Colors.blue;
      case 'resolved':
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getInitials(String name) {
    final nameParts = name.split(' ');
    if (nameParts.length >= 2) {
      return '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name.substring(0, min(2, name.length)).toUpperCase() : 'NA';
  }

  int min(int a, int b) => a < b ? a : b;

  Widget _buildStatisticsSection() {
    final resolvedProblems = _problems.where((p) => p['status'] == 'resolved' || p['status'] == 'completed').length;
    final inProgressProblems = _problems.where((p) => p['status'] == 'in_progress').length;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Statistics',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Team Members',
                '${_teamMembers.length}',
                Icons.people,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                'Total Problems',
                '${_problems.length}',
                Icons.bug_report,
                Colors.red,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Resolved',
                '$resolvedProblems',
                Icons.check_circle,
                Colors.green,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                'In Progress',
                '$inProgressProblems',
                Icons.hourglass_empty,
                Colors.orange,
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Project Details',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Project Info Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              spreadRadius: 1,
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.project['name'] ?? 'Project Name',
                              style: GoogleFonts.poppins(
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (widget.project['description'] != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                widget.project['description'],
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Icon(Icons.calendar_today,
                                    size: 16, color: AppColor.primary),
                                const SizedBox(width: 8),
                                Text(
                                  'Start Date: ${_formatDate(widget.project['start_date'])}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.calendar_today,
                                    size: 16, color: AppColor.primary),
                                const SizedBox(width: 8),
                                Text(
                                  'End Date: ${_formatDate(widget.project['end_date'])}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Statistics Section
                      _buildStatisticsSection(),
                      const SizedBox(height: 24),
                      
                      // Team Members Section
                      Text(
                        'Team Members',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildUserList(),
                      const SizedBox(height: 24),
                      
                      // Problems Section
                      Text(
                        'Problems',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildProblemList(),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}