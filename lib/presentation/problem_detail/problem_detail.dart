import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../ressourses/colormanager.dart';

class ProblemDetail extends StatefulWidget {
  final Map<String, dynamic> problem;
  final Map<String, dynamic>? userProfile;

  const ProblemDetail({Key? key, required this.problem, this.userProfile})
    : super(key: key);

  @override
  State<ProblemDetail> createState() => _ProblemDetailState();
}

class _ProblemDetailState extends State<ProblemDetail> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  List<Map<String, dynamic>> _projectMembers = [];
  bool _showMembers = false;
  String? _assignedToName;
  String? _assignedToId;
  List<Map<String, dynamic>> _allUsers = [];
  bool _showAllUsers = false;
  Map<String, dynamic>? _reporterProfile;
  bool _isTimeImportant = true;
  DateTime? _selectedEndDate;

  // Add these controllers for the form
  final TextEditingController _missionController = TextEditingController();
  DateTime? _selectedStartDate;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _missionController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      setState(() => _isLoading = true);
      
      // Load reporter's profile
      if (widget.problem['user_id'] != null) {
        final reporterResponse = await _supabase
            .from('profiles')
            .select('*')
            .eq('id', widget.problem['user_id'])
            .single();
        
        if (reporterResponse != null) {
          setState(() {
            _reporterProfile = reporterResponse;
          });
        }
      }
      
      // Load current assignment
      final assignmentResponse = await _supabase
          .from('propleme_relation')
          .select('''
            *,
            profiles!inner(
              id,
              first_name,
              last_name
            )
          ''')
          .eq('id_propleme', widget.problem['id'])
          .maybeSingle();

      if (assignmentResponse != null) {
        setState(() {
          _assignedToId = assignmentResponse['id_user'];
          if (assignmentResponse['profiles'] != null) {
            _assignedToName = '${assignmentResponse['profiles']['first_name']} ${assignmentResponse['profiles']['last_name']}';
          }
        });
      }

      await Future.wait([
        _loadProjectMembers(),
        _loadAllUsers(),
      ]);
    } catch (e) {
      print('Error loading initial data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadProjectMembers() async {
    try {
      final response = await _supabase
          .from('project_members')
          .select('*, profiles!user_id(*)')
          .eq('project_id', widget.problem['project_id']);

      if (response != null) {
        setState(() {
          _projectMembers = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      print('Error loading project members: $e');
    }
  }

  Future<void> _loadAllUsers() async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('*')
          .order('created_at', ascending: false);

      if (response != null) {
        setState(() {
          _allUsers = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      print('Error loading all users: $e');
    }
  }

  Future<void> _deleteProblem() async {
    try {
      setState(() => _isLoading = true);
      await _supabase.from('proplemes').delete().eq('id', widget.problem['id']);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Problem deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting problem: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Add this method to show the assignment form dialog
  Future<void> _showAssignmentForm(String userId, String userName) async {
    _missionController.text = ''; // Reset mission text
    _selectedStartDate = DateTime.now(); // Default to today
    _selectedEndDate = DateTime.now().add(const Duration(days: 1)); // Default to tomorrow
    _isTimeImportant = true;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                'Assign Problem to $userName',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Time Importance Switch
                    Row(
                      children: [
                        Switch(
                          value: _isTimeImportant,
                          onChanged: (value) {
                            setState(() => _isTimeImportant = value);
                          },
                          activeColor: AppColor.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Time is important',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Start Date Picker
                    Text(
                      'Start Date',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedStartDate ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2101),
                        );
                        if (picked != null) {
                          setState(() => _selectedStartDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _selectedStartDate != null
                                  ? '${_selectedStartDate!.day}/${_selectedStartDate!.month}/${_selectedStartDate!.year}'
                                  : 'Select Date',
                              style: GoogleFonts.poppins(fontSize: 14),
                            ),
                            const Icon(Icons.calendar_today, size: 18),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // End Date Picker (only if time is important)
                    if (_isTimeImportant) ...[
                      Text(
                        'End Date',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedEndDate ?? DateTime.now().add(const Duration(days: 1)),
                            firstDate: _selectedStartDate ?? DateTime.now(),
                            lastDate: DateTime(2101),
                          );
                          if (picked != null) {
                            setState(() => _selectedEndDate = picked);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _selectedEndDate != null
                                    ? '${_selectedEndDate!.day}/${_selectedEndDate!.month}/${_selectedEndDate!.year}'
                                    : 'Select Date',
                                style: GoogleFonts.poppins(fontSize: 14),
                              ),
                              const Icon(Icons.calendar_today, size: 18),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Mission TextField
                    Text(
                      'Mission Description',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _missionController,
                      decoration: InputDecoration(
                        hintText: 'Enter mission details',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
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
                  onPressed: _selectedStartDate != null && (!_isTimeImportant || _selectedEndDate != null)
                      ? () => Navigator.of(context).pop(true)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColor.primary,
                  ),
                  child: Text(
                    'Assign',
                    style: GoogleFonts.poppins(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      await _assignProblem(
        userId,
        startDate: _selectedStartDate!,
        endDate: _isTimeImportant ? _selectedEndDate : null,
        mission: _missionController.text.trim(),
      );
    }
  }

  // Modify the _assignProblem method to handle end date
  Future<void> _assignProblem(
    String userId, {
    required DateTime startDate,
    DateTime? endDate,
    required String mission,
  }) async {
    try {
      setState(() => _isLoading = true);
      print('DEBUG: Starting assignment process for user: $userId');

      // Get the assigned user's name for the message
      String userName = 'Unknown User';
      try {
        final userResponse = await _supabase
            .from('profiles')
            .select('first_name, last_name')
            .eq('id', userId)
            .single();
        
        if (userResponse != null) {
          userName = '${userResponse['first_name']} ${userResponse['last_name']}';
        }
      } catch (e) {
        print('DEBUG: Error getting user name: $e');
      }

      // First update the problem status to in_progress
      print('DEBUG: Updating problem status to in_progress');
      await _supabase
          .from('proplemes')
          .update({
            'status': 'in_progress',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.problem['id']);

      // Check if there's an existing relation
      final existingRelation = await _supabase
          .from('propleme_relation')
          .select()
          .eq('id_propleme', widget.problem['id'])
          .maybeSingle();

      final formattedStartDate = startDate.toIso8601String().split('T')[0];
      final formattedEndDate = endDate?.toIso8601String().split('T')[0];

      if (existingRelation != null && existingRelation['id'] != null) {
        final updateResponse = await _supabase
            .from('propleme_relation')
            .update({
              'id_user': userId,
              'time_start': formattedStartDate,
              'time_end': formattedEndDate,
              'mission': mission,
              'is_fixed': false,
            })
            .eq('id', existingRelation['id']);
        print('DEBUG: Update response: $updateResponse');
      } else {
        final insertData = {
          'id_propleme': widget.problem['id'],
          'id_user': userId,
          'time_start': formattedStartDate,
          'time_end': formattedEndDate,
          'mission': mission,
          'is_fixed': false,
        };
        print('DEBUG: Insert data: $insertData');
        
        final insertResponse = await _supabase
            .from('propleme_relation')
            .insert(insertData)
            .select();
        print('DEBUG: Insert response: $insertResponse');
      }

      if (mounted) {
        setState(() {
          _assignedToId = userId;
          _assignedToName = userName;
          _showMembers = false;
          // Update the local problem status
          widget.problem['status'] = 'in_progress';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Problem assigned successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e, stackTrace) {
      print('ERROR: Assignment failed');
      print('ERROR details: $e');
      print('ERROR stack trace: $stackTrace');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error assigning problem:\n${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _unassignProblem() async {
    try {
      setState(() => _isLoading = true);
      
      // Get the existing relation
      final existingRelation = await _supabase
          .from('propleme_relation')
          .select()
          .eq('id_project', widget.problem['project_id'])
          .maybeSingle();

      if (existingRelation != null) {
        // Update the relation to mark it as completed
        await _supabase
            .from('propleme_relation')
            .update({
              'time_end': DateTime.now().toIso8601String(),
              'is_fixed': false,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', existingRelation['id']);
      }

      // Update the problem status
      await _supabase
          .from('proplemes')
          .update({
            'status': 'pending',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.problem['id']);

      if (mounted) {
        setState(() {
          _assignedToId = null;
          _assignedToName = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Problem unassigned successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error unassigning problem: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'in_progress':
        return Colors.blue;
      case 'resolved':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString).toLocal();
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

  // Add this helper function to properly format user initials
  String _formatUserInitials(String firstName, String lastName) {
    // Get first character of first name and last name, handle empty strings
    String firstInitial = firstName.isNotEmpty ? firstName[0].toUpperCase() : '';
    String lastInitial = lastName.isNotEmpty ? lastName[0].toUpperCase() : '';
    
    // If we have both initials, return them together
    if (firstInitial.isNotEmpty && lastInitial.isNotEmpty) {
      return '$firstInitial$lastInitial';
    }
    // If we only have first name, return first two letters
    else if (firstInitial.isNotEmpty) {
      return firstName.length > 1 ? firstName.substring(0, 2).toUpperCase() : firstInitial;
    }
    // If we only have last name, return first two letters
    else if (lastInitial.isNotEmpty) {
      return lastName.length > 1 ? lastName.substring(0, 2).toUpperCase() : lastInitial;
    }
    // If no name available, return question mark
    return '?';
  }

  Widget _buildAssignmentInfo(Map<String, dynamic> problem) {
    // Check if problem is resolved
    if (problem['status'] == 'resolved') {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_outline,
                    color: Colors.green,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Problem Resolved',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.green[700],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'This problem has been marked as resolved and cannot be assigned.',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_assignedToName != null) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.blue.withOpacity(0.1),
                    child: Text(
                      _formatUserInitials(
                        _assignedToName!.split(' ')[0],
                        _assignedToName!.split(' ').length > 1 ? _assignedToName!.split(' ')[1] : '',
                      ),
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Resolved by',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          _assignedToName!,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    }

    if (_assignedToId == null || _assignedToName == null) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              setState(() {
                _showMembers = true;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColor.primary,
                    AppColor.primary.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColor.primary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_add_alt_1,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Assign Someone to Fix This Problem',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Split the assigned name into first and last name
    final nameParts = _assignedToName!.split(' ');
    final firstName = nameParts.isNotEmpty ? nameParts[0] : '';
    final lastName = nameParts.length > 1 ? nameParts[1] : '';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.blue,
                child: Text(
                  _formatUserInitials(firstName, lastName),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Currently assigned to:',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      _assignedToName ?? '',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _showMembers = true;
                  });
                },
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Change'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentList() {
    if (!_showMembers) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select User',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      _showMembers = false;
                    });
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _allUsers.length,
            itemBuilder: (context, index) {
              final user = _allUsers[index];
              final isAssigned = _assignedToId == user['id'];
              final userName = '${user['first_name']} ${user['last_name']}';
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: isAssigned ? Colors.green : Colors.grey[400],
                  child: Text(
                    _formatUserInitials(
                      user['first_name'] ?? '',
                      user['last_name'] ?? ''
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                title: Text(
                  userName,
                  style: GoogleFonts.poppins(
                    fontWeight: isAssigned ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                trailing: isAssigned
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : TextButton(
                        onPressed: () => _showAssignmentForm(user['id'], userName),
                        child: const Text('Assign'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColor.primary,
                        ),
                      ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Problem Details',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed:
                _isLoading
                    ? null
                    : () {
                      showDialog(
                        context: context,
                        builder:
                            (context) => AlertDialog(
                              title: const Text('Delete Problem'),
                              content: const Text(
                                'Are you sure you want to delete this problem?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _deleteProblem();
                                  },
                                  child: const Text(
                                    'Delete',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                      );
                    },
          ),
        ],
      ),
      body: _isLoading && _projectMembers.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Problem Image with enhanced design
                  if (widget.problem['image_url'] != null)
                    Container(
                      height: 250,
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              widget.problem['image_url'],
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  color: Colors.grey[200],
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      value: loadingProgress.expectedTotalBytes != null
                                          ? loadingProgress.cumulativeBytesLoaded /
                                              loadingProgress.expectedTotalBytes!
                                          : null,
                                      color: AppColor.primary,
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[200],
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.error_outline,
                                          size: 40,
                                          color: Colors.grey[400],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Failed to load image',
                                          style: GoogleFonts.poppins(
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                            // Gradient overlay for better text visibility
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                height: 100,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      Colors.black.withOpacity(0.7),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Problem Info
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          widget.problem['title'] ?? 'No Title',
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Status and Type
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _getStatusColor(
                                  widget.problem['status'] ?? '',
                                ).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                widget.problem['status'] ?? 'Unknown',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: _getStatusColor(
                                    widget.problem['status'] ?? '',
                                  ),
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
                                color: AppColor.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                widget.problem['type'] ?? 'Unknown',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: AppColor.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Description
                        Text(
                          'Description',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.problem['description'] ?? 'No description',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),

                        // Assignment section
                        Text(
                          'Assignment',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildAssignmentInfo(widget.problem),
                        _buildAssignmentList(),

                        // Reporter Info
                        Text(
                          'Reported by',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: AppColor.primary,
                              child: Text(
                                _reporterProfile != null
                                    ? '${_reporterProfile!['first_name'][0]}${_reporterProfile!['last_name'][0]}'
                                    : '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _reporterProfile != null
                                      ? '${_reporterProfile!['first_name']} ${_reporterProfile!['last_name']}'
                                      : 'Unknown User',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (_reporterProfile != null)
                                  Text(
                                    _reporterProfile!['mission'] ?? 'No role specified',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Created At
                        Text(
                          'Reported on',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.problem['created_at'] != null
                              ? _formatDate(widget.problem['created_at'])
                              : 'Unknown date',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.grey[600],
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
