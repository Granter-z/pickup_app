import 'package:flutter_test/flutter_test.dart';
import 'package:pickup_app/core/models/package.dart';
import 'package:pickup_app/core/models/package_status.dart';

void main() {
  group('UI 显示 — displayLocation', () {
    // ── Case 1: station + canonicalLocation ────────────────────

    test('Case 1: 菜鸟驿站 + 地址', () {
      final package = _createPackage(
        originalStation: '菜鸟驿站',
        canonicalLocation: '邢台信都区绿城诚园北门店',
      );
      expect(package.displayLocation, '菜鸟驿站 · 邢台信都区绿城诚园北门店');
    });

    // ── Case 2: 只有 station ──────────────────────────────────

    test('Case 2: 只有 station', () {
      final package = _createPackage(
        originalStation: '菜鸟驿站',
        canonicalLocation: '',
        cleanedLocation: '',
        rawLocation: '',
      );
      expect(package.displayLocation, '菜鸟驿站');
    });

    // ── Case 3: 只有 location ─────────────────────────────────

    test('Case 3: 只有 canonicalLocation', () {
      final package = _createPackage(
        originalStation: '',
        canonicalLocation: '邢台信都区绿城诚园北门店',
      );
      expect(package.displayLocation, '邢台信都区绿城诚园北门店');
    });

    // ── Case 4: 都为空 ────────────────────────────────────────

    test('Case 4: 都为空时显示"未知驿站"', () {
      final package = _createPackage(
        originalStation: '',
        canonicalLocation: '',
        cleanedLocation: '',
        rawLocation: '',
      );
      expect(package.displayLocation, '未知驿站');
    });

    // ── Case 5: 优先级: canonicalLocation > cleanedLocation ────

    test('Case 5: 优先使用 canonicalLocation', () {
      final package = _createPackage(
        originalStation: '',
        canonicalLocation: '邢台信都区绿城诚园北门店',
        cleanedLocation: '绿城诚园北门店',
        rawLocation: '菜鸟驿站绿城诚园北门店',
      );
      expect(package.displayLocation, '邢台信都区绿城诚园北门店');
    });

    test('Case 5b: 无 canonical 时使用 cleanedLocation', () {
      final package = _createPackage(
        originalStation: '',
        canonicalLocation: '',
        cleanedLocation: '绿城诚园北门店',
        rawLocation: '菜鸟驿站绿城诚园北门店',
      );
      expect(package.displayLocation, '绿城诚园北门店');
    });

    test('Case 5c: 无 canonical 和 cleaned 时使用 rawLocation', () {
      final package = _createPackage(
        originalStation: '',
        canonicalLocation: '',
        cleanedLocation: '',
        rawLocation: '菜鸟驿站绿城诚园北门店',
      );
      expect(package.displayLocation, '菜鸟驿站绿城诚园北门店');
    });

    // ── Case 6: 丰巢 + 地址 ──────────────────────────────────

    test('Case 6: 丰巢 + 地址', () {
      final package = _createPackage(
        originalStation: '丰巢',
        canonicalLocation: '小区东门快递柜',
      );
      expect(package.displayLocation, '丰巢 · 小区东门快递柜');
    });

    // ── Case 7: 妈妈驿站 + 地址 ──────────────────────────────

    test('Case 7: 妈妈驿站 + 地址', () {
      final package = _createPackage(
        originalStation: '妈妈驿站',
        canonicalLocation: '小区西门代收点',
      );
      expect(package.displayLocation, '妈妈驿站 · 小区西门代收点');
    });
  });
}

/// 辅助函数：创建测试用 Package
Package _createPackage({
  String originalStation = '',
  String canonicalLocation = '',
  String cleanedLocation = '',
  String rawLocation = '',
}) {
  return Package(
    id: 'test-1',
    trackingNumber: 'SF1234567890',
    courier: CourierType.sf,
    pickupCode: '15-3-6007',
    location: cleanedLocation,
    originalStation: originalStation,
    urgency: UrgencyLevel.normal,
    status: PackageStatus.arrived,
    addedAt: DateTime.now(),
    rawLocation: rawLocation,
    cleanedLocation: cleanedLocation,
    canonicalLocation: canonicalLocation,
    locationConfidence: 0.5,
  );
}
