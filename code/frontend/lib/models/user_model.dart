import '../core/utils/num_parser.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final String? avatarUrl;
  final String currency;
  final double monthlyIncome;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
    this.currency = 'INR',
    this.monthlyIncome = 60000.0,
  });

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    if (name.isNotEmpty) {
      return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
    }
    return 'U';
  }

  String get effectiveAvatarUrl {
    if (avatarUrl != null && avatarUrl!.trim().isNotEmpty) {
      return avatarUrl!.trim();
    }
    final seed = email.trim().isNotEmpty ? email.trim() : (id.isNotEmpty ? id : name);
    return 'https://api.dicebear.com/10.x/voxel-art/svg?seed=${Uri.encodeComponent(seed)}&backgroundColor=00000000';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'avatarUrl': avatarUrl,
    'currency': currency,
    'monthly_income': monthlyIncome,
  };

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? 'User',
    email: json['email']?.toString() ?? '',
    avatarUrl: json['avatarUrl']?.toString() ?? json['avatar_url']?.toString(),
    currency: json['currency']?.toString() ?? 'INR',
    monthlyIncome: asDouble(
      json['monthly_income'] ?? json['monthlyIncome'],
      60000.0,
    ),
  );
}
