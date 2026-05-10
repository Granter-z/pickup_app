// lib/core/raw_event/raw_event_builder.dart
// 从 OCR 输出和提取结果构建 RawEvent

import 'package:crypto/crypto.dart';
import 'package:pickup_app/core/models/raw_event.dart';
import 'package:pickup_app/core/confidence/confidence_calculator.dart';

/// 从 OCR 输出和提取结果构建 RawEvent
class RawEventBuilder {
  RawEventBuilder({
    ConfidenceCalculator? confidenceCalculator,
  }) : confidenceCalculator = confidenceCalculator ?? ConfidenceCalculator();

  final ConfidenceCalculator confidenceCalculator;

  /// 构建 RawEvent
  ///
  /// 参数：
  /// - rawText: OCR 输出的原始文本
  /// - extractionResults: 各字段的提取结果（包含候选值）
  /// - source: 事件来源（'sms'/'image'/'manual'）
  /// - conflictSignals: 冲突信号列表
  /// - metadata: 元数据（OCR 引擎、图像质量等）
  RawEvent build({
    required String rawText,
    required Map<String, List<Candidate<String>>> extractionResults,
    required String source,
    List<String> conflictSignals = const [],
    Map<String, dynamic> metadata = const {},
    String? debugTrace,
  }) {
    // 验证输入
    assert(rawText.trim().isNotEmpty, 'rawText cannot be empty');
    assert(['sms', 'image', 'manual'].contains(source), 'Invalid source: $source');

    // 提取各字段的候选值
    final possibleCouriers = extractionResults['courier'] ?? [];
    final possiblePickupCodes = extractionResults['pickupCode'] ?? [];
    final possibleTrackingNumbers = extractionResults['trackingNumber'] ?? [];
    final possibleStatuses = extractionResults['status'] ?? [];
    final possibleLocations = extractionResults['location'] ?? [];

    // 计算各字段的置信度
    final courierConfidence = _calculateCourierFieldConfidence(
      possibleCouriers: possibleCouriers,
      possibleTrackingNumbers: possibleTrackingNumbers,
      rawText: rawText,
    );

    final pickupCodeConfidence = _calculatePickupCodeFieldConfidence(
      possiblePickupCodes: possiblePickupCodes,
      rawText: rawText,
    );

    final trackingNumberConfidence = _calculateTrackingNumberFieldConfidence(
      possibleTrackingNumbers: possibleTrackingNumbers,
      possibleCouriers: possibleCouriers,
    );

    final statusConfidence = _calculateStatusFieldConfidence(
      possibleStatuses: possibleStatuses,
      conflictSignals: conflictSignals,
    );

    final locationConfidence = _calculateLocationFieldConfidence(
      possibleLocations: possibleLocations,
    );

    // 计算整体置信度
    final overallConfidence = confidenceCalculator.calculateOverallConfidence(
      courierConfidence: courierConfidence,
      pickupCodeConfidence: pickupCodeConfidence,
      trackingNumberConfidence: trackingNumberConfidence,
      statusConfidence: statusConfidence,
      locationConfidence: locationConfidence,
    );

    // 生成唯一 ID
    final id = _generateEventId(rawText, source);

    return RawEvent(
      id: id,
      rawText: rawText,
      source: source,
      extractedAt: DateTime.now(),
      possibleCouriers: possibleCouriers,
      possiblePickupCodes: possiblePickupCodes,
      possibleTrackingNumbers: possibleTrackingNumbers,
      possibleStatuses: possibleStatuses,
      possibleLocations: possibleLocations,
      overallConfidence: overallConfidence,
      conflictSignals: conflictSignals,
      metadata: {
        ...metadata,
        'confidences': {
          'courier': courierConfidence,
          'pickupCode': pickupCodeConfidence,
          'trackingNumber': trackingNumberConfidence,
          'status': statusConfidence,
          'location': locationConfidence,
        }
      },
      debugTrace: debugTrace,
    );
  }

  /// 计算快递商字段的置信度
  double _calculateCourierFieldConfidence({
    required List<Candidate<String>> possibleCouriers,
    required List<Candidate<String>> possibleTrackingNumbers,
    required String rawText,
  }) {
    if (possibleCouriers.isEmpty) return 0.0;

    // 使用最高置信的候选
    final (courier, confidence) = possibleCouriers.first;
    final trackingNumber = possibleTrackingNumbers.isNotEmpty
        ? possibleTrackingNumbers.first.$1
        : null;

    return confidenceCalculator.calculateCourierConfidence(
      courier: courier,
      trackingNumber: trackingNumber,
      rawText: rawText,
      isKeywordMatched: confidence > 0.5,
    );
  }

  /// 计算取件码字段的置信度
  double _calculatePickupCodeFieldConfidence({
    required List<Candidate<String>> possiblePickupCodes,
    required String rawText,
  }) {
    if (possiblePickupCodes.isEmpty) return 0.0;

    final (code, confidence) = possiblePickupCodes.first;

    return confidenceCalculator.calculatePickupCodeConfidence(
      code: code,
      rawText: rawText,
      formatMatches: confidence > 0.5,
    );
  }

  /// 计算快递单号字段的置信度
  double _calculateTrackingNumberFieldConfidence({
    required List<Candidate<String>> possibleTrackingNumbers,
    required List<Candidate<String>> possibleCouriers,
  }) {
    if (possibleTrackingNumbers.isEmpty) return 0.0;

    final (number, confidence) = possibleTrackingNumbers.first;
    final courier = possibleCouriers.isNotEmpty ? possibleCouriers.first.$1 : null;

    return confidenceCalculator.calculateTrackingNumberConfidence(
      number: number,
      courier: courier,
      formatMatches: confidence > 0.5,
    );
  }

  /// 计算状态字段的置信度
  double _calculateStatusFieldConfidence({
    required List<Candidate<String>> possibleStatuses,
    required List<String> conflictSignals,
  }) {
    if (possibleStatuses.isEmpty) return 0.0;

    final (status, confidence) = possibleStatuses.first;

    return confidenceCalculator.calculateStatusConfidence(
      status: status,
      rawText: '',
      keywordMatched: confidence > 0.5,
      conflictSignals: conflictSignals,
    );
  }

  /// 计算地址字段的置信度
  double _calculateLocationFieldConfidence({
    required List<Candidate<String>> possibleLocations,
  }) {
    if (possibleLocations.isEmpty) return 0.0;

    final (location, confidence) = possibleLocations.first;
    final noiseKeywords = _containsNoiseKeywords(location);

    return confidenceCalculator.calculateLocationConfidence(
      location: location,
      containsNoiseKeywords: noiseKeywords,
    );
  }

  /// 检查是否包含噪音关键词
  bool _containsNoiseKeywords(String text) {
    final noiseKeywords = [
      '转运中心',
      '分拣中心',
      '集散中心',
      '处理中心',
      '航空港',
    ];
    return noiseKeywords.any((kw) => text.contains(kw));
  }

  /// 生成事件 ID（基于内容 hash）
  String _generateEventId(String rawText, String source) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final input = '$rawText:$source:$timestamp';
    return md5.convert(input.codeUnits).toString().substring(0, 12);
  }
}

/// 扩展：检查 RawEvent 是否需要用户干预
extension RawEventDecision on RawEvent {
  /// 是否应该自动生成 Package
  bool get shouldAutoResolve => overallConfidence >= 0.85;

  /// 是否需要用户确认
  bool get needsUserConfirmation => overallConfidence >= 0.60 && overallConfidence < 0.85;

  /// 是否应该被拒绝
  bool get shouldReject => overallConfidence < 0.60;

  /// 获取用户友好的决策描述
  String getDecisionReason() {
    if (shouldAutoResolve) {
      return '置信度 ${(overallConfidence * 100).toStringAsFixed(0)}% - 自动识别';
    } else if (needsUserConfirmation) {
      return '置信度 ${(overallConfidence * 100).toStringAsFixed(0)}% - 请确认';
    } else {
      return '置信度太低 ${(overallConfidence * 100).toStringAsFixed(0)}% - 请重新拍照';
    }
  }
}
