import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import '../ressourses/colormanager.dart';
import 'worker_projects_page.dart';

class WorkerOnboarding extends StatefulWidget {
  const WorkerOnboarding({Key? key}) : super(key: key);

  @override
  State<WorkerOnboarding> createState() => _WorkerOnboardingState();
}

class _WorkerOnboardingState extends State<WorkerOnboarding> with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  late AnimationController _progressController;
  Timer? _timer;
  int _currentPage = 0;
  bool _isUserInteracting = false;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: 'Welcome to Worker Dashboard',
      description: 'Manage and track your assigned problems efficiently',
      imageUrl: 'https://images.unsplash.com/photo-1531403009284-440f080d1e12?ixlib=rb-4.0.3&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&auto=format&fit=crop&w=1470&q=80',
      backgroundColor: const Color(0xFF1E1E1E),
      foregroundColor: Colors.white,
    ),
    OnboardingPage(
      title: 'Your Responsibilities',
      description: 'View and solve problems assigned to you. Update status and provide solutions.',
      imageUrl: 'https://images.unsplash.com/photo-1589652717521-10c0d092dea9?ixlib=rb-4.0.3&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&auto=format&fit=crop&w=1470&q=80',
      backgroundColor: const Color(0xFF1E1E1E),
      foregroundColor: Colors.white,
    ),
    OnboardingPage(
      title: 'Problem Management',
      description: 'Track problem status, communicate with team members, and update progress.',
      imageUrl: 'https://images.unsplash.com/photo-1599658880436-c61792e70672?ixlib=rb-4.0.3&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&auto=format&fit=crop&w=1470&q=80',
      backgroundColor: const Color(0xFF1E1E1E),
      foregroundColor: Colors.white,
    ),
    OnboardingPage(
      title: 'Ready to Start',
      description: 'You\'re all set! Start managing your assigned problems now.',
      imageUrl: 'https://images.unsplash.com/photo-1553877522-43269d4ea984?ixlib=rb-4.0.3&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&auto=format&fit=crop&w=1470&q=80',
      backgroundColor: const Color(0xFF1E1E1E),
      foregroundColor: Colors.white,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..addListener(() {
        setState(() {});
      });
    
    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_isUserInteracting) {
        _nextPage();
      }
    });
    
    _startPageTimer();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _progressController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startPageTimer() {
    _progressController.reset();
    _progressController.forward();
  }

  void _pausePageTimer() {
    _progressController.stop();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
    _startPageTimer();
  }

  Future<void> _completeOnboarding() async {
    _timer?.cancel();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('worker_onboarding_completed', true);
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const WorkerProjectsPage(selectedProject: {}),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTapDown: (details) {
          _isUserInteracting = true;
          _pausePageTimer();
          
          // Instagram-style tap to advance/go back
          final screenWidth = MediaQuery.of(context).size.width;
          if (details.globalPosition.dx < screenWidth / 3) {
            // Left third of screen - go back
            if (_currentPage > 0) {
              _pageController.previousPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
          } else if (details.globalPosition.dx > 2 * screenWidth / 3) {
            // Right third of screen - go forward
            if (_currentPage < _pages.length - 1) {
              _pageController.nextPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            } else {
              _completeOnboarding();
            }
          }
        },
        onTapUp: (_) {
          _isUserInteracting = false;
          _startPageTimer();
        },
        onLongPress: () {
          // Instagram-style long press to pause
          _isUserInteracting = true;
          _pausePageTimer();
        },
        onLongPressUp: () {
          _isUserInteracting = false;
          _startPageTimer();
        },
        child: Stack(
          children: [
            // Page content
            PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              itemCount: _pages.length,
              itemBuilder: (context, index) {
                return _buildPage(_pages[index]);
              },
            ),
            
            // Story progress indicators - Instagram style
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
                child: Row(
                  children: List.generate(
                    _pages.length,
                    (index) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: index < _currentPage
                                ? 1.0
                                : index == _currentPage
                                    ? _progressController.value
                                    : 0.0,
                            backgroundColor: Colors.white.withOpacity(0.3),
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            minHeight: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            
            // Instagram-style top bar with username and time
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    // Circular avatar
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey[800],
                        image: const DecorationImage(
                          image: NetworkImage("https://ui-avatars.com/api/?name=Worker&background=random"),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Username and time
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "worker_app",
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          "Just now",
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            // Instagram-style bottom swipe up indication (only on last page)
            if (_currentPage == _pages.length - 1)
              Positioned(
                bottom: 80,
                left: 0,
                right: 0,
                child: Column(
                  children: [
                    Icon(
                      Icons.keyboard_arrow_up,
                      color: Colors.white,
                      size: 30,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Swipe up to continue',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            
            // Instagram-style reply box at bottom
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.5),
                    ],
                  ),
                ),
                child: Column(
                  children: [
                    // Get Started button (only on last page)
                    if (_currentPage == _pages.length - 1)
                      GestureDetector(
                        onTap: _completeOnboarding,
                        onVerticalDragEnd: (_) => _completeOnboarding(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'GET STARTED',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
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
      ),
    );
  }

  Widget _buildPage(OnboardingPage page) {
    return Container(
      decoration: BoxDecoration(
        color: page.backgroundColor,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Full screen image
          Hero(
            tag: page.imageUrl,
            child: CachedNetworkImage(
              imageUrl: page.imageUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => Center(
                child: CircularProgressIndicator(
                  color: page.foregroundColor,
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: page.backgroundColor,
                child: Center(
                  child: Icon(
                    Icons.error_outline,
                    color: page.foregroundColor,
                    size: 48,
                  ),
                ),
              ),
            ),
          ),
          
          // Dark gradient overlay for better text visibility
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.3),
                  Colors.black.withOpacity(0.7),
                ],
              ),
            ),
          ),
          
          // Main content
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 3),
                // Text content with animations
                AnimatedSlide(
                  offset: const Offset(0, 0),
                  duration: const Duration(milliseconds: 500),
                  child: AnimatedOpacity(
                    opacity: 1.0,
                    duration: const Duration(milliseconds: 500),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        children: [
                          Text(
                            page.title,
                            style: GoogleFonts.poppins(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: page.foregroundColor,
                              shadows: [
                                Shadow(
                                  blurRadius: 10.0,
                                  color: Colors.black.withOpacity(0.5),
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            page.description,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: page.foregroundColor.withOpacity(0.9),
                              height: 1.5,
                              shadows: [
                                Shadow(
                                  blurRadius: 8.0,
                                  color: Colors.black.withOpacity(0.5),
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingPage {
  final String title;
  final String description;
  final String imageUrl;
  final Color backgroundColor;
  final Color foregroundColor;

  OnboardingPage({
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.backgroundColor,
    required this.foregroundColor,
  });
}