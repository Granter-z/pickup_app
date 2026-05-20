/// 包裹分类器 Provider - 行动系统的状态管理
///
/// 职责：
/// 1. 提供基于紧迫度的包裹列表
/// 2. 提供紧急包裹信息
/// 3. 集成 Riverpod 状态管理
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/package.dart';
import '../../core/models/pickup_urgency.dart';
import '../../app/package_classifier.dart';
import 'package_provider.dart';

/// 今日待取包裹列表（按紧迫度排序）
final todayPickupListProvider = Provider<List<Package>>((ref) {
  final packages = ref.watch(pendingPackagesProvider);
  return PackageClassifier.getTodayPickupList(packages);
});

/// 紧急包裹列表（high 或 critical）
final urgentPackagesProvider = Provider<List<Package>>((ref) {
  final packages = ref.watch(pendingPackagesProvider);
  return PackageClassifier.getUrgentPackages(packages);
});

/// 最紧急的包裹
final mostUrgentPackageProvider = Provider<Package?>((ref) {
  final packages = ref.watch(pendingPackagesProvider);
  return PackageClassifier.getMostUrgentPackage(packages);
});

/// 按紧迫度分组的包裹
final packagesByUrgencyProvider =
    Provider<Map<PickupUrgency, List<Package>>>((ref) {
  final packages = ref.watch(pendingPackagesProvider);
  return PackageClassifier.groupByUrgency(packages);
});

/// 各紧迫度包裹数量
final urgencyCountProvider =
    Provider.family<int, PickupUrgency>((ref, urgency) {
  final packages = ref.watch(pendingPackagesProvider);
  return PackageClassifier.getCountByUrgency(packages, urgency);
});
