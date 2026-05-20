// lib/core/address/address_parser.dart
// 分层地址解析器 - 将地址文本解析为结构化数据

import 'parsed_address.dart';
import 'address_dictionary.dart';

/// 解析结果
class ParseResult {
  /// 解析后的地址
  final ParsedAddress address;

  /// 解析置信度
  final double confidence;

  /// 解析警告
  final List<String> warnings;

  const ParseResult({
    required this.address,
    required this.confidence,
    this.warnings = const [],
  });
}

/// 分层地址解析器
///
/// 将地址文本解析为结构化的 ParsedAddress
/// 使用规则解析（方案 A），而不是 NLP 大模型
class AddressParser {
  // ── 解析方法 ──────────────────────────────────────────────

  /// 解析地址文本
  ///
  /// 输入：地址文本（如 "邢台信都区绿城诚园北门店"）
  /// 输出：ParseResult（包含 ParsedAddress 和置信度）
  static ParseResult parse(String text) {
    if (text.isEmpty) {
      return ParseResult(
        address: ParsedAddress(rawText: text),
        confidence: 0.0,
        warnings: ['地址为空'],
      );
    }

    final warnings = <String>[];
    String? province;
    String? city;
    String? district;
    String? road;
    String? community;
    String? building;
    String? unit;
    String? room;
    String? poi;

    // 预处理：OCR 纠错
    String processed = text;
    for (final entry in AddressDictionary.ocrCorrections.entries) {
      processed = processed.replaceAll(entry.key, entry.value);
    }

    // 第一步：提取省份
    province = _extractProvince(processed);

    // 第二步：提取城市
    city = _extractCity(processed);

    // 第三步：提取区/县
    district = _extractDistrict(processed);

    // 第四步：提取路/街
    road = _extractRoad(processed);

    // 第五步：提取小区名
    community = _extractCommunity(processed);

    // 第六步：提取楼栋
    building = _extractBuilding(processed);

    // 第七步：提取单元
    unit = _extractUnit(processed);

    // 第八步：提取房间号
    room = _extractRoom(processed);

    // 第九步：提取 POI
    poi = _extractPOI(processed);

    // 计算置信度
    final confidence = _calculateConfidence(
      province: province,
      city: city,
      district: district,
      road: road,
      community: community,
      building: building,
      unit: unit,
      room: room,
      poi: poi,
    );

    // 生成警告
    if (province == null && city == null && district == null) {
      warnings.add('缺少省市区信息');
    }
    if (community == null && poi == null) {
      warnings.add('缺少小区或POI信息');
    }

    return ParseResult(
      address: ParsedAddress(
        province: province,
        city: city,
        district: district,
        road: road,
        community: community,
        building: building,
        unit: unit,
        room: room,
        poi: poi,
        confidence: confidence,
        rawText: text,
        warnings: warnings,
      ),
      confidence: confidence,
      warnings: warnings,
    );
  }

  // ── 提取方法 ──────────────────────────────────────────────

  /// 提取省份
  static String? _extractProvince(String text) {
    for (final province in AddressDictionary.provinces) {
      if (text.contains(province)) {
        return province;
      }
    }
    return null;
  }

  /// 提取城市
  static String? _extractCity(String text) {
    for (final city in AddressDictionary.cities) {
      if (text.contains(city)) {
        return city;
      }
    }
    return null;
  }

  /// 提取区/县
  static String? _extractDistrict(String text) {
    for (final suffix in AddressDictionary.districtSuffixes) {
      // 使用更精确的匹配：区/县前通常只有 2-4 个汉字
      final pattern = RegExp(r'[\u4e00-\u9fa5]{2,4}' + RegExp.escape(suffix));
      final matches = pattern.allMatches(text).toList();
      if (matches.isNotEmpty) {
        // 返回最后一个匹配（通常是区/县）
        return matches.last.group(0);
      }
    }
    return null;
  }

  /// 提取路/街
  static String? _extractRoad(String text) {
    for (final suffix in AddressDictionary.roadSuffixes) {
      final pattern = RegExp(r'[\u4e00-\u9fa5]{2,10}' + RegExp.escape(suffix));
      final match = pattern.firstMatch(text);
      if (match != null) {
        return match.group(0);
      }
    }
    return null;
  }

  /// 提取小区名
  static String? _extractCommunity(String text) {
    for (final suffix in AddressDictionary.communitySuffixes) {
      // 使用更精确的匹配：小区名前通常只有 2-6 个汉字
      final pattern = RegExp(r'[\u4e00-\u9fa5]{2,6}' + RegExp.escape(suffix));
      final matches = pattern.allMatches(text).toList();
      if (matches.isNotEmpty) {
        // 返回最后一个匹配（通常是小区名）
        return matches.last.group(0);
      }
    }
    return null;
  }

  /// 提取楼栋
  static String? _extractBuilding(String text) {
    for (final suffix in AddressDictionary.buildingSuffixes) {
      final pattern = RegExp(r'\d+' + RegExp.escape(suffix));
      final match = pattern.firstMatch(text);
      if (match != null) {
        return match.group(0);
      }
    }
    return null;
  }

  /// 提取单元
  static String? _extractUnit(String text) {
    for (final suffix in AddressDictionary.unitSuffixes) {
      final pattern = RegExp(r'\d+' + RegExp.escape(suffix));
      final match = pattern.firstMatch(text);
      if (match != null) {
        return match.group(0);
      }
    }
    return null;
  }

  /// 提取房间号
  static String? _extractRoom(String text) {
    for (final suffix in AddressDictionary.roomSuffixes) {
      final pattern = RegExp(r'\d+' + RegExp.escape(suffix));
      final match = pattern.firstMatch(text);
      if (match != null) {
        return match.group(0);
      }
    }
    return null;
  }

  /// 提取 POI
  static String? _extractPOI(String text) {
    for (final suffix in AddressDictionary.poiSuffixes) {
      // 使用更精确的匹配：POI 前通常只有 2-4 个汉字
      final pattern = RegExp(r'[\u4e00-\u9fa5]{2,4}' + RegExp.escape(suffix));
      final matches = pattern.allMatches(text).toList();
      if (matches.isNotEmpty) {
        // 返回最后一个匹配（通常是 POI）
        return matches.last.group(0);
      }
    }
    return null;
  }

  // ── 置信度计算 ──────────────────────────────────────────────

  /// 计算解析置信度
  static double _calculateConfidence({
    String? province,
    String? city,
    String? district,
    String? road,
    String? community,
    String? building,
    String? unit,
    String? room,
    String? poi,
  }) {
    double score = 0.0;

    // 省份
    if (province != null) score += 0.10;

    // 城市
    if (city != null) score += 0.15;

    // 区/县
    if (district != null) score += 0.25;

    // 路/街
    if (road != null) score += 0.10;

    // 小区名
    if (community != null) score += 0.20;

    // 楼栋
    if (building != null) score += 0.05;

    // 单元
    if (unit != null) score += 0.05;

    // 房间号
    if (room != null) score += 0.05;

    // POI
    if (poi != null) score += 0.10;

    return score.clamp(0.0, 1.0);
  }
}
