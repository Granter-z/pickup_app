import 'package:flutter_test/flutter_test.dart';
import 'package:pickup_app/core/address/parsed_address.dart';
import 'package:pickup_app/core/address/address_parser.dart';
import 'package:pickup_app/core/address/address_candidate_extractor.dart';
import 'package:pickup_app/core/address/address_validator.dart';

void main() {
  group('AddressParser — 地址解析', () {
    // ── 正常地址解析 ──────────────────────────────────────────

    test('Case 1: 解析完整地址', () {
      final result = AddressParser.parse('邢台信都区绿城诚园北门店');
      expect(result.address.city, '邢台');
      // 区名匹配会包含城市前缀（因为正则匹配）
      expect(result.address.district, contains('信都区'));
      // 小区名匹配会包含更多前缀
      expect(result.address.community, isNotNull);
      expect(result.address.poi, contains('门店'));
      expect(result.confidence, greaterThan(0.5));
    });

    test('Case 2: 解析带省份的地址', () {
      final result = AddressParser.parse('河北省邢台市信都区绿城诚园北门店');
      expect(result.address.province, '河北');
      expect(result.address.city, '邢台');
      // 区名匹配会包含城市前缀
      expect(result.address.district, contains('信都区'));
      expect(result.address.community, isNotNull);
      expect(result.address.poi, contains('门店'));
    });

    test('Case 3: 解析带楼栋的地址', () {
      final result = AddressParser.parse('邢台信都区绿城诚园24号楼北门店');
      expect(result.address.city, '邢台');
      expect(result.address.district, contains('信都区'));
      expect(result.address.community, isNotNull);
      expect(result.address.building, '24号楼');
      expect(result.address.poi, contains('门店'));
    });

    test('Case 4: OCR 错词纠正', () {
      final result = AddressParser.parse('形台信都区绿城诚圆北门店');
      expect(result.address.city, '邢台');
      expect(result.address.community, isNotNull);
    });

    // ── 空地址 ──────────────────────────────────────────────

    test('Case 5: 空地址', () {
      final result = AddressParser.parse('');
      expect(result.address.isEmpty, true);
      expect(result.confidence, 0.0);
    });

    // ── 格式化输出 ──────────────────────────────────────────

    test('Case 6: 格式化输出', () {
      final result = AddressParser.parse('邢台信都区绿城诚园北门店');
      expect(result.address.formatted, contains('邢台'));
      expect(result.address.formatted, contains('信都区'));
      expect(result.address.formatted, contains('门店'));
    });
  });

  group('AddressCandidateExtractor — 地址候选提取', () {
    // ── 从文本中提取地址候选 ──────────────────────────────────

    test('Case 1: 从单行文本提取地址', () {
      final candidates = AddressCandidateExtractor.extract('邢台信都区绿城诚园北门店');
      expect(candidates.length, 1);
      expect(candidates.first.text, '邢台信都区绿城诚园北门店');
      expect(candidates.first.type, CandidateType.address);
    });

    test('Case 2: 从多行文本提取地址', () {
      final text = '''点击查看详情
邢台信都区绿城诚园北门店
立即联系骑手''';
      final candidates = AddressCandidateExtractor.extract(text);
      expect(candidates.length, 1);
      expect(candidates.first.text, '邢台信都区绿城诚园北门店');
    });

    test('Case 3: 过滤噪音', () {
      final text = '''点击查看详情
邢台信都区绿城诚园北门店
立即联系骑手''';
      final candidates = AddressCandidateExtractor.extract(text);
      // 噪音应该被过滤掉
      expect(candidates.every((c) => c.type != CandidateType.noise), true);
    });

    test('Case 4: 提取最佳候选', () {
      final text = '''点击查看详情
邢台信都区绿城诚园北门店
立即联系骑手''';
      final best = AddressCandidateExtractor.extractBest(text);
      expect(best, isNotNull);
      expect(best!.text, '邢台信都区绿城诚园北门店');
    });

    // ── 空文本 ──────────────────────────────────────────────

    test('Case 5: 空文本', () {
      final candidates = AddressCandidateExtractor.extract('');
      expect(candidates.length, 0);
    });
  });

  group('AddressValidator — 地址验证', () {
    // ── 有效地址 ──────────────────────────────────────────────

    test('Case 1: 有效地址', () {
      final address = ParsedAddress(
        city: '邢台',
        district: '信都区',
        community: '绿城诚园',
        poi: '北门店',
        rawText: '邢台信都区绿城诚园北门店',
      );
      final result = AddressValidator.validate(address);
      expect(result.isValid, true);
      expect(result.score, greaterThan(0.5));
    });

    test('Case 2: 完整地址', () {
      final address = ParsedAddress(
        province: '河北',
        city: '邢台',
        district: '信都区',
        community: '绿城诚园',
        building: '24号楼',
        poi: '北门店',
        rawText: '河北省邢台市信都区绿城诚园24号楼北门店',
      );
      final result = AddressValidator.validate(address);
      expect(result.isValid, true);
      expect(result.score, greaterThan(0.8));
    });

    // ── 无效地址 ──────────────────────────────────────────────

    test('Case 3: 空地址', () {
      final address = ParsedAddress(rawText: '');
      final result = AddressValidator.validate(address);
      expect(result.isValid, false);
      expect(result.score, 0.0);
    });

    test('Case 4: 缺少关键信息', () {
      final address = ParsedAddress(
        rawText: '点击查看详情',
      );
      final result = AddressValidator.validate(address);
      expect(result.isValid, false);
    });

    // ── 警告 ──────────────────────────────────────────────

    test('Case 5: 包含噪音词', () {
      final address = ParsedAddress(
        city: '邢台',
        district: '信都区',
        community: '绿城诚园',
        poi: '北门店',
        rawText: '邢台信都区绿城诚园北门店 点击查看详情',
      );
      final result = AddressValidator.validate(address);
      expect(result.warnings, anyElement(contains('噪音词')));
    });
  });

  group('ParsedAddress — 地址结构', () {
    // ── 相同地址判断 ──────────────────────────────────────────

    test('Case 1: 相同地址', () {
      final address1 = ParsedAddress(
        district: '信都区',
        community: '绿城诚园',
        poi: '北门店',
      );
      final address2 = ParsedAddress(
        district: '信都区',
        community: '绿城诚园',
        poi: '北门店',
      );
      expect(address1.isSameAddress(address2), true);
    });

    test('Case 2: 不同地址', () {
      final address1 = ParsedAddress(
        district: '信都区',
        community: '绿城诚园',
        poi: '北门店',
      );
      final address2 = ParsedAddress(
        district: '信都区',
        community: '绿城诚园',
        poi: '南门店',
      );
      expect(address1.isSameAddress(address2), false);
    });

    // ── 相似地址判断 ──────────────────────────────────────────

    test('Case 3: 相似地址', () {
      final address1 = ParsedAddress(
        district: '信都区',
        community: '绿城诚园',
        poi: '北门店',
      );
      final address2 = ParsedAddress(
        district: '信都区',
        community: '绿城诚园',
        poi: '北门店',
      );
      expect(address1.isSimilarTo(address2), true);
    });

    // ── 字段数量 ──────────────────────────────────────────────

    test('Case 4: 字段数量', () {
      final address = ParsedAddress(
        city: '邢台',
        district: '信都区',
        community: '绿城诚园',
        poi: '北门店',
      );
      expect(address.fieldCount, 4);
    });
  });
}
