/// 物流事件类型枚举
/// 定义包裹生命周期中的各种关键事件
library;

/// 物流事件类型
enum LogisticsEventType {
  /// 包裹创建
  packageCreated,

  /// 发货
  shipped,

  /// 到达驿站/取件点
  arrivedStation,

  /// 派送中
  outForDelivery,

  /// 取件码生成
  pickupCodeGenerated,

  /// 已签收/已取件
  signed,

  /// 延迟
  delayed,

  /// 异常
  exception,
}

/// 物流事件类型扩展
extension LogisticsEventTypeX on LogisticsEventType {
  /// 事件显示名称
  String get displayName {
    switch (this) {
      case LogisticsEventType.packageCreated:
        return '包裹创建';
      case LogisticsEventType.shipped:
        return '已发货';
      case LogisticsEventType.arrivedStation:
        return '已到达取件点';
      case LogisticsEventType.outForDelivery:
        return '派送中';
      case LogisticsEventType.pickupCodeGenerated:
        return '取件码生成';
      case LogisticsEventType.signed:
        return '已签收';
      case LogisticsEventType.delayed:
        return '延迟';
      case LogisticsEventType.exception:
        return '异常';
    }
  }

  /// 事件图标（简单描述，实际UI用emoji或图标）
  String get iconEmoji {
    switch (this) {
      case LogisticsEventType.packageCreated:
        return '📦';
      case LogisticsEventType.shipped:
        return '🚚';
      case LogisticsEventType.arrivedStation:
        return '📍';
      case LogisticsEventType.outForDelivery:
        return '🛵';
      case LogisticsEventType.pickupCodeGenerated:
        return '🔢';
      case LogisticsEventType.signed:
        return '✅';
      case LogisticsEventType.delayed:
        return '⏱️';
      case LogisticsEventType.exception:
        return '⚠️';
    }
  }
}

/// 物流事件数据模型
/// 记录包裹的完整物流生命周期事件
class LogisticsEvent {
  /// 事件唯一标识（用于去重）
  final String id;

  /// 关联的包裹ID
  final String packageId;

  /// 事件类型
  final LogisticsEventType type;

  /// 事件发生时间
  final DateTime time;

  /// 事件来源：'ocr' / 'manual' / 'mock' / 'notification'
  final String source;

  /// 原始文本（如OCR输出）
  final String? rawText;

  /// 元数据（扩展字段，如位置信息、设备信息等）
  final Map<String, dynamic>? metadata;

  const LogisticsEvent({
    required this.id,
    required this.packageId,
    required this.type,
    required this.time,
    required this.source,
    this.rawText,
    this.metadata,
  });

  /// 生成事件ID（去重用）
  /// 规则：pickupCode + type + timestampMinute
  static String generateEventId({
    required String pickupCode,
    required LogisticsEventType type,
    required DateTime time,
  }) {
    // 精确到分钟
    final timestampMinute = DateTime(time.year, time.month, time.day, time.hour, time.minute).millisecondsSinceEpoch;
    return '${pickupCode}_${type.name}_$timestampMinute'.toLowerCase();
  }

  /// 复制并修改
  LogisticsEvent copyWith({
    String? id,
    String? packageId,
    LogisticsEventType? type,
    DateTime? time,
    String? source,
    String? rawText,
    Map<String, dynamic>? metadata,
  }) {
    return LogisticsEvent(
      id: id ?? this.id,
      packageId: packageId ?? this.packageId,
      type: type ?? this.type,
      time: time ?? this.time,
      source: source ?? this.source,
      rawText: rawText ?? this.rawText,
      metadata: metadata ?? this.metadata,
    );
  }

  /// 转换为JSON（用于存储）
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'packageId': packageId,
      'type': type.name,
      'time': time.toIso8601String(),
      'source': source,
      'rawText': rawText,
      'metadata': metadata,
    };
  }

  /// 从JSON创建
  factory LogisticsEvent.fromJson(Map<String, dynamic> json) {
    return LogisticsEvent(
      id: json['id'] as String,
      packageId: json['packageId'] as String,
      type: LogisticsEventType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => LogisticsEventType.exception,
      ),
      time: DateTime.parse(json['time'] as String),
      source: json['source'] as String,
      rawText: json['rawText'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}
