/// 事件流 Provider - 管理物流事件聚合器
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/engine/event_aggregator.dart';
import '../../core/models/package.dart';
import '../../core/models/logistics_event.dart';

/// 事件聚合器 Provider
final eventAggregatorProvider = Provider<EventAggregator>((ref) {
  return EventAggregator();
});

/// 包裹事件列表 Provider
final packageEventsProvider = Provider.family<List<LogisticsEvent>, String>((ref, packageId) {
  final aggregator = ref.watch(eventAggregatorProvider);
  return aggregator.getEventsForPackage(packageId);
});

/// 事件总数 Provider
final eventCountProvider = Provider<int>((ref) {
  final aggregator = ref.watch(eventAggregatorProvider);
  return aggregator.eventCount;
});
