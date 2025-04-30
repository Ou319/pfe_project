import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../ressourses/colormanager.dart';
import 'chart_details_page.dart';

class ChartSection extends StatefulWidget {
  const ChartSection({Key? key}) : super(key: key);

  @override
  State<ChartSection> createState() => _ChartSectionState();
}

class _ChartSectionState extends State<ChartSection> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  Map<String, int> _statusCounts = {};
  Map<String, int> _typeCounts = {};
  int _totalProblems = 0;
  int _resolvedProblems = 0;
  double _resolutionRate = 0;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    try {
      setState(() => _isLoading = true);

      final response = await _supabase
          .from('proplemes')
          .select('status, type')
          .order('created_at');

      if (response != null) {
        final problems = List<Map<String, dynamic>>.from(response);
        
        // Reset counters
        _statusCounts = {};
        _typeCounts = {};
        _totalProblems = problems.length;
        _resolvedProblems = 0;

        // Count problems by status and type
        for (var problem in problems) {
          final status = problem['status'] as String? ?? 'unknown';
          final type = problem['type'] as String? ?? 'unknown';

          _statusCounts[status] = (_statusCounts[status] ?? 0) + 1;
          _typeCounts[type] = (_typeCounts[type] ?? 0) + 1;

          if (status == 'resolved') {
            _resolvedProblems++;
          }
        }

        // Calculate resolution rate
        _resolutionRate = _totalProblems > 0 
            ? (_resolvedProblems / _totalProblems) * 100 
            : 0;

        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      print('Error loading statistics: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusCounts = {};
          _typeCounts = {};
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(
                  Icons.insert_chart_outlined,
                  color: AppColor.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Problems Overview',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          // Statistics Cards
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _buildStatCard(
                  'Total Problems',
                  _totalProblems.toString(),
                  Icons.bug_report_outlined,
                  Colors.blue,
                ),
                const SizedBox(width: 16),
                _buildStatCard(
                  'Resolution Rate',
                  '${_resolutionRate.toStringAsFixed(1)}%',
                  Icons.check_circle_outline,
                  Colors.green,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Charts
          if (_statusCounts.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Problems by Status',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildStatusChart(),
                ],
              ),
            ),
          ],
          if (_typeCounts.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Problems by Type',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildChart(),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    value,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
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

  void _onChartTapped(String type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChartDetailsPage(
          filterType: 'type',
          filterValue: type,
          statusColor: _getStatusColor(type),
        ),
      ),
    );
  }

  void _onStatusTapped(String status) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChartDetailsPage(
          filterType: 'status',
          filterValue: status,
          statusColor: _getStatusColor(status),
        ),
      ),
    );
  }

  Widget _buildChart() {
    if (_typeCounts.isEmpty) {
      return const Center(child: Text('No data available for chart'));
    }

    return Container(
      height: 300,
      padding: const EdgeInsets.all(16),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: _typeCounts.values.reduce((a, b) => a > b ? a : b).toDouble(),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final types = _typeCounts.keys.toList();
                  if (value >= 0 && value < types.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        types[value.toInt()],
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
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
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(
                showTitles: false,
              ),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(
                showTitles: false,
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(show: false),
          barGroups: _getTypeGroups(),
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              tooltipBgColor: Colors.white,
              tooltipRoundedRadius: 8,
              tooltipPadding: const EdgeInsets.all(8),
              tooltipMargin: 8,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final types = _typeCounts.keys.toList();
                final type = types[group.x];
                final count = _typeCounts[type];
                return BarTooltipItem(
                  '$type: $count',
                  GoogleFonts.poppins(
                    color: AppColor.primary,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
            touchCallback: (FlTouchEvent event, BarTouchResponse? touchResponse) {
              if (event is FlTapUpEvent && touchResponse?.spot != null) {
                final types = _typeCounts.keys.toList();
                final type = types[touchResponse!.spot!.touchedBarGroupIndex];
                _onChartTapped(type);
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChart() {
    if (_statusCounts.isEmpty) {
      return const Center(child: Text('No data available for chart'));
    }

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      child: PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 40,
          sections: _getStatusSections(),
          pieTouchData: PieTouchData(
            enabled: true,
            touchCallback: (FlTouchEvent event, PieTouchResponse? touchResponse) {
              if (event is FlTapUpEvent && touchResponse?.touchedSection != null) {
                final statuses = _statusCounts.keys.toList();
                final status = statuses[touchResponse!.touchedSection!.touchedSectionIndex];
                _onStatusTapped(status);
              }
            },
          ),
        ),
      ),
    );
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

  List<PieChartSectionData> _getStatusSections() {
    final List<Color> colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.red,
      Colors.purple,
    ];

    return _statusCounts.entries.map((entry) {
      final index = _statusCounts.keys.toList().indexOf(entry.key);
      final color = colors[index % colors.length];
      final percentage = (entry.value / _totalProblems) * 100;

      return PieChartSectionData(
        color: color,
        value: entry.value.toDouble(),
        title: '${percentage.toStringAsFixed(1)}%',
        radius: 100,
        titleStyle: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  List<BarChartGroupData> _getTypeGroups() {
    final List<Color> colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
    ];

    return _typeCounts.entries.map((entry) {
      final index = _typeCounts.keys.toList().indexOf(entry.key);
      final color = colors[index % colors.length];

      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: entry.value.toDouble(),
            color: color,
            width: 20,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    }).toList();
  }
} 