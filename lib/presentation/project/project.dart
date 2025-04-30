import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../ressourses/colormanager.dart';
import 'package:google_fonts/google_fonts.dart';
import 'account_settings.dart';
import '../ressourses/routesmanager.dart';
import '../navigationbottombar/view/navigationbottombar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../ressourses/imgmanager.dart';
import 'dart:async';

class Project extends StatefulWidget {
  const Project({super.key});

  @override
  State<Project> createState() => _ProjectState();
}

class _ProjectState extends State<Project> {
  final _supabase = Supabase.instance.client;
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _projects = [];
  List<Map<String, dynamic>> _filteredProjects = [];
  bool _isLoading = true;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadProjects();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _filterProjects(_searchController.text);
    });
  }

  Future<void> _loadProjects() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final orgResponse =
          await _supabase
              .from('organisations')
              .select()
              .eq('user_id', user.id)
              .single();

      if (orgResponse != null) {
        final response = await _supabase
            .from('projects')
            .select()
            .eq('id_organisition', orgResponse['id']);

        setState(() {
          _projects = List<Map<String, dynamic>>.from(response);
          _filteredProjects = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading projects: $e')));
      }
    }
  }

  Future<void> _showCreateProjectDialog() async {
    return showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'Create New Project',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Project Name',
                      labelStyle: GoogleFonts.poppins(),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _descriptionController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      labelStyle: GoogleFonts.poppins(),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: Text('Start Date', style: GoogleFonts.poppins()),
                    subtitle: Text(
                      _startDate != null
                          ? '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}'
                          : 'Select date',
                      style: GoogleFonts.poppins(),
                    ),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(
                          const Duration(days: 365 * 5),
                        ),
                      );
                      if (date != null) {
                        setState(() => _startDate = date);
                      }
                    },
                  ),
                  ListTile(
                    title: Text('End Date', style: GoogleFonts.poppins()),
                    subtitle: Text(
                      _endDate != null
                          ? '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'
                          : 'Select date',
                      style: GoogleFonts.poppins(),
                    ),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _startDate ?? DateTime.now(),
                        firstDate: _startDate ?? DateTime.now(),
                        lastDate: DateTime.now().add(
                          const Duration(days: 365 * 5),
                        ),
                      );
                      if (date != null) {
                        setState(() => _endDate = date);
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _nameController.clear();
                  _descriptionController.clear();
                  setState(() {
                    _startDate = null;
                    _endDate = null;
                  });
                  Navigator.pop(context);
                },
                child: Text(
                  'Cancel',
                  style: GoogleFonts.poppins(color: Colors.grey[600]),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (_nameController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter a project name'),
                      ),
                    );
                    return;
                  }

                  try {
                    final user = _supabase.auth.currentUser;
                    if (user != null) {
                      // Get organization ID
                      final orgResponse =
                          await _supabase
                              .from('organisations')
                              .select()
                              .eq('user_id', user.id)
                              .single();

                      if (orgResponse != null) {
                        // Create project
                        await _supabase.from('projects').insert({
                          'name': _nameController.text,
                          'description': _descriptionController.text,
                          'id_organisition': orgResponse['id'],
                          'start_date': _startDate?.toIso8601String(),
                          'end_data': _endDate?.toIso8601String(),
                          'created_at': DateTime.now().toIso8601String(),
                        });

                        // Refresh projects list
                        await _loadProjects();

                        // Clear form
                        _nameController.clear();
                        _descriptionController.clear();
                        setState(() {
                          _startDate = null;
                          _endDate = null;
                        });

                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Project created successfully'),
                            ),
                          );
                        }
                      }
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error creating project: $e')),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColor.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Create',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
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
        centerTitle: true,
        title: Text(
          'Projects',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        actions: [
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder:
                      (context, animation, secondaryAnimation) =>
                          const AccountSettings(),
                  transitionsBuilder: (
                    context,
                    animation,
                    secondaryAnimation,
                    child,
                  ) {
                    const begin = Offset(1.0, 0.0);
                    const end = Offset.zero;
                    const curve = Curves.easeInOut;
                    var tween = Tween(
                      begin: begin,
                      end: end,
                    ).chain(CurveTween(curve: curve));
                    var offsetAnimation = animation.drive(tween);
                    return SlideTransition(
                      position: offsetAnimation,
                      child: child,
                    );
                  },
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColor.grey,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  'U',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by name or description...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(7),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 16,
                        ),
                      ),
                      style: GoogleFonts.poppins(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(Icons.filter_list),
                    onPressed: () {
                      _showFilterBottomSheet();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child:
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _filteredProjects.isEmpty
                        ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.folder_open,
                                size: 80,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No projects found',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Try a different search term',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        )
                        : GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio: 1.2,
                              ),
                          itemCount: _filteredProjects.length,
                          itemBuilder: (context, index) {
                            final project = _filteredProjects[index];
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                GestureDetector(
                                  onTap: () async {
                                    try {
                                      final prefs =
                                          await SharedPreferences.getInstance();
                                      await prefs.setString(
                                        'selected_project_id',
                                        project['id'].toString(),
                                      );

                                      if (!mounted) return;
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (_) => NavigationBottomBar(
                                                selectedProject: project,
                                              ),
                                        ),
                                      );
                                    } catch (e) {
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Error selecting project: $e',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  child: Container(
                                    height: 140,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFFEEEEEE),
                                        width: 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Stack(
                                      children: [
                                        Center(
                                          child: Image.asset(
                                            AppImg.logo,
                                            width: 60,
                                            height: 60,
                                          ),
                                        ),
                                        Positioned(
                                          top: 12,
                                          right: 12,
                                          child: GestureDetector(
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder:
                                                      (context) => Scaffold(
                                                        appBar: AppBar(
                                                          title: Text(
                                                            'Project Details',
                                                            style:
                                                                GoogleFonts.poppins(
                                                                  fontSize: 18,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                ),
                                                          ),
                                                        ),
                                                        body: Center(
                                                          child: Text(
                                                            'Project details page coming soon...',
                                                            style:
                                                                GoogleFonts.poppins(),
                                                          ),
                                                        ),
                                                      ),
                                                ),
                                              );
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: Colors.grey[200],
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.more_vert,
                                                size: 16,
                                                color: Colors.black,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  project['name'] ?? 'No Name',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateProjectDialog,
        backgroundColor: AppColor.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _filterProjects(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredProjects = List.from(_projects);
      });
      return;
    }

    final filtered =
        _projects.where((project) {
          final name = project['name']?.toString().toLowerCase() ?? '';
          final description =
              project['description']?.toString().toLowerCase() ?? '';
          final searchQuery = query.toLowerCase();

          return name.contains(searchQuery) ||
              description.contains(searchQuery);
        }).toList();

    setState(() {
      _filteredProjects = filtered;
    });
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
      ),
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Sort Projects',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: Text('Sort by Name', style: GoogleFonts.poppins()),
                  onTap: () {
                    _sortProjects('name');
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  title: Text(
                    'Sort by Last Open',
                    style: GoogleFonts.poppins(),
                  ),
                  onTap: () {
                    _sortProjects('last_open');
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  title: Text('Sort by End Time', style: GoogleFonts.poppins()),
                  onTap: () {
                    _sortProjects('end_time');
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
    );
  }

  void _sortProjects(String sortBy) {
    setState(() {
      switch (sortBy) {
        case 'name':
          _filteredProjects.sort(
            (a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''),
          );
          break;
        case 'last_open':
          _filteredProjects.sort(
            (a, b) => (a['last_open'] ?? '').compareTo(b['last_open'] ?? ''),
          );
          break;
        case 'end_time':
          _filteredProjects.sort(
            (a, b) => (a['end_data'] ?? '').compareTo(b['end_data'] ?? ''),
          );
          break;
      }
    });
  }
}
