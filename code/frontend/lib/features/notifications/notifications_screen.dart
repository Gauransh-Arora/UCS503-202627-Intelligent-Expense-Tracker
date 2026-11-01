import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../models/notification_model.dart';
import '../../services/api_service.dart';
import '../../services/local_notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isLoading = true;
  bool _isTriggering = false;
  int _selectedFilter = 0; // 0: All, 1: Unread
  List<NotificationItemModel> _notifications = [];
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        ApiService.getNotifications(
          unreadOnly: _selectedFilter == 1,
          forceRefresh: forceRefresh,
        ),
        ApiService.getUnreadNotificationCount(forceRefresh: forceRefresh),
      ]);
      if (!mounted) return;
      setState(() {
        _notifications = results[0] as List<NotificationItemModel>;
        _unreadCount = results[1] as int;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load notifications: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _markAsRead(NotificationItemModel item) async {
    if (item.isRead) return;
    try {
      await ApiService.markNotificationAsRead(item.id);
      setState(() {
        final index = _notifications.indexWhere((n) => n.id == item.id);
        if (index != -1) {
          _notifications[index] = item.copyWith(isRead: true);
        }
        if (_unreadCount > 0) _unreadCount--;
      });
    } catch (e) {
      // Ignored for non-blocking UI
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      await ApiService.markAllNotificationsAsRead();
      setState(() {
        _notifications = _notifications
            .map((n) => n.copyWith(isRead: true))
            .toList();
        _unreadCount = 0;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All notifications marked as read'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  Future<void> _triggerAutoScan() async {
    setState(() => _isTriggering = true);
    try {
      final result = await ApiService.triggerAutoNotifications();
      if (!mounted) return;
      setState(() => _isTriggering = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Scan complete: ${result.generatedCount} alert(s) generated',
          ),
          backgroundColor: AppColors.primary,
        ),
      );
      if (result.notifications.isNotEmpty) {
        LocalNotificationService.showFromNotificationItems(
          result.notifications,
        );
      }
      _loadNotifications();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isTriggering = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Scan failed: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  IconData _iconForType(String type) {
    switch (type.toLowerCase()) {
      case 'spending_alert':
      case 'anomaly':
        return LucideIcons.alertTriangle;
      case 'recurring_reminder':
      case 'subscription':
        return LucideIcons.repeat;
      case 'shared_debt':
      case 'split':
        return LucideIcons.users;
      case 'wishlist_ready':
      case 'wishlist':
        return LucideIcons.heart;
      default:
        return LucideIcons.bell;
    }
  }

  Color _colorForType(String type) {
    switch (type.toLowerCase()) {
      case 'spending_alert':
      case 'anomaly':
        return AppColors.warning;
      case 'recurring_reminder':
      case 'subscription':
        return AppColors.info;
      case 'shared_debt':
      case 'split':
        return AppColors.catBills;
      case 'wishlist_ready':
      case 'wishlist':
        return AppColors.success;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Notifications'),
            if (_unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  '$_unreadCount',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Run Scan',
            icon: _isTriggering
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(LucideIcons.rotateCcw, size: 20),
            onPressed: _isTriggering ? null : _triggerAutoScan,
          ),
          if (_unreadCount > 0)
            IconButton(
              tooltip: 'Mark All Read',
              icon: const Icon(LucideIcons.checkCheck, size: 20),
              onPressed: _markAllAsRead,
            ),
        ],
      ),
      body: Column(
        children: [
          // Filter Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip('All', 0),
                const SizedBox(width: 8),
                _buildFilterChip('Unread ($_unreadCount)', 1),
              ],
            ),
          ),

          // Notification List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () => _loadNotifications(forceRefresh: true),
                    child: _notifications.isEmpty
                        ? _buildEmptyState()
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                            itemCount: _notifications.length,
                            separatorBuilder: (_, index) =>
                                const SizedBox(height: 6),
                            itemBuilder: (context, index) {
                              final item = _notifications[index];
                              return _buildNotificationCard(item);
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, int index) {
    final isSelected = _selectedFilter == index;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedFilter = index);
        _loadNotifications();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard(NotificationItemModel item) {
    final typeColor = _colorForType(item.notificationType);
    final typeIcon = _iconForType(item.notificationType);

    return InkWell(
      onTap: () => _markAsRead(item),
      borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: item.isRead
              ? AppColors.surfaceCard
              : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
          border: Border.all(
            color: item.isRead
                ? AppColors.border
                : AppColors.primary.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Center(child: Icon(typeIcon, color: typeColor, size: 18)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: item.isRead
                                ? FontWeight.w600
                                : FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (!item.isRead)
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.message,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.timeAgo,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'No Notifications',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            _selectedFilter == 1
                ? 'No unread alerts.'
                : 'Alerts for unusual spending or debt will appear here.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: _triggerAutoScan,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
              ),
            ),
            child: const Text(
              'Scan For Alerts',
              style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
