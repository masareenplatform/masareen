import 'package:json_annotation/json_annotation.dart';

part 'task_model.g.dart';

@JsonSerializable()
class TaskModel {
  final String id;
  final String title;
  final String status;
  final String priority;
  final String? description;

  TaskModel({
    required this.id,
    required this.title,
    required this.status,
    required this.priority,
    this.description,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) => _$TaskModelFromJson(json);
  Map<String, dynamic> toJson() => _$TaskModelToJson(this);
}



