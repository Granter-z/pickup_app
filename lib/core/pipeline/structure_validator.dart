/// 地址结构验证器
///
/// 职责：
/// 1. 评估 ParsedAddress 的结构完整性
/// 2. 输出 0.0-1.0 的结构完整性评分
/// 3. 纯 Dart，不依赖 Flutter SDK
library;

import '../address/parsed_address.dart';

/// 地址结构验证器
class StructureValidator {
  /// 评估地址结构完整性
  ///
  /// 输入：ParsedAddress
  /// 输出：0.0-1.0 的结构完整性评分
  ///
  /// 评分规则：
  /// - city +0.2, district +0.2, province +0.1
  /// - community +0.2, building +0.15, room +0.15, poi +0.1
  /// - 全部为空返回 -1.0
  /// - 只有 poi 返回 -0.3
  static double validate(ParsedAddress address) {
    final hasAny = address.province != null ||
        address.city != null ||
        address.district != null ||
        address.community != null ||
        address.building != null ||
        address.room != null ||
        address.poi != null;

    if (!hasAny) return -1.0;

    final onlyPoi = address.province == null &&
        address.city == null &&
        address.district == null &&
        address.community == null &&
        address.building == null &&
        address.room == null &&
        address.poi != null;

    if (onlyPoi) return -0.3;

    double score = 0.0;

    if (address.city != null) score += 0.2;
    if (address.district != null) score += 0.2;
    if (address.province != null) score += 0.1;
    if (address.community != null) score += 0.2;
    if (address.building != null) score += 0.15;
    if (address.room != null) score += 0.15;
    if (address.poi != null) score += 0.1;

    return score.clamp(0.0, 1.0);
  }
}
