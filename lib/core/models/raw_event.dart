// lib/core/models/raw_event.dart
// 从 OCR 文本提取的原始事件，包含多个可能性和置信度

import 'package:equatable/equatable.dart';

/// 候选值和置信度对
typedef Candidate<T> = (T value, double confidence);

/// 从 OCR 输出提取的事件模型
/// 包含多个可能的字段值和各自的置信度
class RawEvent extends Equatable {
  const RawEvent({
    required this.id,
    required this.rawText,
    required this.source,
    required this.extractedAt,
    required this.possibleCouriers,
    required this.possiblePickupCodes,
    required this.possibleTrackingNumbers,
    required this.possibleStatuses,
    required this.possibleLocations,
    required this.overallConfidence,
    this.conflictSignals = const [],
    this.metadata = const {},
    this.debugTrace,
  });

  /// 唯一标识 (UUID 或 hash)
  final String id;

  /// OCR 输出的原始文本
  final String rawText;

  /// 来源：'sms' / 'image' / 'manual'
  final String source;

  /// 提取时间戳
  final DateTime extractedAt;

  /// 候选快递商 (排序后，按置信度降序)
  /// 例: [(顺丰, 0.98), (未知, 0.02)]
  final List<Candidate<String>> possibleCouriers;

  /// 候选取件码
  final List<Candidate<String>> possiblePickupCodes;

  /// 候选快递单号
  final List<Candidate<String>> possibleTrackingNumbers;

  /// 候选状态
  /// 例: [(arrived, 0.85), (delivering, 0.10), (unknown, 0.05)]
  final List<Candidate<String>> possibleStatuses;

  /// 候选收货地址
  final List<Candidate<String>> possibleLocations;

  /// 整体置信度（加权平均）
  /// 0.0 - 1.0，高置信能自动生成 Package
  final double overallConfidence;

  /// 冲突信号 (如果同时出现相冲突的状态)
  /// 例: ['already_arrived', 'already_collected']
  final List<String> conflictSignals;

  /// 元数据 (OCR 引擎、图像质量、设备等)
  final Map<String, dynamic> metadata;

  /// 调试信息 (诊断用)
  final String? debugTrace;

  /// 获取最高置信的候选值
  String? get topCourier => possibleCouriers.isNotEmpty ? possibleCouriers.first.$1 : null;
  String? get topPickupCode => possiblePickupCodes.isNotEmpty ? possiblePickupCodes.first.$1 : null;
  String? get topTrackingNumber => possibleTrackingNumbers.isNotEmpty ? possibleTrackingNumbers.first.$1 : null;
  String? get topStatus => possibleStatuses.isNotEmpty ? possibleStatuses.first.$1 : null;
  String? get topLocation => possibleLocations.isNotEmpty ? possibleLocations.first.$1 : null;

  /// 获取最高置信的置信度
  double get topCourierConfidence => possibleCouriers.isNotEmpty ? possibleCouriers.first.$2 : 0.0;

  /// 构建顶级候选组合
  TopCandidate toTopCandidate() => TopCandidate(
    courier: topCourier,
    pickupCode: topPickupCode,
    trackingNumber: topTrackingNumber,
    status: topStatus,
    location: topLocation,
    combinedConfidence: overallConfidence,
  );

  /// 是否有冲突信号
  bool get hasConflict => conflictSignals.isNotEmpty;

  /// 复制并修改
  RawEvent copyWith({
    String? id,
    String? rawText,
    String? source,
    DateTime? extractedAt,
    List<Candidate<String>>? possibleCouriers,
    List<Candidate<String>>? possiblePickupCodes,
    List<Candidate<String>>? possibleTrackingNumbers,
    List<Candidate<String>>? possibleStatuses,
    List<Candidate<String>>? possibleLocations,
    double? overallConfidence,
    List<String>? conflictSignals,
    Map<String, dynamic>? metadata,
    String? debugTrace,
  }) => RawEvent(
    id: id ?? this.id,
    rawText: rawText ?? this.rawText,
    source: source ?? this.source,
    extractedAt: extractedAt ?? this.extractedAt,
    possibleCouriers: possibleCouriers ?? this.possibleCouriers,
    possiblePickupCodes: possiblePickupCodes ?? this.possiblePickupCodes,
    possibleTrackingNumbers: possibleTrackingNumbers ?? this.possibleTrackingNumbers,
    possibleStatuses: possibleStatuses ?? this.possibleStatuses,
    possibleLocations: possibleLocations ?? this.possibleLocations,
    overallConfidence: overallConfidence ?? this.overallConfidence,
    conflictSignals: conflictSignals ?? this.conflictSignals,
    metadata: metadata ?? this.metadata,
    debugTrace: debugTrace ?? this.debugTrace,
  );

  @override
  List<Object?> get props => [
    id,
    rawText,
    source,
    extractedAt,
    possibleCouriers,
    possiblePickupCodes,
    possibleTrackingNumbers,
    possibleStatuses,
    possibleLocations,
    overallConfidence,
    conflictSignals,
    metadata,
    debugTrace,
  ];
}

/// 从 RawEvent 中提取的最高置信候选组合
class TopCandidate extends Equatable {
  const TopCandidate({
    required this.courier,
    required this.pickupCode,
    required this.trackingNumber,
    required this.status,
    required this.location,
    required this.combinedConfidence,
  });

  final String? courier;
  final String? pickupCode;
  final String? trackingNumber;
  final String? status;
  final String? location;
  final double combinedConfidence;

  /// 是否应该自动生成 Package（不需要用户确认）
  bool shouldAutoResolve() => combinedConfidence >= 0.85;

  /// 是否需要用户确认
  bool needsUserConfirmation() => combinedConfidence >= 0.60 && combinedConfidence < 0.85;

  /// 是否应该被拒绝
  bool shouldReject() => combinedConfidence < 0.60;

  /// 决策等级
  ResolveDecision get decision {
    if (shouldAutoResolve()) return ResolveDecision.autoResolve;
    if (needsUserConfirmation()) return ResolveDecision.needsConfirmation;
    return ResolveDecision.reject;
  }

  @override
  List<Object?> get props => [
    courier,
    pickupCode,
    trackingNumber,
    status,
    location,
    combinedConfidence,
  ];
}

/// RawEvent 解析决策
enum ResolveDecision {
  autoResolve,           // 高置信，自动生成 Package
  needsConfirmation,     // 中置信，展示确认框给用户
  reject,                // 低置信，拒绝并提示重拍
}

/// RawEvent 来源
enum RawEventSource {
  sms,      // 短信截图
  image,    // 相机图片
  manual,   // 用户手动输入
}
