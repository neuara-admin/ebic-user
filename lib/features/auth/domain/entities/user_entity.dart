/// Section 48 & 60 - User Entity
class UserEntity {
  final String id;
  final String phone;
  final String? name;
  final String? email;
  final String role;
  final bool isActive;
  final DateTime? createdAt;

  const UserEntity({
    required this.id,
    required this.phone,
    this.name,
    this.email,
    this.role = 'CUSTOMER',
    this.isActive = true,
    this.createdAt,
  });

  factory UserEntity.fromJson(Map<String, dynamic> json) {
    return UserEntity(
      id: json['id']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      name: json['name'] as String?,
      email: json['email'] as String?,
      role: json['role'] as String? ?? 'CUSTOMER',
      isActive: json['isActive'] as bool? ?? true,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone': phone,
        'name': name,
        'email': email,
        'role': role,
        'isActive': isActive,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      };
}
