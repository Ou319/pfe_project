import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../ressourses/colormanager.dart';

class ProblemDetailWorker extends StatefulWidget {
  final Map<String, dynamic> problem;

  const ProblemDetailWorker({Key? key, required this.problem}) : super(key: key);

  @override
  State<ProblemDetailWorker> createState() => _ProblemDetailWorkerState();
}

class _ProblemDetailWorkerState extends State<ProblemDetailWorker> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  Map<String, dynamic>? _problemRelation;

  @override
  void initState() {
    super.initState();
    _loadProblemRelation();
  }

  Future<void> _loadProblemRelation() async {
    try {
      setState(() => _isLoading = true);
      
      final response = await _supabase
          .from('propleme_relation')
          .select('*')
          .eq('id_propleme', widget.problem['id'])
          .maybeSingle();

      if (response != null) {
        setState(() {
          _problemRelation = response;
        });
      }
    } catch (e) {
      print('Error loading problem relation: $e');
    } finally {
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

  Future<void> _markProblemAsFixed() async {
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
      await _supabase
          .from('proplemes')
          .update({
            'status': 'resolved',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.problem['id']);

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
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // Custom App Bar with Image
                SliverAppBar(
                  expandedHeight: 250,
                  pinned: true,
                  backgroundColor: Colors.white,
                  flexibleSpace: FlexibleSpaceBar(
                    background: widget.problem['image_url'] != null
                        ? Stack(
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
                              // Gradient overlay
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withOpacity(0.7),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Container(
                            color: Colors.grey[200],
                            child: Center(
                              child: Icon(
                                Icons.image_not_supported,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                            ),
                          ),
                  ),
                  leading: IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),

                // Problem Details
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title and Status
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                widget.problem['title'] ?? 'No Title',
                                style: GoogleFonts.poppins(
                                  fontSize: 24,
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
                                color: widget.problem['status'] == 'resolved'
                                    ? Colors.green
                                    : AppColor.primary,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                widget.problem['status'] == 'resolved'
                                    ? 'Resolved'
                                    : 'In Progress',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
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
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Text(
                            widget.problem['description'] ?? 'No description',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: Colors.grey[800],
                              height: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Time Information
                        Text(
                          'Time Information',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.withOpacity(0.3)),
                          ),
                          child: Column(
                            children: [
                              _buildTimeInfoRow(
                                'Start Date',
                                _formatDate(_problemRelation?['time_start']),
                                Icons.calendar_today,
                              ),
                              const SizedBox(height: 12),
                              _buildTimeInfoRow(
                                'End Date',
                                _formatDate(_problemRelation?['time_end']),
                                Icons.calendar_today,
                              ),
                              const SizedBox(height: 12),
                              _buildTimeInfoRow(
                                'Mission',
                                _problemRelation?['mission'] ?? 'No mission specified',
                                Icons.assignment,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Mark as Fixed Button
                        if (widget.problem['status'] != 'resolved')
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _markProblemAsFixed,
                              icon: const Icon(Icons.check_circle_outline),
                              label: Text(
                                'Mark as Fixed',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
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

  Widget _buildTimeInfoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.blue, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
} 