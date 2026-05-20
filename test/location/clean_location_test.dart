import 'package:flutter_test/flutter_test.dart';
import 'package:pickup_app/core/parser/extractors.dart';

void main() {
  group('cleanLocation — 站点前缀清除', () {
    // ── 正常前缀 ──────────────────────────────────────────────

    test('Case 1: 正常菜鸟前缀', () {
      const input = '菜鸟驿站邢台信都区绿城诚园北门店';
      const station = '菜鸟驿站';
      final result = StationExtractor.cleanLocation(input, station);
      expect(result, '邢台信都区绿城诚园北门店');
    });

    test('Case 2: OCR 错误"鸟一"', () {
      const input = '鸟一邢台信都区绿城诚园北门店';
      const station = '菜鸟驿站';
      final result = StationExtractor.cleanLocation(input, station);
      expect(result, '邢台信都区绿城诚园北门店');
    });

    test('Case 3: OCR 错误"菜乌"', () {
      const input = '菜乌邢台信都区绿城诚园北门店';
      const station = '菜鸟驿站';
      final result = StationExtractor.cleanLocation(input, station);
      expect(result, '邢台信都区绿城诚园北门店');
    });

    // ── 不能误删正常地址 ──────────────────────────────────────

    test('Case 4: 不能误删"北门店"（不含前缀）', () {
      const input = '邢台信都区绿城诚园北门店';
      const station = '菜鸟驿站';
      final result = StationExtractor.cleanLocation(input, station);
      // 地址本身不含站点前缀，应原样返回
      expect(result, '邢台信都区绿城诚园北门店');
    });

    test('Case 5: 空输入', () {
      const input = '';
      const station = '菜鸟驿站';
      final result = StationExtractor.cleanLocation(input, station);
      expect(result, '');
    });

    test('Case 6: station 为空时原样返回', () {
      const input = '菜鸟驿站邢台信都区绿城诚园北门店';
      const station = '';
      final result = StationExtractor.cleanLocation(input, station);
      expect(result, '菜鸟驿站邢台信都区绿城诚园北门店');
    });

    // ── 其他站点类型 ──────────────────────────────────────────

    test('Case 7: 丰巢前缀', () {
      const input = '丰巢邢台信都区绿城诚园北门店';
      const station = '丰巢';
      final result = StationExtractor.cleanLocation(input, station);
      expect(result, '邢台信都区绿城诚园北门店');
    });

    test('Case 8: 妈妈驿站前缀', () {
      const input = '妈妈驿站邢台信都区绿城诚园北门店';
      const station = '妈妈驿站';
      final result = StationExtractor.cleanLocation(input, station);
      expect(result, '邢台信都区绿城诚园北门店');
    });

    // ── 边界情况 ──────────────────────────────────────────────

    test('Case 9: 前缀后有分隔符', () {
      const input = '菜鸟驿站·邢台信都区绿城诚园北门店';
      const station = '菜鸟驿站';
      final result = StationExtractor.cleanLocation(input, station);
      expect(result, '邢台信都区绿城诚园北门店');
    });

    test('Case 10: 前缀后有空格', () {
      const input = '菜鸟驿站 邢台信都区绿城诚园北门店';
      const station = '菜鸟驿站';
      final result = StationExtractor.cleanLocation(input, station);
      expect(result, '邢台信都区绿城诚园北门店');
    });
  });
}
