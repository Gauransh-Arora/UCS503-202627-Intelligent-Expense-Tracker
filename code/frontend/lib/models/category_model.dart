class CategoryModel {
  final String id;
  final String name;
  final String? icon;
  final bool isDefault;

  const CategoryModel({
    required this.id,
    required this.name,
    this.icon,
    this.isDefault = false,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) => CategoryModel(
        id: json['id']?.toString() ?? '',
        name: json['name'] as String? ?? 'Other',
        icon: json['icon'] as String?,
        isDefault: json['is_default'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon,
        'is_default': isDefault,
      };
}
