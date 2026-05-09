/// OCR结果数据结构 - 纯Dart
/// 
/// 职责：
/// 1. 定义OCR结果的数据结构
/// 2. 包含置信度和候选结果
/// 3. 提供结果验证和转换
library;

import '../parser/parse_result.dart';

/// OCR结果
class OcrResult {
  /// 原始识别文本
  final String rawText;
  
  /// 识别置信度（0.0-1.0）
  final double confidence;
  
  /// 候选解析结果（按置信度排序）
  final List<ParseCandidate> candidates;
  
  /// 解析警告
  final List<ParseWarning> warnings;
  
  /// 识别时间
  final DateTime timestamp;

  const OcrResult({
    required this.rawText,
    this.confidence = 0.0,
    this.candidates = const [],
    this.warnings = const [],
    required this.timestamp,
  });

  /// 是否为有效结果
  bool get isValid => rawText.isNotEmpty && confidence > 0.0;
  
  /// 是否有候选结果
  bool get hasCandidates => candidates.isNotEmpty;
  
  /// 最佳候选结果
  ParseCandidate? get bestCandidate => 
      candidates.isNotEmpty ? candidates.first : null;
  
  /// 所有警告信息
  List<String> get allWarnings => 
      warnings.map((w) => w.message).toList();

  /// 创建空结果
  factory OcrResult.empty() {
    return OcrResult(
      rawText: '',
      confidence: 0.0,
      timestamp: DateTime.now(),
    );
  }

  /// 创建错误结果
  factory OcrResult.error(String message) {
    return OcrResult(
      rawText: '',
      confidence: 0.0,
      warnings: [ParseWarning.error(message)],
      timestamp: DateTime.now(),
    );
  }

  /// 转换为ParseResult（取最佳候选）
  ParseResult? toParseResult() {
    return bestCandidate?.result;
  }
}

/// 解析候选结果
class ParseCandidate {
  /// 解析结果
  final ParseResult result;
  
  /// 候选置信度
  final double confidence;
  
  /// 候选来源
  final String source;
  
  /// 候选排名
  final int rank;

  const ParseCandidate({
    required this.result,
    required this.confidence,
    required this.source,
    this.rank = 0,
  });

  /// 是否为高置信度候选
  bool get isHighConfidence => confidence >= 0.8;
  
  /// 是否为中等置信度候选
  bool get isMediumConfidence => confidence >= 0.6 && confidence < 0.8;
  
  /// 是否为低置信度候选
  bool get isLowConfidence => confidence < 0.6;
}

/// 解析警告
class ParseWarning {
  /// 警告级别
  final WarningLevel level;
  
  /// 警告消息
  final String message;
  
  /// 警告来源
  final String source;
  
  /// 警告时间
  final DateTime timestamp;

  const ParseWarning({
    required this.level,
    required this.message,
    this.source = '',
    required this.timestamp,
  });

  /// 创建错误警告
  factory ParseWarning.error(String message, {String source = ''}) {
    return ParseWarning(
      level: WarningLevel.error,
      message: message,
      source: source,
      timestamp: DateTime.now(),
    );
  }

  /// 创建警告
  factory ParseWarning.warning(String message, {String source = ''}) {
    return ParseWarning(
      level: WarningLevel.warning,
      message: message,
      source: source,
      timestamp: DateTime.now(),
    );
  }

  /// 创建信息
  factory ParseWarning.info(String message, {String source = ''}) {
    return ParseWarning(
      level: WarningLevel.info,
      message: message,
      source: source,
      timestamp: DateTime.now(),
    );
  }
}

/// 警告级别
enum WarningLevel {
  /// 错误
  error,
  
  /// 警告
  warning,
  
  /// 信息
  info,
}
