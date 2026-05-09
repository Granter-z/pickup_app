import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pickup_app/core/models/package.dart';
import 'package:pickup_app/core/models/package_status.dart';
import 'package:pickup_app/core/parser/text_parser.dart';
import 'package:pickup_app/core/sanitizer/text_sanitizer.dart';

void main() {
  group('good — 必须解析成功', () {
    final cases = [
      'sf_arrived_with_code',
      'zto_transit_sms',
      'jd_delivering_detail',
      'multi_package_sms',
    ];
    for (final name in cases) {
      test(name, () {
        final text = File('test/fixtures/good/$name.txt')
            .readAsStringSync();
        final results = TextParser.parseMulti(text);
        expect(results.isNotEmpty, true,
            reason: '$name: 应该至少解析出一个包裹');
        expect(results.first.isValid, true,
            reason: '$name: 解析结果应为 valid');
        expect(results.first.canCreatePackage, true,
            reason: '$name: 应该可以创建包裹');
      });
    }

    test('arrived_with_code_override', () {
      final text = File('test/fixtures/good/arrived_with_code_override.txt')
          .readAsStringSync();
      final results = TextParser.parseMulti(text);
      expect(results.isNotEmpty, true, reason: '应该解析出包裹');
      final r = results.first;
      expect(r.pickupCode.value, '7-3-6007', reason: '取件码应被识别');
      expect(r.status.value, PackageStatus.arrived,
          reason: '有取件码时状态应为 arrived，不是 pickedUp');
    });
  });

  group('bad — 必须触发熔断', () {
    final cases = [
      'dashboard_homepage',
      'settings_page',
      'shopping_product',
    ];
    for (final name in cases) {
      test(name, () {
        final text = File('test/fixtures/bad/$name.txt')
            .readAsStringSync();
        final shouldAbort = TextSanitizer.shouldAbortParse(text);
        expect(shouldAbort, true,
            reason: '$name: 非物流内容应该触发熔断');
      });
    }
  });

  group('edge — 观察行为，不强断言', () {
    final cases = [
      'partial_ocr_garbled',
      'mixed_courier_names',
      'very_short_sms',
      'conflict_transit_arrival',
    ];
    for (final name in cases) {
      test(name, () {
        final text = File('test/fixtures/edge/$name.txt')
            .readAsStringSync();
        // 只要不崩溃即可
        final results = TextParser.parseMulti(text);
        expect(results, isNotNull,
            reason: '$name: 边缘情况不应该抛出异常');
        // 打印供人工观察
        debugPrint('[$name] count=${results.length}');
        for (final r in results) {
          debugPrint('  courier=${r.courier.value.displayName} '
              'status=${r.status.value.label} '
              'confidence=${r.overallConfidence.toStringAsFixed(2)}');
        }
      });
    }
  });
}
