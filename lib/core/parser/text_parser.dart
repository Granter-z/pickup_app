/// 文本解析器 - 核心层
/// 
/// 职责：
/// 1. 协调各个提取器
/// 2. 提供单条和批量解析
/// 3. 处理多包裹文本
/// 4. 计算置信度和警告
library;

import 'text_preprocessor.dart';
import 'extractors.dart';
import 'parse_result.dart';
import 'regex_patterns.dart';

/// 文本解析器
class TextParser {
  /// 解析单条文本
  static ParseResult parse(String text) {
    final raw = TextPreprocessor.preprocess(text);
    
    final courier = CourierExtractor.extract(raw);
    final pickupCode = PickupCodeExtractor.extract(raw);
    final trackingNumber = TrackingNumberExtractor.extract(raw);
    final phoneTail = PhoneTailExtractor.extract(raw);
    final location = LocationExtractor.extract(raw);
    final status = StatusExtractor.extract(raw);
    
    final warnings = <String>[];
    
    // 计算总体置信度
    final confidences = [
      courier.confidence,
      pickupCode.confidence,
      trackingNumber.confidence,
      phoneTail.confidence,
      location.confidence,
      status.confidence,
    ];
    
    final validConfidences = confidences.where((c) => c > 0).toList();
    final overallConfidence = validConfidences.isEmpty 
        ? 0.0 
        : validConfidences.reduce((a, b) => a + b) / validConfidences.length;
    
    return ParseResult(
      courier: courier,
      pickupCode: pickupCode,
      trackingNumber: trackingNumber,
      phoneTail: phoneTail,
      location: location,
      status: status,
      warnings: warnings,
      overallConfidence: overallConfidence,
    );
  }

  /// 解析多条文本（批量）
  static List<ParseResult> parseMulti(String text) {
    final raw = TextPreprocessor.preprocess(text);
    final boundaries = _findBoundaries(raw);

    if (boundaries.length <= 1) {
      return [parse(text)];
    }

    final commonHeader = boundaries[0] > 10 
        ? raw.substring(0, boundaries[0]) 
        : '';

    final results = <ParseResult>[];
    for (var i = 0; i < boundaries.length; i++) {
      final start = boundaries[i];
      final end = i + 1 < boundaries.length 
          ? boundaries[i + 1] 
          : raw.length;
      var segment = raw.substring(start, end);
      if (commonHeader.isNotEmpty) {
        segment = '$commonHeader\n$segment';
      }
      results.add(parse(segment));
    }
    return results;
  }

  /// 查找文本中的包裹边界
  static List<int> _findBoundaries(String text) {
    final positions = <int>[];

    // 取件码/取货码
    for (final m in RegexPatterns.labeledPickupCode.allMatches(text)) {
      positions.add(m.start);
    }

    // 裸bay码
    for (final m in RegexPatterns.bayFormatCode.allMatches(text)) {
      if (!positions.any((p) => (p - m.start).abs() < 5)) {
        positions.add(m.start);
      }
    }

    positions.sort();
    return positions;
  }

  /// 向后兼容的解析方法
  static ParsedPackage parseLegacy(String text) {
    return parse(text).toParsedPackage();
  }

  /// 向后兼容的批量解析方法
  static List<ParsedPackage> parseMultiLegacy(String text) {
    return parseMulti(text).map((r) => r.toParsedPackage()).toList();
  }
}
