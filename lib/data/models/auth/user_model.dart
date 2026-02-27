import 'package:json_annotation/json_annotation.dart';

part 'user_model.g.dart';

@JsonSerializable()
class UserModel {
  final String id;
  final String username;
  final String email;

  // Fields returned by real API
  final String? role;            // "OWNER"

  @JsonKey(name: 'accountStatus')
  final String? accountStatus;   // "PENDING", "ACTIVE"

  @JsonKey(name: 'isEmailVerified')
  final bool? isEmailVerified;

  @JsonKey(name: 'createdAt')
  final String? createdAt;

  @JsonKey(name: 'updatedAt')
  final String? updatedAt;

  // Stored locally — not from API user object
  @JsonKey(includeFromJson: false, includeToJson: false)
  final String? token;

  // Kept for display — populated from BusinessProvider
  @JsonKey(name: 'business_name', includeFromJson: false)
  final String? businessName;

  const UserModel({
    required this.id,
    required this.username,
    required this.email,
    this.role,
    this.accountStatus,
    this.isEmailVerified,
    this.createdAt,
    this.updatedAt,
    this.token,
    this.businessName,
  });

  UserModel copyWith({
    String? id,
    String? username,
    String? email,
    String? role,
    String? accountStatus,
    bool? isEmailVerified,
    String? createdAt,
    String? updatedAt,
    String? token,
    String? businessName,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      role: role ?? this.role,
      accountStatus: accountStatus ?? this.accountStatus,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      token: token ?? this.token,
      businessName: businessName ?? this.businessName,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);

  Map<String, dynamic> toJson() => _$UserModelToJson(this);
}
