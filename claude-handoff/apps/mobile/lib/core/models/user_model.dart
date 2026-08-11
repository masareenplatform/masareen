import 'package:json_annotation/json_annotation.dart';

part 'user_model.g.dart';

@JsonSerializable()
class UserModel {
  final String id;
  final String email;
  final String fullName;
  final String role;
  final int impactAssetCount;
  final double pmsScore;

  UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.impactAssetCount = 0,
    this.pmsScore = 0.0,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => _$UserModelFromJson(json);
  Map<String, dynamic> toJson() => _$UserModelToJson(this);
}



