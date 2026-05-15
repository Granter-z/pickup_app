import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pickup_app/core/models/package.dart';
import 'package:pickup_app/core/models/package_status.dart';
import 'package:pickup_app/core/parser/text_parser.dart';
import 'package:pickup_app/core/parser/extractors.dart';

void main() {
  group('Notification text parsing', () {
    test('JD arrived notification', () {
      final text = File('test/fixtures/notifications/jd_arrived.txt')
          .readAsStringSync();
      final results = TextParser.parseMulti(text);
      expect(results.isNotEmpty, true, reason: '应该解析出包裹');
      final r = results.first;
      expect(r.courier.value, CourierType.jd, reason: '快递公司应为京东');
      expect(r.pickupCode.value, '6-8-2301', reason: '取件码应被识别');
      expect(r.status.value, PackageStatus.arrived, reason: '状态应为已到达');
      expect(r.isValid, true);
      expect(r.canCreatePackage, true);
    });

    test('Cainiao arrived notification', () {
      final text = File('test/fixtures/notifications/cainiao_arrived.txt')
          .readAsStringSync();
      final results = TextParser.parseMulti(text);
      expect(results.isNotEmpty, true, reason: '应该解析出包裹');
      final r = results.first;
      expect(r.pickupCode.value, '15-3-6007', reason: '取件码应被识别');
      expect(r.status.value, PackageStatus.arrived, reason: '状态应为已到达');
      expect(r.location.value.isNotEmpty, true, reason: '位置应被识别');
      expect(r.station.value, '菜鸟驿站', reason: '站点名称应被识别');
    });

    test('Taobao delivering notification', () {
      final text = File('test/fixtures/notifications/taobao_delivering.txt')
          .readAsStringSync();
      final results = TextParser.parseMulti(text);
      expect(results.isNotEmpty, true, reason: '应该解析出包裹');
      final r = results.first;
      expect(r.courier.value, CourierType.zto, reason: '快递公司应为中通');
      expect(r.trackingNumber.value, '76929191489436', reason: '运单号应被识别');
      expect(r.isValid, true);
    });

    test('PDD arrived notification', () {
      final text = File('test/fixtures/notifications/pdd_arrived.txt')
          .readAsStringSync();
      final results = TextParser.parseMulti(text);
      expect(results.isNotEmpty, true, reason: '应该解析出包裹');
      final r = results.first;
      expect(r.pickupCode.value, '7-3-6007', reason: '取件码应被识别');
      expect(r.status.value, PackageStatus.arrived, reason: '状态应为已到达');
      expect(r.station.value, '驿站', reason: '站点名称应被识别');
    });

    test('SF delivering notification', () {
      final text = File('test/fixtures/notifications/sf_delivering.txt')
          .readAsStringSync();
      final results = TextParser.parseMulti(text);
      expect(results.isNotEmpty, true, reason: '应该解析出包裹');
      final r = results.first;
      expect(r.courier.value, CourierType.sf, reason: '快递公司应为顺丰');
      expect(r.trackingNumber.value, 'SF123456789012', reason: '运单号应被识别');
    });

    test('Multi-package notification', () {
      final text = File('test/fixtures/notifications/multi_package_notification.txt')
          .readAsStringSync();
      final results = TextParser.parseMulti(text);
      expect(results.length, greaterThanOrEqualTo(2),
          reason: '应解析出至少2个包裹');

      final pickupCodes = results.map((r) => r.pickupCode.value).toList();
      expect(pickupCodes, contains('13-2-5039'), reason: '应包含取件码 13-2-5039');
      expect(pickupCodes, contains('15-5-5014'), reason: '应包含取件码 15-5-5014');
    });

    test('StationExtractor.cleanLocation strips OCR noise', () {
      // "鸟一" is OCR noise from "菜鸟"
      final cleaned = StationExtractor.cleanLocation('鸟一邢台信都区绿城诚园北门店', '菜鸟');
      expect(cleaned, '邢台信都区绿城诚园北门店');

      // "个菜鸟" prefix from OCR (real screenshot case)
      final cleaned2 = StationExtractor.cleanLocation('个菜鸟邢台信都区绿城诚园北门店', '菜鸟');
      expect(cleaned2, '邢台信都区绿城诚园北门店');

      // Normal case: no noise
      final normal = StationExtractor.cleanLocation('邢台信都区绿城诚园北门店', '菜鸟');
      expect(normal, '邢台信都区绿城诚园北门店');

      // "北门店" should NOT be stripped (it's part of the address)
      final address = StationExtractor.cleanLocation('邢台信都区绿城诚园北门店', '菜鸟');
      expect(address, '邢台信都区绿城诚园北门店');

      // Empty location
      expect(StationExtractor.cleanLocation('', '菜鸟'), '');
    });

    test('Non-courier notification produces low confidence or other courier', () {
      final text = File('test/fixtures/notifications/non_courier_notification.txt')
          .readAsStringSync();
      final results = TextParser.parseMulti(text);
      if (results.isNotEmpty) {
        expect(results.first.courier.value, CourierType.other,
            reason: '非快递通知应识别为 other');
      }
      // Either no results or very low confidence is acceptable
    });
  });
}
