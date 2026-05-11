import 'package:flutter_test/flutter_test.dart';
import 'package:pickup_app/core/parser/text_parser.dart';
import 'package:pickup_app/core/parser/extractors.dart';

void main() {
  test('完整格式「菜鸟驿站」应被提取为站点名称', () {
    final text = '''菜鸟驿站
您有1个包裹已到站，取件码 15-3-6007，邢台信都区绿城诚园北门店''';

    final result = TextParser.parse(text);

    expect(result.station.value, '菜鸟驿站', reason: '站点名称应为菜鸟驿站');
    expect(result.location.value.contains('邢台'), true, reason: '地址应包含邢台');
  });

  test('OCR 只识别出「菜鸟」不含「驿站」时，应标准化为「菜鸟驿站」', () {
    final text = '''菜鸟
中通快递
取件码 15-3-6007
邢台信都区绿城诚园北门店''';

    final result = TextParser.parse(text);

    expect(result.station.value, '菜鸟驿站',
        reason: '只识别出"菜鸟"时应标准化为"菜鸟驿站"');
  });

  test('OCR 误识别「菜乌」应标准化为「菜鸟驿站」', () {
    final text = '菜乌 邢台信都区绿城诚园北门店';

    final station = StationExtractor.extract(text);

    expect(station, '菜鸟驿站', reason: '"菜乌"应标准化为"菜鸟驿站"');
  });

  test('「门店」不应被提取为站点名（当有更好的匹配时）', () {
    final text = '''菜鸟
取件码 15-3-6007
邢台信都区绿城诚园北门店''';

    final station = StationExtractor.extract(text);

    expect(station, '菜鸟驿站', reason: '应该返回菜鸟驿站而不是门店');
  });

  test('StationExtractor 关键词优先级测试', () {
    final text = '菜鸟 邢台信都区绿城诚园北门店';
    final station = StationExtractor.extract(text);

    expect(station, '菜鸟驿站',
        reason: '"菜鸟"排在"门店"前面，应优先匹配');
  });
}