/// 事件聚合器 - 纯Dart，不依赖Flutter
/// 
/// 职责：
/// 1. 接收 OCR / 手动输入 / mock 数据
/// 2. 转换为 LogisticsEvent
/// 3. 事件去重
/// 4. 按 packageId 聚合事件
/// 5. 更新 Package 状态（通过事件驱动）
library;

import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/package.dart';
import '../models/package_status.dart';
import '../models/logistics_event.dart';

/// 事件聚合器
class EventAggregator {
  static const _uuid = Uuid();

  /// 所有事件列表（按时间排序）
  final List<LogisticsEvent> _events = [];

  /// 事件索引：packageId -> 事件列表
  final Map<String, List<LogisticsEvent>> _eventsByPackage = {};

  /// 事件ID集合（用于快速去重）
  final Set<String> _eventIds = {};

  /// 事件聚合器
  EventAggregator() {
    debugPrint('[Aggregator] initialized');
  }

  /// 获取所有事件（不可变视图）
  UnmodifiableListView<LogisticsEvent> get allEvents => UnmodifiableListView(_events);

  /// 获取指定包裹的所有事件（按时间排序，最新在前）
  List<LogisticsEvent> getEventsForPackage(String packageId) {
    final events = _eventsByPackage[packageId] ?? [];
    return List.from(events)..sort((a, b) => b.time.compareTo(a.time));
  }

  /// 检查事件是否已存在（去重用）
  bool hasEvent(String eventId) {
    final exists = _eventIds.contains(eventId);
    debugPrint('[Aggregator] check event exists: eventId=$eventId, exists=$exists');
    return exists;
  }

  /// 处理一个包裹（核心流程）
  /// 
  /// 如果包裹已存在（通过 fingerprint 匹配）：
  ///   - 更新包裹信息
  ///   - 追加新事件
  ///   - 更新状态
  /// 如果包裹不存在：
  ///   - 创建新包裹
  /// 
  /// [incomingPackage] 新接收的包裹
  /// [existingPackages] 现有包裹列表
  /// [rawText] 原始文本（用于事件）
  /// [source] 来源
  /// 返回：处理后的包裹（新建或更新后的）
  Package processPackage({
    required Package incomingPackage,
    required List<Package> existingPackages,
    String? rawText,
    String source = 'mock',
  }) {
    debugPrint('[Aggregator] processPackage called');
    debugPrint('[Aggregator] incoming: id=${incomingPackage.id}, fingerprint=${incomingPackage.fingerprint}');
    
    // 1. 查找是否已存在（通过 fingerprint）
    final existingIndex = existingPackages.indexWhere(
      (p) => p.fingerprint == incomingPackage.fingerprint,
    );
    
    if (existingIndex != -1) {
      final existingPackage = existingPackages[existingIndex];
      debugPrint('[Aggregator] existing package found: id=${existingPackage.id}');
      
      // 2. 更新现有包裹
      return _updateExistingPackage(
        existingPackage: existingPackage,
        incomingPackage: incomingPackage,
        rawText: rawText,
        source: source,
      );
    } else {
      debugPrint('[Aggregator] no existing package, creating new');
      
      // 3. 创建新包裹
      return _createNewPackage(
        package: incomingPackage,
        rawText: rawText,
        source: source,
      );
    }
  }

  /// 更新现有包裹
  Package _updateExistingPackage({
    required Package existingPackage,
    required Package incomingPackage,
    String? rawText,
    String source = 'mock',
  }) {
    debugPrint('[Aggregator] _updateExistingPackage called');
    debugPrint('[Aggregator] existing: status=${existingPackage.status.label}');
    debugPrint('[Aggregator] incoming: status=${incomingPackage.status.label}');
    
    Package result = existingPackage;
    
    // 1. 创建并去重事件
    final pickupCode = incomingPackage.pickupCode.isNotEmpty 
        ? incomingPackage.pickupCode 
        : existingPackage.pickupCode;
    
    final now = DateTime.now();
    
    // 尝试创建包裹创建事件
    final createdEventId = LogisticsEvent.generateEventId(
      pickupCode: pickupCode,
      type: LogisticsEventType.packageCreated,
      time: now,
    );
    if (!hasEvent(createdEventId)) {
      final createdEvent = LogisticsEvent(
        id: createdEventId,
        packageId: existingPackage.id,
        type: LogisticsEventType.packageCreated,
        time: now,
        source: source,
        rawText: rawText,
      );
      _addEvent(createdEvent);
      // 确保事件添加到 package.events
      if (!result.events.any((e) => e.id == createdEvent.id)) {
        result = result.copyWith(
          events: [...result.events, createdEvent],
        );
      }
      result = updatePackageFromEvent(result, createdEvent);
    }
    
    // 尝试创建取件码事件（如果有取件码）
    if (pickupCode.isNotEmpty) {
      final pickupEventId = LogisticsEvent.generateEventId(
        pickupCode: pickupCode,
        type: LogisticsEventType.pickupCodeGenerated,
        time: now,
      );
      if (!hasEvent(pickupEventId)) {
        final pickupEvent = LogisticsEvent(
          id: pickupEventId,
          packageId: existingPackage.id,
          type: LogisticsEventType.pickupCodeGenerated,
          time: now,
          source: source,
          rawText: rawText,
          metadata: {'pickupCode': pickupCode},
        );
        _addEvent(pickupEvent);
        // 确保事件添加到 package.events
        if (!result.events.any((e) => e.id == pickupEvent.id)) {
          result = result.copyWith(
            events: [...result.events, pickupEvent],
          );
        }
        result = updatePackageFromEvent(result, pickupEvent);
      }
    }
    
    // 2. 更新字段（保留原ID和创建时间）
    result = result.copyWith(
      trackingNumber: incomingPackage.trackingNumber.isNotEmpty 
          ? incomingPackage.trackingNumber 
          : result.trackingNumber,
      pickupCode: incomingPackage.pickupCode.isNotEmpty 
          ? incomingPackage.pickupCode 
          : result.pickupCode,
      location: incomingPackage.location.isNotEmpty 
          ? incomingPackage.location 
          : result.location,
      originalStation: incomingPackage.originalStation.isNotEmpty 
          ? incomingPackage.originalStation 
          : result.originalStation,
      description: incomingPackage.description.isNotEmpty 
          ? incomingPackage.description 
          : result.description,
    );
    
    debugPrint('[Aggregator] _updateExistingPackage completed: status=${result.status.label}');
    debugPrint('[Aggregator] events count: ${result.events.length}');
    return result;
  }

  /// 创建新包裹
  Package _createNewPackage({
    required Package package,
    String? rawText,
    String source = 'mock',
  }) {
    debugPrint('[Aggregator] _createNewPackage called');
    
    final now = DateTime.now();
    Package result = package;
    
    // 1. 创建包裹创建事件
    final createdEventId = LogisticsEvent.generateEventId(
      pickupCode: package.pickupCode,
      type: LogisticsEventType.packageCreated,
      time: now,
    );
    final createdEvent = LogisticsEvent(
      id: createdEventId,
      packageId: package.id,
      type: LogisticsEventType.packageCreated,
      time: now,
      source: source,
      rawText: rawText,
    );
    _addEvent(createdEvent);
    // 确保事件添加到 package.events
    result = result.copyWith(
      events: [...result.events, createdEvent],
    );
    result = updatePackageFromEvent(result, createdEvent);
    
    // 2. 创建取件码事件（如果有取件码）
    if (package.pickupCode.isNotEmpty) {
      final pickupEventId = LogisticsEvent.generateEventId(
        pickupCode: package.pickupCode,
        type: LogisticsEventType.pickupCodeGenerated,
        time: now,
      );
      final pickupEvent = LogisticsEvent(
        id: pickupEventId,
        packageId: package.id,
        type: LogisticsEventType.pickupCodeGenerated,
        time: now,
        source: source,
        rawText: rawText,
        metadata: {'pickupCode': package.pickupCode},
      );
      _addEvent(pickupEvent);
      // 确保事件添加到 package.events
      result = result.copyWith(
        events: [...result.events, pickupEvent],
      );
      result = updatePackageFromEvent(result, pickupEvent);
    }
    
    debugPrint('[Aggregator] _createNewPackage completed: id=${result.id}');
    debugPrint('[Aggregator] events count: ${result.events.length}');
    return result;
  }

  /// 创建包裹创建事件（保留兼容性）
  /// [package] 新创建的包裹
  /// [source] 来源
  LogisticsEvent createPackageCreatedEvent(Package package, {String source = 'ocr'}) {
    debugPrint('[Aggregator] createPackageCreatedEvent called (packageId: ${package.id})');
    final now = DateTime.now();
    final eventId = LogisticsEvent.generateEventId(
      pickupCode: package.pickupCode,
      type: LogisticsEventType.packageCreated,
      time: now,
    );

    final event = LogisticsEvent(
      id: eventId,
      packageId: package.id,
      type: LogisticsEventType.packageCreated,
      time: now,
      source: source,
      rawText: '包裹创建: ${package.courier.displayName} ${package.trackingNumber}',
      metadata: {
        'trackingNumber': package.trackingNumber,
        'courier': package.courier.name,
      },
    );

    _addEvent(event);
    return event;
  }

  /// 创建取件码生成事件（保留兼容性）
  /// [package] 包裹
  /// [pickupCode] 取件码
  /// [source] 来源
  LogisticsEvent createPickupCodeEvent(Package package, String pickupCode, {String source = 'ocr'}) {
    debugPrint('[Aggregator] createPickupCodeEvent called (packageId: ${package.id})');
    final now = DateTime.now();
    final eventId = LogisticsEvent.generateEventId(
      pickupCode: pickupCode,
      type: LogisticsEventType.pickupCodeGenerated,
      time: now,
    );

    final event = LogisticsEvent(
      id: eventId,
      packageId: package.id,
      type: LogisticsEventType.pickupCodeGenerated,
      time: now,
      source: source,
      rawText: '取件码生成: $pickupCode',
      metadata: {'pickupCode': pickupCode},
    );

    _addEvent(event);
    return event;
  }

  /// 创建签收事件（保留兼容性）
  /// [package] 包裹
  /// [source] 来源
  LogisticsEvent createSignedEvent(Package package, {String source = 'manual'}) {
    debugPrint('[Aggregator] createSignedEvent called (packageId: ${package.id})');
    final now = DateTime.now();
    final eventId = LogisticsEvent.generateEventId(
      pickupCode: package.pickupCode,
      type: LogisticsEventType.signed,
      time: now,
    );

    final event = LogisticsEvent(
      id: eventId,
      packageId: package.id,
      type: LogisticsEventType.signed,
      time: now,
      source: source,
      rawText: '包裹已签收',
    );

    _addEvent(event);
    return event;
  }

  /// 根据事件更新包裹状态
  /// [pkg] 原始包裹
  /// [event] 新事件
  /// 返回更新后的包裹
  Package updatePackageFromEvent(Package pkg, LogisticsEvent event) {
    debugPrint('[Aggregator] updatePackageFromEvent called');
    debugPrint('[Aggregator] packageId: ${pkg.id}');
    debugPrint('[Aggregator] event: ${event.type}');
    
    // 确保事件属于此包裹
    if (event.packageId != pkg.id) {
      debugPrint('[Aggregator] event packageId mismatch, skipping');
      return pkg;
    }

    debugPrint('[Aggregator] current status: ${pkg.status.label}');

    // 先检查事件是否已经在 package.events 中
    final eventExists = pkg.events.any((e) => e.id == event.id);
    if (eventExists) {
      debugPrint('[Aggregator] event already exists in package, skipping');
      return pkg;
    }

    // 根据事件类型映射到包裹状态
    final newStatus = _mapEventToStatus(event.type);

    PackageStatus? statusToUpdate = newStatus;
    if (newStatus != null) {
      // 检查状态机，是否允许转换
      if (!pkg.status.canTransitionTo(newStatus)) {
        debugPrint('[Aggregator] invalid transition: ${pkg.status.label} -> $newStatus, skipping');
        statusToUpdate = null;
      }
    }

    if (statusToUpdate != null) {
      debugPrint('[Aggregator] status update: ${pkg.status.label} -> $statusToUpdate');

      // 使用事件时间作为状态转换时间
      final transition = StatusTransition(
        from: pkg.status,
        to: statusToUpdate,
        timestamp: event.time,
        reason: 'Event: ${event.type.name}',
      );

      final updated = pkg.copyWith(
        status: statusToUpdate,
        pickedUpAt: statusToUpdate == PackageStatus.pickedUp ? event.time : pkg.pickedUpAt,
        archivedAt: statusToUpdate == PackageStatus.archived ? event.time : pkg.archivedAt,
        statusHistory: [...pkg.statusHistory, transition],
        events: [...pkg.events, event],
      );

      debugPrint('[Aggregator] package updated: new status=${updated.status.label}');
      debugPrint('[Aggregator] events count: ${updated.events.length}');
      return updated;
    } else {
      // 即使状态不变，也要记录事件
      final updated = pkg.copyWith(
        events: [...pkg.events, event],
      );
      debugPrint('[Aggregator] event added to package (no status change)');
      debugPrint('[Aggregator] events count: ${updated.events.length}');
      return updated;
    }
  }

  /// 添加事件到聚合器（内部方法）
  void _addEvent(LogisticsEvent event) {
    debugPrint('[Aggregator] _addEvent called');
    debugPrint('[Aggregator] eventId: ${event.id}');
    
    // 去重检查
    if (_eventIds.contains(event.id)) {
      debugPrint('[Aggregator] event already exists, skipping');
      return;
    }
    
    _events.add(event);
    _eventIds.add(event.id);

    if (!_eventsByPackage.containsKey(event.packageId)) {
      _eventsByPackage[event.packageId] = [];
    }
    _eventsByPackage[event.packageId]!.add(event);

    // 保持整体列表按时间排序
    _events.sort((a, b) => b.time.compareTo(a.time));

    debugPrint('[Aggregator] event added. Total events: ${_events.length}');
  }

  /// 清空所有事件（用于测试）
  void clear() {
    debugPrint('[Aggregator] clear called');
    _events.clear();
    _eventsByPackage.clear();
    _eventIds.clear();
    debugPrint('[Aggregator] cleared. Total events now: ${_events.length}');
  }

  /// 事件总数
  int get eventCount => _events.length;

  /// 将事件类型映射到包裹状态
  PackageStatus? _mapEventToStatus(LogisticsEventType type) {
    switch (type) {
      case LogisticsEventType.packageCreated:
        return PackageStatus.transit;
      case LogisticsEventType.shipped:
        return PackageStatus.transit;
      case LogisticsEventType.arrivedStation:
        return PackageStatus.arrived;
      case LogisticsEventType.outForDelivery:
        return PackageStatus.delivering;
      case LogisticsEventType.pickupCodeGenerated:
        return PackageStatus.arrived;
      case LogisticsEventType.signed:
        return PackageStatus.pickedUp;
      case LogisticsEventType.delayed:
      case LogisticsEventType.exception:
        return null; // 不改变状态，仅记录事件
    }
  }
}
