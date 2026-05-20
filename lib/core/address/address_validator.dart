// lib/core/address/address_validator.dart
// 地址验证器 - 验证地址结构的合理性

import 'parsed_address.dart';
import 'address_dictionary.dart';

/// 验证结果
class ValidationResult {
  /// 是否有效
  final bool isValid;

  /// 验证分数
  final double score;

  /// 验证警告
  final List<String> warnings;

  /// 验证错误
  final List<String> errors;

  const ValidationResult({
    required this.isValid,
    required this.score,
    this.warnings = const [],
    this.errors = const [],
  });
}

/// 地址验证器
///
/// 验证地址结构的合理性
class AddressValidator {
  // ── 验证方法 ──────────────────────────────────────────────

  /// 验证地址
  ///
  /// 输入：ParsedAddress
  /// 输出：ValidationResult
  static ValidationResult validate(ParsedAddress address) {
    final warnings = <String>[];
    final errors = <String>[];
    double score = 1.0;

    // 检查是否为空
    if (address.isEmpty) {
      return const ValidationResult(
        isValid: false,
        score: 0.0,
        errors: ['地址为空'],
      );
    }

    // 检查层级结构
    final hierarchyResult = _validateHierarchy(address);
    warnings.addAll(hierarchyResult.warnings);
    errors.addAll(hierarchyResult.errors);
    score *= hierarchyResult.score;

    // 检查字段完整性
    final completenessResult = _validateCompleteness(address);
    warnings.addAll(completenessResult.warnings);
    score *= completenessResult.score;

    // 检查字段格式
    final formatResult = _validateFormat(address);
    warnings.addAll(formatResult.warnings);
    errors.addAll(formatResult.errors);
    score *= formatResult.score;

    // 检查噪音
    final noiseResult = _validateNoise(address);
    warnings.addAll(noiseResult.warnings);
    score *= noiseResult.score;

    final isValid = errors.isEmpty && score >= 0.5;

    return ValidationResult(
      isValid: isValid,
      score: score.clamp(0.0, 1.0),
      warnings: warnings,
      errors: errors,
    );
  }

  // ── 层级验证 ──────────────────────────────────────────────

  /// 验证地址层级结构
  ///
  /// 检查：city → district → poi 是否合理
  static ValidationResult _validateHierarchy(ParsedAddress address) {
    final warnings = <String>[];
    final errors = <String>[];
    double score = 1.0;

    // 如果有城市，检查是否在已知城市列表中
    if (address.city != null) {
      if (!AddressDictionary.cities.contains(address.city)) {
        warnings.add('未知城市: ${address.city}');
        score *= 0.9;
      }
    }

    // 如果有区/县，检查格式
    if (address.district != null) {
      bool hasValidSuffix = false;
      for (final suffix in AddressDictionary.districtSuffixes) {
        if (address.district!.endsWith(suffix)) {
          hasValidSuffix = true;
          break;
        }
      }
      if (!hasValidSuffix) {
        warnings.add('区/县格式可能不正确: ${address.district}');
        score *= 0.9;
      }
    }

    // 检查省市区层级
    if (address.province != null && address.city != null) {
      // 这里可以添加省份和城市的对应关系检查
      // 暂时跳过
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      score: score,
      warnings: warnings,
      errors: errors,
    );
  }

  // ── 完整性验证 ──────────────────────────────────────────────

  /// 验证地址完整性
  static ValidationResult _validateCompleteness(ParsedAddress address) {
    final warnings = <String>[];
    double score = 1.0;

    // 检查是否有关键字段
    if (address.district == null && address.community == null && address.poi == null) {
      warnings.add('缺少关键地址信息（区/小区/POI）');
      score *= 0.5;
    }

    // 检查字段数量
    if (address.fieldCount < 2) {
      warnings.add('地址信息过少');
      score *= 0.7;
    }

    return ValidationResult(
      isValid: true,
      score: score,
      warnings: warnings,
    );
  }

  // ── 格式验证 ──────────────────────────────────────────────

  /// 验证地址格式
  static ValidationResult _validateFormat(ParsedAddress address) {
    final warnings = <String>[];
    final errors = <String>[];
    double score = 1.0;

    // 检查省份格式
    if (address.province != null) {
      if (!AddressDictionary.provinces.contains(address.province)) {
        warnings.add('未知省份: ${address.province}');
        score *= 0.9;
      }
    }

    // 检查城市格式
    if (address.city != null) {
      if (!AddressDictionary.cities.contains(address.city)) {
        warnings.add('未知城市: ${address.city}');
        score *= 0.9;
      }
    }

    // 检查区/县格式
    if (address.district != null) {
      bool hasValidSuffix = false;
      for (final suffix in AddressDictionary.districtSuffixes) {
        if (address.district!.endsWith(suffix)) {
          hasValidSuffix = true;
          break;
        }
      }
      if (!hasValidSuffix) {
        warnings.add('区/县格式可能不正确: ${address.district}');
        score *= 0.9;
      }
    }

    // 检查小区格式
    if (address.community != null) {
      bool hasValidSuffix = false;
      for (final suffix in AddressDictionary.communitySuffixes) {
        if (address.community!.endsWith(suffix)) {
          hasValidSuffix = true;
          break;
        }
      }
      if (!hasValidSuffix) {
        warnings.add('小区格式可能不正确: ${address.community}');
        score *= 0.9;
      }
    }

    // 检查 POI 格式
    if (address.poi != null) {
      bool hasValidSuffix = false;
      for (final suffix in AddressDictionary.poiSuffixes) {
        if (address.poi!.endsWith(suffix)) {
          hasValidSuffix = true;
          break;
        }
      }
      if (!hasValidSuffix) {
        warnings.add('POI 格式可能不正确: ${address.poi}');
        score *= 0.9;
      }
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      score: score,
      warnings: warnings,
      errors: errors,
    );
  }

  // ── 噪音验证 ──────────────────────────────────────────────

  /// 验证地址中的噪音
  static ValidationResult _validateNoise(ParsedAddress address) {
    final warnings = <String>[];
    double score = 1.0;

    // 检查原始文本中的噪音
    final rawText = address.rawText;
    for (final noise in AddressDictionary.noiseWords) {
      if (rawText.contains(noise)) {
        warnings.add('地址包含噪音词: $noise');
        score *= 0.8;
      }
    }

    return ValidationResult(
      isValid: true,
      score: score,
      warnings: warnings,
    );
  }
}
