import 'package:flutter/material.dart';
import 'package:flutter_pfe/presentation/ressourses/colormanager.dart';
import 'package:flutter_pfe/presentation/worker_dashboard/worker_projects_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_pfe/presentation/project/account_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class WorkerProblemsPage extends StatefulWidget {
  final Map<String, dynamic> selectedProject;

  const WorkerProblemsPage({super.key, required this.selectedProject});

  @override
  State<WorkerProblemsPage> createState() => _WorkerProblemsPageState();
}

class _WorkerProblemsPageState extends State<WorkerProblemsPage> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _imageUrlController = TextEditingController();
  String _selectedStatus = 'pending';
  String _selectedType = 'unknown';
  bool _isLoading = false;
  List<Map<String, dynamic>> _problems = [];
  bool _isLoadingProblems = true;
  String? _firstName;
  String? _lastName;
  Map<String, dynamic> _currentProject = {};

  @override
  void initState() {
    super.initState();
    _loadProjectData();
    _loadProblems();
    _loadUserProfile();
  }

  Future<void> _loadProjectData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final projectJson = prefs.getString('selected_project');
      
      if (projectJson != null) {
        setState(() {
          _currentProject = Map<String, dynamic>.from(json.decode(projectJson));
        });
      } else if (widget.selectedProject.isNotEmpty) {
        setState(() {
          _currentProject = widget.selectedProject;
        });
        await prefs.setString('selected_project', json.encode(widget.selectedProject));
      } else {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const WorkerProjectsPage(selectedProject: {}),
            ),
          );
        }
      }
    } catch (e) {
      print('Error loading project data: $e');
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const WorkerProjectsPage(selectedProject: {}),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();

      setState(() {
        _firstName = response['first_name'];
        _lastName = response['last_name'];
      });
    } catch (e) {
      print('Error loading user profile: $e');
    }
  }

  String _getInitials() {
    final firstName = _firstName ?? '';
    final lastName = _lastName ?? '';
    return '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}'
        .toUpperCase();
  }

  Future<void> _loadProblems() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      setState(() => _isLoadingProblems = true);

      final response = await _supabase
          .from('proplemes')
          .select('*')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _problems = List<Map<String, dynamic>>.from(response);
          _isLoadingProblems = false;
        });
      }
    } catch (e) {
      print('Error loading problems: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading problems: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoadingProblems = false);
      }
    }
  }

  Future<void> _submitProblem() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      try {
        final user = _supabase.auth.currentUser;
        if (user == null) throw Exception('User not authenticated');

        final response = await _supabase
            .from('proplemes')
            .insert({
              'title': _titleController.text,
              'description': _descriptionController.text,
              'type': _selectedType,
              'status': _selectedStatus,
              'user_id': user.id,
              'image_url': _imageUrlController.text.isNotEmpty ? _imageUrlController.text : null,
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            })
            .select();

        if (response.isNotEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Problem submitted successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          }
          
          _titleController.clear();
          _descriptionController.clear();
          _imageUrlController.clear();
          setState(() => _isLoading = false);
          
          await _loadProblems();
        }
      } catch (e) {
        print('Error submitting problem: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error submitting problem: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _isLoading = false);
      }
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
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

  String _formatDate(String? dateString) {
    if (dateString == null) return '';
    final date = DateTime.parse(dateString);
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Row(
          children: [
            // Icon(Icons.business, color: AppColor.primary, size: 24),
            // const SizedBox(width: 8),
            Expanded(
              child: Text(
                _currentProject['name'] ?? 'Project',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: AppColor.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('selected_project');
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => const WorkerProjectsPage(selectedProject: {}),
                ),
              );
            }
          },
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AccountSettings()),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  // boxShadow: [
                  //   BoxShadow(
                  //     color: AppColor.primary.withOpacity(0.4),
                  //     blurRadius: 8,
                  //     offset: const Offset(0, 2),
                  //   ),
                  // ],
                ),
                child: CircleAvatar(
                  backgroundColor: AppColor.primary,
                  child: Text(
                    _getInitials(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColor.primary, AppColor.primary.withOpacity(0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColor.primary.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.report_problem_outlined,
                    color: Colors.white,
                    size: 36,
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Report a Problem',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Submit issues for your project',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.withOpacity(0.1), width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Problem Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          labelText: 'Problem Title',
                          hintText: 'Enter a clear, concise title',
                          labelStyle: TextStyle(color: Colors.grey[600]),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColor.primary, width: 2),
                          ),
                          prefixIcon: Icon(Icons.title, color: AppColor.primary),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a title';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: 'Description',
                          hintText: 'Provide details about the problem',
                          labelStyle: TextStyle(color: Colors.grey[600]),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColor.primary, width: 2),
                          ),
                          prefixIcon: Padding(
                            padding: const EdgeInsets.only(bottom: 64),
                            child: Icon(Icons.description, color: AppColor.primary),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a description';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<String>(
                        value: _selectedStatus,
                        decoration: InputDecoration(
                          labelText: 'Status',
                          labelStyle: TextStyle(color: Colors.grey[600]),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColor.primary, width: 2),
                          ),
                          prefixIcon: Icon(Icons.flag, color: AppColor.primary),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'pending',
                            child: Text('Pending', style: TextStyle(color: _getStatusColor('pending'))),
                          ),
                          DropdownMenuItem(
                            value: 'in_progress',
                            child: Text('In Progress', style: TextStyle(color: _getStatusColor('in_progress'))),
                          ),
                          DropdownMenuItem(
                            value: 'resolved',
                            child: Text('Resolved', style: TextStyle(color: _getStatusColor('resolved'))),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedStatus = value!;
                          });
                        },
                      ),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<String>(
                        value: _selectedType,
                        decoration: InputDecoration(
                          labelText: 'Type',
                          labelStyle: TextStyle(color: Colors.grey[600]),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColor.primary, width: 2),
                          ),
                          prefixIcon: Icon(Icons.category, color: AppColor.primary),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'can_fix',
                            child: Text('Can Fix'),
                          ),
                          DropdownMenuItem(
                            value: 'unknown',
                            child: Text('Unknown'),
                          ),
                          DropdownMenuItem(
                            value: 'hard',
                            child: Text('Hard'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedType = value!;
                          });
                        },
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _imageUrlController,
                        decoration: InputDecoration(
                          labelText: 'Image URL',
                          hintText: 'Enter image URL (optional)',
                          labelStyle: TextStyle(color: Colors.grey[600]),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColor.primary, width: 2),
                          ),
                          prefixIcon: Icon(Icons.image, color: AppColor.primary),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                      ),
                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submitProblem,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColor.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 2,
                          ),
                          child: _isLoading
                              ? SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.send, color: Colors.white, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Submit Problem',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.history, size: 20, color: Colors.grey),
                    SizedBox(width: 8),
                    Text(
                      'Recent Problems',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: _loadProblems,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            _isLoadingProblems
                ? const Center(child: CircularProgressIndicator())
                : _problems.isEmpty
                    ? Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.grey.withOpacity(0.1), width: 1),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  size: 48,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'No problems reported yet',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Your reported problems will appear here',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _problems.length,
                        itemBuilder: (context, index) {
                          final problem = _problems[index];
                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: Colors.grey.withOpacity(0.1), width: 1),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          problem['title'] ?? 'No title',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(problem['status'])
                                              .withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          problem['status'] ?? 'Unknown',
                                          style: TextStyle(
                                            color: _getStatusColor(problem['status']),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    problem['description'] ?? 'No description',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Type: ${problem['type'] ?? 'Unknown'}',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        _formatDate(problem['created_at']),
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (problem['image_url'] != null) ...[
                                    const SizedBox(height: 12),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        problem['image_url'],
                                        height: 150,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            height: 150,
                                            color: Colors.grey[200],
                                            child: const Center(
                                              child: Icon(Icons.broken_image, color: Colors.grey),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ],
        ),
      ),
    );
  }
}