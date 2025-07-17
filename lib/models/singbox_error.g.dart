// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'singbox_error.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SingboxError _$SingboxErrorFromJson(Map<String, dynamic> json) => SingboxError(
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
  singboxErrorCode: $enumDecode(
    _$SingboxErrorCodeEnumMap,
    json['singboxErrorCode'],
  ),
  operation: $enumDecode(_$SingboxOperationEnumMap, json['operation']),
  singboxConfig: json['singboxConfig'] as Map<String, dynamic>?,
  nativeErrorMessage: json['nativeErrorMessage'] as String?,
  protocol: json['protocol'] as String?,
  serverEndpoint: json['serverEndpoint'] as String?,
);

Map<String, dynamic> _$SingboxErrorToJson(SingboxError instance) =>
    <String, dynamic>{
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
      'singboxErrorCode': _$SingboxErrorCodeEnumMap[instance.singboxErrorCode]!,
      'operation': _$SingboxOperationEnumMap[instance.operation]!,
      'singboxConfig': instance.singboxConfig,
      'nativeErrorMessage': instance.nativeErrorMessage,
      'protocol': instance.protocol,
      'serverEndpoint': instance.serverEndpoint,
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

const _$SingboxErrorCodeEnumMap = {
  SingboxErrorCode.initFailed: 'SINGBOX_INIT_FAILED',
  SingboxErrorCode.configInvalid: 'SINGBOX_CONFIG_INVALID',
  SingboxErrorCode.startFailed: 'SINGBOX_START_FAILED',
  SingboxErrorCode.stopFailed: 'SINGBOX_STOP_FAILED',
  SingboxErrorCode.connectionFailed: 'SINGBOX_CONNECTION_FAILED',
  SingboxErrorCode.protocolError: 'SINGBOX_PROTOCOL_ERROR',
  SingboxErrorCode.authFailed: 'SINGBOX_AUTH_FAILED',
  SingboxErrorCode.networkUnreachable: 'SINGBOX_NETWORK_UNREACHABLE',
  SingboxErrorCode.tunSetupFailed: 'SINGBOX_TUN_SETUP_FAILED',
  SingboxErrorCode.permissionDenied: 'SINGBOX_PERMISSION_DENIED',
  SingboxErrorCode.libraryNotFound: 'SINGBOX_LIBRARY_NOT_FOUND',
  SingboxErrorCode.processCrashed: 'SINGBOX_PROCESS_CRASHED',
  SingboxErrorCode.statsUnavailable: 'SINGBOX_STATS_UNAVAILABLE',
  SingboxErrorCode.timeout: 'SINGBOX_TIMEOUT',
  SingboxErrorCode.unknown: 'SINGBOX_UNKNOWN',
};

const _$SingboxOperationEnumMap = {
  SingboxOperation.initialization: 'initialization',
  SingboxOperation.configuration: 'configuration',
  SingboxOperation.connection: 'connection',
  SingboxOperation.statistics: 'statistics',
  SingboxOperation.monitoring: 'monitoring',
  SingboxOperation.cleanup: 'cleanup',
};
