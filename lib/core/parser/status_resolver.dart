// lib/core/parser/status_resolver.dart
// 状态解析器 - Timeline Semantic System

import '../models/package_status.dart';

/// 检测到的状态
class DetectedStatus {
  /// 状态类型
  final PackageStatus status;

  /// 状态来源（关键词）
  final String source;

  /// 置信度
  final double confidence;

  /// 是否是历史状态（非当前状态）
  final bool isHistorical;

  const DetectedStatus({
    required this.status,
    required this.source,
    this.confidence = 1.0,
    this.isHistorical = false,
  });

  @override
  String toString() {
    return 'DetectedStatus(status: ${status.label}, source: $source, '
        'confidence: $confidence, isHistorical: $isHistorical)';
  }
}

/// 解析后的状态
class ResolvedStatus {
  /// 最终状态
  final PackageStatus status;

  /// 是否有冲突
  final bool hasConflict;

  /// 决策原因
  final List<String> reasons;

  /// 所有检测到的状态
  final List<DetectedStatus> detectedStatuses;

  const ResolvedStatus({
    required this.status,
    required this.hasConflict,
    required this.reasons,
    this.detectedStatuses = const [],
  });

  @override
  String toString() {
    return 'ResolvedStatus(status: ${status.label}, hasConflict: $hasConflict, '
        'reasons: $reasons)';
  }
}

/// 状态解析器
///
/// 负责：
/// 1. 时间线理解
/// 2. 状态优先级
/// 3. 最终状态决策
///
/// 核心思想：
/// - 历史物流 + 当前到达 ≠ 冲突
/// - 只有同层级矛盾才是冲突
class StatusResolver {
  // ── 状态优先级 ──────────────────────────────────────────────

  /// 状态优先级（数值越大越优先）
  static const Map<PackageStatus, int> _statusPriority = {
    PackageStatus.transit: 0,
    PackageStatus.delivering: 1,
    PackageStatus.arrived: 2,
    PackageStatus.pickedUp: 3,
    PackageStatus.archived: 4,
  };

  // ── 解析方法 ──────────────────────────────────────────────

  /// 解析状态
  ///
  /// 输入：检测到的状态列表
  /// 输出：ResolvedStatus（包含最终状态和是否有冲突）
  static ResolvedStatus resolve(List<DetectedStatus> statuses) {
    if (statuses.isEmpty) {
      return const ResolvedStatus(
        status: PackageStatus.transit,
        hasConflict: false,
        reasons: ['没有检测到状态，默认为运输中'],
      );
    }

    // 只有一个状态，直接返回
    if (statuses.length == 1) {
      return ResolvedStatus(
        status: statuses.first.status,
        hasConflict: false,
        reasons: ['只有一个状态: ${statuses.first.source}'],
        detectedStatuses: statuses,
      );
    }

    final reasons = <String>[];

    // ── Rule 1: arrival + pickupCode 直接确认 ──────────────────
    final hasArrival = statuses.any((s) => s.status == PackageStatus.arrived);
    final hasPickupCode = statuses.any((s) =>
        s.source.contains('取件码') || s.source.contains('取货码'));

    if (hasArrival && hasPickupCode) {
      reasons.add('到达状态 + 取件码，直接确认为 arrived');
      return ResolvedStatus(
        status: PackageStatus.arrived,
        hasConflict: false,
        reasons: reasons,
        detectedStatuses: statuses,
      );
    }

    // ── Rule 2: 历史物流 + 当前到达 ≠ 冲突 ──────────────────────
    final historicalStatuses = statuses.where((s) => s.isHistorical).toList();
    final currentStatuses = statuses.where((s) => !s.isHistorical).toList();

    if (historicalStatuses.isNotEmpty && currentStatuses.isNotEmpty) {
      // 有历史状态和当前状态，按时间线理解
      final highestCurrent = _getHighestPriority(currentStatuses);
      reasons.add('历史物流 + 当前状态，按时间线理解: ${highestCurrent.source}');
      return ResolvedStatus(
        status: highestCurrent.status,
        hasConflict: false,
        reasons: reasons,
        detectedStatuses: statuses,
      );
    }

    // ── Rule 3: 同层级矛盾才冲突 ──────────────────────────────
    final uniqueStatuses = statuses.map((s) => s.status).toSet();

    // 检查是否有真正的矛盾
    if (_hasRealConflict(statuses)) {
      reasons.add('检测到同层级矛盾');
      final highest = _getHighestPriority(statuses);
      return ResolvedStatus(
        status: highest.status,
        hasConflict: true,
        reasons: reasons,
        detectedStatuses: statuses,
      );
    }

    // ── Rule 4: 默认取最高优先级 ──────────────────────────────
    final highest = _getHighestPriority(statuses);
    reasons.add('取最高优先级状态: ${highest.source}');
    return ResolvedStatus(
      status: highest.status,
      hasConflict: false,
      reasons: reasons,
      detectedStatuses: statuses,
    );
  }

  // ── 辅助方法 ──────────────────────────────────────────────

  /// 获取最高优先级的状态
  static DetectedStatus _getHighestPriority(List<DetectedStatus> statuses) {
    return statuses.reduce((a, b) {
      final aPriority = _statusPriority[a.status] ?? 0;
      final bPriority = _statusPriority[b.status] ?? 0;
      return aPriority >= bPriority ? a : b;
    });
  }

  /// 检查是否有真正的矛盾
  ///
  /// 真正的矛盾：
  /// - arrived + transit（同层级）
  /// - pickedUp + arrived（同层级）
  ///
  /// 不是矛盾：
  /// - transit + arrived（时间线 progression）
  /// - delivering + arrived（时间线 progression）
  static bool _hasRealConflict(List<DetectedStatus> statuses) {
    final statusSet = statuses.map((s) => s.status).toSet();

    // 检查是否同时有 arrived 和 transit（且不是历史+当前）
    if (statusSet.contains(PackageStatus.arrived) &&
        statusSet.contains(PackageStatus.transit)) {
      // 如果有历史状态和当前状态，不是矛盾
      final hasHistorical = statuses.any((s) => s.isHistorical);
      final hasCurrent = statuses.any((s) => !s.isHistorical);
      if (hasHistorical && hasCurrent) {
        return false; // 时间线 progression
      }
      return true; // 同层级矛盾
    }

    // 检查是否同时有 pickedUp 和 arrived
    if (statusSet.contains(PackageStatus.pickedUp) &&
        statusSet.contains(PackageStatus.arrived)) {
      return true;
    }

    // 检查是否同时有 pickedUp 和 transit
    if (statusSet.contains(PackageStatus.pickedUp) &&
        statusSet.contains(PackageStatus.transit)) {
      return true;
    }

    return false;
  }
}
