// lib/domain/entities/tool_result_entity.dart

class ToolResultEntity {
  final String toolName;
  final Map<String, dynamic> result;
  final bool success;
  final String? errorMessage;

  const ToolResultEntity({
    required this.toolName,
    required this.result,
    required this.success,
    this.errorMessage,
  });
}
