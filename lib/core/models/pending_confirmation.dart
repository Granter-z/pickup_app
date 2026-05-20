/// 待确认包裹数据结构 - 纯Dart
/// 
/// 职责：
/// 1. 存储待确认的包裹信息
/// 2. 包含置信度和原始数据
/// 3. 提供确认/修改操作
library;

import 'package.dart';
import 'package_status.dart';

/// 待确认包裹
class PendingConfirmation {
  /// 唯一标识
  final String id;
  
  /// 解析出的快递公司
  final CourierType courier;
  
  /// 解析出的取件码
  final String pickupCode;
  
  /// 解析出的运单号
  final String trackingNumber;
  
  /// 解析出的取货地点
  final String location;

  /// 原始站点名称（菜鸟驿站等）
  final String originalStation;
  
  /// 解析出的状态
  final PackageStatus status;
  
  /// 整体置信度（0.0-1.0）
  final double confidence;
  
  /// 各字段置信度
  final FieldConfidence fieldConfidence;
  
  /// 原始 OCR 文本
  final String rawText;
  
  /// 警告信息
  final List<String> warnings;
  
  /// 创建时间
  final DateTime createdAt;

  /// OCR 原始提取地址
  final String rawLocation;

  /// regex 清洗后地址
  final String cleanedLocation;

  const PendingConfirmation({
    required this.id,
    required this.courier,
    this.pickupCode = '',
    this.trackingNumber = '',
    this.location = '',
    this.originalStation = '',
    this.status = PackageStatus.arrived,
    required this.confidence,
    required this.fieldConfidence,
    this.rawText = '',
    this.warnings = const [],
    required this.createdAt,
    this.rawLocation = '',
    this.cleanedLocation = '',
  });

  /// 是否为低置信度（需要确认）
  bool get needsConfirmation => confidence < 0.7;
  
  /// 是否为高置信度（可自动通过）
  bool get isHighConfidence => confidence >= 0.9;
  
  /// 获取置信度等级描述
  String get confidenceLabel {
    if (confidence >= 0.9) return '高';
    if (confidence >= 0.7) return '中';
    if (confidence >= 0.5) return '低';
    return '很低';
  }

  /// 转换为 Package
  Package toPackage({String? id}) {
    return Package(
      id: id ?? this.id,
      trackingNumber: trackingNumber.isNotEmpty 
          ? trackingNumber 
          : 'OCR-${DateTime.now().millisecondsSinceEpoch}',
      courier: courier,
      pickupCode: pickupCode,
      location: location,
      originalStation: originalStation,
      description: _buildDescription(),
      urgency: UrgencyLevel.normal,
      status: status,
      addedAt: DateTime.now(),
      rawLocation: rawLocation,
      cleanedLocation: cleanedLocation,
      canonicalLocation: cleanedLocation,
      locationConfidence: Package.calculateLocationConfidence(cleanedLocation),
    );
  }

  /// 构建描述
  String _buildDescription() {
    final parts = <String>[];
    if (pickupCode.isNotEmpty) parts.add('取件码 $pickupCode');
    if (location.isNotEmpty) parts.add(location);
    return parts.isNotEmpty ? parts.join(' · ') : 'OCR识别';
  }

  /// 复制并修改
  PendingConfirmation copyWith({
    String? id,
    CourierType? courier,
    String? pickupCode,
    String? trackingNumber,
    String? location,
    String? originalStation,
    PackageStatus? status,
    double? confidence,
    FieldConfidence? fieldConfidence,
    String? rawText,
    List<String>? warnings,
    DateTime? createdAt,
    String? rawLocation,
    String? cleanedLocation,
  }) {
    return PendingConfirmation(
      id: id ?? this.id,
      courier: courier ?? this.courier,
      pickupCode: pickupCode ?? this.pickupCode,
      trackingNumber: trackingNumber ?? this.trackingNumber,
      location: location ?? this.location,
      originalStation: originalStation ?? this.originalStation,
      status: status ?? this.status,
      confidence: confidence ?? this.confidence,
      fieldConfidence: fieldConfidence ?? this.fieldConfidence,
      rawText: rawText ?? this.rawText,
      warnings: warnings ?? this.warnings,
      createdAt: createdAt ?? this.createdAt,
      rawLocation: rawLocation ?? this.rawLocation,
      cleanedLocation: cleanedLocation ?? this.cleanedLocation,
    );
  }
}

/// 字段置信度
class FieldConfidence {
  final double courier;
  final double pickupCode;
  final double trackingNumber;
  final double location;
  final double status;

  const FieldConfidence({
    this.courier = 0.0,
    this.pickupCode = 0.0,
    this.trackingNumber = 0.0,
    this.location = 0.0,
    this.status = 0.0,
  });

  /// 获取最低置信度
  double get min => [courier, pickupCode, trackingNumber, location, status]
      .reduce((a, b) => a < b ? a : b);
  
  /// 获取平均置信度
  double get average => (courier + pickupCode + trackingNumber + location + status) / 5;
  
  /// 是否有任何低置信度字段
  bool get hasLowConfidence => [courier, pickupCode, trackingNumber, location, status]
      .any((c) => c < 0.7);

  /// 获取低置信度字段名列表
  List<String> get lowConfidenceFields {
    final fields = <String>[];
    if (courier < 0.7) fields.add('快递公司');
    if (pickupCode < 0.7) fields.add('取件码');
    if (trackingNumber < 0.7) fields.add('运单号');
    if (location < 0.7) fields.add('取货地点');
    if (status < 0.7) fields.add('状态');
    return fields;
  }
}
