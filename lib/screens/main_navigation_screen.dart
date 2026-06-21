import 'package:flutter/material.dart';
import 'ai_advisor_screen.dart';
import 'campaigns_screen.dart';
import 'dashboard_screen.dart';
import 'analytics_screen.dart';
import 'drone_screen.dart';
import 'map_screen.dart';
import 'reports_screen.dart';
import 'alerts_screen.dart';
import 'settings_screen.dart';
import '../widgets/agri_app_shell.dart';

/// Navigation wrapper hosting the farmer-ready AgriDrone product tabs.
class MainNavigationScreen extends StatelessWidget {
  const MainNavigationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Order must match AgriAppShell._items and aiAdvisorPageLabels.
    final List<Widget> screens = [
      const DashboardScreen(), // Farm Home
      const AiAdvisorScreen(), // AI Advisor
      const CampaignsScreen(), // Campaigns
      const AnalyticsScreen(), // Crop Images
      const DroneScreen(), // Drone Activity
      const MapScreen(), // Field Map
      const ReportsScreen(), // Reports
      const AlertsScreen(), // Action Plan
      const SettingsScreen(), // Settings
    ];

    return AgriAppShell(screens: screens);
  }
}
