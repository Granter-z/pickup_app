// lib/core/confidence/confidence_calculator.dart
// 从提取结果计算字段和整体置信度

import 'package:pickup_app/core/models/courier_type.dart';

/// 置信度权重配置
class ConfidenceWeights {
  const ConfidenceWeights({
    this.courierWeight = 0.35,      // 快递商最重要
    this.pickupCodeWeight = 0.30,   // 取件码也很关键
    this.trackingNumberWeight = 0.20,
    this.statusWeight = 0.10,
    this.locationWeight = 0.05,
  });

  final double courierWeight;
  final double pickupCodeWeight;
  final double trackingNumberWeight;
  final double statusWeight;
  final double locationWeight;

  /// 验证权重和为 1.0
  bool get isValid {
    final sum = courierWeight + pickupCodeWeight + trackingNumberWeight + statusWeight + locationWeight;
    return (sum - 1.0).abs() < 0.01; // 浮点误差容忍
  }
}

/// 置信度计算器
/// 负责从各个字段的提取结果计算置信度分数
class ConfidenceCalculator {
  ConfidenceCalculator({
    ConfidenceWeights? weights,
  }) : weights = weights ?? const ConfidenceWeights() {
    assert(this.weights.isValid, 'Confidence weights must sum to 1.0');
  }

  final ConfidenceWeights weights;

  /// 计算快递商字段的置信度
  ///
  /// 因素：
  /// - 是否是已知的快递商
  /// - tracking number 的前缀是否匹配
  /// - 文本中的 keyword 匹配程度
  double calculateCourierConfidence({
    required String courier,
    required String? trackingNumber,
    required String? rawText,
    required bool isKeywordMatched,
  }) {
    double confidence = 0.0;

    // 1. 是否是已知的快递商（基础分）
    if (_isKnownCourier(courier)) {
      confidence += 0.50;
    } else {
      confidence += 0.10; // "未知" 快递商
    }

    // 2. tracking number 前缀是否匹配（仅对足够长的单号）
    if (trackingNumber != null && trackingNumber.length >= 10 && _courierPrefixMatches(courier, trackingNumber)) {
      confidence += 0.25;
    }

    // 3. keyword 是否匹配
    if (isKeywordMatched) {
      confidence += 0.25;
    }

    return confidence.clamp(0.0, 1.0);
  }

  /// 计算取件码字段的置信度
  ///
  /// 因素：
  /// - 格式是否符合规范（如 15-3-6007）
  /// - 是否在合理的字符数范围内
  /// - 周围上下文
  double calculatePickupCodeConfidence({
    required String code,
    required String rawText,
    required bool formatMatches,
  }) {
    double confidence = 0.0;

    // 1. 格式匹配（主要因素）
    if (formatMatches) {
      confidence += 0.60;
    } else {
      confidence += 0.10;
    }

    // 2. 长度在合理范围
    if (code.length >= 5 && code.length <= 30) {
      confidence += 0.25;
    } else if (code.length <= 40) {
      confidence += 0.10;
    }

    // 3. 是否在文本中出现多次（重复出现 = 更可信）
    final occurrences = _countOccurrences(rawText, code);
    if (occurrences >= 2) {
      confidence += 0.15;
    }

    return confidence.clamp(0.0, 1.0);
  }

  /// 计算快递单号的置信度
  double calculateTrackingNumberConfidence({
    required String number,
    required String? courier,
    required bool formatMatches,
  }) {
    double confidence = 0.0;

    // 1. 格式匹配
    if (formatMatches) {
      confidence += 0.60;
    } else {
      confidence += 0.15;
    }

    // 2. 与快递商是否匹配
    if (courier != null && _courierPrefixMatches(courier, number)) {
      confidence += 0.35;
    }

    // 3. 长度合理（通常 12-20 位）
    if (number.length >= 12 && number.length <= 20) {
      confidence += 0.05;
    }

    return confidence.clamp(0.0, 1.0);
  }

  /// 计算状态字段的置信度
  ///
  /// 因素：
  /// - keyword 是否明确
  /// - 是否有冲突信号
  double calculateStatusConfidence({
    required String status,
    required String rawText,
    required bool keywordMatched,
    required List<String> conflictSignals,
  }) {
    double confidence = 0.0;

    // 1. keyword 匹配
    if (keywordMatched) {
      confidence += 0.70;
    } else {
      confidence += 0.15; // 推测
    }

    // 2. 是否有冲突信号（降低置信度）
    if (conflictSignals.isEmpty) {
      confidence += 0.30;
    } else if (conflictSignals.length == 1) {
      confidence += 0.10;
    }
    // 多个冲突 = 0

    return confidence.clamp(0.0, 1.0);
  }

  /// 计算地址字段的置信度
  ///
  /// 因素：
  /// - 是否包含噪音关键词（转运中心、分拣中心等）
  /// - 是否以"自提"开头
  /// - 字符长度
  double calculateLocationConfidence({
    required String location,
    required bool containsNoiseKeywords,
  }) {
    double confidence = 0.0;

    // 1. 不包含噪音关键词
    if (!containsNoiseKeywords) {
      confidence += 0.60;
    } else {
      confidence += 0.10;
    }

    // 2. 字符数在合理范围
    if (location.length >= 4 && location.length <= 50) {
      confidence += 0.30;
    } else if (location.length <= 100) {
      confidence += 0.10;
    }

    // 3. 是否包含自提/柜/驿站等关键词
    if (_containsPickupKeywords(location)) {
      confidence += 0.10;
    }

    return confidence.clamp(0.0, 1.0);
  }

  /// 计算整体置信度（加权平均）
  ///
  /// 如果缺少字段，该字段置信度设为 0
  double calculateOverallConfidence({
    required double courierConfidence,
    required double pickupCodeConfidence,
    required double trackingNumberConfidence,
    required double statusConfidence,
    required double locationConfidence,
  }) {
    final weighted =
      (courierConfidence * weights.courierWeight) +
      (pickupCodeConfidence * weights.pickupCodeWeight) +
      (trackingNumberConfidence * weights.trackingNumberWeight) +
      (statusConfidence * weights.statusWeight) +
      (locationConfidence * weights.locationWeight);

    return weighted.clamp(0.0, 1.0);
  }

  // ============ 辅助方法 ============

  /// 是否是已知的快递商
  bool _isKnownCourier(String courier) {
    try {
      CourierType.fromString(courier);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 快递商前缀是否与单号匹配
  /// 例: 顺丰(SF) + SF123456 → true
  bool _courierPrefixMatches(String courier, String trackingNumber) {
    final prefix = _getCourierPrefix(courier);
    if (prefix == null) return false;
    return trackingNumber.toUpperCase().startsWith(prefix);
  }

  /// 获取快递商的单号前缀
  String? _getCourierPrefix(String courier) {
    return switch (courier.toLowerCase()) {
      '顺丰' || 'sf express' => 'SF',
      '极兔' || 'jt express' => 'JT',
      '圆通' || 'yto' => 'YT',
      '中通' || 'zt' => 'ZT',
      _ => null,
    };
  }

  /// 计算字符串在文本中出现的次数
  int _countOccurrences(String text, String pattern) {
    if (pattern.isEmpty) return 0;
    return RegExp(RegExp.escape(pattern)).allMatches(text).length;
  }

  /// 是否包含自提相关关键词
  bool _containsPickupKeywords(String text) {
    final keywords = ['自提', '柜', '驿站', '便利店', '超市'];
    return keywords.any((kw) => text.contains(kw));
  }
}

/// 置信度分数阈值（用于决策）
class ConfidenceThresholds {
  static const double autoResolve = 0.85;      // ≥ 0.85: 自动生成 Package
  static const double needsConfirmation = 0.60; // 0.60-0.85: 需要用户确认
  // < 0.60: 拒绝
}
