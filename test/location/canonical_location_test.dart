import 'package:flutter_test/flutter_test.dart';
import 'package:pickup_app/core/models/package.dart';

void main() {
  group('canonicalLocation 收敛规则', () {
    // ── Rule 1: 长地址覆盖短地址 ──────────────────────────────

    test('Rule 1: 长地址覆盖短地址', () {
      final result = Package.resolveCanonicalLocation(
        existing: '绿城诚园北门店',
        incoming: '邢台信都区绿城诚园北门店',
        existingConfidence: 0.5,
        incomingConfidence: 0.5,
      );
      expect(result, '邢台信都区绿城诚园北门店');
    });

    // ── Rule 2: 短地址不能覆盖长地址 ──────────────────────────

    test('Rule 2: 短地址不能覆盖长地址', () {
      final result = Package.resolveCanonicalLocation(
        existing: '邢台信都区绿城诚园北门店',
        incoming: '诚园北门店',
        existingConfidence: 0.5,
        incomingConfidence: 0.5,
      );
      expect(result, '邢台信都区绿城诚园北门店');
    });

    // ── Rule 3: 新地址包含旧地址 → 替换 ──────────────────────

    test('Rule 3: 新地址包含旧地址', () {
      final result = Package.resolveCanonicalLocation(
        existing: '诚园北门店',
        incoming: '绿城诚园北门店',
        existingConfidence: 0.5,
        incomingConfidence: 0.5,
      );
      expect(result, '绿城诚园北门店');
    });

    // ── Rule 4: 置信度更高 → 替换 ──────────────────────────────

    test('Rule 4: 置信度更高时替换', () {
      final result = Package.resolveCanonicalLocation(
        existing: '绿城诚园北门店',
        incoming: '绿城诚圆北门店',
        existingConfidence: 0.5,
        incomingConfidence: 0.8,
      );
      expect(result, '绿城诚圆北门店');
    });

    test('Rule 4b: 置信度更低时不替换', () {
      final result = Package.resolveCanonicalLocation(
        existing: '绿城诚园北门店',
        incoming: '绿城诚圆北门店',
        existingConfidence: 0.8,
        incomingConfidence: 0.5,
      );
      expect(result, '绿城诚园北门店');
    });

    // ── 边界情况 ──────────────────────────────────────────────

    test('边界: 旧地址为空时使用新地址', () {
      final result = Package.resolveCanonicalLocation(
        existing: '',
        incoming: '邢台信都区绿城诚园北门店',
        existingConfidence: 0.0,
        incomingConfidence: 0.5,
      );
      expect(result, '邢台信都区绿城诚园北门店');
    });

    test('边界: 新地址为空时保持旧地址', () {
      final result = Package.resolveCanonicalLocation(
        existing: '邢台信都区绿城诚园北门店',
        incoming: '',
        existingConfidence: 0.5,
        incomingConfidence: 0.0,
      );
      expect(result, '邢台信都区绿城诚园北门店');
    });

    test('边界: 两个都为空', () {
      final result = Package.resolveCanonicalLocation(
        existing: '',
        incoming: '',
        existingConfidence: 0.0,
        incomingConfidence: 0.0,
      );
      expect(result, '');
    });

    // ── 多次收敛模拟 ──────────────────────────────────────────

    test('多次 OCR 收敛: 地址越来越完整', () {
      // 第一次 OCR
      var canonical = Package.resolveCanonicalLocation(
        existing: '',
        incoming: '诚园北门店',
        existingConfidence: 0.0,
        incomingConfidence: 0.5,
      );
      expect(canonical, '诚园北门店');

      // 第二次 OCR: 更完整
      canonical = Package.resolveCanonicalLocation(
        existing: canonical,
        incoming: '绿城诚园北门店',
        existingConfidence: 0.5,
        incomingConfidence: 0.5,
      );
      expect(canonical, '绿城诚园北门店');

      // 第三次 OCR: 最完整
      canonical = Package.resolveCanonicalLocation(
        existing: canonical,
        incoming: '邢台信都区绿城诚园北门店',
        existingConfidence: 0.5,
        incomingConfidence: 0.5,
      );
      expect(canonical, '邢台信都区绿城诚园北门店');

      // 第四次 OCR: 较短，不应覆盖
      canonical = Package.resolveCanonicalLocation(
        existing: canonical,
        incoming: '诚园北门店',
        existingConfidence: 0.5,
        incomingConfidence: 0.5,
      );
      expect(canonical, '邢台信都区绿城诚园北门店');
    });
  });

  group('locationConfidence 置信度计算', () {
    test('空地址置信度为 0', () {
      final confidence = Package.calculateLocationConfidence('');
      expect(confidence, 0.0);
    });

    test('包含省市区加分', () {
      final confidence = Package.calculateLocationConfidence('邢台市信都区');
      expect(confidence, greaterThanOrEqualTo(0.2));
    });

    test('包含小区名加分', () {
      final confidence = Package.calculateLocationConfidence('绿城诚园小区');
      expect(confidence, greaterThanOrEqualTo(0.2));
    });

    test('Case 4: 包含门店/驿站加分（但长度短会减分）', () {
      // "北门店" 包含门店 (+0.2)，但长度 < 4 (-0.2)，总分 0.0
      final confidence = Package.calculateLocationConfidence('北门店');
      expect(confidence, 0.0);
    });

    test('Case 4b: 包含门店且长度足够', () {
      // "邢台信都区绿城诚园北门店" 包含门店 (+0.2)，包含区 (+0.2)，长度 > 10 (+0.1)，总分 0.5
      final confidence = Package.calculateLocationConfidence('邢台信都区绿城诚园北门店');
      expect(confidence, greaterThanOrEqualTo(0.5));
    });

    test('长度 > 10 加分', () {
      final confidence = Package.calculateLocationConfidence('邢台信都区绿城诚园北门店');
      expect(confidence, greaterThanOrEqualTo(0.1));
    });

    test('地址太短减分', () {
      final confidence = Package.calculateLocationConfidence('北门');
      expect(confidence, lessThanOrEqualTo(0.0));
    });
  });
}
