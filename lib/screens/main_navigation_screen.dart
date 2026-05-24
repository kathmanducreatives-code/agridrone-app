import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/dashboard_providers.dart';
import '../theme/app_colors.dart';
import 'dashboard_screen.dart';
import 'test_ai_screen.dart';    // Test AI Sandbox
import 'analytics_screen.dart'; // Lab
import 'drone_screen.dart';     // Live
import 'map_screen.dart';       // GPS Flight paths map view
import 'alerts_screen.dart';    // Alerts
import 'settings_screen.dart';  // Settings

/// Navigation wrapper hosting the 7 central curation operator tabs.
class MainNavigationScreen extends ConsumerWidget {
  const MainNavigationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTab = ref.watch(currentTabProvider);

    final List<Widget> screens = [
      const DashboardScreen(),
      const TestAiScreen(),    // Test AI Sandbox (Index 1)
      const AnalyticsScreen(), // Lab Curation Grid (Index 2)
      const DroneScreen(),     // Live Card Stream (Index 3)
      const MapScreen(),       // GPS Flight paths map view (Index 4)
      const AlertsScreen(),    // Alerts (Index 5)
      const SettingsScreen(),  // Settings (Index 6)
    ];

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: IndexedStack(
        index: activeTab,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.line, width: 1.0),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: activeTab,
          onTap: (index) => ref.read(currentTabProvider.notifier).set(index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.surface,
          selectedItemColor: AppColors.green,
          unselectedItemColor: AppColors.textDim,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 11,
            fontFamily: 'Space Grotesk',
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.normal,
            fontSize: 11,
            fontFamily: 'Space Grotesk',
          ),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard, color: AppColors.green),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.science_outlined),
              activeIcon: Icon(Icons.science, color: AppColors.green),
              label: 'Test AI',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.biotech_outlined),
              activeIcon: Icon(Icons.biotech, color: AppColors.green),
              label: 'Lab',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bolt_outlined),
              activeIcon: Icon(Icons.bolt, color: AppColors.green),
              label: 'Live',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.map_outlined),
              activeIcon: Icon(Icons.map, color: AppColors.green),
              label: 'Map',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.notifications_none_outlined),
              activeIcon: Icon(Icons.notifications, color: AppColors.green),
              label: 'Alerts',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings, color: AppColors.green),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
