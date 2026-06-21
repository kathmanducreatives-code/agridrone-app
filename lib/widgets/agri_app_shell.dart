import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/campaign_providers.dart';
import '../providers/dashboard_providers.dart';
import '../providers/demo_mode_provider.dart';
import '../providers/global_ai_advisor_provider.dart';
import '../theme/app_colors.dart';
import 'global_ai_advisor.dart';

class AgriAppShell extends ConsumerWidget {
  final List<Widget> screens;

  const AgriAppShell({
    super.key,
    required this.screens,
  });

  static const _items = [
    _NavItem(Icons.home_rounded, 'Farm Home'),
    _NavItem(Icons.eco_rounded, 'AI Advisor'),
    _NavItem(Icons.workspaces_rounded, 'Campaigns'),
    _NavItem(Icons.photo_library_rounded, 'Crop Images'),
    _NavItem(Icons.flight_takeoff_rounded, 'Drone Activity'),
    _NavItem(Icons.map_rounded, 'Field Map'),
    _NavItem(Icons.description_rounded, 'Reports'),
    _NavItem(Icons.task_alt_rounded, 'Action Plan'),
    _NavItem(Icons.tune_rounded, 'Settings'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTab = ref.watch(currentTabProvider);
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;

    // Leaving the Campaigns tab (index 2) drops the open campaign + its AI
    // Advisor scope, so the advisor's current page never goes stale.
    ref.listen<int>(currentTabProvider, (prev, next) {
      if (next != 2) {
        ref.read(selectedFlightCampaignProvider.notifier).clear();
        ref.read(globalAiAdvisorProvider.notifier).clearCampaignContext();
      }
    });

    if (!isDesktop) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: Stack(
          children: [
            IndexedStack(index: activeTab, children: screens),
            const GlobalAiAdvisorOverlay(hasBottomNavigation: true),
          ],
        ),
        bottomNavigationBar: _MobileNavigation(
          items: _items,
          activeTab: activeTab,
          onChanged: (index) =>
              ref.read(currentTabProvider.notifier).set(index),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          Row(
            children: [
              _Sidebar(
                items: _items,
                activeTab: activeTab,
                onChanged: (index) =>
                    ref.read(currentTabProvider.notifier).set(index),
              ),
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFF7FBF6),
                        Color(0xFFFFFFFF),
                        Color(0xFFEFF8EF),
                      ],
                    ),
                  ),
                  child: IndexedStack(index: activeTab, children: screens),
                ),
              ),
            ],
          ),
          const GlobalAiAdvisorOverlay(hasBottomNavigation: false),
        ],
      ),
    );
  }
}

class _Sidebar extends ConsumerWidget {
  final List<_NavItem> items;
  final int activeTab;
  final ValueChanged<int> onChanged;

  const _Sidebar({
    required this.items,
    required this.activeTab,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demoMode = ref.watch(demoModeProvider);
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: 262,
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(220),
            border: const Border(right: BorderSide(color: AppColors.line)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.green,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.green.withAlpha(70),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.eco_rounded,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AgriDrone',
                          style: GoogleFonts.spaceGrotesk(
                            color: AppColors.text,
                            fontSize: 18,
                            height: 1,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'Guardian',
                          style: GoogleFonts.spaceGrotesk(
                            color: AppColors.green,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text(
                'Crop Health Platform',
                style: GoogleFonts.spaceGrotesk(
                  color: AppColors.textFaint,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              // Scrollable so ten nav items never overflow on short screens.
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    for (int i = 0; i < items.length; i++)
                      _SidebarButton(
                        item: items[i],
                        selected: i == activeTab,
                        onTap: () => onChanged(i),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.green.withAlpha(18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.green.withAlpha(55)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.auto_awesome_rounded,
                            color: AppColors.greenDeep, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          demoMode ? 'Demo Preview' : 'Live Data Mode',
                          style: GoogleFonts.spaceGrotesk(
                            color: AppColors.greenDeep,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      demoMode
                          ? demoPreviewLabel
                          : 'Live farm data is shown when cloud sync is available.',
                      style: GoogleFonts.spaceGrotesk(
                        color: AppColors.textDim,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Switch.adaptive(
                      value: demoMode,
                      activeThumbColor: AppColors.green,
                      activeTrackColor: AppColors.green.withAlpha(70),
                      onChanged: (value) =>
                          ref.read(demoModeProvider.notifier).setEnabled(value),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarButton extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? AppColors.green.withAlpha(26) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: selected
                  ? Border.all(color: AppColors.green.withAlpha(70))
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  color: selected ? AppColors.greenDeep : AppColors.textDim,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.label,
                    style: GoogleFonts.spaceGrotesk(
                      color: selected ? AppColors.greenDeep : AppColors.textDim,
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileNavigation extends StatelessWidget {
  final List<_NavItem> items;
  final int activeTab;
  final ValueChanged<int> onChanged;

  const _MobileNavigation({
    required this.items,
    required this.activeTab,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Ten farmer-ready tabs do not fit a fixed bar on a phone, so the bar
    // scrolls horizontally and keeps the active tab in view.
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 66,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final selected = i == activeTab;
              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => onChanged(i),
                child: Container(
                  width: 72,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.green.withAlpha(20)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        items[i].icon,
                        size: 20,
                        color: selected
                            ? AppColors.greenDeep
                            : AppColors.textFaint,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        items[i].label.split(' ').first,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.spaceGrotesk(
                          fontWeight:
                              selected ? FontWeight.w800 : FontWeight.w600,
                          fontSize: 10,
                          color: selected
                              ? AppColors.greenDeep
                              : AppColors.textFaint,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;

  const _NavItem(this.icon, this.label);
}
