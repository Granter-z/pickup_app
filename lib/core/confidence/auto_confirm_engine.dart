// lib/core/confidence/auto_confirm_engine.dart
// 自动确认引擎 - 独立的自动确认决策系统

import '../models/package.dart';
import '../address/address_parser.dart';
import 'location_quality_analyzer.dart';
import 'suspicious_dictionary.dart';

/// 自动确认结果
class AutoConfirmResult {
  /// 是否应该自动确认
  final bool shouldAutoConfirm;

  /// 决策原因列表
  final List<String> reasons;

  /// 信任分数 (0.0 ~ 1.0)
  final double trustScore;

  /// 字段置信度
  final double fieldConfidence;

  /// 语义置信度
  final double semanticConfidence;

  /// 历史稳定性
  final double historicalStability;

  const AutoConfirmResult({
    required this.shouldAutoConfirm,
    required this.reasons,
    required this.trustScore,
    this.fieldConfidence = 0.0,
    this.semanticConfidence = 0.0,
    this.historicalStability = 0.0,
  });

  @override
  String toString() {
    return 'AutoConfirmResult(shouldAutoConfirm: $shouldAutoConfirm, '
        'trustScore: ${trustScore.toStringAsFixed(2)}, reasons: $reasons)';
  }
}

/// 历史记录接口
///
/// 用于查询地址的历史出现次数
abstract class HistoryRepository {
  /// 查询地址的历史出现次数
  int getLocationCount(String location);

  /// 查询取件码的历史出现次数
  int getPickupCodeCount(String pickupCode);

  /// 查询地址是否是新地址
  bool isNewLocation(String location);
}

/// 自动确认引擎
///
/// 独立的自动确认决策系统
/// 不依赖简单的 confidence > 0.9，而是评估"低风险 + 高稳定"
class AutoConfirmEngine {
  final HistoryRepository? _historyRepository;

  AutoConfirmEngine({HistoryRepository? historyRepository})
      : _historyRepository = historyRepository;

  /// 评估是否应该自动确认
  ///
  /// 输入：Package
  /// 输出：AutoConfirmResult
  AutoConfirmResult evaluate(Package package) {
    final reasons = <String>[];
    double fieldConfidence = 0.0;
    double semanticConfidence = 0.0;
    double historicalStability = 0.0;

    // ── Rule 1: pickupCode 必须存在 ──────────────────────────
    if (package.pickupCode.isEmpty) {
      reasons.add('缺少取件码，绝不自动确认');
      return AutoConfirmResult(
        shouldAutoConfirm: false,
        reasons: reasons,
        trustScore: 0.0,
      );
    }

    // ── Rule 2: trackingNumber 必须存在 ──────────────────────
    if (package.trackingNumber.isEmpty) {
      reasons.add('缺少运单号，可能是假事件');
      return AutoConfirmResult(
        shouldAutoConfirm: false,
        reasons: reasons,
        trustScore: 0.0,
      );
    }

    // ── Rule 3: 语义质量检查 ──────────────────────────────────
    final locationResult = LocationQualityAnalyzer.analyze(
      rawLocation: package.rawLocation,
      cleanedLocation: package.cleanedLocation,
      originalStation: package.originalStation,
    );
    semanticConfidence = locationResult.score;

    if (semanticConfidence < 0.8) {
      reasons.add('地址可信度不足 (${semanticConfidence.toStringAsFixed(2)})');
    }

    // ── Rule 4: 可疑词检查 ──────────────────────────────────
    if (locationResult.hitSuspiciousWords.isNotEmpty) {
      reasons.add('检测到可疑词: ${locationResult.hitSuspiciousWords.join(", ")}');
    }

    // ── Rule 5: 历史稳定性检查 ──────────────────────────────
    historicalStability = _calculateHistoricalStability(package);
    if (historicalStability < 0.5) {
      reasons.add('地址历史稳定性不足 (${historicalStability.toStringAsFixed(2)})');
    }

    // ── 计算字段置信度 ──────────────────────────────────────
    fieldConfidence = _calculateFieldConfidence(package);

    // ── 计算信任分数 ──────────────────────────────────────
    final trustScore = _calculateTrustScore(
      fieldConfidence: fieldConfidence,
      semanticConfidence: semanticConfidence,
      historicalStability: historicalStability,
    );

    // ── 最终决策 ──────────────────────────────────────────
    final shouldAutoConfirm = _makeDecision(
      pickupCodeExists: package.pickupCode.isNotEmpty,
      trackingNumberExists: package.trackingNumber.isNotEmpty,
      semanticConfidence: semanticConfidence,
      hasSuspiciousWords: locationResult.hitSuspiciousWords.isNotEmpty,
      historicalStability: historicalStability,
      trustScore: trustScore,
    );

    if (shouldAutoConfirm) {
      reasons.add('满足自动确认条件');
    }

    return AutoConfirmResult(
      shouldAutoConfirm: shouldAutoConfirm,
      reasons: reasons,
      trustScore: trustScore,
      fieldConfidence: fieldConfidence,
      semanticConfidence: semanticConfidence,
      historicalStability: historicalStability,
    );
  }

  // ── 辅助方法 ──────────────────────────────────────────────

  /// 计算字段置信度
  double _calculateFieldConfidence(Package package) {
    double score = 0.0;
    int count = 0;

    // 取件码
    if (package.pickupCode.isNotEmpty) {
      score += 0.9;
      count++;
    }

    // 运单号
    if (package.trackingNumber.isNotEmpty) {
      score += 0.8;
      count++;
    }

    // 地址
    if (package.cleanedLocation.isNotEmpty) {
      score += 0.7;
      count++;
    }

    // 快递公司
    if (package.courier != CourierType.other) {
      score += 0.8;
      count++;
    }

    return count > 0 ? score / count : 0.0;
  }

  /// 计算历史稳定性
  double _calculateHistoricalStability(Package package) {
    if (_historyRepository == null) {
      // 没有历史仓库时，返回默认值
      return 0.5;
    }

    final location = package.cleanedLocation.isNotEmpty
        ? package.cleanedLocation
        : package.rawLocation;

    if (location.isEmpty) {
      return 0.0;
    }

    // 查询地址历史出现次数
    final locationCount = _historyRepository.getLocationCount(location);

    // 查询取件码历史出现次数
    final pickupCodeCount = _historyRepository.getPickupCodeCount(package.pickupCode);

    // 计算稳定性分数
    // 出现次数越多，稳定性越高
    double locationStability = 0.0;
    if (locationCount >= 5) {
      locationStability = 1.0;
    } else if (locationCount >= 3) {
      locationStability = 0.8;
    } else if (locationCount >= 1) {
      locationStability = 0.6;
    } else {
      locationStability = 0.3; // 新地址
    }

    double codeStability = 0.0;
    if (pickupCodeCount >= 3) {
      codeStability = 1.0;
    } else if (pickupCodeCount >= 1) {
      codeStability = 0.7;
    } else {
      codeStability = 0.4;
    }

    // 综合稳定性
    return (locationStability * 0.6 + codeStability * 0.4).clamp(0.0, 1.0);
  }

  /// 计算信任分数
  double _calculateTrustScore({
    required double fieldConfidence,
    required double semanticConfidence,
    required double historicalStability,
  }) {
    return (fieldConfidence * 0.4 +
            semanticConfidence * 0.3 +
            historicalStability * 0.3)
        .clamp(0.0, 1.0);
  }

  /// 最终决策
  bool _makeDecision({
    required bool pickupCodeExists,
    required bool trackingNumberExists,
    required double semanticConfidence,
    required bool hasSuspiciousWords,
    required double historicalStability,
    required double trustScore,
  }) {
    // 必须条件
    if (!pickupCodeExists) return false;
    if (!trackingNumberExists) return false;

    // 语义质量必须达标
    if (semanticConfidence < 0.8) return false;

    // 不能有可疑词
    if (hasSuspiciousWords) return false;

    // 历史稳定性必须达标
    if (historicalStability < 0.5) return false;

    // 信任分数必须达标
    if (trustScore < 0.7) return false;

    return true;
  }
}
