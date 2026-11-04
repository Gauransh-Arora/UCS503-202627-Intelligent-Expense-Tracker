import 'package:intl/intl.dart';
import '../../widgets/edit_income_dialog.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_theme.dart';
import '../bank_statement/bank_statements_screen.dart';
import '../../models/user_model.dart';
import '../../models/wishlist_model.dart';
import '../../models/intelligence_model.dart';
import '../../services/api_service.dart';
import '../wishlist/wishlist_screen.dart';
import '../recurring/recurring_screen.dart';
import '../split_expense/shared_expenses_screen.dart';
import '../insights/insights_screen.dart';
import '../../core/constants/app_constants.dart';
import '../../core/routing/app_router.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/user_avatar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _notificationsEnabled = true;
  String _selectedCurrency = 'INR (₹)';
  UserModel? _user;
  int _wishlistCount = 0;
  int _recurringCount = 0;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData({bool forceRefresh = false}) async {
    try {
      final results = await Future.wait([
        ApiService.getCurrentUser(forceRefresh: forceRefresh).catchError(
          (_) =>
              const UserModel(id: '', name: 'User', email: 'user@example.com'),
        ),
        ApiService.getWishlistItems(forceRefresh: forceRefresh)
            .catchError((_) => <WishlistItemModel>[]),
        ApiService.detectRecurringExpenses(forceRefresh: forceRefresh)
            .catchError((_) => <DetectedRecurringModel>[]),
      ]);

      if (mounted) {
        setState(() {
          _user = results[0] as UserModel;
          _wishlistCount = (results[1] as List<WishlistItemModel>).length;
          _recurringCount = (results[2] as List<DetectedRecurringModel>).length;
        });
      }
    } catch (_) {}
  }

  void _showCurrencySelector() {
    final currencies = [
      'INR (₹)',
      'USD (\$)',
      'EUR (€)',
      'GBP (£)',
      'AED (د.إ)',
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTokens.radiusLarge),
        ),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select Currency',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      LucideIcons.x,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 8),
              ...currencies.map(
                (c) => ListTile(
                  dense: true,
                  title: Text(
                    c,
                    style: TextStyle(
                      fontWeight: _selectedCurrency == c
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  trailing: _selectedCurrency == c ? const
                       Icon(
                          LucideIcons.check,
                          color: AppColors.primary,
                          size: 18,
                        )
                      : null,
                  onTap: () {
                    setState(() => _selectedCurrency = c);
                    Navigator.pop(ctx);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text(
          'Are you sure you want to log out of your account?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ApiService.clearToken();
              if (!mounted) return;
              AppRouter.router.go(AppConstants.routeLogin);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    bool isDeleting = false;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surfaceCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
            side: const BorderSide(color: AppColors.border),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
                ),
                child: const Icon(
                  LucideIcons.trash2,
                  color: AppColors.danger,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Delete Account',
                  style: TextStyle(
                    fontFamily: AppTheme.fontSans,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Are you sure you want to permanently delete your account?',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'This will permanently delete all your data including expenses, bank statements, receipts, group splits, and all uploaded files.\n\nThis action cannot be undone.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              if (isDeleting) ...[
                const SizedBox(height: 16),
                const Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.danger),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Deleting account and all data...',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: isDeleting ? null : () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: isDeleting
                  ? null
                  : () async {
                      setDialogState(() => isDeleting = true);
                      try {
                        await ApiService.deleteAccount();
                        if (dialogCtx.mounted) {
                          Navigator.pop(dialogCtx);
                        }
                        scaffoldMessenger.showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Your account and all associated data have been permanently deleted.',
                            ),
                            backgroundColor: AppColors.success,
                          ),
                        );
                        AppRouter.router.go(AppConstants.routeLogin);
                      } catch (e) {
                        if (dialogCtx.mounted) {
                          setDialogState(() => isDeleting = false);
                        }
                        scaffoldMessenger.showSnackBar(
                          SnackBar(
                            content: Text('Failed to delete account: $e'),
                            backgroundColor: AppColors.danger,
                          ),
                        );
                      }
                    },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete Account'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _user ?? const UserModel(id: '', name: 'User', email: '');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Profile')),
      body: RefreshIndicator(
        onRefresh: _loadProfileData,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            // ─── User Profile Header ─────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  UserAvatar(
                    avatarUrl: user.avatarUrl,
                    emailSeed: user.email,
                    initials: user.initials,
                    size: 68,
                    borderRadius: AppTokens.radiusMedium,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user.email,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(
                        AppTokens.radiusSmall,
                      ),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Text(
                      'Active',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ─── Financial Tools ───────────────────────
            const _SectionTitle(title: 'Ledger & Intelligence'),
            _SettingsGroup(
              children: [
                _SettingsTile(
                  icon: LucideIcons.heart,
                  title: 'Wishlist & Purchase Readiness',
                  subtitle: '$_wishlistCount items tracked',
                  onTap: () => Navigator.of(context)
                      .push(
                        MaterialPageRoute(
                          builder: (_) => const WishlistScreen(),
                        ),
                      )
                      .then((_) => _loadProfileData()),
                ),
                const Divider(height: 1, indent: 44, color: AppColors.border),
                _SettingsTile(
                  icon: LucideIcons.repeat,
                  title: 'Recurring Subscriptions & Bills',
                  subtitle: '$_recurringCount commitments',
                  onTap: () => Navigator.of(context)
                      .push(
                        MaterialPageRoute(
                          builder: (_) => const RecurringScreen(),
                        ),
                      )
                      .then((_) => _loadProfileData()),
                ),
                const Divider(height: 1, indent: 44, color: AppColors.border),
                _SettingsTile(
                  icon: LucideIcons.users,
                  title: 'Shared Expenses & Debts',
                  subtitle: 'Manage group splits and settlement',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SharedExpensesScreen(),
                    ),
                  ),
                ),
                const Divider(height: 1, indent: 44, color: AppColors.border),
                _SettingsTile(
                  icon: LucideIcons.shieldCheck,
                  title: 'Spending Insights & Anomalies',
                  subtitle: 'Automated deviation detection',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const InsightsScreen()),
                  ),
                ),
                const Divider(height: 1, indent: 44, color: AppColors.border),
                _SettingsTile(
                  icon: LucideIcons.fileSpreadsheet,
                  title: 'Bank Statements',
                  subtitle: 'Upload and parse statements',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const BankStatementsScreen(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ─── Preferences Section ──────────────────────────────────
            const _SectionTitle(title: 'Preferences'),
            _SettingsGroup(
              children: [
                _SettingsTile(
                  icon: LucideIcons.wallet,
                  title: 'Monthly Income',
                  subtitle: '₹${NumberFormat.decimalPattern('en_IN').format(user.monthlyIncome)} / month',
                  onTap: () async {
                    final newIncome = await showEditIncomeDialog(
                      context,
                      currentIncome: user.monthlyIncome,
                      onSuccess: _loadProfileData,
                    );
                    if (newIncome != null && mounted) {
                      setState(() {
                        _user = UserModel(
                          id: user.id,
                          name: user.name,
                          email: user.email,
                          avatarUrl: user.avatarUrl,
                          currency: user.currency,
                          monthlyIncome: newIncome,
                        );
                      });
                    }
                  },
                ),
                const Divider(height: 1, indent: 44, color: AppColors.border),
                _SettingsTile(
                  icon: LucideIcons.coins,
                  title: 'Currency',
                  subtitle: _selectedCurrency,
                  onTap: _showCurrencySelector,
                ),
                const Divider(height: 1, indent: 44, color: AppColors.border),
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 2,
                  ),
                  secondary: const SizedBox(
                    width: 28,
                    height: 28,
                    child: Center(
                      child: Icon(
                        LucideIcons.bell,
                        color: AppColors.textPrimary,
                        size: 18,
                      ),
                    ),
                  ),
                  title: const Text(
                    'Notifications',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  subtitle: const Text(
                    'Alerts and reminders',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  value: _notificationsEnabled,
                  activeThumbColor: AppColors.primary,
                  onChanged: (val) =>
                      setState(() => _notificationsEnabled = val),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ─── Account & Security ───────────────────────────────────
            const _SectionTitle(title: 'Account & Security'),
            _SettingsGroup(
              children: [
                _SettingsTile(
                  icon: LucideIcons.user,
                  title: 'Personal Information',
                  subtitle: 'Account details and credentials',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Account settings saved')),
                    );
                  },
                ),
                const Divider(height: 1, indent: 44, color: AppColors.border),
                _SettingsTile(
                  icon: LucideIcons.keyRound,
                  title: 'Security & PIN',
                  subtitle: 'Authentication configuration',
                  onTap: () {},
                ),
                const Divider(height: 1, indent: 44, color: AppColors.border),
                _SettingsTile(
                  icon: LucideIcons.download,
                  title: 'Export Financial Report',
                  subtitle: 'Download Excel or CSV summary',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Financial statement exported'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  },
                ),
                const Divider(height: 1, indent: 44, color: AppColors.border),
                _SettingsTile(
                  icon: LucideIcons.trash2,
                  title: 'Delete Account',
                  subtitle: 'Erase account and all associated data',
                  iconColor: AppColors.danger,
                  textColor: AppColors.danger,
                  onTap: _showDeleteAccountDialog,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ─── Logout Button ────────────────────────────────────────
            InkWell(
              onTap: _showLogoutDialog,
              borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
                  border: Border.all(
                    color: AppColors.border,
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      LucideIcons.logOut,
                      color: AppColors.textSecondary,
                      size: 18,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Log Out',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ─── Delete Account Button ────────────────────────────────
            InkWell(
              onTap: _showDeleteAccountDialog,
              borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
                  border: Border.all(
                    color: AppColors.danger.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.trash2,
                      color: AppColors.danger,
                      size: 18,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Delete Account',
                            style: TextStyle(
                              color: AppColors.danger,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Permanently erase account and all stored data',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      LucideIcons.chevronRight,
                      size: 18,
                      color: AppColors.danger.withValues(alpha: 0.6),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // App Branding & Version info
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppLogo(size: 52, borderRadius: AppTokens.radiusMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Intelligent Expense Tracker · v1.0.0',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppColors.textTertiary, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceCard,
      borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(children: children),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? textColor;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: SizedBox(
        width: 28,
        height: 28,
        child: Center(
          child: Icon(icon, color: iconColor ?? AppColors.textPrimary, size: 18),
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: textColor ?? AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
      ),
      trailing: Icon(
        LucideIcons.chevronRight,
        size: 18,
        color: textColor ?? AppColors.textTertiary,
      ),
    );
  }
}
