// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_error.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppError _$AppErrorFromJson(Map<String, dynamic> json) => AppError(
  id: json['id'] as String,
  category: $enumDecode(_$ErrorCategoryEnumMap, json['category']),
  severity: $enumDecode(_$ErrorSeverityEnumMap, json['severity']),
  userMessage: json['userMessage'] as String,
  technicalMessage: json['technicalMessage'] as String,
  errorCode: json['errorCode'] as String?,
  context: json['context'] as Map<String, dynamic>?,
  recoveryActions: (json['recoveryActions'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  isRetryable: json['isRetryable'] as bool? ?? false,
  shouldReport: json['shouldReport'] as bool? ?? true,
  timestamp: DateTime.parse(json['timestamp'] as String),
  stackTrace: json['stackTrace'] as String?,
);

Map<String, dynamic> _$AppErrorToJson(AppError instance) => <String, dynamic>{
  'id': instance.id,
  'category': _$ErrorCategoryEnumMap[instance.category]!,
  'severity': _$ErrorSeverityEnumMap[instance.severity]!,
  'userMessage': instance.userMessage,
  'technicalMessage': instance.technicalMessage,
  'errorCode': instance.errorCode,
  'context': instance.context,
  'recoveryActions': instance.recoveryActions,
  'isRetryable': instance.isRetryable,
  'shouldReport': instance.shouldReport,
  'timestamp': instance.timestamp.toIso8601String(),
  'stackTrace': instance.stackTrace,
};

const _$ErrorCategoryEnumMap = {
  ErrorCategory.network: 'network',
  ErrorCategory.configuration: 'configuration',
  ErrorCategory.permission: 'permission',
  ErrorCategory.platform: 'platform',
  ErrorCategory.authentication: 'authentication',
  ErrorCategory.system: 'system',
  ErrorCategory.unknown: 'unknown',
};

const _$ErrorSeverityEnumMap = {
  ErrorSeverity.low: 'low',
  ErrorSeverity.medium: 'medium',
  ErrorSeverity.high: 'high',
  ErrorSeverity.critical: 'critical',
};
