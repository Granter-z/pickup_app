// lib/core/debug/performance_trace.dart
// 性能追踪工具 - 用于分析各阶段耗时

import 'package:flutter/foundation.dart';

/// 性能追踪器
///
/// 用于统计各阶段耗时，找出性能瓶颈
class PerformanceTrace {
  final Stopwatch _stopwatch = Stopwatch();
  final Map<String, int> _stageTimes = {};
  String? _currentStage;
  final String _name;
  final bool _enabled;

  PerformanceTrace({
    required String name,
    bool enabled = true,
  })  : _name = name,
        _enabled = enabled;

  /// 开始一个阶段
  void startStage(String stage) {
    if (!_enabled) return;

    // 结束上一个阶段
    if (_currentStage != null) {
      endStage();
    }

    _currentStage = stage;
    _stopwatch.reset();
    _stopwatch.start();

    if (kDebugMode) {
      debugPrint('[$_name] ▶ $stage');
    }
  }

  /// 结束当前阶段
  void endStage() {
    if (!_enabled || _currentStage == null) return;

    _stopwatch.stop();
    final elapsed = _stopwatch.elapsedMilliseconds;
    _stageTimes[_currentStage!] = elapsed;

    if (kDebugMode) {
      debugPrint('[$_name] ◀ $_currentStage: ${elapsed}ms');
    }

    _currentStage = null;
  }

  /// 获取某个阶段的耗时
  int? getStageTime(String stage) => _stageTimes[stage];

  /// 获取所有阶段的耗时
  Map<String, int> get stageTimes => Map.unmodifiable(_stageTimes);

  /// 获取总耗时
  int get totalTime =>
      _stageTimes.values.fold(0, (sum, time) => sum + time);

  /// 打印性能报告
  void printReport() {
    if (!_enabled) return;

    debugPrint('');
    debugPrint('═══════════════════════════════════════════');
    debugPrint('  [$_name] Performance Report');
    debugPrint('═══════════════════════════════════════════');

    int total = 0;
    for (final entry in _stageTimes.entries) {
      debugPrint('  ${entry.key}: ${entry.value}ms');
      total += entry.value;
    }

    debugPrint('───────────────────────────────────────────');
    debugPrint('  Total: ${total}ms');
    debugPrint('═══════════════════════════════════════════');
    debugPrint('');
  }

  /// 获取性能报告字符串
  String getReport() {
    final buffer = StringBuffer();
    buffer.writeln('[$_name] Performance Report:');
    for (final entry in _stageTimes.entries) {
      buffer.writeln('  ${entry.key}: ${entry.value}ms');
    }
    buffer.writeln('  Total: ${totalTime}ms');
    return buffer.toString();
  }
}

/// 全局性能追踪器（用于简单的性能统计）
class GlobalPerformanceTrace {
  static final Map<String, List<int>> _records = {};

  /// 记录某个操作的耗时
  static void record(String operation, int milliseconds) {
    _records.putIfAbsent(operation, () => []);
    _records[operation]!.add(milliseconds);
  }

  /// 获取某个操作的平均耗时
  static double? getAverage(String operation) {
    final times = _records[operation];
    if (times == null || times.isEmpty) return null;
    return times.reduce((a, b) => a + b) / times.length;
  }

  /// 获取某个操作的最大耗时
  static int? getMax(String operation) {
    final times = _records[operation];
    if (times == null || times.isEmpty) return null;
    return times.reduce((a, b) => a > b ? a : b);
  }

  /// 获取某个操作的最小耗时
  static int? getMin(String operation) {
    final times = _records[operation];
    if (times == null || times.isEmpty) return null;
    return times.reduce((a, b) => a < b ? a : b);
  }

  /// 打印全局性能报告
  static void printReport() {
    if (_records.isEmpty) {
      debugPrint('No performance records');
      return;
    }

    debugPrint('');
    debugPrint('═══════════════════════════════════════════');
    debugPrint('  Global Performance Report');
    debugPrint('═══════════════════════════════════════════');

    for (final entry in _records.entries) {
      final avg = getAverage(entry.key);
      final max = getMax(entry.key);
      final min = getMin(entry.key);
      debugPrint('  ${entry.key}:');
      debugPrint('    avg: ${avg?.toStringAsFixed(1)}ms, '
          'min: ${min}ms, max: ${max}ms, '
          'count: ${entry.value.length}');
    }

    debugPrint('═══════════════════════════════════════════');
    debugPrint('');
  }

  /// 清除所有记录
  static void clear() {
    _records.clear();
  }
}
