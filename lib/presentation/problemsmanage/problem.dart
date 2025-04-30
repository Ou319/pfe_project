import 'package:flutter/material.dart';
import 'package:flutter_pfe/presentation/ressourses/colormanager.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../problem_detail/problem_detail.dart';
import '../ressourses/valuesmanager.dart';

class Problem extends StatefulWidget {
  const Problem({super.key});

  @override
  State<Problem> createState() => _ProblemState();
}

class _ProblemState extends State<Problem> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _problems = [];
  String? _selectedType;
  String? _selectedStatus;
  String? _selectedAssignment;
  List<Map<String, dynamic>> _filteredProblems = [];
  TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProblems();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProblems() async {
    try {
      setState(() {
        _isLoading = true;
        _problems.clear();
        _filteredProblems.clear();
      });

      final response = await _supabase
          .from('proplemes')
          .select('''
            *,
            propleme_relation(
              id,
              id_user,
              time_start,
              time_end,
              is_fixed,
              profiles(
                id,
                first_name,
                last_name
              )
            )
          ''')
          .order('created_at', ascending: false);

      print('Problems response: $response'); // Debug print

      if (response != null) {
        final problems = List<Map<String, dynamic>>.from(response);
        print('Parsed problems: $problems'); // Debug print

        setState(() {
          _problems = problems;
          _filteredProblems = List.from(problems);
          _isLoading = false;
        });
        _applyFilters();
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
        setState(() {
          _isLoading = false;
          _problems = [];
          _filteredProblems = [];
        });
      }
    }
  }

  void _applyFilters() {
    if (_problems.isEmpty) {
      setState(() => _filteredProblems = []);
      return;
    }

    List<Map<String, dynamic>> filtered = List.from(_problems);

    // Apply type filter
    if (_selectedType != null) {
      filtered = filtered.where((p) => p['type'] == _selectedType).toList();
    }

    // Apply status filter
    if (_selectedStatus != null) {
      filtered = filtered.where((p) => p['status'] == _selectedStatus).toList();
    }

    // Apply assignment filter
    if (_selectedAssignment != null) {
      if (_selectedAssignment == 'assigned') {
        filtered = filtered.where((p) => 
          p['propleme_relation'] != null && 
          (p['propleme_relation'] as List).isNotEmpty
        ).toList();
      } else if (_selectedAssignment == 'unassigned') {
        filtered = filtered.where((p) => 
          p['propleme_relation'] == null || 
          (p['propleme_relation'] as List).isEmpty
        ).toList();
      }
    }

    // Apply search filter
    if (_searchController.text.isNotEmpty) {
      final searchTerm = _searchController.text.toLowerCase();
      filtered = filtered.where((p) =>
        (p['title']?.toString().toLowerCase() ?? '').contains(searchTerm) ||
        (p['description']?.toString().toLowerCase() ?? '').contains(searchTerm)
      ).toList();
    }

    setState(() {
      _filteredProblems = filtered;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Problems Management',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.black),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search bar with updated style
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search problems...',
                      hintStyle: GoogleFonts.poppins(color: Colors.grey),
                      prefixIcon: Icon(Icons.search, color: AppColor.primary),
                      filled: true,
                      fillColor: Colors.grey[50],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: AppColor.primary, width: 1),
                      ),
                    ),
                    onChanged: (value) => _applyFilters(),
                  ),
                ),
                // Active filters with updated style
                if (_selectedType != null || _selectedStatus != null || _selectedAssignment != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: Colors.white,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (_selectedType != null)
                          Chip(
                            label: Text(
                              'Type: $_selectedType',
                              style: GoogleFonts.poppins(color: AppColor.primary),
                            ),
                            backgroundColor: AppColor.primary.withOpacity(0.1),
                            deleteIconColor: AppColor.primary,
                            onDeleted: () {
                              setState(() {
                                _selectedType = null;
                                _applyFilters();
                              });
                            },
                          ),
                        if (_selectedStatus != null)
                          Chip(
                            label: Text(
                              'Status: $_selectedStatus',
                              style: GoogleFonts.poppins(color: AppColor.primary),
                            ),
                            backgroundColor: AppColor.primary.withOpacity(0.1),
                            deleteIconColor: AppColor.primary,
                            onDeleted: () {
                              setState(() {
                                _selectedStatus = null;
                                _applyFilters();
                              });
                            },
                          ),
                        if (_selectedAssignment != null)
                          Chip(
                            label: Text(
                              'Assignment: ${_selectedAssignment == 'assigned' ? 'Assigned' : 'Unassigned'}',
                              style: GoogleFonts.poppins(color: AppColor.primary),
                            ),
                            backgroundColor: AppColor.primary.withOpacity(0.1),
                            deleteIconColor: AppColor.primary,
                            onDeleted: () {
                              setState(() {
                                _selectedAssignment = null;
                                _applyFilters();
                              });
                            },
                          ),
                      ],
                    ),
                  ),
                // Problems list with updated style
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadProblems,
                    color: AppColor.primary,
                    child: _filteredProblems.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.search_off,
                                    size: 64,
                                    color: Colors.grey[300],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No problems found matching your filters',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      color: Colors.grey,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredProblems.length,
                            itemBuilder: (context, index) {
                              final problem = _filteredProblems[index];
                              return _buildProblemCard(problem);
                            },
                          ),
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _showFilterDialog() {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Filter Problems',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedType,
              decoration: const InputDecoration(labelText: 'Problem Type'),
              items: [
                const DropdownMenuItem(value: null, child: Text('All Types')),
                ...{'hardware', 'software', 'network', 'other'}.map(
                  (type) => DropdownMenuItem(value: type, child: Text(type)),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedType = value;
                  _applyFilters();
                });
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedStatus,
              decoration: const InputDecoration(labelText: 'Status'),
              items: [
                const DropdownMenuItem(value: null, child: Text('All Statuses')),
                ...{'pending', 'in_progress', 'resolved'}.map(
                  (status) => DropdownMenuItem(value: status, child: Text(status)),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedStatus = value;
                  _applyFilters();
                });
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedAssignment,
              decoration: const InputDecoration(labelText: 'Assignment'),
              items: const [
                DropdownMenuItem(value: null, child: Text('All Problems')),
                DropdownMenuItem(value: 'assigned', child: Text('Assigned')),
                DropdownMenuItem(value: 'unassigned', child: Text('Unassigned')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedAssignment = value;
                  _applyFilters();
                });
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _selectedType = null;
                _selectedStatus = null;
                _selectedAssignment = null;
                _searchController.clear();
                _applyFilters();
              });
              Navigator.pop(context);
            },
            child: const Text('Clear All'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildProblemCard(Map<String, dynamic> problem) {
    final relation = problem['propleme_relation'];
    final isAssigned = relation != null && (relation as List).isNotEmpty;
    final assignedUser = isAssigned ? relation[0]['profiles'] : null;
    final status = problem['status'] ?? 'unknown';
    final type = problem['type'] ?? 'unknown';
    final isResolved = status == 'resolved';

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Stack(
        children: [
          // Main Card
          Container(
            margin: const EdgeInsets.only(top: 15),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 2,
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProblemDetail(
                        problem: problem,
                        userProfile: null,
                      ),
                    ),
                  ).then((_) => _loadProblems());
                },
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title and Type
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          problem['title'] ?? 'Untitled Problem',
                                          style: GoogleFonts.poppins(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                            color: isResolved ? Colors.grey[600] : Colors.black87,
                                          ),
                                        ),
                                      ),
                                      if (isResolved)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.check_circle,
                                                size: 14,
                                                color: Colors.green[700],
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Resolved',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 12,
                                                  color: Colors.green[700],
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  // Enhanced Description Section
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isResolved ? Colors.grey[50] : Colors.grey[50],
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isResolved ? Colors.grey[200]! : Colors.grey[200]!,
                                        width: 1,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.description_outlined,
                                              size: 16,
                                              color: isResolved ? Colors.grey[400] : Colors.grey[600],
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Description',
                                              style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: isResolved ? Colors.grey[400] : Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          problem['description'] ?? 'No description provided',
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            color: isResolved ? Colors.grey[500] : Colors.grey[800],
                                            height: 1.5,
                                          ),
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Type Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isResolved ? Colors.grey[200] : AppColor.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: isResolved ? Colors.grey[300]! : AppColor.primary.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getTypeIcon(type),
                                  size: 16,
                                  color: isResolved ? Colors.grey[600] : AppColor.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  type,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: isResolved ? Colors.grey[600] : AppColor.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Bottom Info Row
                      Row(
                        children: [
                          if (isAssigned) ...[
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isResolved ? Colors.grey[100] : Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: isResolved ? Colors.grey[300] : Colors.blue.withOpacity(0.2),
                                    child: Text(
                                      '${assignedUser['first_name'][0]}${assignedUser['last_name'][0]}'.toUpperCase(),
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isResolved ? Colors.grey[600] : Colors.blue,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${assignedUser['first_name']} ${assignedUser['last_name']}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: isResolved ? Colors.grey[600] : Colors.blue,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                          ] else
                            const Spacer(),
                          // Created Date
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isResolved ? Colors.grey[100] : Colors.grey[100],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 14,
                                  color: isResolved ? Colors.grey[400] : Colors.grey[600],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _formatDate(problem['created_at']),
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: isResolved ? Colors.grey[400] : Colors.grey[600],
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
          ),
          // Status Badge
          Positioned(
            top: 0,
            left: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _getStatusColor(status),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: _getStatusColor(status).withOpacity(0.3),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getStatusIcon(status),
                    size: 16,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    status.toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'hardware':
        return Icons.computer;
      case 'software':
        return Icons.code;
      case 'network':
        return Icons.wifi;
      default:
        return Icons.build;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.hourglass_empty;
      case 'in_progress':
        return Icons.trending_up;
      case 'resolved':
        return Icons.check_circle;
      default:
        return Icons.info;
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    final date = DateTime.parse(dateStr).toLocal();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Color _getStatusColor(String? status) {
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
}