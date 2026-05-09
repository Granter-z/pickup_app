import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../main.dart';
import '../models/package_model.dart';
import '../core/models/pending_confirmation.dart';
import '../services/hero_decision_service.dart';

class PackageListNotifier extends StateNotifier<List<Package>> {
  final Box<HivePackage> _box = Hive.box<HivePackage>(kPackagesBox);

  PackageListNotifier() : super([]) {
    state = _box.isNotEmpty 
        ? _box.values.map((hivePkg) => hivePkg.toPackage()).toList()
        : _initialPackages;
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
        location: package.location.isNotEmpty ? package.location : existing.location,
        pickupCode: package.pickupCode.isNotEmpty ? package.pickupCode : existing.pickupCode,
        description: package.description.isNotEmpty ? package.description : existing.description,
        urgency: _higherUrgency(existing.urgency, package.urgency),
        addedAt: package.addedAt.isAfter(existing.addedAt) ? package.addedAt : existing.addedAt,
        status: package.status.urgencyScore > existing.status.urgencyScore 
            ? package.status 
            : existing.status,
      );
      
      state = [
        for (int i = 0; i < state.length; i++)
          if (i == existingIndex) updated else state[i],
      ];
    } else {
      state = [...state, package];
    }
    _sync();
  }
  
  UrgencyLevel _higherUrgency(UrgencyLevel a, UrgencyLevel b) {
    return a.score >= b.score ? a : b;
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
  
  /// 自动归档已取件超过7天的包裹
  void autoArchive() {
    state = [
      for (final p in state)
        p.shouldAutoArchive 
            ? p.copyWith(
                status: PackageStatus.archived,
                archivedAt: DateTime.now(),
              )
            : p,
    ];
    _sync();
  }

  void _sync() {
    _box.clear();
    for (final p in state) {
      _box.put(p.id, HivePackage.fromPackage(p));
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
  
  pending.sort((a, b) {
    final locationA = a.location.isNotEmpty ? a.location : 'ZZZ';
    final locationB = b.location.isNotEmpty ? b.location : 'ZZZ';
    final locationCompare = locationA.compareTo(locationB);
    if (locationCompare != 0) return locationCompare;
    
    return b.compositeUrgencyScore.compareTo(a.compositeUrgencyScore);
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

// ── 待确认区 ──────────────────────────────────────────────────

/// 待确认包裹管理器
class PendingConfirmationNotifier extends StateNotifier<List<PendingConfirmation>> {
  PendingConfirmationNotifier() : super([]);

  /// 添加待确认包裹
  void add(PendingConfirmation confirmation) {
    state = [...state, confirmation];
  }

  /// 批量添加
  void addAll(List<PendingConfirmation> confirmations) {
    state = [...state, ...confirmations];
  }

  /// 确认包裹（移除待确认，返回 Package）
  Package? confirm(String id) {
    final index = state.indexWhere((c) => c.id == id);
    if (index == -1) return null;

    final confirmation = state[index];
    state = state.where((c) => c.id != id).toList();
    return confirmation.toPackage();
  }

  /// 拒绝包裹（直接移除）
  void reject(String id) {
    state = state.where((c) => c.id != id).toList();
  }

  /// 修改后确认
  Package? confirmWithEdit(String id, {
    CourierType? courier,
    String? pickupCode,
    String? trackingNumber,
    String? location,
    PackageStatus? status,
  }) {
    final index = state.indexWhere((c) => c.id == id);
    if (index == -1) return null;

    final original = state[index];
    final edited = original.copyWith(
      courier: courier ?? original.courier,
      pickupCode: pickupCode ?? original.pickupCode,
      trackingNumber: trackingNumber ?? original.trackingNumber,
      location: location ?? original.location,
      status: status ?? original.status,
    );

    state = state.where((c) => c.id != id).toList();
    return edited.toPackage();
  }

  /// 清空所有
  void clear() {
    state = [];
  }
}

/// 待确认包裹 Provider
final pendingConfirmationsProvider =
    StateNotifierProvider<PendingConfirmationNotifier, List<PendingConfirmation>>(
  (ref) => PendingConfirmationNotifier(),
);

/// 待确认包裹数量 Provider
final pendingConfirmationCountProvider = Provider<int>((ref) {
  return ref.watch(pendingConfirmationsProvider).length;
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
