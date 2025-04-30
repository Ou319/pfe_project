import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../ressourses/colormanager.dart';
import '../problem_detail/problem_detail.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({Key? key}) : super(key: key);

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  List<String> _searchHistory = [];
  bool _isLoading = false;
  bool _isSearching = false;
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _loadSearchHistory();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _slideAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _searchHistory = prefs.getStringList('problem_search_history') ?? [];
    });
  }

  Future<void> _saveSearchHistory(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList('problem_search_history') ?? [];
    
    history.remove(query);
    history.insert(0, query);
    final updatedHistory = history.take(10).toList();
    
    await prefs.setStringList('problem_search_history', updatedHistory);
    setState(() {
      _searchHistory = updatedHistory;
    });
  }

  Future<void> _searchProblems(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _isSearching = true;
    });

    try {
      final response = await _supabase
          .from('proplemes')
          .select('*, profiles!user_id(*)')
          .or('title.ilike.%$query%,description.ilike.%$query%')
          .order('created_at', ascending: false);

      if (response != null) {
        setState(() {
          _searchResults = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
        await _saveSearchHistory(query);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error searching problems: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
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
          onPressed: () {
            _animationController.reverse().then((_) {
              Navigator.pop(context);
            });
          },
        ),
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(20),
          ),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Search problems...',
              border: InputBorder.none,
              hintStyle: TextStyle(color: Colors.grey[400]),
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            style: const TextStyle(color: Colors.black),
            onChanged: (value) {
              _searchProblems(value);
            },
          ),
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, color: Colors.black),
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchResults = [];
                  _isSearching = false;
                });
              },
            ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(_slideAnimation.value * MediaQuery.of(context).size.width, 0),
            child: Opacity(
              opacity: _fadeAnimation.value,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      children: [
                        if (!_isSearching && _searchHistory.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Recent Searches',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  children: _searchHistory.map((query) {
                                    return ActionChip(
                                      label: Text(query),
                                      onPressed: () {
                                        _searchController.text = query;
                                        _searchProblems(query);
                                      },
                                      backgroundColor: Colors.grey[100],
                                      labelStyle: GoogleFonts.poppins(
                                        color: Colors.black87,
                                        fontSize: 14,
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) {
                              final problem = _searchResults[index];
                              final userProfile = problem['profiles'];
                              
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                child: Card(
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: InkWell(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        PageRouteBuilder(
                                          pageBuilder: (context, animation, secondaryAnimation) =>
                                              ProblemDetail(
                                                problem: problem,
                                                userProfile: userProfile,
                                              ),
                                          transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                            return FadeTransition(
                                              opacity: animation,
                                              child: child,
                                            );
                                          },
                                        ),
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 20,
                                                backgroundColor: AppColor.primary,
                                                child: Text(
                                                  userProfile != null
                                                      ? '${userProfile['first_name']?[0] ?? ''}${userProfile['last_name']?[0] ?? ''}'
                                                      : '?',
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
                                                      userProfile != null
                                                          ? '${userProfile['first_name']} ${userProfile['last_name']}'
                                                          : 'Unknown User',
                                                      style: GoogleFonts.poppins(
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                    Text(
                                                      problem['created_at'] != null
                                                          ? DateTime.parse(
                                                                problem['created_at'],
                                                              )
                                                              .toLocal()
                                                              .toString()
                                                              .split('.')[0]
                                                          : '',
                                                      style: GoogleFonts.poppins(
                                                        fontSize: 12,
                                                        color: Colors.grey,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: _getStatusColor(
                                                    problem['status'] ?? '',
                                                  ).withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(20),
                                                ),
                                                child: Text(
                                                  problem['status'] ?? 'Unknown',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 12,
                                                    color: _getStatusColor(
                                                      problem['status'] ?? '',
                                                    ),
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            problem['title'] ?? 'No Title',
                                            style: GoogleFonts.poppins(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            problem['description'] ?? 'No description',
                                            style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              color: Colors.grey[600],
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 12),
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
                                              problem['type'] ?? 'Unknown',
                                              style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                color: AppColor.primary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
            ),
          );
        },
      ),
    );
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
} 