import 'package:flutter_test/flutter_test.dart';
import 'package:pickup_app/core/confidence/location_quality_analyzer.dart';
import 'package:pickup_app/core/confidence/confidence_calculator.dart';

void main() {
  group('LocationQualityAnalyzer — 地址质量分析', () {
    // ── 正常地址 ──────────────────────────────────────────────

    test('Case 1: 正常地址应该高分', () {
      final result = LocationQualityAnalyzer.analyze(
        rawLocation: '邢台信都区绿城诚园北门店',
        cleanedLocation: '邢台信都区绿城诚园北门店',
      );
      expect(result.score, greaterThan(0.9));
      expect(result.suspicious, false);
    });

    test('Case 2: 正常地址（含小区名）应该高分', () {
      final result = LocationQualityAnalyzer.analyze(
        rawLocation: '邢台信都区绿城诚园小区北门店',
        cleanedLocation: '邢台信都区绿城诚园小区北门店',
      );
      expect(result.score, greaterThan(0.9));
      expect(result.suspicious, false);
    });

    // ── 异常词检测 ──────────────────────────────────────────

    test('Case 3: 包含"面对面"应该低分', () {
      final result = LocationQualityAnalyzer.analyze(
        rawLocation: '绿城诚园北门面对面大院驿站',
        cleanedLocation: '绿城诚园北门面对面大院驿站',
      );
      expect(result.score, lessThan(0.9));
      expect(result.suspicious, true);
      expect(result.hitSuspiciousWords, contains('面对面'));
    });

    test('Case 4: 包含"点击"应该低分', () {
      final result = LocationQualityAnalyzer.analyze(
        rawLocation: '点击查看详情',
        cleanedLocation: '点击查看详情',
      );
      expect(result.score, lessThan(0.8));
      expect(result.suspicious, true);
      expect(result.hitSuspiciousWords, contains('点击'));
    });

    test('Case 5: 包含"查看"应该低分', () {
      final result = LocationQualityAnalyzer.analyze(
        rawLocation: '查看取件详情',
        cleanedLocation: '查看取件详情',
      );
      expect(result.score, lessThan(0.8));
      expect(result.suspicious, true);
      expect(result.hitSuspiciousWords, contains('查看'));
    });

    // ── 长度异常 ──────────────────────────────────────────────

    test('Case 6: 地址太短应该扣分', () {
      final result = LocationQualityAnalyzer.analyze(
        rawLocation: '北门',
        cleanedLocation: '北门',
      );
      expect(result.score, lessThan(0.9));
      expect(result.warnings, anyElement(contains('地址过短')));
    });

    test('Case 7: 地址太长应该扣分', () {
      final result = LocationQualityAnalyzer.analyze(
        rawLocation: '这是一个非常非常非常非常非常非常非常非常非常非常非常非常长的地址超过了30个字符',
        cleanedLocation: '这是一个非常非常非常非常非常非常非常非常非常非常非常非常长的地址超过了30个字符',
      );
      // 地址太长应该有警告
      expect(result.warnings, anyElement(contains('地址过长')));
      // 分数应该被扣分
      expect(result.score, lessThan(1.0));
    });

    // ── OCR 错词检测 ──────────────────────────────────────────

    test('Case 8: OCR 错词"形台"应该扣分', () {
      final result = LocationQualityAnalyzer.analyze(
        rawLocation: '形台信都区绿城诚园北门店',
        cleanedLocation: '形台信都区绿城诚园北门店',
      );
      // OCR 错词应该被检测到
      expect(result.hitOcrErrors, contains('形台'));
      expect(result.warnings, anyElement(contains('OCR 错词')));
    });

    test('Case 9: OCR 错词"诚圆"应该扣分', () {
      final result = LocationQualityAnalyzer.analyze(
        rawLocation: '邢台信都区绿城诚圆北门店',
        cleanedLocation: '邢台信都区绿城诚圆北门店',
      );
      // OCR 错词应该被检测到
      expect(result.hitOcrErrors, contains('诚圆'));
      expect(result.warnings, anyElement(contains('OCR 错词')));
    });

    // ── 空地址 ──────────────────────────────────────────────

    test('Case 10: 空地址应该 0 分', () {
      final result = LocationQualityAnalyzer.analyze(
        rawLocation: '',
        cleanedLocation: '',
      );
      expect(result.score, 0.0);
      expect(result.suspicious, true);
    });

    // ── 加分项 ──────────────────────────────────────────────

    test('Case 11: 包含区/县应该加分', () {
      final result = LocationQualityAnalyzer.analyze(
        rawLocation: '信都区绿城诚园北门店',
        cleanedLocation: '信都区绿城诚园北门店',
      );
      expect(result.score, greaterThanOrEqualTo(1.0));
    });

    test('Case 12: 包含小区名应该加分', () {
      final result = LocationQualityAnalyzer.analyze(
        rawLocation: '绿城诚园小区北门店',
        cleanedLocation: '绿城诚园小区北门店',
      );
      expect(result.score, greaterThanOrEqualTo(1.0));
    });

    test('Case 13: 包含门店应该加分', () {
      final result = LocationQualityAnalyzer.analyze(
        rawLocation: '邢台信都区绿城诚园北门店',
        cleanedLocation: '邢台信都区绿城诚园北门店',
      );
      expect(result.score, greaterThanOrEqualTo(1.0));
    });

    test('Case 14: 包含数字门牌应该加分', () {
      final result = LocationQualityAnalyzer.analyze(
        rawLocation: '邢台信都区绿城诚园24号楼',
        cleanedLocation: '邢台信都区绿城诚园24号楼',
      );
      expect(result.score, greaterThanOrEqualTo(1.0));
    });
  });

  group('ConfidenceCalculator — 整体置信度计算', () {
    test('Case 1: 提取置信度 0.92 + 语义置信度 0.65 → 整体约 0.82', () {
      final calculator = ConfidenceCalculator();
      final result = calculator.calculateOverallConfidenceWithSemantic(
        extractionConfidence: 0.92,
        semanticConfidence: 0.65,
      );
      expect(result, closeTo(0.82, 0.01));
    });

    test('Case 2: 提取置信度 0.92 + 语义置信度 0.95 → 整体约 0.93', () {
      final calculator = ConfidenceCalculator();
      final result = calculator.calculateOverallConfidenceWithSemantic(
        extractionConfidence: 0.92,
        semanticConfidence: 0.95,
      );
      expect(result, closeTo(0.93, 0.01));
    });

    test('Case 3: 地址语义置信度分析', () {
      final calculator = ConfidenceCalculator();
      final result = calculator.calculateLocationSemanticConfidence(
        rawLocation: '邢台信都区绿城诚园北门店',
        cleanedLocation: '邢台信都区绿城诚园北门店',
      );
      expect(result, greaterThan(0.9));
    });

    test('Case 4: 可疑地址语义置信度应该低', () {
      final calculator = ConfidenceCalculator();
      final result = calculator.calculateLocationSemanticConfidence(
        rawLocation: '绿城诚园北门面对面大院驿站',
        cleanedLocation: '绿城诚园北门面对面大院驿站',
      );
      expect(result, lessThan(0.9));
    });
  });
}
