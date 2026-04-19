import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/auth_service.dart';

class WomenDashboardScreen extends StatefulWidget {
  final VoidCallback onLogout;

  const WomenDashboardScreen({super.key, required this.onLogout});

  @override
  State<WomenDashboardScreen> createState() => _WomenDashboardScreenState();
}

class _WomenDashboardScreenState extends State<WomenDashboardScreen> {
  int _selectedIndex = 0;

  // Placeholder views
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      _HomeTab(onLogout: widget.onLogout),
      const _ContactsTab(),
      const _MapTab(),
      const _ProfileTab(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _pages[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(
              blurRadius: 20,
              color: Colors.black.withAlpha(12), // 0.05 opacity
            )
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 8),
            child: GNav(
              rippleColor: AppColors.roseTint,
              hoverColor: AppColors.roseTint,
              gap: 8,
              activeColor: AppColors.rosePrimary,
              iconSize: 24,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              duration: const Duration(milliseconds: 400),
              tabBackgroundColor: AppColors.rosePrimary.withAlpha(25), // 0.1 opacity
              color: AppColors.textSecondary,
              tabs: const [
                GButton(
                  icon: Icons.home,
                  text: 'Home',
                ),
                GButton(
                  icon: Icons.group,
                  text: 'Contacts',
                ),
                GButton(
                  icon: Icons.map,
                  text: 'Routes',
                ),
                GButton(
                  icon: Icons.person,
                  text: 'Profile',
                ),
              ],
              selectedIndex: _selectedIndex,
              onTabChange: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeTab extends StatefulWidget {
  final VoidCallback onLogout;
  const _HomeTab({required this.onLogout});

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  Map<String, dynamic>? _profile;
  bool _isLoadingProfile = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await AuthService.instance.getProfile();
      if (mounted) {
        setState(() {
          _profile = profile;
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to load profile: $e');
      if (mounted) {
        setState(() => _isLoadingProfile = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String name = _profile?['full_name'] ?? 'User';
    final String? photoUrl = _profile?['profile_photo_url'];

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: AppColors.background,
            floating: true,
            automaticallyImplyLeading: false,
            title: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.rosePrimary,
                  backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                  child: photoUrl == null ? const Icon(Icons.person, color: Colors.white, size: 20) : null,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Stay Safe,', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                    _isLoadingProfile
                        ? const SizedBox(
                            width: 50,
                            height: 10,
                            child: LinearProgressIndicator(color: AppColors.rosePrimary),
                          )
                        : Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  ],
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout, color: AppColors.rosePrimary),
                onPressed: widget.onLogout,
              )
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  // SOS Button
                  GestureDetector(
                    onTap: () {
                      // Trigger SOS
                    },
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.red.withAlpha(25),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withAlpha(76),
                            blurRadius: 30,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Container(
                          width: 150,
                          height: 150,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Colors.redAccent, Colors.red],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: const Center(
                            child: Text(
                              'SOS',
                              style: TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Press and hold for 3 seconds to trigger emergency',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 48),

                  // Quick Actions Grid
                  Row(
                    children: [
                      Expanded(
                        child: _ActionCard(
                          title: 'Live Tracking',
                          icon: Icons.near_me,
                          color: AppColors.bluePrimary,
                          onTap: () {},
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _ActionCard(
                          title: 'Fake Call',
                          icon: Icons.phone_in_talk,
                          color: AppColors.greenPrimary,
                          onTap: () {},
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionCard(
                          title: 'Record Audio',
                          icon: Icons.mic,
                          color: Colors.purpleAccent,
                          onTap: () {},
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _ActionCard(
                          title: 'Safe Places',
                          icon: Icons.shield,
                          color: Colors.orangeAccent,
                          onTap: () {},
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: color.withAlpha(25),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withAlpha(76)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactsTab extends StatelessWidget {
  const _ContactsTab();
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Trusted Contacts'));
  }
}

class _MapTab extends StatelessWidget {
  const _MapTab();
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Safe Routes Map'));
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab();
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('User Profile'));
  }
}
