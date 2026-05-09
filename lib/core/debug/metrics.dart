/// 轻量计数器 — 零依赖，用于 pipeline 稳定性统计
library;

import 'package:flutter/foundation.dart';

class Metrics {
  static final _counts = <String, int>{};

  static void inc(String key) {
    _counts[key] = (_counts[key] ?? 0) + 1;
  }

  static void report() {
    debugPrint('=== METRICS ===');
    _counts.forEach((k, v) => debugPrint('  $k: $v'));
  }

  static void reset() => _counts.clear();
}
