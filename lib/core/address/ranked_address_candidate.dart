/// 排名后的地址候选
///
/// 职责：
/// 1. 封装解析后的地址及其各维度置信度
/// 2. 纯 Dart，不依赖 Flutter SDK
library;

import 'parsed_address.dart';

/// 排名后的地址候选
class RankedAddressCandidate {
  /// 解析后的地址
  final ParsedAddress address;

  /// OCR 置信度
  final double ocrConfidence;

  /// 语义置信度
  final double semanticConfidence;

  /// 结构置信度
  final double structureConfidence;

  /// 最终置信度
  final double finalConfidence;

  const RankedAddressCandidate({
    required this.address,
    required this.ocrConfidence,
    required this.semanticConfidence,
    required this.structureConfidence,
    required this.finalConfidence,
  });

  @override
  String toString() =>
      'RankedAddressCandidate("${address.fullAddress}", final: ${finalConfidence.toStringAsFixed(3)})';
}
