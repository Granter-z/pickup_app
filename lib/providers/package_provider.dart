import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../main.dart';
import '../models/package_model.dart';
import '../models/status_extension.dart';
import '../services/hero_decision_service.dart';

class PackageListNotifier extends StateNotifier<List<Package>> {
  final Box<Package> _box = Hive.box<Package>(kPackagesBox);

  PackageListNotifier() : super([]) {
    state = _box.isNotEmpty ? _box.values.toList() : _initialPackages;
    _sync();
  }

  void addPackage(Package package) {
    // 检查是否已存在相同的快递（基于快递公司和运单号）
    final existingIndex = state.indexWhere((p) => 
        p.courier == package.courier && 
        p.trackingNumber == package.trackingNumber &&
        p.status.isPending);
    
    if (existingIndex != -1) {
      // 已存在相同快递，整合信息
      final existing = state[existingIndex];
      final updated = existing.copyWith(
        // 使用新包裹的位置信息（如果有）
        location: package.location.isNotEmpty ? package.location : existing.location,
        // 使用新包裹的取件码（如果有）
        pickupCode: package.pickupCode.isNotEmpty ? package.pickupCode : existing.pickupCode,
        // 使用新包裹的描述（如果有）
        description: package.description.isNotEmpty ? package.description : existing.description,
        // 选择更高的紧急程度
        urgency: _higherUrgency(existing.urgency, package.urgency),
        // 更新添加时间
        addedAt: package.addedAt.isAfter(existing.addedAt) ? package.addedAt : existing.addedAt,
        // 如果新包裹是已到达状态，更新状态
        status: package.status.urgencyScore > existing.status.urgencyScore 
            ? package.status 
            : existing.status,
      );
      
      state = [
        for (int i = 0; i < state.length; i++)
          if (i == existingIndex) updated else state[i],
      ];
    } else {
      // 不存在重复，直接添加
      state = [...state, package];
    }
    _sync();
  }
  
  UrgencyLevel _higherUrgency(UrgencyLevel a, UrgencyLevel b) {
    // 紧急程度优先级：urgent > warning > normal > low
    const order = {
      UrgencyLevel.urgent: 3,
      UrgencyLevel.warning: 2,
      UrgencyLevel.normal: 1,
      UrgencyLevel.low: 0,
    };
    return order[a]! >= order[b]! ? a : b;
  }

  void markPickedUp(String id) {
    state = [
      for (final p in state)
        if (p.id == id)
          p.copyWith(
            status: PackageStatus.pickedUp,
            pickedUpAt: DateTime.now(),
          )
        else
          p,
    ];
    _sync();
  }

  void _sync() {
    _box.clear();
    for (final p in state) {
      _box.put(p.id, p);
    }
  }
}

final packageListProvider =
    StateNotifierProvider<PackageListNotifier, List<Package>>((ref) {
  return PackageListNotifier();
});

final pendingPackagesProvider = Provider<List<Package>>((ref) {
  final pending = ref
      .watch(packageListProvider)
      .where((p) => p.status.isPending)
      .toList();
  
  // 先按取货地点分组，相同地址放在一起
  // 然后在每个地址组内按紧急程度排序
  pending.sort((a, b) {
    // 首先按取货地点排序（空地址排在最后）
    final locationA = a.location.isNotEmpty ? a.location : 'ZZZ'; // 空地址排最后
    final locationB = b.location.isNotEmpty ? b.location : 'ZZZ';
    final locationCompare = locationA.compareTo(locationB);
    if (locationCompare != 0) return locationCompare;
    
    // 同一地址内按紧急程度排序（高优先级在前）
    return b.status.urgencyScore.compareTo(a.status.urgencyScore);
  });
  
  return pending;
});

final completedPackagesProvider = Provider<List<Package>>((ref) {
  return ref.watch(packageListProvider).where((p) => p.status.isCompleted).toList();
});

final groupedPendingPackagesProvider = Provider<Map<String, List<Package>>>((ref) {
  final pending = ref.watch(pendingPackagesProvider);
  final grouped = <String, List<Package>>{};
  
  for (final package in pending) {
    final location = package.location.isNotEmpty ? package.location : '未指定取货点';
    grouped.putIfAbsent(location, () => []).add(package);
  }
  
  return grouped;
});

final heroDecisionProvider = Provider<HeroCardDecision>((ref) {
  final packages = ref.watch(packageListProvider);
  return HeroDecisionService.decide(packages);
});

final _initialPackages = <Package>[
  Package(
    id: '1',
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
    id: '2',
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
    id: '3',
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
    id: '4',
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
    id: '5',
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
    id: '6',
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
