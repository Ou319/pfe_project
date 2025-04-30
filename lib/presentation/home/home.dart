import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import '../project/project.dart';
import '../ressourses/colormanager.dart';
import '../ressourses/valuesmanager.dart';
import '../problem_detail/problem_detail.dart';
import '../project_users/project_users.dart';
import '../problemsmanage/problem.dart';
import 'notifications_section.dart';
import 'chart_section.dart';

class HomePage extends StatefulWidget {
  final Function(int)? onNavigate;
  
  const HomePage({Key? key, this.onNavigate}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _supabase = Supabase.instance.client;
  String _projectName = '';
  bool _isLoading = true;
  List<Map<String, dynamic>> _problems = [];
  Map<String, Map<String, dynamic>> _userProfiles = {};
  Map<String, int> _problemTypeCounts = {};
  String? _selectedType;
  String? _selectedStatus;
  List<Map<String, dynamic>> _filteredProblems = [];

  // Pagination variables
  static const int _pageSize = 20;
  int _currentPage = 0;
  bool _hasMoreData = true;
  bool _isLoadingMore = false;

  // Cache for user profiles
  final Map<String, Map<String, dynamic>> _profileCache = {};

  // Scroll controller for lazy loading
  final ScrollController _scrollController = ScrollController();

  int _selectedIndex = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadProblems();
    _setupRealtimeSubscription();
    _setupScrollListener();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _loadMoreProblems();
      }
    });
  }

  Future<void> _loadMoreProblems() async {
    if (_isLoadingMore || !_hasMoreData) return;

    setState(() => _isLoadingMore = true);
    try {
      final nextPage = _currentPage + 1;
      final response = await _supabase
          .from('proplemes')
          .select('''
            *,
            propleme_relation!left(
              id,
              id_user,
              time_start,
              time_end,
              is_fixed,
              profiles!inner(
                id,
                first_name,
                last_name
              )
            )
          ''')
          .order('created_at', ascending: false)
          .range(nextPage * _pageSize, (nextPage + 1) * _pageSize - 1);

      if (response != null && response.isNotEmpty) {
        final newProblems = List<Map<String, dynamic>>.from(response);

        // Fetch user profiles for new problems
        for (var problem in newProblems) {
          if (problem['user_id'] != null &&
              !_profileCache.containsKey(problem['user_id'])) {
            final userResponse =
                await _supabase
                    .from('profiles')
                    .select()
                    .eq('id', problem['user_id'])
                    .maybeSingle();

            if (userResponse != null) {
              _profileCache[problem['user_id']] = userResponse;
            }
          }
        }

        if (mounted) {
          setState(() {
            _problems.addAll(newProblems);
            _userProfiles = Map.from(_profileCache);
            _currentPage = nextPage;
            _hasMoreData = response.length == _pageSize;
          });
          _updateProblemTypeCounts();
        }
      } else {
        setState(() => _hasMoreData = false);
      }
    } catch (e) {
      print('Error loading more problems: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  Future<void> _loadProblems() async {
    try {
      setState(() {
        _isLoading = true;
        _currentPage = 0;
        _hasMoreData = true;
        _problems.clear();
        _profileCache.clear();
      });

      // Updated query to include problem relation and assigned user info
      final response = await _supabase
          .from('proplemes')
          .select('''
            *,
            propleme_relation!left(
              id,
              id_user,
              time_start,
              time_end,
              is_fixed,
              profiles!inner(
                id,
                first_name,
                last_name
              )
            )
          ''')
          .order('created_at', ascending: false)
          .limit(_pageSize);

      if (response != null) {
        final problems = List<Map<String, dynamic>>.from(response);

        // Fetch user profiles for all problems
        for (var problem in problems) {
          if (problem['user_id'] != null &&
              !_profileCache.containsKey(problem['user_id'])) {
            final userResponse =
                await _supabase
                    .from('profiles')
                    .select()
                    .eq('id', problem['user_id'])
                    .maybeSingle();

            if (userResponse != null) {
              _profileCache[problem['user_id']] = userResponse;
            }
          }
        }

        if (mounted) {
          setState(() {
            _problems = problems;
            _userProfiles = Map.from(_profileCache);
            _isLoading = false;
            _hasMoreData = response.length == _pageSize;
          });
          _updateProblemTypeCounts();
        }
      }
    } catch (e) {
      print('Error loading problems: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading problems: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  void _updateProblemTypeCounts() {
    final counts = <String, int>{};
    for (var problem in _problems) {
      final type = problem['type'] ?? 'Unknown';
      counts[type] = (counts[type] ?? 0) + 1;
    }
    setState(() {
      _problemTypeCounts = counts;
    });
  }

  // Memoize the chart data to prevent unnecessary rebuilds
  late final _chartData = _buildChartData();

  BarChartData _buildChartData() {
    // Pre-calculate data
    final problemTypes = _problemTypeCounts.keys.toList();
    final Map<String, Map<String, int>> statusCounts = {};

    // Calculate max value for scaling
    int maxCount = 0;

    for (var problem in _problems) {
      final type = problem['type'] ?? 'Unknown';
      final status = problem['status'] ?? 'Unknown';

      if (!statusCounts.containsKey(type)) {
        statusCounts[type] = {'pending': 0, 'in_progress': 0, 'resolved': 0};
      }
      statusCounts[type]![status] = (statusCounts[type]![status] ?? 0) + 1;

      // Update max count
      final total = statusCounts[type]!.values.reduce((a, b) => a + b);
      if (total > maxCount) {
        maxCount = total;
      }
    }

    // Calculate interval based on max count
    final interval = (maxCount / 10).ceil();
    final adjustedMaxY = (interval * 10).toDouble();

    // Limit the number of problem types shown to improve performance
    final displayTypes = problemTypes.take(8).toList();

    return BarChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: interval.toDouble(),
        getDrawingHorizontalLine: (value) {
          return FlLine(
            color: Colors.grey.withOpacity(0.1),
            strokeWidth: 1,
            dashArray: [5, 5],
          );
        },
      ),
      titlesData: FlTitlesData(
        show: true,
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            getTitlesWidget: (value, meta) {
              if (value.toInt() >= 0 && value.toInt() < displayTypes.length) {
                final isSelected = _selectedType == displayTypes[value.toInt()];
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    displayTypes[value.toInt()],
                    style: TextStyle(
                      color: isSelected ? AppColor.primary : Colors.grey,
                      fontSize: 10,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                );
              }
              return const Text('');
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: interval.toDouble(),
            getTitlesWidget: (value, meta) {
              return Text(
                value.toInt().toString(),
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      barGroups: List.generate(displayTypes.length, (index) {
        final type = displayTypes[index];
        final counts = statusCounts[type]!;
        final isSelected = _selectedType == type;

        return BarChartGroupData(
          x: index,
          groupVertically: true,
          barRods: [
            BarChartRodData(
              toY: counts['pending']!.toDouble(),
              color: Colors.orange,
              width: isSelected ? 12 : 8,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(6),
              ),
            ),
            BarChartRodData(
              toY: counts['in_progress']!.toDouble(),
              color: Colors.blue,
              width: isSelected ? 12 : 8,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(6),
              ),
            ),
            BarChartRodData(
              toY: counts['resolved']!.toDouble(),
              color: Colors.green,
              width: isSelected ? 12 : 8,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(6),
              ),
            ),
          ],
        );
      }),
      maxY: adjustedMaxY,
      barTouchData: BarTouchData(
        enabled: true,
        touchTooltipData: BarTouchTooltipData(
          tooltipBgColor: Colors.white,
          tooltipRoundedRadius: 8,
          tooltipPadding: const EdgeInsets.all(8),
          tooltipMargin: 8,
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            final type = displayTypes[groupIndex];
            final status = ['pending', 'in_progress', 'resolved'][rodIndex];
            final count = statusCounts[type]![status]!;

            return BarTooltipItem(
              '$status: $count',
              TextStyle(color: rod.color, fontWeight: FontWeight.bold),
            );
          },
        ),
        handleBuiltInTouches: false,
        touchCallback: (FlTouchEvent event, BarTouchResponse? response) {
          if (response?.spot != null && event is FlTapUpEvent) {
            final type = displayTypes[response!.spot!.touchedBarGroupIndex];
            if (mounted) {
              setState(() {
                _selectedType = _selectedType == type ? null : type;
                if (_selectedType != null) {
                  _filteredProblems =
                      _problems.where((p) => p['type'] == type).toList();
                }
              });
            }
          }
        },
      ),
    );
  }

  Widget _buildChart() {
    if (_problemTypeCounts.isEmpty) {
      return const Center(child: Text('No data available for chart'));
    }

    return Container(
      height: 300,
      padding: const EdgeInsets.all(16),
      child: BarChart(_chartData),
    );
  }

  void _setupRealtimeSubscription() {
    _supabase.from('proplemes').stream(primaryKey: ['id']).listen((
      List<Map<String, dynamic>> data,
    ) {
      setState(() {
        _problems = data;
        _updateProblemTypeCounts();
        if (_selectedType != null) {
          _filteredProblems =
              _problems.where((p) => p['type'] == _selectedType).toList();
        }
      });
    });
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);
      final prefs = await SharedPreferences.getInstance();
      final projectId = prefs.getString('selected_project_id');

      if (projectId != null) {
        final response =
            await _supabase
                .from('projects')
                .select()
                .eq('id', projectId)
                .single();

        setState(() {
          _projectName = response['name'] ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading data: $e');
      setState(() => _isLoading = false);
    }
  }

  Widget _buildStatusChart() {
    // Calculate status counts
    final Map<String, int> statusCounts = {
      'pending': 0,
      'in_progress': 0,
      'resolved': 0,
    };

    for (var problem in _problems) {
      final status = problem['status'] ?? 'Unknown';
      if (statusCounts.containsKey(status)) {
        statusCounts[status] = (statusCounts[status] ?? 0) + 1;
      }
    }

    final total = statusCounts.values.reduce((a, b) => a + b);
    if (total == 0) {
      return const Center(child: Text('No data available for chart'));
    }

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      child: PieChart(
        PieChartData(
          sections: [
            PieChartSectionData(
              value: statusCounts['pending']!.toDouble(),
              title:
                  '${((statusCounts['pending']! / total) * 100).toStringAsFixed(1)}%',
              color: Colors.orange,
              radius: _selectedStatus == 'pending' ? 90 : 80,
              titleStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            PieChartSectionData(
              value: statusCounts['in_progress']!.toDouble(),
              title:
                  '${((statusCounts['in_progress']! / total) * 100).toStringAsFixed(1)}%',
              color: Colors.blue,
              radius: _selectedStatus == 'in_progress' ? 90 : 80,
              titleStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            PieChartSectionData(
              value: statusCounts['resolved']!.toDouble(),
              title:
                  '${((statusCounts['resolved']! / total) * 100).toStringAsFixed(1)}%',
              color: Colors.green,
              radius: _selectedStatus == 'resolved' ? 90 : 80,
              titleStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
          sectionsSpace: 2,
          centerSpaceRadius: 40,
          startDegreeOffset: -90,
          pieTouchData: PieTouchData(
            touchCallback: (FlTouchEvent event, pieTouchResponse) {
              if (event is FlTapUpEvent &&
                  pieTouchResponse?.touchedSection != null) {
                final status =
                    ['pending', 'in_progress', 'resolved'][pieTouchResponse!
                        .touchedSection!
                        .touchedSectionIndex];
                setState(() {
                  _selectedStatus = _selectedStatus == status ? null : status;
                  if (_selectedStatus != null) {
                    _filteredProblems =
                        _problems
                            .where((p) => p['status'] == _selectedStatus)
                            .toList();
                  }
                });
              }
            },
          ),
        ),
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Project Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.05),
                      spreadRadius: 1,
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.folder_outlined,
                          color: AppColor.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Current Project',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              _projectName.isNotEmpty ? _projectName : 'No Project Selected',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        color: AppColor.primary,
                      ),
                      onSelected: (value) {
                        switch (value) {
                          case 'change_project':
                            Navigator.pushNamed(context, '/project');
                            break;
                          case 'project_settings':
                            // Add project settings navigation here
                            break;
                        }
                      },
                      itemBuilder: (BuildContext context) => [
                        PopupMenuItem<String>(
                          value: 'change_project',
                          child: Row(
                            children: [
                              Icon(Icons.swap_horiz, color: AppColor.primary, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Change Project',
                                style: GoogleFonts.poppins(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem<String>(
                          value: 'project_settings',
                          child: Row(
                            children: [
                              Icon(Icons.settings, color: AppColor.primary, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Project Settings',
                                style: GoogleFonts.poppins(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ChartSection(),
              NotificationsSection(
                onNavigateToProblems: (index) {
                  if (widget.onNavigate != null) {
                    widget.onNavigate!(2); // Index 2 is for Problems
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getInitials(String firstName, String lastName) {
    return '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}'
        .toUpperCase();
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

  // Add this helper function to get assigned user info
  Widget _buildAssignmentInfo(Map<String, dynamic> problem) {
    final problemRelation = problem['propleme_relation'];
    if (problemRelation == null || problemRelation.isEmpty) {
      return const SizedBox.shrink();
    }

    final relation = problemRelation[0]; // Get the first relation
    if (relation == null || relation['profiles'] == null) {
      return const SizedBox.shrink();
    }

    final assignedUser = relation['profiles'];
    final isFixed = relation['is_fixed'] ?? false;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isFixed ? Colors.green.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isFixed ? Colors.green.withOpacity(0.3) : Colors.blue.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isFixed ? Icons.check_circle : Icons.person,
            size: 16,
            color: isFixed ? Colors.green : Colors.blue,
          ),
          const SizedBox(width: 6),
          Text(
            isFixed 
              ? 'Fixed by ${assignedUser['first_name']} ${assignedUser['last_name']}'
              : 'Assigned to ${assignedUser['first_name']} ${assignedUser['last_name']}',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: isFixed ? Colors.green : Colors.blue,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
