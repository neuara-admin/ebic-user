import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'home_screen.dart';
import '../health/health_hub_screen.dart';
import '../orders/orders_list_screen.dart';
import '../health_pass/health_pass_screen.dart';
import '../profile/profile_screen.dart';

/// Module 20 & Specification Section 1 & 29: 5-Destination Primary Bottom Navigation
/// [ Home (🏠) | Health (❤️) | Bookings (📋) | Health Pass (💳) | Profile (👤) ]
class MainNavShell extends StatefulWidget {
  final int initialTab;

  const MainNavShell({super.key, this.initialTab = 0});

  @override
  State<MainNavShell> createState() => _MainNavShellState();
}

class _MainNavShellState extends State<MainNavShell> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;
  }

  void switchTab(int index) {
    if (index >= 0 && index < 5) {
      setState(() => _currentIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(onNavigateTab: switchTab),
      const HealthHubScreen(),
      const OrdersListScreen(),
      const HealthPassScreen(),
      const ProfileScreen(),
    ];

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBg = isDark ? AppColors.slate900 : Colors.white;
    final selectedColor = isDark ? AppColors.primaryLight : AppColors.primary;
    final unselectedColor = isDark ? AppColors.slate400 : AppColors.slate600;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: navBg,
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.slate800 : AppColors.slate200,
              width: 0.8,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.25 : 0.05),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() => _currentIndex = index);
          },
          selectedItemColor: selectedColor,
          unselectedItemColor: unselectedColor,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          type: BottomNavigationBarType.fixed,
          backgroundColor: navBg,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.favorite_outline_rounded),
              activeIcon: Icon(Icons.favorite_rounded),
              label: 'Health',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              activeIcon: Icon(Icons.receipt_long_rounded),
              label: 'Bookings',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.card_membership_outlined),
              activeIcon: Icon(Icons.card_membership_rounded),
              label: 'Health Pass',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

