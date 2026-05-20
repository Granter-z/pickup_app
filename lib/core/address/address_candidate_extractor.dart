// lib/core/address/address_candidate_extractor.dart
// 地址候选提取器 - 从文本中提取地址候选

import 'address_dictionary.dart';

/// 地址候选
class AddressCandidate {
  /// 候选文本
  final String text;

  /// 候选分数
  final double score;

  /// 候选类型
  final CandidateType type;

  /// 在原文中的位置
  final int startIndex;

  /// 在原文中的结束位置
  final int endIndex;

  const AddressCandidate({
    required this.text,
    required this.score,
    required this.type,
    this.startIndex = 0,
    this.endIndex = 0,
  });

  @override
  String toString() {
    return 'AddressCandidate(text: $text, score: ${score.toStringAsFixed(2)}, type: $type)';
  }
}

/// 候选类型
enum CandidateType {
  /// 地址候选
  address,

  /// 噪音
  noise,

  /// 未知
  unknown,
}

/// 地址候选提取器
///
/// 从文本中提取地址候选
/// 核心思想：先找 Candidate，而不是分析全文
class AddressCandidateExtractor {
  // ── 评分权重 ──────────────────────────────────────────────

  /// 包含区/县
  static const double _districtWeight = 0.30;

  /// 包含路/街
  static const double _roadWeight = 0.20;

  /// 包含小区名
  static const double _communityWeight = 0.25;

  /// 包含 POI
  static const double _poiWeight = 0.15;

  /// 包含数字
  static const double _numberWeight = 0.10;

  /// 噪音词扣分
  static const double _noisePenalty = 0.50;

  /// 长度异常扣分
  static const double _lengthPenalty = 0.20;

  // ── 长度阈值 ──────────────────────────────────────────────

  /// 最小地址长度
  static const int _minLength = 4;

  /// 最大地址长度
  static const int _maxLength = 50;

  // ── 提取方法 ──────────────────────────────────────────────

  /// 从文本中提取地址候选列表
  ///
  /// 输入：OCR 原始文本或清洗后文本
  /// 输出：地址候选列表（按分数降序）
  static List<AddressCandidate> extract(String text) {
    if (text.isEmpty) return [];

    // 第一步：按行分割
    final lines = text.split('\n');

    // 第二步：对每一行进行候选提取
    final candidates = <AddressCandidate>[];
    int currentIndex = 0;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        currentIndex += line.length + 1; // +1 for newline
        continue;
      }

      // 计算候选分数
      final score = _calculateScore(trimmed);

      // 判断候选类型
      final type = _classifyCandidate(trimmed, score);

      // 创建候选
      final candidate = AddressCandidate(
        text: trimmed,
        score: score,
        type: type,
        startIndex: currentIndex,
        endIndex: currentIndex + trimmed.length,
      );

      candidates.add(candidate);
      currentIndex += line.length + 1; // +1 for newline
    }

    // 第三步：过滤和排序
    final filtered = candidates.where((c) => c.type == CandidateType.address).toList();
    filtered.sort((a, b) => b.score.compareTo(a.score));

    return filtered;
  }

  /// 从文本中提取最佳地址候选
  ///
  /// 返回分数最高的地址候选
  static AddressCandidate? extractBest(String text) {
    final candidates = extract(text);
    return candidates.isNotEmpty ? candidates.first : null;
  }

  /// 从文本中提取所有候选（包括噪音）
  ///
  /// 用于调试和分析
  static List<AddressCandidate> extractAll(String text) {
    if (text.isEmpty) return [];

    final lines = text.split('\n');
    final candidates = <AddressCandidate>[];
    int currentIndex = 0;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        currentIndex += line.length + 1;
        continue;
      }

      final score = _calculateScore(trimmed);
      final type = _classifyCandidate(trimmed, score);

      candidates.add(AddressCandidate(
        text: trimmed,
        score: score,
        type: type,
        startIndex: currentIndex,
        endIndex: currentIndex + trimmed.length,
      ));

      currentIndex += line.length + 1;
    }

    return candidates;
  }

  // ── 评分方法 ──────────────────────────────────────────────

  /// 计算候选分数
  static double _calculateScore(String text) {
    double score = 0.0;

    // 检查噪音词
    for (final noise in AddressDictionary.noiseWords) {
      if (text.contains(noise)) {
        score -= _noisePenalty;
      }
    }

    // 检查区/县
    for (final suffix in AddressDictionary.districtSuffixes) {
      if (text.contains(suffix)) {
        score += _districtWeight;
        break;
      }
    }

    // 检查路/街
    for (final suffix in AddressDictionary.roadSuffixes) {
      if (text.contains(suffix)) {
        score += _roadWeight;
        break;
      }
    }

    // 检查小区名
    for (final suffix in AddressDictionary.communitySuffixes) {
      if (text.contains(suffix)) {
        score += _communityWeight;
        break;
      }
    }

    // 检查 POI
    for (final suffix in AddressDictionary.poiSuffixes) {
      if (text.contains(suffix)) {
        score += _poiWeight;
        break;
      }
    }

    // 检查数字
    if (RegExp(r'\d').hasMatch(text)) {
      score += _numberWeight;
    }

    // 长度检查
    if (text.length < _minLength || text.length > _maxLength) {
      score -= _lengthPenalty;
    }

    return score.clamp(0.0, 1.0);
  }

  /// 分类候选
  static CandidateType _classifyCandidate(String text, double score) {
    // 检查噪音词
    for (final noise in AddressDictionary.noiseWords) {
      if (text.contains(noise)) {
        return CandidateType.noise;
      }
    }

    // 检查是否像地址
    if (score >= 0.3) {
      return CandidateType.address;
    }

    return CandidateType.unknown;
  }
}
