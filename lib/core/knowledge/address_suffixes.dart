/// 地址后缀知识库
///
/// 纯 Dart，不依赖 Flutter SDK
/// 提供地址解析所需的后缀列表
library;

/// 地址后缀知识库
class AddressSuffixes {
  // ── 区/县后缀 ──────────────────────────────────────────────

  /// 区/县后缀
  static const List<String> districtSuffixes = ['区', '县', '市'];

  // ── 路/街后缀 ──────────────────────────────────────────────

  /// 路/街后缀
  static const List<String> roadSuffixes = ['路', '街', '大道'];

  // ── POI 后缀 ──────────────────────────────────────────────

  /// POI（兴趣点）后缀
  static const List<String> poiSuffixes = ['店', '驿站', '超市', '广场'];

  // ── 小区后缀 ──────────────────────────────────────────────

  /// 小区后缀
  static const List<String> communitySuffixes = ['小区', '苑', '花园', '公寓'];
}
