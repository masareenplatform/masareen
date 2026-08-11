import 'package:json_annotation/json_annotation.dart';

part 'opportunity_model.g.dart';

@JsonSerializable()
class OpportunityModel {
  final String id;
  final String title;
  final String description;
  final String orgId;
  final String status;
  final double minPmsScore;
  final List<String> requiredSkills;
  final double? compensationUsd;
  final String? deadline;

  OpportunityModel({
    required this.id,
    required this.title,
    required this.description,
    required this.orgId,
    required this.status,
    required this.minPmsScore,
    required this.requiredSkills,
    this.compensationUsd,
    this.deadline,
  });

  factory OpportunityModel.fromJson(Map<String, dynamic> json) => _$OpportunityModelFromJson(json);
  Map<String, dynamic> toJson() => _$OpportunityModelToJson(this);
}



