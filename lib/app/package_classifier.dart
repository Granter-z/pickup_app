/// 包裹分类器 - 行动系统的智能调度器
///
/// 职责：
/// 1. 基于紧迫度进行权重排序
/// 2. 首页今日清单过滤和排序
/// 3. 通知拦截判断
library;

import '../core/models/package.dart';
import '../core/models/package_status.dart';
import '../core/models/pickup_urgency.dart';

/// 包裹分类器
class PackageClassifier {
  /// 查找当前最高优先级的包裹（用于 HeroCard 动态置顶）
  static Package? getMostUrgentPackage(List<Package> packages) {
    final activeList = getTodayPickupList(packages);
    if (activeList.isEmpty) return null;

    // 按紧迫度排序，critical -> high -> medium -> low
    activeList.sort(
        (a, b) => b.pickupUrgency.score.compareTo(a.pickupUrgency.score));
    return activeList.first;
  }

  /// 首页今日清单：不仅过滤状态，还要按紧迫度降序排列
  static List<Package> getTodayPickupList(List<Package> packages) {
    final list = packages
        .where((p) =>
            p.status != PackageStatus.pickedUp &&
            p.status != PackageStatus.archived)
        .toList();

    // 关键行动规则：最紧急的永远排在列表最前
    list.sort(
        (a, b) => b.pickupUrgency.score.compareTo(a.pickupUrgency.score));
    return list;
  }

  /// 获取紧急包裹列表（high 或 critical）
  static List<Package> getUrgentPackages(List<Package> packages) {
    return getTodayPickupList(packages)
        .where((p) => p.pickupUrgency.needsImmediateAction)
        .toList();
  }

  /// 通知拦截闸：只有高紧迫度才允许触发系统级推送通知
  static bool shouldTriggerPushNotification(Package package) {
    return package.pickupUrgency.needsImmediateAction;
  }

  /// 获取待确认包裹数量
  static int getPendingConfirmationCount(List<Package> packages) {
    // 这里需要根据实际的待确认逻辑来实现
    // 暂时返回 0，后续可以集成 PendingConfirmation 模型
    return 0;
  }

  /// 按紧迫度分组
  static Map<PickupUrgency, List<Package>> groupByUrgency(
      List<Package> packages) {
    final map = <PickupUrgency, List<Package>>{};
    for (final urgency in PickupUrgency.values) {
      map[urgency] = [];
    }

    for (final package in getTodayPickupList(packages)) {
      map[package.pickupUrgency]!.add(package);
    }

    return map;
  }

  /// 获取特定紧迫度的包裹数量
  static int getCountByUrgency(
      List<Package> packages, PickupUrgency urgency) {
    return getTodayPickupList(packages)
        .where((p) => p.pickupUrgency == urgency)
        .length;
  }
}
