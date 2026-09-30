import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      HealthHubScreen(isActive: _currentIndex == 1),
      const OrdersListScreen(),
      const HealthPassScreen(),
      const ProfileScreen(),
    ];

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBg = isDark ? const Color(0xFF0F172A) : Colors.white;

    final navItems = [
      _NavItem(Icons.home_outlined, Icons.home_rounded, 'Home'),
      _NavItem(Icons.favorite_outline_rounded, Icons.favorite_rounded, 'Health'),
      _NavItem(Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'Bookings'),
      _NavItem(Icons.shield_outlined, Icons.shield_rounded, 'Health Pass'),
      _NavItem(Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
    ];

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
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.35 : 0.04),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(navItems.length, (idx) {
                final item = navItems[idx];
                final isSelected = _currentIndex == idx;

                return Expanded(
                  child: InkWell(
                    onTap: () {
                      if (_currentIndex != idx) {
                        HapticFeedback.selectionClick();
                        setState(() => _currentIndex = idx);
                      }
                    },
                    borderRadius: BorderRadius.circular(16),
                    splashColor: AppColors.primary.withOpacity(0.1),
                    highlightColor: Colors.transparent,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            padding: EdgeInsets.symmetric(
                              horizontal: isSelected ? 16 : 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (isDark
                                      ? AppColors.primary.withOpacity(0.2)
                                      : AppColors.primarySubtle)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(
                              isSelected ? item.activeIcon : item.icon,
                              size: 22,
                              color: isSelected
                                  ? (isDark ? AppColors.primaryLight : AppColors.primary)
                                  : (isDark ? AppColors.slate400 : AppColors.slate500),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                              color: isSelected
                                  ? (isDark ? AppColors.primaryLight : AppColors.primaryDark)
                                  : (isDark ? AppColors.slate400 : AppColors.slate500),
                              letterSpacing: 0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItem(this.icon, this.activeIcon, this.label);
}

