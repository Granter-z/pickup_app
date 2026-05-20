import 'package:flutter_test/flutter_test.dart';
import 'package:pickup_app/core/parser/status_resolver.dart';
import 'package:pickup_app/core/models/package_status.dart';
import 'dart:io';

/// 加载 fixture 文件
String loadFixture(String path) {
  final file = File('test/fixtures/$path');
  return file.readAsStringSync();
}

void main() {
  group('StatusResolver — 状态解析器', () {
    // ── Rule 1: arrival + pickupCode 直接确认 ──────────────────

    test('Case 1: arrival + pickupCode 应该直接确认为 arrived', () {
      final statuses = [
        DetectedStatus(
          status: PackageStatus.arrived,
          source: '已放至代收点',
          confidence: 0.9,
        ),
        DetectedStatus(
          status: PackageStatus.arrived,
          source: '取件码 5010',
          confidence: 0.95,
        ),
      ];

      final result = StatusResolver.resolve(statuses);
      expect(result.status, PackageStatus.arrived);
      expect(result.hasConflict, false);
    });

    // ── Rule 2: 历史物流 + 当前到达 ≠ 冲突 ──────────────────────

    test('Case 2: 历史物流 + 当前到达不应该冲突', () {
      final statuses = [
        DetectedStatus(
          status: PackageStatus.transit,
          source: '已发往邢台转运中心',
          confidence: 0.9,
          isHistorical: true, // 历史状态
        ),
        DetectedStatus(
          status: PackageStatus.arrived,
          source: '已放至代收点',
          confidence: 0.9,
          isHistorical: false, // 当前状态
        ),
      ];

      final result = StatusResolver.resolve(statuses);
      expect(result.status, PackageStatus.arrived);
      expect(result.hasConflict, false);
    });

    test('Case 3: 运输中 + 待取件不应该冲突', () {
      final statuses = [
        DetectedStatus(
          status: PackageStatus.transit,
          source: '运输中',
          confidence: 0.9,
          isHistorical: true,
        ),
        DetectedStatus(
          status: PackageStatus.arrived,
          source: '待取件',
          confidence: 0.9,
          isHistorical: false,
        ),
      ];

      final result = StatusResolver.resolve(statuses);
      expect(result.status, PackageStatus.arrived);
      expect(result.hasConflict, false);
    });

    // ── Rule 3: 同层级矛盾才冲突 ──────────────────────────────

    test('Case 4: arrived + transit（同层级）应该冲突', () {
      final statuses = [
        DetectedStatus(
          status: PackageStatus.arrived,
          source: '已放至代收点',
          confidence: 0.9,
          isHistorical: false, // 都是当前状态
        ),
        DetectedStatus(
          status: PackageStatus.transit,
          source: '运输中',
          confidence: 0.9,
          isHistorical: false, // 都是当前状态
        ),
      ];

      final result = StatusResolver.resolve(statuses);
      expect(result.hasConflict, true);
    });

    test('Case 5: pickedUp + arrived 应该冲突', () {
      final statuses = [
        DetectedStatus(
          status: PackageStatus.pickedUp,
          source: '已取件',
          confidence: 0.9,
        ),
        DetectedStatus(
          status: PackageStatus.arrived,
          source: '待取件',
          confidence: 0.9,
        ),
      ];

      final result = StatusResolver.resolve(statuses);
      expect(result.hasConflict, true);
    });

    // ── 单个状态 ──────────────────────────────────────────────

    test('Case 6: 单个状态直接返回', () {
      final statuses = [
        DetectedStatus(
          status: PackageStatus.arrived,
          source: '已放至代收点',
          confidence: 0.9,
        ),
      ];

      final result = StatusResolver.resolve(statuses);
      expect(result.status, PackageStatus.arrived);
      expect(result.hasConflict, false);
    });

    // ── 空状态 ──────────────────────────────────────────────

    test('Case 7: 空状态默认为运输中', () {
      final result = StatusResolver.resolve([]);
      expect(result.status, PackageStatus.transit);
      expect(result.hasConflict, false);
    });

    // ── 时间线 progression ──────────────────────────────────────

    test('Case 8: 派送中 + 到达是时间线 progression', () {
      final statuses = [
        DetectedStatus(
          status: PackageStatus.delivering,
          source: '派送中',
          confidence: 0.9,
          isHistorical: true,
        ),
        DetectedStatus(
          status: PackageStatus.arrived,
          source: '已放至代收点',
          confidence: 0.9,
          isHistorical: false,
        ),
      ];

      final result = StatusResolver.resolve(statuses);
      expect(result.status, PackageStatus.arrived);
      expect(result.hasConflict, false);
    });
  });

  group('StatusResolver — Regression Tests', () {
    // ── 真实 Case: 历史物流 + 当前到达 ──────────────────────────

    test('history_and_arrival_mix: 历史物流不应与当前到达冲突', () {
      // 这个 fixture 包含：
      // - "快件已发往南昌转运中心" (历史 transit)
      // - "已放至代收点" (当前 arrived)
      // - "取件码: 5-4-5010" (pickupCode)
      final text = loadFixture('edge/history_and_arrival_mix.txt');

      // 模拟检测到的状态
      final statuses = [
        DetectedStatus(
          status: PackageStatus.transit,
          source: '快件已发往',
          confidence: 0.9,
          isHistorical: true, // 历史物流
        ),
        DetectedStatus(
          status: PackageStatus.arrived,
          source: '已放至代收点',
          confidence: 0.9,
          isHistorical: false, // 当前到达
        ),
        DetectedStatus(
          status: PackageStatus.arrived,
          source: '取件码',
          confidence: 0.95,
          isHistorical: false,
        ),
      ];

      final result = StatusResolver.resolve(statuses);

      // 应该解析为 arrived，不冲突
      expect(result.status, PackageStatus.arrived);
      expect(result.hasConflict, false);
    });
  });
}
