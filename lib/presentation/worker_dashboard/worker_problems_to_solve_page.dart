import 'package:flutter/material.dart';
import 'package:flutter_pfe/presentation/ressourses/colormanager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../problem_detail/problem_detail.dart';
import '../problem_detail/problem_detail_worker.dart';

class WorkerProblemsToSolvePage extends StatefulWidget {
  final Map<String, dynamic> selectedProject;

  const WorkerProblemsToSolvePage({super.key, required this.selectedProject});

  @override
  State<WorkerProblemsToSolvePage> createState() => _WorkerProblemsToSolvePageState();
}

class _WorkerProblemsToSolvePageState extends State<WorkerProblemsToSolvePage> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _assignedProblems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAssignedProblems();
  }

  Future<void> _loadAssignedProblems() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      print('Loading problems for user: ${user.id}');

      // First get the problems with their relations
      final response = await _supabase
          .from('proplemes')
          .select('''
            *,
            propleme_relation!inner(
              time_start,
              time_end,
              mission,
              is_fixed
            )
          ''')
          .eq('status', 'in_progress')
          .order('created_at', ascending: false);

      print('Loaded ${response.length} problems');

      setState(() {
        _assignedProblems = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading assigned problems: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error loading problems: Please try again',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() => _isLoading = false);
    }
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

  void _viewProblemDetails(Map<String, dynamic> problem) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProblemDetailWorker(
          problem: problem,
        ),
      ),
    ).then((_) => _loadAssignedProblems()); // Reload after returning
  }

  Future<void> _markProblemAsFixed(Map<String, dynamic> problemRelation) async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Mark Problem as Fixed',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            'Are you sure you want to mark this problem as fixed?',
            style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
              child: Text(
                'Mark as Fixed',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      // Get the problem ID
      final problemId = problemRelation['proplemes']['id'];
      if (problemId == null) {
        throw Exception('Problem ID not found');
      }

      print('Updating problem status for ID: $problemId');

      // Only update the status in proplemes table
      await _supabase
          .from('proplemes')
          .update({
            'status': 'resolved',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', problemId);

      print('Problem status updated successfully');

      // Reload the problems list
      await _loadAssignedProblems();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  'Problem marked as fixed successfully',
                  style: GoogleFonts.poppins(),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('Error marking problem as fixed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to mark problem as fixed. Please try again.',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getTimeRemaining(Map<String, dynamic> problem) {
    try {
      final relation = problem['propleme_relation'];
      if (relation == null) return 'No deadline set';

      final endDateStr = relation['time_end'];
      if (endDateStr == null) return 'No deadline set';

      final endDate = DateTime.parse(endDateStr);
      final startDate = DateTime.parse(relation['time_start']);
      final now = DateTime.now();
      
      if (endDate.isBefore(now)) {
        return 'Overdue';
      }

      final difference = endDate.difference(now);
      final days = difference.inDays;
      final hours = difference.inHours.remainder(24);
      final minutes = difference.inMinutes.remainder(60);

      if (days > 0) {
        return '$days days remaining';
      } else if (hours > 0) {
        return '$hours hours remaining';
      } else {
        return '$minutes minutes remaining';
      }
    } catch (e) {
      return 'Invalid date';
    }
  }

  double _getProgress(Map<String, dynamic> problem) {
    try {
      final relation = problem['propleme_relation'];
      if (relation == null) return 0.0;

      final startDateStr = relation['time_start'];
      final endDateStr = relation['time_end'];
      
      if (startDateStr == null || endDateStr == null) return 0.0;

      final startDate = DateTime.parse(startDateStr);
      final endDate = DateTime.parse(endDateStr);
      final now = DateTime.now();

      if (endDate.isBefore(now)) return 1.0;
      if (startDate.isAfter(now)) return 0.0;

      final totalDuration = endDate.difference(startDate).inSeconds;
      final elapsedDuration = now.difference(startDate).inSeconds;

      return (elapsedDuration / totalDuration).clamp(0.0, 1.0);
    } catch (e) {
      return 0.0;
    }
  }

  Color _getTimeRemainingColor(Map<String, dynamic> problem) {
    try {
      final relation = problem['propleme_relation'];
      if (relation == null) return Colors.grey;

      final endDateStr = relation['time_end'];
      if (endDateStr == null) return Colors.grey;

      final endDate = DateTime.parse(endDateStr);
      final now = DateTime.now();
      final difference = endDate.difference(now);
      
      if (endDate.isBefore(now)) {
        return Colors.red;
      } else if (difference.inHours < 24) {
        return Colors.orange;
      } else {
        return Colors.green;
      }
    } catch (e) {
      return Colors.grey;
    }
  }

  Widget _buildAssignedProblemCard(Map<String, dynamic> problem) {
    if (problem == null) return const SizedBox.shrink();

    final bool isResolved = problem['status'] == 'resolved';
    final Color statusColor = isResolved ? Colors.green : AppColor.primary;
    final String timeRemaining = _getTimeRemaining(problem);
    final Color timeColor = _getTimeRemainingColor(problem);
    final double progress = _getProgress(problem);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _viewProblemDetails(problem),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      problem['title'] ?? 'No title',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isResolved ? Icons.check_circle : Icons.pending,
                          size: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isResolved ? 'Fixed' : 'In Progress',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                problem['description'] ?? 'No description',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.black87,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              // Progress Bar
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Progress',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: timeColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(timeColor),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    'Created: ${_formatDate(problem['created_at'])}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: timeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: timeColor.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      timeColor == Colors.red
                          ? Icons.warning_rounded
                          : Icons.timer_outlined,
                      size: 16,
                      color: timeColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      timeRemaining,
                      style: GoogleFonts.poppins(
                        color: timeColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (!isResolved) 
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _markProblemAsFixed({'proplemes': problem}),
                    icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                    label: Text(
                      'Mark as Fixed',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _assignedProblems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 64,
                        color: Colors.green[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No problems assigned',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'You have no problems to solve at the moment',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadAssignedProblems,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _assignedProblems.length,
                    itemBuilder: (context, index) {
                      return _buildAssignedProblemCard(_assignedProblems[index]);
                    },
                  ),
                ),
    );
  }
} 