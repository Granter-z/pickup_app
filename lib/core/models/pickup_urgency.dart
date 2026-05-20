/// 取件紧迫度 - 行动系统的核心驱动力
///
/// 职责：
/// 1. 基于时间规则动态计算取件紧迫程度
/// 2. 驱动首页排序、通知、路线规划
/// 3. 纯 Dart，不依赖 Flutter
library;

/// 取件紧迫度
enum PickupUrgency {
  /// 新到件（24小时内），不急
  low,

  /// 已放置超24小时，但离超时还远
  medium,

  /// 明天即将超时，开始产生滞留风险
  high,

  /// 今天最后一天 / 已经超时开始计费，必须立刻行动
  critical,
}

/// 紧迫度语义扩展
extension PickupUrgencyX on PickupUrgency {
  /// 紧迫度标签
  String get label {
    switch (this) {
      case PickupUrgency.low:
        return '不急';
      case PickupUrgency.medium:
        return '待取';
      case PickupUrgency.high:
        return '即将超时';
      case PickupUrgency.critical:
        return '急需处理';
    }
  }

  /// 紧迫度评分（用于排序）
  int get score {
    switch (this) {
      case PickupUrgency.low:
        return 0;
      case PickupUrgency.medium:
        return 1;
      case PickupUrgency.high:
        return 2;
      case PickupUrgency.critical:
        return 3;
    }
  }

  /// 是否需要立即行动
  bool get needsImmediateAction =>
      this == PickupUrgency.high || this == PickupUrgency.critical;

  /// 是否会产生滞留费风险
  bool get hasTimeoutRisk =>
      this == PickupUrgency.high || this == PickupUrgency.critical;
}

/// 紧迫度计算器 - 纯逻辑，不依赖 UI
class PickupUrgencyCalculator {
  /// 计算包裹的取件紧迫度
  ///
  /// 规则优先级：
  /// 1. 已取件 → low
  /// 2. 有明确超时时间 → 基于时间差计算
  /// 3. 无超时时间 → 基于入库时间粗略判断
  static PickupUrgency calculate({
    required DateTime addedAt,
    required bool isPickedUp,
    DateTime? timeoutAt,
  }) {
    // 已取件 → 低优先级
    if (isPickedUp) return PickupUrgency.low;

    final now = DateTime.now();

    // 有明确超时时间 → 精确计算
    if (timeoutAt != null) {
      final difference = timeoutAt.difference(now);

      // 已超时
      if (difference.isNegative) return PickupUrgency.critical;

      // 12小时内超时
      if (difference.inHours <= 12) return PickupUrgency.critical;

      // 24小时内超时
      if (difference.inHours <= 24) return PickupUrgency.high;

      // 48小时内超时
      if (difference.inHours <= 48) return PickupUrgency.medium;
    }

    // 兜底：基于入库时间粗略判断
    final hoursInStorage = now.difference(addedAt).inHours;

    if (hoursInStorage >= 72) return PickupUrgency.high;
    if (hoursInStorage >= 48) return PickupUrgency.medium;
    if (hoursInStorage >= 24) return PickupUrgency.low;

    return PickupUrgency.low;
  }
}
