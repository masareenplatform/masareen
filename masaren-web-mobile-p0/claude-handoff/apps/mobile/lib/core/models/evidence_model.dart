import 'package:json_annotation/json_annotation.dart';

part 'evidence_model.g.dart';

@JsonSerializable()
class EvidenceModel {
  final String id;
  final String title;
  final String status;
  final double aiConfidence;
  final String mediaType;
  final String description;

  EvidenceModel({
    required this.id,
    required this.title,
    required this.status,
    required this.aiConfidence,
    required this.mediaType,
    required this.description,
  });

  factory EvidenceModel.fromJson(Map<String, dynamic> json) => _$EvidenceModelFromJson(json);
  Map<String, dynamic> toJson() => _$EvidenceModelToJson(this);
}



