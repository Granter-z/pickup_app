/// 调试用 Mock 包裹数据
///
/// 仅在 kDebugMode 下加载，不污染生产环境和测试。
library;

import 'package:flutter/foundation.dart';
import 'package:pickup_app/core/models/package.dart';
import 'package:pickup_app/core/models/package_status.dart';

/// 开发调试用的 mock 包裹列表
final List<Package> mockPackages = [
  Package(
    id: 'mock_1',
    trackingNumber: 'SF1234567890',
    courier: CourierType.sf,
    pickupCode: '6-8-2301',
    location: '小区东门菜鸟驿站',
    description: 'Apple AirPods Pro',
    urgency: UrgencyLevel.urgent,
    status: PackageStatus.arrived,
    addedAt: DateTime.now().subtract(const Duration(hours: 2)),
  ),
  Package(
    id: 'mock_2',
    trackingNumber: 'JD9876543210',
    courier: CourierType.jd,
    pickupCode: '',
    location: '京东快递柜 A-12',
    description: 'Kindle Paperwhite',
    urgency: UrgencyLevel.warning,
    status: PackageStatus.arrived,
    addedAt: DateTime.now().subtract(const Duration(hours: 5)),
  ),
  Package(
    id: 'mock_3',
    trackingNumber: 'ZTO2024050100001',
    courier: CourierType.zto,
    pickupCode: '8812',
    location: '小区西门快递点',
    description: '日用品套装',
    urgency: UrgencyLevel.normal,
    status: PackageStatus.delivering,
    addedAt: DateTime.now().subtract(const Duration(hours: 8)),
  ),
  Package(
    id: 'mock_4',
    trackingNumber: 'YT2024050100002',
    courier: CourierType.yt,
    pickupCode: '3-5-1802',
    location: '圆通驿站',
    description: '书籍 x3',
    urgency: UrgencyLevel.low,
    status: PackageStatus.transit,
    addedAt: DateTime.now().subtract(const Duration(days: 1)),
  ),
  Package(
    id: 'mock_5',
    trackingNumber: 'SF9999888877',
    courier: CourierType.sf,
    pickupCode: '',
    location: '顺丰速运营业点',
    description: '机械键盘',
    urgency: UrgencyLevel.normal,
    status: PackageStatus.pickedUp,
    addedAt: DateTime.now().subtract(const Duration(days: 2)),
    pickedUpAt: DateTime.now().subtract(const Duration(days: 1)),
  ),
  Package(
    id: 'mock_6',
    trackingNumber: 'YD2024042800003',
    courier: CourierType.yd,
    pickupCode: '5566',
    location: '韵达快递超市',
    description: '手机壳',
    urgency: UrgencyLevel.low,
    status: PackageStatus.pickedUp,
    addedAt: DateTime.now().subtract(const Duration(days: 3)),
    pickedUpAt: DateTime.now().subtract(const Duration(days: 2)),
  ),
];

/// 在 debug 模式下加载 mock 数据到 notifier
void loadMockPackages(dynamic notifier) {
  if (!kDebugMode) return;
  for (final pkg in mockPackages) {
    notifier.addPackage(pkg);
  }
}
