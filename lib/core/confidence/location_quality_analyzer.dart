// lib/core/confidence/location_quality_analyzer.dart
// 地址质量分析器 - 语义置信度分析

import 'suspicious_dictionary.dart';

/// 地址质量分析结果
class LocationQualityResult {
  /// 语义置信度分数 (0.0 ~ 1.0)
  final double score;

  /// 警告信息列表
  final List<String> warnings;

  /// 是否可疑
  final bool suspicious;

  /// 命中的异常词
  final List<String> hitSuspiciousWords;

  /// 命中的 OCR 错词
  final List<String> hitOcrErrors;

  /// 命中的重复语义
  final List<String> hitDuplicatePatterns;

  const LocationQualityResult({
    required this.score,
    required this.warnings,
    required this.suspicious,
    this.hitSuspiciousWords = const [],
    this.hitOcrErrors = const [],
    this.hitDuplicatePatterns = const [],
  });

  @override
  String toString() {
    return 'LocationQualityResult(score: ${score.toStringAsFixed(2)}, '
        'suspicious: $suspicious, warnings: $warnings)';
  }
}

/// 地址质量分析器
///
/// 分析地址的语义合理性，判断是否像真实地址
class LocationQualityAnalyzer {
  // ── 评分规则 ──────────────────────────────────────────────

  /// 异常词扣分（每个异常词）
  static const double _suspiciousWordPenalty = 0.25;

  /// 地址太长扣分
  static const double _tooLongPenalty = 0.15;

  /// 地址太短扣分
  static const double _tooShortPenalty = 0.30;

  /// 重复语义扣分
  static const double _duplicateSemanticPenalty = 0.15;

  /// OCR 错词扣分（每个错词）
  static const double _ocrErrorPenalty = 0.12;

  // ── 加分规则 ──────────────────────────────────────────────

  /// 包含区/县加分
  static const double _districtBonus = 0.05;

  /// 包含小区名加分
  static const double _communityBonus = 0.05;

  /// 包含门店/驿站加分
  static const double _stationBonus = 0.05;

  /// 包含数字门牌加分
  static const double _doorNumberBonus = 0.05;

  // ── 长度阈值 ──────────────────────────────────────────────

  /// 正常地址最小长度
  static const int _minNormalLength = 4;

  /// 正常地址最大长度
  static const int _maxNormalLength = 25;

  /// 过长地址阈值
  static const int _tooLongThreshold = 30;

  // ── 分析方法 ──────────────────────────────────────────────

  /// 分析地址质量
  ///
  /// 输入：
  /// - rawLocation: OCR 原始提取地址
  /// - cleanedLocation: 清洗后地址
  /// - originalStation: 原始站点名称
  ///
  /// 输出：
  /// - LocationQualityResult: 包含分数、警告、是否可疑等信息
  static LocationQualityResult analyze({
    required String rawLocation,
    required String cleanedLocation,
    String originalStation = '',
  }) {
    // 使用 cleanedLocation 进行分析，如果没有则使用 rawLocation
    final location = cleanedLocation.isNotEmpty ? cleanedLocation : rawLocation;

    // 空地址直接返回低分
    if (location.isEmpty) {
      return const LocationQualityResult(
        score: 0.0,
        warnings: ['地址为空'],
        suspicious: true,
      );
    }

    double score = 1.0;
    final warnings = <String>[];
    final hitSuspiciousWords = <String>[];
    final hitOcrErrors = <String>[];
    final hitDuplicatePatterns = <String>[];

    // ── Rule 1: 异常词检测 ──────────────────────────────────
    for (final word in SuspiciousDictionary.suspiciousWords) {
      if (location.contains(word)) {
        score -= _suspiciousWordPenalty;
        hitSuspiciousWords.add(word);
        warnings.add('包含异常词: $word');
      }
    }

    // ── Rule 2: 地址长度异常 ────────────────────────────────
    if (location.length > _tooLongThreshold) {
      score -= _tooLongPenalty;
      warnings.add('地址过长: ${location.length}字');
    } else if (location.length < _minNormalLength) {
      score -= _tooShortPenalty;
      warnings.add('地址过短: ${location.length}字');
    }

    // ── Rule 3: 重复语义检测 ────────────────────────────────
    for (final pattern in SuspiciousDictionary.duplicatePatterns) {
      if (pattern.length >= 2) {
        final first = pattern[0];
        final second = pattern[1];
        if (location.contains(first) && location.contains(second)) {
          // 检查是否是真正的重复（例如"驿站"和"大院驿站"）
          if (_isDuplicateSemantic(location, first, second)) {
            score -= _duplicateSemanticPenalty;
            hitDuplicatePatterns.add('$first+$second');
            warnings.add('重复语义: $first + $second');
          }
        }
      }
    }

    // ── Rule 4: OCR 错词检测 ────────────────────────────────
    for (final entry in SuspiciousDictionary.ocrErrorMap.entries) {
      // 只检测错误词（正确词不扣分）
      if (location.contains(entry.key) && entry.key != entry.value) {
        score -= _ocrErrorPenalty;
        hitOcrErrors.add(entry.key);
        warnings.add('OCR 错词: ${entry.key} → ${entry.value}');
      }
    }

    // ── Rule 5: 地点结构检测（加分项） ──────────────────────
    // 加分项有上限，不能超过 0.2
    double bonus = 0.0;
    if (_containsAnyKeyword(location, SuspiciousDictionary.districtKeywords)) {
      bonus += _districtBonus;
    }
    if (_containsAnyKeyword(location, SuspiciousDictionary.communityKeywords)) {
      bonus += _communityBonus;
    }
    if (_containsAnyKeyword(location, SuspiciousDictionary.stationKeywords)) {
      bonus += _stationBonus;
    }
    if (SuspiciousDictionary.doorNumberPattern.hasMatch(location)) {
      bonus += _doorNumberBonus;
    }
    // 加分项上限 0.2
    score += bonus.clamp(0.0, 0.2);

    // ── 最终分数 ──────────────────────────────────────────
    final finalScore = score.clamp(0.0, 1.0);
    final suspicious = finalScore < 0.7 || hitSuspiciousWords.isNotEmpty;

    return LocationQualityResult(
      score: finalScore,
      warnings: warnings,
      suspicious: suspicious,
      hitSuspiciousWords: hitSuspiciousWords,
      hitOcrErrors: hitOcrErrors,
      hitDuplicatePatterns: hitDuplicatePatterns,
    );
  }

  // ── 辅助方法 ──────────────────────────────────────────────

  /// 检查是否包含任意一个关键词
  static bool _containsAnyKeyword(String text, List<String> keywords) {
    return keywords.any((kw) => text.contains(kw));
  }

  /// 检查是否是重复语义
  ///
  /// 例如："驿站" 和 "大院驿站" 是重复的
  /// 但 "驿站" 和 "菜鸟驿站" 不是重复的（因为菜鸟是修饰词）
  static bool _isDuplicateSemantic(String location, String first, String second) {
    // 如果两个词相同，不是重复
    if (first == second) return false;

    // 如果一个词包含另一个词，是重复
    if (first.contains(second) || second.contains(first)) {
      return true;
    }

    // 检查是否在同一个上下文中出现
    // 例如："大院驿站" 中的 "驿站" 和单独的 "驿站" 是重复的
    final firstIndex = location.indexOf(first);
    final secondIndex = location.indexOf(second);

    if (firstIndex >= 0 && secondIndex >= 0) {
      // 如果两个词距离很近（< 5个字符），可能是重复
      final distance = (firstIndex - secondIndex).abs();
      if (distance < first.length + second.length + 2) {
        return true;
      }
    }

    return false;
  }
}
