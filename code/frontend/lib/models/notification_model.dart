import 'package:intl/intl.dart';

class NotificationItemModel {
  final String id;
  final String userId;
  final String title;
  final String message;
  final String notificationType;
  final bool isRead;
  final DateTime createdAt;

  const NotificationItemModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.notificationType,
    required this.isRead,
    required this.createdAt,
  });

  String get timeAgo {
    final now = DateTime.now();
    final diff = now.difference(createdAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('dd MMM').format(createdAt);
  }

  factory NotificationItemModel.fromJson(Map<String, dynamic> json) {
    return NotificationItemModel(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      notificationType: json['notification_type'] as String? ?? 'system',
      isRead: json['is_read'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  NotificationItemModel copyWith({bool? isRead}) {
    return NotificationItemModel(
      id: id,
      userId: userId,
      title: title,
      message: message,
      notificationType: notificationType,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }
}

class AutoNotificationResult {
  final int generatedCount;
  final List<NotificationItemModel> notifications;

  const AutoNotificationResult({
    required this.generatedCount,
    required this.notifications,
  });

  factory AutoNotificationResult.fromJson(Map<String, dynamic> json) {
    final list = json['notifications'] as List? ?? [];
    return AutoNotificationResult(
      generatedCount: json['generated_count'] as int? ?? list.length,
      notifications: list
          .map((e) => NotificationItemModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
