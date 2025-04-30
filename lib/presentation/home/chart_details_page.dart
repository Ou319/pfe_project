import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../ressourses/colormanager.dart';

class ChartDetailsPage extends StatefulWidget {
  final String filterType;
  final String filterValue;
  final Color statusColor;

  const ChartDetailsPage({
    Key? key,
    required this.filterType,
    required this.filterValue,
    required this.statusColor,
  }) : super(key: key);

  @override
  State<ChartDetailsPage> createState() => _ChartDetailsPageState();
}

class _ChartDetailsPageState extends State<ChartDetailsPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _problems = [];
  final ScrollController _scrollController = ScrollController();
  static const int _pageSize = 20;
  bool _hasMoreData = true;
  bool _isLoadingMore = false;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _loadProblems();
    _setupScrollListener();
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _loadMoreProblems();
      }
    });
  }

  Future<void> _loadProblems() async {
    try {
      setState(() => _isLoading = true);

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
                last_name,
                email
              )
            )
          ''')
          .eq(widget.filterType, widget.filterValue)
          .order('created_at', ascending: false)
          .range(0, _pageSize - 1);

      if (mounted) {
        setState(() {
          _problems = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
          _hasMoreData = response.length == _pageSize;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading problems: $e')),
        );
      }
    }
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
                last_name,
                email
              )
            )
          ''')
          .eq(widget.filterType, widget.filterValue)
          .order('created_at', ascending: false)
          .range(nextPage * _pageSize, (nextPage + 1) * _pageSize - 1);

      if (mounted) {
        setState(() {
          _problems.addAll(List<Map<String, dynamic>>.from(response));
          _currentPage = nextPage;
          _hasMoreData = response.length == _pageSize;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading more problems: $e')),
        );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: widget.statusColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${widget.filterType == 'type' ? 'Problems of type' : 'Problems with status'}: ${widget.filterValue}',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _problems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No problems found',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _problems.length + (_hasMoreData ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _problems.length) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    final problem = _problems[index];
                    final relation = problem['propleme_relation']?[0];
                    final assignedUser = relation?['profiles'];
                    final isFixed = relation?['is_fixed'] ?? false;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
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
                                  problem['title'] ?? 'No Title',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: widget.filterType == 'type'
                                      ? _getStatusColor(problem['status'])
                                          .withOpacity(0.1)
                                      : _getStatusColor(problem['type'])
                                          .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  widget.filterType == 'type'
                                      ? problem['status'] ?? 'Unknown'
                                      : problem['type'] ?? 'Unknown',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: widget.filterType == 'type'
                                        ? _getStatusColor(problem['status'])
                                        : _getStatusColor(problem['type']),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (problem['description'] != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              problem['description'],
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                          if (assignedUser != null) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(
                                  isFixed ? Icons.check_circle : Icons.person,
                                  size: 16,
                                  color: isFixed ? Colors.green : AppColor.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isFixed
                                      ? 'Fixed by ${assignedUser['first_name']} ${assignedUser['last_name']}'
                                      : 'Assigned to ${assignedUser['first_name']} ${assignedUser['last_name']}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: isFixed ? Colors.green : AppColor.primary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 12),
                          Text(
                            'Created: ${DateTime.parse(problem['created_at']).toLocal().toString().split('.')[0]}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
} 