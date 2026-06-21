import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/campaign_providers.dart';
import '../providers/dashboard_providers.dart';
import '../providers/global_ai_advisor_provider.dart';
import '../providers/realtime_providers.dart';
import '../services/realtime_service.dart';
import '../theme/app_colors.dart';
import 'global_ai_advisor.dart';

class AgriAppShell extends ConsumerWidget {
  final List<Widget> screens;

  const AgriAppShell({
    super.key,
    required this.screens,
  });

  static const _items = [
    _NavItem(0, Icons.home_rounded, 'Home'),
    _NavItem(2, Icons.workspaces_rounded, 'Our Field'),
    _NavItem(3, Icons.photo_library_rounded, 'Crop Images'),
    _NavItem(4, Icons.flight_takeoff_rounded, 'Flights'),
    _NavItem(6, Icons.description_rounded, 'Reports'),
    _NavItem(5, Icons.map_rounded, 'Map'),
    _NavItem(7, Icons.task_alt_rounded, 'Alerts'),
    _NavItem(8, Icons.settings_rounded, 'Settings'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTab = ref.watch(currentTabProvider);
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;

    // Leaving the Campaigns/Our Field tab (index 2) drops the open campaign + its AI
    // Advisor scope, so the advisor's current page never goes stale.
    ref.listen<int>(currentTabProvider, (prev, next) {
      if (next != 2) {
        ref.read(selectedFlightCampaignProvider.notifier).clear();
        ref.read(globalAiAdvisorProvider.notifier).clearCampaignContext();
      }
    });

    final bodyContent = IndexedStack(
      index: activeTab == 1 ? 0 : activeTab,
      children: screens,
    );

    if (!isDesktop) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 76), // leave space for bottom AI bar
                child: bodyContent,
              ),
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: GlobalAiCommandBar(),
            ),
            const GlobalAiAdvisorModal(),
          ],
        ),
        bottomNavigationBar: _MobileNavigation(
          items: _items,
          activeTab: activeTab,
          onChanged: (tabIndex) =>
              ref.read(currentTabProvider.notifier).set(tabIndex),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          Positioned.fill(
            child: Column(
              children: [
                const _AgriTopHeader(),
                const _SandboxTabBar(),
                Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1320),
                      child: bodyContent,
                    ),
                  ),
                ),
                // Leave bottom space for the fixed AI bar on desktop
                const SizedBox(height: 80),
              ],
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 12,
            child: GlobalAiCommandBar(),
          ),
          const GlobalAiAdvisorModal(),
        ],
      ),
    );
  }
}

class _AgriTopHeader extends ConsumerWidget {
  const _AgriTopHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connStateAsync = ref.watch(realtimeConnectionProvider);
    Color connectionColor = AppColors.crit;
    String connLabel = 'Offline';

    connStateAsync.whenData((state) {
      if (state == RealtimeConnectionState.connected) {
        connectionColor = AppColors.green;
        connLabel = 'Online';
      } else if (state == RealtimeConnectionState.connecting) {
        connectionColor = AppColors.warn;
        connLabel = 'Connecting';
      }
    });

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.green.withAlpha(28),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.eco_rounded, color: AppColors.green, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Namaste, Kisan Dai/Didi',
                    style: GoogleFonts.spaceGrotesk(
                      color: AppColors.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'AgriDrone Crop Advisor',
                    style: GoogleFonts.spaceGrotesk(
                      color: AppColors.textDim,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // BS season and district weather
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.teal.withAlpha(20),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.teal.withAlpha(60)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, color: AppColors.teal, size: 13),
                    const SizedBox(width: 6),
                    Text(
                      'असार · Paddy Season',
                      style: GoogleFonts.spaceGrotesk(
                        color: AppColors.teal,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.warn.withAlpha(20),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.warn.withAlpha(60)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_queue_rounded, color: AppColors.warn, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'Jhapa, Terai · 28°C · Rainy',
                      style: GoogleFonts.spaceGrotesk(
                        color: AppColors.textDim,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Status dot
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: connectionColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    connLabel,
                    style: GoogleFonts.spaceGrotesk(
                      color: connectionColor,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SandboxTabBar extends ConsumerWidget {
  const _SandboxTabBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTab = ref.watch(currentTabProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: AgriAppShell._items.map((item) {
            final isSelected = activeTab == item.index ||
                (item.index == 2 && activeTab == 5); // Map/Campaign detail redirects
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                selected: isSelected,
                avatar: Icon(
                  item.icon,
                  size: 15,
                  color: isSelected ? Colors.white : AppColors.textDim,
                ),
                label: Text(item.label),
                labelStyle: GoogleFonts.spaceGrotesk(
                  color: isSelected ? Colors.white : AppColors.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
                selectedColor: AppColors.green,
                backgroundColor: AppColors.surface2,
                disabledColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Colors.transparent),
                ),
                onSelected: (selected) {
                  if (selected) {
                    ref.read(currentTabProvider.notifier).set(item.index);
                  }
                },
              ),
            );
          }).toList(),
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
              final selected = items[i].index == activeTab;
              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => onChanged(items[i].index),
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
                        items[i].label,
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
  final int index;
  final IconData icon;
  final String label;

  const _NavItem(this.index, this.icon, this.label);
}
