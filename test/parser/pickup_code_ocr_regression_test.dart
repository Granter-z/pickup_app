/// 取件码 OCR 误识别回归测试
///
/// 针对常见 OCR 误识别场景的回归测试
import 'package:flutter_test/flutter_test.dart';
import 'package:pickup_app/core/parser/extractors.dart';

void main() {
  group('取件码 OCR 误识别回归', () {
    test('日文长音ー应被识别为横杠', () {
      // OCR 常见：取件码:6ー4-5010
      const text = '取件码:6ー4-5010要制';
      final result = PickupCodeExtractor.extract(text);
      expect(result.value, equals('6-4-5010'),
        reason: '日文长音ー(U+30FC)应被规范化为普通横杠');
      print('✅ 6ー4-5010 → ${result.value}');
    });

    test('中文破折号—应被识别为横杠', () {
      const text = '取件码:6—4—5010';
      final result = PickupCodeExtractor.extract(text);
      expect(result.value, equals('6-4-5010'),
        reason: '中文破折号应被规范化为普通横杠');
      print('✅ 6—4—5010 → ${result.value}');
    });

    test('全角横杠－应被识别为横杠', () {
      const text = '取件码:6－4－5010';
      final result = PickupCodeExtractor.extract(text);
      expect(result.value, equals('6-4-5010'),
        reason: '全角横杠应被规范化为普通横杠');
      print('✅ 6－4－5010 → ${result.value}');
    });

    test('混合横杠类型应正确规范化', () {
      const text = '取件码:6ー4—5010';
      final result = PickupCodeExtractor.extract(text);
      expect(result.value, equals('6-4-5010'),
        reason: '混合横杠类型应全部规范化');
      print('✅ 6ー4—5010 → ${result.value}');
    });

    test('正常横杠格式不受影响', () {
      const text = '取件码:6-4-5010';
      final result = PickupCodeExtractor.extract(text);
      expect(result.value, equals('6-4-5010'),
        reason: '正常横杠格式应保持不变');
      print('✅ 6-4-5010 → ${result.value}');
    });
  });
}
