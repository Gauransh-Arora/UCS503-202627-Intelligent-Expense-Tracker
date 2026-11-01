import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_tokens.dart';
import '../features/home/home_screen.dart';
import '../features/expenses/expenses_screen.dart';
import '../features/analytics/analytics_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/add_expense/add_expense_modal.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  final Set<int> _activatedTabs = {0};

  int get _actualTabIndex => _currentIndex == 2
      ? 0
      : (_currentIndex > 2 ? _currentIndex - 1 : _currentIndex);

  void _onTabTapped(int index) {
    final actual = index == 2 ? 0 : (index > 2 ? index - 1 : index);
    setState(() {
      _currentIndex = index;
      _activatedTabs.add(actual);
    });
  }

  void _openAddExpense() {
    AddExpenseModal.show(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _actualTabIndex,
        children: [
          const HomeScreen(),
          _activatedTabs.contains(1)
              ? const ExpensesScreen()
              : const SizedBox.shrink(),
          _activatedTabs.contains(2)
              ? const AnalyticsScreen()
              : const SizedBox.shrink(),
          _activatedTabs.contains(3)
              ? const ProfileScreen()
              : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surfaceCard,
          border: Border(
            top: BorderSide(
              color: AppColors.border,
              width: AppTokens.cardBorderWidth,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x0C20352A),
              offset: Offset(0, -2),
              blurRadius: 4,
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                _NavItem(
                  icon: LucideIcons.layoutDashboard,
                  label: 'Overview',
                  isActive: _currentIndex == 0,
                  onTap: () => _onTabTapped(0),
                ),
                _NavItem(
                  icon: LucideIcons.receipt,
                  label: 'Expenses',
                  isActive: _currentIndex == 1,
                  onTap: () => _onTabTapped(1),
                ),
                // Central Add Button (Tactile chunky 3D Duolingo action button)
                Expanded(
                  child: Center(
                    child: Tooltip(
                      message: 'Add transaction',
                      child: InkWell(
                        onTap: _openAddExpense,
                        borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
                        child: Container(
                          width: 46,
                          height: 46,
                          margin: const EdgeInsets.only(bottom: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
                            border: Border.all(
                              color: AppColors.buttonDepth,
                              width: 1.5,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: AppColors.buttonDepth,
                                offset: Offset(0, 3),
                                blurRadius: 0,
                              ),
                            ],
                          ),
                          child: const Icon(
                            LucideIcons.plus,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                _NavItem(
                  icon: LucideIcons.barChart2,
                  label: 'Analytics',
                  isActive: _currentIndex == 3,
                  onTap: () => _onTabTapped(3),
                ),
                _NavItem(
                  icon: LucideIcons.user,
                  label: 'Account',
                  isActive: _currentIndex == 4,
                  onTap: () => _onTabTapped(4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: isActive ? AppColors.mint : Colors.transparent,
                borderRadius: BorderRadius.circular(AppTokens.radiusFull),
              ),
              child: Icon(
                icon,
                color: isActive ? AppColors.primary : AppColors.textSecondary,
                size: 20,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontFamily: AppTheme.fontSans,
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
