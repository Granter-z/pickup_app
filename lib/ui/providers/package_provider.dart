import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../app/hero_decision.dart';
import '../../core/debug/debug_trace.dart';
import '../../core/debug/metrics.dart';
import '../../core/models/logistics_event.dart';
import '../../core/models/pending_confirmation.dart';
import '../../main.dart';
import '../../platform/notification/notification_adapter.dart';
import '../../platform/storage/hive_package.dart';

class PackageListNotifier extends StateNotifier<List<Package>> {
  Box<HivePackage>? _box;

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

    try {
      _box = Hive.box<HivePackage>(kPackagesBox);
      debugPrint('[PackageListNotifier] Hive box opened: ${_box!.name}');
      debugPrint('[PackageListNotifier] box.isOpen: ${_box!.isOpen}');
      debugPrint('[PackageListNotifier] box.length: ${_box!.length}');
    } catch (e, stack) {
      DebugTrace.error('Hive box open FAILED', error: e, stackTrace: stack);
      state = [];
      return;
    }

    if (_box!.isNotEmpty) {
      final loaded = <Package>[];
      for (final hivePkg in _box!.values) {
        try {
          loaded.add(hivePkg.toPackage());
        } catch (e) {
          debugPrint('[PackageListNotifier] FAILED to convert HivePackage: $e');
        }
      }
      state = loaded;
      debugPrint('[PackageListNotifier] Loaded ${loaded.length} packages from Hive');
    } else {
      state = [];
      debugPrint('[PackageListNotifier] Hive box is EMPTY, starting with clean state');
    }

    _sync();
    debugPrint('[PackageListNotifier] initialized. Total packages in state: ${state.length}');
    DebugTrace.separator('PACKAGE PROVIDER INIT DONE');
  }

  void addPackage(Package package) {
    debugPrint('[PackageListNotifier] addPackage called (id: ${package.id})');
    DebugTrace.separator('ADD PACKAGE START');

    final existingIndex = _findExistingPackage(package);
    if (existingIndex != -1) {
      final existing = state[existingIndex];
      final resolvedStatus = _resolveStatus(existing.status, package.status);
      final resolvedRawLocation =
          existing.rawLocation.isNotEmpty ? existing.rawLocation : package.rawLocation;
      final resolvedCleanedLocation =
          package.cleanedLocation.isNotEmpty ? package.cleanedLocation : existing.cleanedLocation;
      final resolvedCanonicalLocation = Package.resolveCanonicalLocation(
        existing: existing.canonicalLocation,
        incoming: package.cleanedLocation,
        existingConfidence: existing.locationConfidence,
        incomingConfidence: package.locationConfidence,
      );
      final resolvedLocationConfidence = package.locationConfidence > existing.locationConfidence
          ? package.locationConfidence
          : existing.locationConfidence;

      final mergedEvents = <LogisticsEvent>[
        ...existing.events,
        ...package.events,
      ];
      final uniqueEvents = <String, LogisticsEvent>{};
      for (final event in mergedEvents) {
        uniqueEvents.putIfAbsent(event.id, () => event);
      }

      final updated = existing.copyWith(
        trackingNumber: package.trackingNumber.isNotEmpty ? package.trackingNumber : existing.trackingNumber,
        location: package.location.isNotEmpty ? package.location : existing.location,
        originalStation: package.originalStation.isNotEmpty ? package.originalStation : existing.originalStation,
        pickupCode: package.pickupCode.isNotEmpty ? package.pickupCode : existing.pickupCode,
        description: package.description.isNotEmpty ? package.description : existing.description,
        urgency: _higherUrgency(existing.urgency, package.urgency),
        addedAt: package.addedAt.isAfter(existing.addedAt) ? package.addedAt : existing.addedAt,
        status: resolvedStatus,
        transitFingerprint: package.transitFingerprint ?? existing.transitFingerprint,
        rawLocation: resolvedRawLocation,
        cleanedLocation: resolvedCleanedLocation,
        canonicalLocation: resolvedCanonicalLocation,
        locationConfidence: resolvedLocationConfidence,
        events: uniqueEvents.values.toList(),
      );

      state = [
        for (var i = 0; i < state.length; i++)
          if (i == existingIndex) updated else state[i],
      ];

      if (updated.status.isArrived && !updated.notifiedArrived) {
        _triggerArrivedNotification(updated);
      }
    } else {
      state = [...state, package];
      if (package.status.isArrived && !package.notifiedArrived) {
        _triggerArrivedNotification(package);
      }
    }

    _sync();
    DebugTrace.separator('ADD PACKAGE COMPLETE');
  }

  void _triggerArrivedNotification(Package package) {
    final notificationService = NotificationAdapter();
    final updatedPackage = package.copyWith(notifiedArrived: true);
    state = [
      for (final p in state)
        if (p.id == package.id) updatedPackage else p,
    ];
    _sync();

    try {
      notificationService.showArrivedNotification(package);
      notificationService.scheduleReminderNotification(package);
    } catch (e) {
      debugPrint('[PackageListNotifier] Notification skipped: $e');
    }
  }

  int _findExistingPackage(Package package) {
    debugPrint('[PackageListNotifier] _findExistingPackage called');
    DebugTrace.separator('DEDUPE CHECK');

    if (package.pickupCode.isEmpty) {
      Metrics.inc('dedupe.miss');
      return -1;
    }

    final index = state.indexWhere(
      (p) =>
          p.pickupCode.isNotEmpty &&
          p.pickupCode == package.pickupCode &&
          p.courier == package.courier,
    );

    if (index != -1) {
      Metrics.inc('dedupe.hit');
      return index;
    }

    Metrics.inc('dedupe.miss');
    return -1;
  }

  UrgencyLevel _higherUrgency(UrgencyLevel a, UrgencyLevel b) {
    return a.score >= b.score ? a : b;
  }

  PackageStatus _resolveStatus(PackageStatus existing, PackageStatus incoming) {
    final existingPri = _statusPriority[existing] ?? 0;
    final incomingPri = _statusPriority[incoming] ?? 0;
    return incomingPri > existingPri ? incoming : existing;
  }

  void markPickedUp(String id) {
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

  void autoArchive() {
    state = [
      for (final p in state)
        if (p.shouldAutoArchive)
          p.copyWith(
            status: PackageStatus.archived,
            archivedAt: DateTime.now(),
          )
        else
          p,
    ];
    _sync();
  }

  void clearCompleted() {
    state = state.where((p) => !p.status.isCompleted).toList();
    _sync();
  }

  void _sync() {
    final box = _box;
    if (box == null) return;

    final stateIds = <String>{};
    for (final p in state) {
      stateIds.add(p.id);
      box.put(p.id, HivePackage.fromPackage(p));
    }

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
  final pending = ref.watch(packageListProvider).where((p) => p.status.isPending).toList();

  pending.sort((a, b) {
    final locationA = a.canonicalLocation.isNotEmpty
        ? a.canonicalLocation
        : a.location.isNotEmpty
            ? a.location
            : 'ZZZ';
    final locationB = b.canonicalLocation.isNotEmpty
        ? b.canonicalLocation
        : b.location.isNotEmpty
            ? b.location
            : 'ZZZ';
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
    grouped.putIfAbsent(package.displayLocation, () => []).add(package);
  }

  return grouped;
});

final heroDecisionProvider = Provider<HeroDecision>((ref) {
  final packages = ref.watch(packageListProvider);
  return HeroDecisionService.decide(packages);
});

class PendingConfirmationNotifier extends StateNotifier<List<PendingConfirmation>> {
  PendingConfirmationNotifier() : super([]);

  void add(PendingConfirmation confirmation) {
    state = [...state, confirmation];
  }

  void addAll(List<PendingConfirmation> confirmations) {
    state = [...state, ...confirmations];
  }

  Package? confirm(String id) {
    final index = state.indexWhere((c) => c.id == id);
    if (index == -1) return null;

    final confirmation = state[index];
    state = state.where((c) => c.id != id).toList();
    return confirmation.toPackage();
  }

  void reject(String id) {
    state = state.where((c) => c.id != id).toList();
  }

  Package? confirmWithEdit(
    String id, {
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

  void clear() {
    state = [];
  }
}

final pendingConfirmationsProvider =
    StateNotifierProvider<PendingConfirmationNotifier, List<PendingConfirmation>>(
  (ref) => PendingConfirmationNotifier(),
);

final pendingConfirmationCountProvider = Provider<int>((ref) {
  return ref.watch(pendingConfirmationsProvider).length;
});
