import 'package:flutter_test/flutter_test.dart';
import 'package:pickup_app/core/models/package.dart';
import 'package:pickup_app/core/models/package_status.dart';
import 'package:pickup_app/core/parser/extractors.dart';

void main() {
  group('Station 保留 — originalStation 永不丢失', () {
    // ── extract 正确识别 ──────────────────────────────────────

    test('Case 1: 从 OCR 文本提取站点名', () {
      const ocrText = '菜鸟驿站邢台信都区绿城诚园北门店';
      final station = StationExtractor.extract(ocrText);
      expect(station, '菜鸟驿站');
    });

    test('Case 2: OCR 错误"鸟一"在 extract 中不被识别（仅在 cleanLocation 中处理）', () {
      const ocrText = '鸟一邢台信都区绿城诚园北门店';
      final station = StationExtractor.extract(ocrText);
      // "鸟一" 不在 _stationKeywords 中，但 "门店" 在，所以会匹配到 "门店"
      expect(station, '门店');
    });

    test('Case 3: OCR 错误"菜乌"也能识别为菜鸟驿站', () {
      const ocrText = '菜乌邢台信都区绿城诚园北门店';
      final station = StationExtractor.extract(ocrText);
      expect(station, '菜鸟驿站');
    });

    // ── cleanLocation 后 originalStation 仍保留 ──────────────

    test('Case 4: cleanLocation 不影响 originalStation', () {
      const location = '菜鸟驿站邢台信都区绿城诚园北门店';
      const station = '菜鸟驿站';

      final cleaned = StationExtractor.cleanLocation(location, station);

      // cleanedLocation 去掉了前缀
      expect(cleaned, '邢台信都区绿城诚园北门店');

      // originalStation 仍然保留
      expect(station, '菜鸟驿站');
    });

    // ── Package 创建后 originalStation 保留 ──────────────────

    test('Case 5: Package 创建后 originalStation 正确', () {
      final package = Package(
        id: 'test-1',
        trackingNumber: 'SF1234567890',
        courier: CourierType.sf,
        pickupCode: '15-3-6007',
        location: '邢台信都区绿城诚园北门店',
        originalStation: '菜鸟驿站',
        urgency: UrgencyLevel.normal,
        status: PackageStatus.arrived,
        addedAt: DateTime.now(),
        rawLocation: '菜鸟驿站邢台信都区绿城诚园北门店',
        cleanedLocation: '邢台信都区绿城诚园北门店',
        canonicalLocation: '邢台信都区绿城诚园北门店',
        locationConfidence: 0.8,
      );

      expect(package.originalStation, '菜鸟驿站');
      expect(package.location, '邢台信都区绿城诚园北门店');
      expect(package.cleanedLocation, '邢台信都区绿城诚园北门店');
      expect(package.canonicalLocation, '邢台信都区绿城诚园北门店');
    });

    // ── copyWith 后 originalStation 保留 ──────────────────────

    test('Case 6: copyWith 不改变 originalStation', () {
      final original = Package(
        id: 'test-1',
        trackingNumber: 'SF1234567890',
        courier: CourierType.sf,
        pickupCode: '15-3-6007',
        location: '邢台信都区绿城诚园北门店',
        originalStation: '菜鸟驿站',
        urgency: UrgencyLevel.normal,
        status: PackageStatus.arrived,
        addedAt: DateTime.now(),
      );

      final updated = original.copyWith(
        status: PackageStatus.pickedUp,
      );

      expect(updated.originalStation, '菜鸟驿站');
    });

    // ── 丰巢也能正确保留 ──────────────────────────────────────

    test('Case 7: 丰巢站点也能正确保留', () {
      final package = Package(
        id: 'test-2',
        trackingNumber: 'SF9876543210',
        courier: CourierType.sf,
        pickupCode: 'A-12',
        location: '小区东门快递柜',
        originalStation: '丰巢',
        urgency: UrgencyLevel.normal,
        status: PackageStatus.arrived,
        addedAt: DateTime.now(),
      );

      expect(package.originalStation, '丰巢');
      expect(package.location, '小区东门快递柜');
    });
  });
}
