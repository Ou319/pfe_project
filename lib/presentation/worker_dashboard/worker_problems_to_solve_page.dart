import 'package:flutter/material.dart';
import 'package:flutter_pfe/presentation/ressourses/colormanager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../problem_detail/problem_detail.dart';

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

      // First get the problems
      final response = await _supabase
          .from('proplemes')
          .select()
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
        builder: (context) => ProblemDetail(
          problem: problem,
          userProfile: null, // We don't need this for now
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

  Widget _buildAssignedProblemCard(Map<String, dynamic> problem) {
    if (problem == null) return const SizedBox.shrink();

    final bool isResolved = problem['status'] == 'resolved';
    final Color statusColor = isResolved ? Colors.green : AppColor.primary;

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