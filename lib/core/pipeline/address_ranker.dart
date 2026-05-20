/// 地址排名器
///
/// 职责：
/// 1. 综合 OCR 置信度、语义置信度、结构置信度计算最终评分
/// 2. 纯 Dart，不依赖 Flutter SDK
library;

/// 地址排名器
class AddressRanker {
  /// 计算最终评分
  ///
  /// 输入：
  /// - ocrConfidence: OCR 置信度
  /// - semanticConfidence: 语义置信度
  /// - structureConfidence: 结构置信度
  ///
  /// 输出：最终评分
  ///
  /// 公式：ocrConfidence * 0.4 + semanticConfidence * 0.3 + structureConfidence * 0.3
  static double rank({
    required double ocrConfidence,
    required double semanticConfidence,
    required double structureConfidence,
  }) {
    return ocrConfidence * 0.4 +
        semanticConfidence * 0.3 +
        structureConfidence * 0.3;
  }
}
