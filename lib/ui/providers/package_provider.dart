import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../../main.dart';
import '../../core/debug/debug_trace.dart';
import '../../core/debug/metrics.dart';
import '../../platform/storage/hive_package.dart';
import '../../core/models/pending_confirmation.dart';
import '../../app/hero_decision.dart';
import '../../platform/notification/notification_adapter.dart';

class PackageListNotifier extends StateNotifier<List<Package>> {
  Box<HivePackage>? _box;

  /// 生命周期优先级：状态只能前进，不能倒退
  /// transit → delivering → arrived → pickedUp → archived
  static const Map<PackageStatus, int> _statusPriority = {
    PackageStatus.transit: 0,
    PackageStatus.delivering: 1,
    PackageStatus.arrived: 2,
    PackageStatus.pickedUp: 3,
    PackageStatus.archived: 4,
  };

  PackageListNotifier() : super([]) {
    debugPrint('[PackageListNotifier] initializing...');
    DebugTrace.separator('PACKAGE PROVIDER INIT');

    // ── Step 1: 获取 Hive box ────────────────────────────────
    try {
      _box = Hive.box<HivePackage>(kPackagesBox);
      debugPrint('[PackageListNotifier] Hive box opened: ${_box!.name}');
      debugPrint('[PackageListNotifier] box.isOpen: ${_box!.isOpen}');
      debugPrint('[PackageListNotifier] box.length: ${_box!.length}');
    } catch (e, stack) {
      DebugTrace.error('Hive box open FAILED', error: e, stackTrace: stack);
      debugPrint('[PackageListNotifier] Falling back to _initialPackages (no Hive persistence)');
      state = _initialPackages;
      return;
    }

    // ── Step 2: 从 Hive 加载 ─────────────────────────────────
    if (_box!.isNotEmpty) {
      final loaded = <Package>[];
      for (final hivePkg in _box!.values) {
        try {
          final pkg = hivePkg.toPackage();
          loaded.add(pkg);
          debugPrint('[PackageListNotifier] loaded: id=${pkg.id}'
              ' tracking=${pkg.trackingNumber}'
              ' code=${pkg.pickupCode}'
              ' status=${pkg.status.label}');
        } catch (e) {
          debugPrint('[PackageListNotifier] FAILED to convert HivePackage: $e');
        }
      }
      state = loaded;
      debugPrint('[PackageListNotifier] Loaded ${loaded.length} packages from Hive');
    } else {
      debugPrint('[PackageListNotifier] Hive box is EMPTY, using _initialPackages (${_initialPackages.length} items)');
      state = _initialPackages;
    }

    // ── Step 3: 同步回 Hive ──────────────────────────────────
    _sync();
    debugPrint('[PackageListNotifier] Synced ${state.length} packages back to Hive');
    DebugTrace.separator('PACKAGE PROVIDER INIT DONE');
    debugPrint('[PackageListNotifier] initialized. Total packages in state: ${state.length}');
  }

  void addPackage(Package package) {
    debugPrint('[PackageListNotifier] addPackage called (id: ${package.id})');
    DebugTrace.separator('ADD PACKAGE START');
    debugPrint('[PackageListNotifier] incoming: courier=${package.courier.displayName} '
        'tracking="${package.trackingNumber}" '
        'code=${package.pickupCode} '
        'location=${package.location} '
        'station=${package.originalStation} '
        'status=${package.status.label} '
        'fingerprint=${package.transitFingerprint}');
    debugPrint('[PackageListNotifier] state before: ${state.length} packages');

    // ── Step 1: Dedupe ───────────────────────────────────────
    final existingIndex = _findExistingPackage(package);

    if (existingIndex != -1) {
      // ── Step 2a: Merge ─────────────────────────────────────
      DebugTrace.separator('MERGE EXISTING PACKAGE');
      final existing = state[existingIndex];
      debugPrint('[PackageListNotifier] existing package found! Merging (id: ${existing.id})');
      debugPrint('[PackageListNotifier] existing: id=${existing.id} '
          'tracking=${existing.trackingNumber} '
          'status=${existing.status.label} '
          'notifiedArrived=${existing.notifiedArrived}');

      final resolvedStatus = _resolveStatus(existing.status, package.status);

      final updated = existing.copyWith(
        location: package.location.isNotEmpty ? package.location : existing.location,
        originalStation: package.originalStation.isNotEmpty ? package.originalStation : existing.originalStation,
        pickupCode: package.pickupCode.isNotEmpty ? package.pickupCode : existing.pickupCode,
        description: package.description.isNotEmpty ? package.description : existing.description,
        urgency: _higherUrgency(existing.urgency, package.urgency),
        addedAt: package.addedAt.isAfter(existing.addedAt) ? package.addedAt : existing.addedAt,
        status: resolvedStatus,
        transitFingerprint: package.transitFingerprint ?? existing.transitFingerprint,
        // 合并两个包裹的 events，去重
        events: [...existing.events, ...package.events]..fold(<String>{}, (ids, event) {
          if (!ids.contains(event.id)) {
            ids.add(event.id);
          }
          return ids;
        }).map((id) {
          return existing.events.firstWhere((e) => e.id == id, orElse: () => package.events.firstWhere((e) => e.id == id));
        }).toList(),
      );

      debugPrint('[PackageListNotifier] merged: status=${updated.status.label} '
          'urgency=${updated.urgency.label} '
          'location=${updated.location}');

      state = [
        for (int i = 0; i < state.length; i++)
          if (i == existingIndex) updated else state[i],
      ];

      if (updated.status.isArrived && !updated.notifiedArrived) {
        debugPrint('[PackageListNotifier] arrived, triggering notification');
        _triggerArrivedNotification(updated);
      }
    } else {
      // ── Step 2b: Create ────────────────────────────────────
      DebugTrace.separator('CREATE NEW PACKAGE');
      debugPrint('[PackageListNotifier] no existing package found, creating new');
      debugPrint('[PackageListNotifier] new: id=${package.id} tracking=${package.trackingNumber}');

      state = [...state, package];

      if (package.status.isArrived && !package.notifiedArrived) {
        debugPrint('[PackageListNotifier] arrived, triggering notification');
        _triggerArrivedNotification(package);
      }
    }

    // ── Step 3: Persist ──────────────────────────────────────
    _sync();
    debugPrint('[PackageListNotifier] addPackage completed. Final state: ${state.length} packages');

    DebugTrace.separator('ADD PACKAGE COMPLETE');
  }
  
  /// 触发到件通知
  void _triggerArrivedNotification(Package package) {
    final notificationService = NotificationAdapter();
    
    // 标记为已通知
    final updatedPackage = package.copyWith(notifiedArrived: true);
    state = [
      for (final p in state)
        if (p.id == package.id) updatedPackage else p,
    ];
    _sync();
    
    // 异步发送通知
    notificationService.showArrivedNotification(package);
    notificationService.scheduleReminderNotification(package);
  }
  
  /// 查找已存在的相同包裹
  ///
  /// 去重标准：指纹匹配（Fingerprint V1）
  /// 使用 fingerprint 作为唯一判断标准
  /// 高概率识别同一包裹
  int _findExistingPackage(Package package) {
    debugPrint('[PackageListNotifier] _findExistingPackage called');
    DebugTrace.separator('DEDUPE CHECK');

    debugPrint('[PackageListNotifier] state.length: ${state.length}');
    debugPrint('[PackageListNotifier] Incoming fingerprint: ${package.fingerprint}');
    for (var i = 0; i < state.length; i++) {
      final p = state[i];
      debugPrint('[PackageListNotifier]   [$i] id=${p.id} tracking="${p.trackingNumber}" '
          'fingerprint=${p.fingerprint} status=${p.status.label}');
    }

    // 使用 fingerprint 查找
    debugPrint('[PackageListNotifier] Dedupe by fingerprint: ${package.fingerprint}');
    final index = state.indexWhere((p) => p.fingerprint == package.fingerprint);

    if (index != -1) {
      Metrics.inc('dedupe.hit');
      debugPrint('[PackageListNotifier] → HIT: index=$index id=${state[index].id} (fingerprint match)');
      return index;
    }

    Metrics.inc('dedupe.miss');
    debugPrint('[PackageListNotifier] → NO MATCH (no fingerprint match)');
    return -1;
  }
  
  UrgencyLevel _higherUrgency(UrgencyLevel a, UrgencyLevel b) {
    return a.score >= b.score ? a : b;
  }

  /// 状态只能前进，不能倒退
  ///
  /// lifecycle: transit(0) → delivering(1) → arrived(2) → pickedUp(3) → archived(4)
  PackageStatus _resolveStatus(PackageStatus existing, PackageStatus incoming) {
    final existingPri = _statusPriority[existing] ?? 0;
    final incomingPri = _statusPriority[incoming] ?? 0;

    DebugTrace.separator('STATUS RESOLUTION');
    debugPrint('[PackageListNotifier] existing=${existing.label}($existingPri) '
        'incoming=${incoming.label}($incomingPri)');

    final resolved = incomingPri > existingPri ? incoming : existing;
    debugPrint('[PackageListNotifier] resolved=${resolved.label}');

    return resolved;
  }

  void markPickedUp(String id) {
    // 取消该包裹的通知
    NotificationAdapter().cancelNotification(id);
    
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

  /// 清除所有已完成（已取件 + 已归档）的包裹
  void clearCompleted() {
    state = state.where((p) => !p.status.isCompleted).toList();
    _sync();
  }

  void _sync() {
    final box = _box;
    if (box == null) return;

    // Write-through: put all current packages
    final stateIds = <String>{};
    for (final p in state) {
      stateIds.add(p.id);
      box.put(p.id, HivePackage.fromPackage(p));
    }

    // Remove packages no longer in state
    for (final key in box.keys.toList()) {
      if (!stateIds.contains(key)) {
        box.delete(key);
      }
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
    final location = package.displayLocation;
    grouped.putIfAbsent(location, () => []).add(package);
  }
  
  return grouped;
});

final heroDecisionProvider = Provider<HeroDecision>((ref) {
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
