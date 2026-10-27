import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import 'dashboard_screen.dart';
import 'quran_screen.dart';
import 'hadith_adhkar_screen.dart';
import 'utilities_screen.dart';
import 'settings_screen.dart';

class MainNavigation extends ConsumerStatefulWidget {
  const MainNavigation({super.key});

  @override
  ConsumerState<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends ConsumerState<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const QuranScreen(),
    const HadithAdhkarScreen(),
    const UtilitiesScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final theme = settings.palette;
    final isRTL = settings.language == 'ku' || settings.language == 'ar';

    final tabHome = settings.language == 'ku' ? 'سەرەکی' : settings.language == 'ar' ? 'الرئيسية' : 'Home';
    final tabQuran = settings.language == 'ku' ? 'قورئان' : settings.language == 'ar' ? 'القرآن' : 'Quran';
    final tabDua = settings.language == 'ku' ? 'زیکر و دوعا' : settings.language == 'ar' ? 'الأذكار' : 'Adhkar';
    final tabUtils = settings.language == 'ku' ? 'بەشەکانی تر' : settings.language == 'ar' ? 'أقسام أخرى' : 'Explore';
    final tabSettings = settings.language == 'ku' ? 'ڕێکخستن' : settings.language == 'ar' ? 'الإعدادات' : 'Settings';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Directionality(
        textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
        child: Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            border: Border(
              top: BorderSide(
                color: Colors.white.withOpacity(0.08),
                width: 1.0,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 64,
              child: Row(
                children: [
                  _buildNavItem(
                    index: 0,
                    label: tabHome,
                    activeIcon: Icons.home_rounded,
                    inactiveIcon: Icons.home_outlined,
                    primaryColor: theme.primaryColor,
                  ),
                  _buildNavItem(
                    index: 1,
                    label: tabQuran,
                    activeIcon: Icons.menu_book_rounded,
                    inactiveIcon: Icons.menu_book_outlined,
                    primaryColor: theme.primaryColor,
                  ),
                  _buildNavItem(
                    index: 2,
                    label: tabDua,
                    activeIcon: Icons.auto_stories_rounded,
                    inactiveIcon: Icons.auto_stories_outlined,
                    primaryColor: theme.primaryColor,
                  ),
                  _buildNavItem(
                    index: 3,
                    label: tabUtils,
                    activeIcon: Icons.grid_view_rounded,
                    inactiveIcon: Icons.grid_view_outlined,
                    primaryColor: theme.primaryColor,
                  ),
                  _buildNavItem(
                    index: 4,
                    label: tabSettings,
                    activeIcon: Icons.settings_rounded,
                    inactiveIcon: Icons.settings_outlined,
                    primaryColor: theme.primaryColor,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String label,
    required IconData activeIcon,
    required IconData inactiveIcon,
    required Color primaryColor,
  }) {
    final isSelected = _currentIndex == index;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (_currentIndex != index) {
            HapticFeedback.selectionClick();
            setState(() {
              _currentIndex = index;
            });
          }
        },
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.symmetric(
              horizontal: isSelected ? 12 : 6,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: isSelected ? primaryColor.withOpacity(0.16) : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? primaryColor.withOpacity(0.35) : Colors.transparent,
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isSelected ? activeIcon : inactiveIcon,
                  size: 22,
                  color: isSelected ? primaryColor : Colors.white.withOpacity(0.45),
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? primaryColor : Colors.white.withOpacity(0.45),
                      fontFamily: 'Rabar',
                    ),
                    maxLines: 1,
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
