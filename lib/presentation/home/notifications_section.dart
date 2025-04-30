import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../problemsmanage/problem.dart';
import '../ressourses/colormanager.dart';
import '../problem_detail/problem_detail.dart';

class NotificationsSection extends StatefulWidget {
  final Function(int)? onNavigateToProblems;
  
  const NotificationsSection({
    Key? key,
    this.onNavigateToProblems,
  }) : super(key: key);

  @override
  State<NotificationsSection> createState() => _NotificationsSectionState();
}

class _NotificationsSectionState extends State<NotificationsSection> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState(); 
    _loadNotifications();
    _setupRealtimeSubscription();
  }

  void _setupRealtimeSubscription() {
    _supabase
        .from('propleme_relation')
        .stream(primaryKey: ['id'])
        .listen((List<Map<String, dynamic>> data) {
      _loadNotifications();
    });
  }

  Future<void> _loadNotifications() async {
    try {
      setState(() => _isLoading = true);

      final response = await _supabase
          .from('propleme_relation')
          .select('''
            *,
            profiles!inner(
              id,
              first_name,
              last_name
            ),
            proplemes!inner(
              id,
              title,
              description,
              status
            )
          ''')
          .or('is_fixed.eq.true,time_start.gte.${DateTime.now().subtract(const Duration(days: 7)).toIso8601String()}')
          .order('created_at', ascending: false)
          .limit(10);

      print('Notifications response: $response'); // Debug print

      if (response != null) {
        final notifications = List<Map<String, dynamic>>.from(response);
        print('Parsed notifications: $notifications'); // Debug print
        
        if (mounted) {
          setState(() {
            _notifications = notifications;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading notifications: $e');
      if (mounted) {
        setState(() {
          _notifications = [];
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading notifications: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getNotificationMessage(Map<String, dynamic> notification) {
    final userName = '${notification['profiles']['first_name']} ${notification['profiles']['last_name']}';
    final isFixed = notification['is_fixed'] ?? false;
    
    if (isFixed) {
      return '$userName has fixed the problem';
    } else {
      return '$userName has been assigned to this problem';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.notifications_none,
                      color: AppColor.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Recent Updates',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () {
                    if (widget.onNavigateToProblems != null) {
                      widget.onNavigateToProblems!(1);
                    }
                  },
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label: Text(
                    'View All',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColor.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_notifications.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.notifications_off_outlined,
                      size: 48,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No recent updates',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _notifications.length,
              separatorBuilder: (context, index) => Divider(
                color: Colors.grey[100],
                height: 1,
              ),
              itemBuilder: (context, index) {
                final notification = _notifications[index];
                final problem = notification['proplemes'];
                final isFixed = notification['is_fixed'] ?? false;

                return InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProblemDetail(
                          problem: problem,
                          userProfile: null,
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    child: Row(
                      children: [
                        // Status Icon
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isFixed
                                ? Colors.green.withOpacity(0.1)
                                : Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isFixed ? Icons.check_circle : Icons.person_add,
                            color: isFixed ? Colors.green : Colors.blue,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                problem['title'] ?? 'Untitled Problem',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _getNotificationMessage(notification),
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatTimestamp(notification['created_at']),
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey[400],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Arrow Icon
                        Icon(
                          Icons.chevron_right,
                          color: Colors.grey[400],
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return '';
    final date = DateTime.parse(timestamp).toLocal();
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
} 