/// 提取器接口和实现 - 纯逻辑
/// 
/// 职责：
/// 1. 定义提取器接口
/// 2. 实现各种字段提取器
/// 3. 使用词典和regex
library;

import '../models/package.dart';
import '../models/package_status.dart';
import 'courier_dictionary.dart';
import 'status_dictionary.dart';
import 'regex_patterns.dart';
import 'text_preprocessor.dart';

/// 提取结果
class ExtractionResult<T> {
  final T value;
  final double confidence;
  final String? source;
  
  const ExtractionResult({
    required this.value,
    this.confidence = 1.0,
    this.source,
  });
}

/// 快递公司提取器
class CourierExtractor {
  static ExtractionResult<CourierType> extract(String text) {
    final lower = text.toLowerCase();
    String? found;
    var maxLen = 0;
    bool isSpecific = false;

    for (final entry in CourierDictionary.platformAliases.entries) {
      if (!lower.contains(entry.key.toLowerCase())) continue;
      
      final isSpecificMatch = CourierDictionary.specificCouriers
          .any((s) => entry.key.contains(s) || s.contains(entry.key));
      
      if (isSpecificMatch || entry.key.length > maxLen) {
        maxLen = isSpecificMatch ? 999 : entry.key.length;
        found = entry.value;
        isSpecific = isSpecificMatch;
      }
    }

    if (found == null) {
      return ExtractionResult(
        value: CourierType.other,
        confidence: 0.0,
        source: 'no_match',
      );
    }

    final courierType = CourierDictionary.getCourierType(found);
    return ExtractionResult(
      value: courierType,
      confidence: isSpecific ? 0.95 : 0.8,
      source: 'keyword_match',
    );
  }
}

/// 取件码提取器
class PickupCodeExtractor {
  static ExtractionResult<String> extract(String text) {
    // Priority 1: 带标签的取件码
    final labelMatch = RegexPatterns.labeledPickupCode.firstMatch(text);
    if (labelMatch != null) {
      final code = labelMatch.group(1)!;
      if (!RegExp(r'^\d{10,}$').hasMatch(code)) {
        return ExtractionResult(
          value: code,
          confidence: 0.95,
          source: 'labeled_code',
        );
      }
    }

    // Priority 2: 短格式取件码
    final shortMatch = RegexPatterns.shortPickupCode.firstMatch(text);
    if (shortMatch != null) {
      final code = shortMatch.group(1)!;
      if (!RegExp(r'^\d{10,}$').hasMatch(code)) {
        return ExtractionResult(
          value: code,
          confidence: 0.9,
          source: 'short_code',
        );
      }
    }

    // Priority 3: Bay格式
    final bayMatch = RegexPatterns.bayFormatCode.firstMatch(text);
    if (bayMatch != null) {
      return ExtractionResult(
        value: bayMatch.group(0)!,
        confidence: 0.85,
        source: 'bay_format',
      );
    }

    // Priority 4: 4-8位数字
    for (final m in RegexPatterns.digitCode.allMatches(text)) {
      final code = m.group(1)!;
      final before = text.substring(0, m.start);
      if (!RegexPatterns.trackingPrefix.hasMatch(before) &&
          !RegexPatterns.courierPrefix.hasMatch(code)) {
        return ExtractionResult(
          value: code,
          confidence: 0.7,
          source: 'digit_code',
        );
      }
    }

    return ExtractionResult(
      value: '',
      confidence: 0.0,
      source: 'no_match',
    );
  }
}

/// 取货地点提取器
class LocationExtractor {
  static ExtractionResult<String> extract(String text) {
    // Priority 1: 地点标题格式1
    final title1Match = RegexPatterns.locationTitle1.firstMatch(text);
    if (title1Match != null) {
      var loc = TextPreprocessor.cleanLocation(title1Match.group(1)!.trim());
      if (loc.length >= 6 && !TextPreprocessor.isAdText(loc)) {
        return ExtractionResult(
          value: loc,
          confidence: 0.9,
          source: 'title_pattern_1',
        );
      }
    }

    // Priority 2: 地点标题格式2
    final title2Match = RegexPatterns.locationTitle2.firstMatch(text);
    if (title2Match != null) {
      var loc = TextPreprocessor.cleanLocation(title2Match.group(1)!.trim());
      if (loc.length >= 6 && !TextPreprocessor.isAdText(loc)) {
        return ExtractionResult(
          value: loc,
          confidence: 0.85,
          source: 'title_pattern_2',
        );
      }
    }

    // Priority 3: 到达格式
    final arrivalMatch = RegexPatterns.arrivalFormat.firstMatch(text);
    if (arrivalMatch != null) {
      var loc = arrivalMatch.group(1) ?? arrivalMatch.group(0) ?? '';
      loc = loc.replaceFirst(RegexPatterns.arrivalPrefix, '').trim();
      loc = TextPreprocessor.cleanLocation(loc);
      if (loc.length >= 3 && !TextPreprocessor.isAdText(loc)) {
        return ExtractionResult(
          value: loc,
          confidence: 0.8,
          source: 'arrival_format',
        );
      }
    }

    // Priority 4: 关键词搜索
    final keywords = [
      '驿站', '营业部', '网点', '配送站', '自提点', '快递柜',
      '店', '门面', '服务点', '代收点',
    ];

    String? bestLocation;
    var bestLength = 0;

    for (final kw in keywords) {
      final idx = text.indexOf(kw);
      if (idx != -1) {
        final start = (idx - 30).clamp(0, text.length);
        var candidate = text.substring(start, idx + kw.length).trim();
        candidate = TextPreprocessor.cleanLocation(candidate);

        if (candidate.length > bestLength && 
            candidate.length >= 4 && 
            !TextPreprocessor.isAdText(candidate)) {
          bestLocation = candidate;
          bestLength = candidate.length;
        }
      }
    }

    if (bestLocation != null) {
      return ExtractionResult(
        value: bestLocation,
        confidence: 0.7,
        source: 'keyword_search',
      );
    }

    return ExtractionResult(
      value: '',
      confidence: 0.0,
      source: 'no_match',
    );
  }
}

/// 运单号提取器
class TrackingNumberExtractor {
  static ExtractionResult<String> extract(String text) {
    // Priority 1: 带标签的运单号
    final labelMatch = RegexPatterns.labeledTrackingNumber.firstMatch(text);
    if (labelMatch != null) {
      return ExtractionResult(
        value: labelMatch.group(1)!,
        confidence: 0.95,
        source: 'labeled_tracking',
      );
    }

    // Priority 2: 快递公司+运单号
    final courierMatch = RegexPatterns.courierTrackingNumber.firstMatch(text);
    if (courierMatch != null) {
      return ExtractionResult(
        value: courierMatch.group(1)!,
        confidence: 0.9,
        source: 'courier_tracking',
      );
    }

    // Priority 3: 快递公司前缀
    final patterns = [
      RegexPatterns.sfTracking,
      RegexPatterns.jdTracking,
      RegexPatterns.ztoTracking,
      RegexPatterns.ytTracking,
      RegexPatterns.yt88Tracking,
      RegexPatterns.numericTracking,
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final number = match.group(1)!;
        if (!RegexPatterns.phoneNumber.hasMatch(number)) {
          return ExtractionResult(
            value: number,
            confidence: 0.8,
            source: 'courier_prefix',
          );
        }
      }
    }

    return ExtractionResult(
      value: '',
      confidence: 0.0,
      source: 'no_match',
    );
  }
}

/// 手机尾号提取器
class PhoneTailExtractor {
  static ExtractionResult<String> extract(String text) {
    // Pattern 1: 明确的手机尾号
    final tailMatch = RegexPatterns.explicitTail.firstMatch(text);
    if (tailMatch != null) {
      return ExtractionResult(
        value: tailMatch.group(1)!,
        confidence: 0.95,
        source: 'explicit_tail',
      );
    }

    // Pattern 2: 掩码手机号
    final maskedMatch = RegexPatterns.maskedPhone.firstMatch(text);
    if (maskedMatch != null) {
      return ExtractionResult(
        value: maskedMatch.group(1)!,
        confidence: 0.9,
        source: 'masked_phone',
      );
    }

    // Pattern 3: 完整手机号
    final phoneMatch = RegexPatterns.fullPhone.firstMatch(text);
    if (phoneMatch != null) {
      final full = phoneMatch.group(1)!;
      return ExtractionResult(
        value: full.substring(full.length - 4),
        confidence: 0.85,
        source: 'full_phone',
      );
    }

    // Pattern 4: 机主相关尾号
    final ownerMatch = RegexPatterns.ownerTail.firstMatch(text);
    if (ownerMatch != null) {
      return ExtractionResult(
        value: ownerMatch.group(1)!,
        confidence: 0.8,
        source: 'owner_tail',
      );
    }

    return ExtractionResult(
      value: '',
      confidence: 0.0,
      source: 'no_match',
    );
  }
}

/// 状态提取器（多信号验证）
/// 
/// arrived 判定需要多个信号同时满足：
/// - 取件码信号（取件码、取货码、提取码）
/// - 驿站/地点信号（驿站、营业部、网点、快递柜）
/// - 已到达信号（已到达、待取件、已入库）
/// - 取件动作信号（取件、提取、提货）
/// 
/// 重要：单独的数字或取件码不足以推断为 arrived
class StatusExtractor {
  /// 提取状态
  static ExtractionResult<PackageStatus> extract(String text) {
    // 第一步：尝试匹配高置信度关键词（stageMap）
    final directMatch = _matchDirectKeywords(text);
    if (directMatch != null) {
      return directMatch;
    }

    // 第二步：多信号验证
    final signals = _analyzeSignals(text);
    return _determineBySignals(signals);
  }

  /// 匹配高置信度关键词
  static ExtractionResult<PackageStatus>? _matchDirectKeywords(String text) {
    PackageStatus? found;
    var bestLen = 0;

    for (final entry in StatusDictionary.stageMap.entries) {
      if (!text.contains(entry.key)) continue;
      if (entry.key.length > bestLen) {
        found = entry.value;
        bestLen = entry.key.length;
      }
    }

    if (found != null) {
      return ExtractionResult(
        value: found,
        confidence: 0.9,
        source: 'direct_keyword',
      );
    }

    return null;
  }

  /// 分析文本中的各种信号
  static StatusSignals _analyzeSignals(String text) {
    // 检查是否真的提取到了取件码（使用 PickupCodeExtractor）
    final pickupCodeResult = PickupCodeExtractor.extract(text);
    final hasExtractedPickupCode = pickupCodeResult.value.isNotEmpty && 
        pickupCodeResult.confidence >= 0.7;
    
    // 检查是否包含取件码关键词
    final hasPickupCodeKeyword = _containsAny(text, StatusDictionary.pickupCodeSignals);
    
    // 取件码信号 = 真的提取到了取件码 AND 包含取件码关键词
    // 这样可以避免误匹配时间、日期等数字
    final hasPickupCodeSignal = hasExtractedPickupCode && hasPickupCodeKeyword;
    
    return StatusSignals(
      hasPickupCodeSignal: hasPickupCodeSignal,
      hasLocationSignal: _containsAny(text, StatusDictionary.locationSignals),
      hasArrivedSignal: _containsAny(text, StatusDictionary.arrivedSignals),
      hasPickupActionSignal: _containsAny(text, StatusDictionary.pickupActionSignals),
      hasPickedUpSignal: _containsAny(text, StatusDictionary.pickedUpSignals),
      hasDeliveringSignal: _containsAny(text, StatusDictionary.deliveringSignals),
      hasTransitSignal: _containsAny(text, StatusDictionary.transitSignals),
      hasBayFormat: StatusDictionary.bayFormatRegex.hasMatch(text),
      hasDigitCode: StatusDictionary.digitCodeRegex.hasMatch(text),
    );
  }

  /// 根据信号确定状态
  static ExtractionResult<PackageStatus> _determineBySignals(StatusSignals signals) {
    // ── 已取件判定 ──────────────────────────────────────────────
    // 签收/代收信号单独出现即可判定
    if (signals.hasPickedUpSignal) {
      return ExtractionResult(
        value: PackageStatus.pickedUp,
        confidence: 0.85,
        source: 'picked_up_signal',
      );
    }

    // ── 派送中判定 ──────────────────────────────────────────────
    // 派送/配送信号单独出现即可判定
    if (signals.hasDeliveringSignal) {
      return ExtractionResult(
        value: PackageStatus.delivering,
        confidence: 0.85,
        source: 'delivering_signal',
      );
    }

    // ── 运送中判定 ──────────────────────────────────────────────
    // 揽收/运输信号单独出现即可判定
    if (signals.hasTransitSignal) {
      return ExtractionResult(
        value: PackageStatus.transit,
        confidence: 0.85,
        source: 'transit_signal',
      );
    }

    // ── 已到达判定（多信号验证）──────────────────────────────────
    // 需要至少 2 个信号同时满足才推断为 arrived
    // 且必须包含取件码信号或地点信号
    final arrivedSignalCount = signals.arrivedSignalCount;
    final hasEssentialSignal = signals.hasPickupCodeSignal || signals.hasLocationSignal;

    if (arrivedSignalCount >= 2 && hasEssentialSignal) {
      // 多信号满足，高置信度 arrived
      return ExtractionResult(
        value: PackageStatus.arrived,
        confidence: 0.8 + (arrivedSignalCount - 2) * 0.05,
        source: 'multi_signal_arrived',
      );
    }

    if (arrivedSignalCount == 1 && hasEssentialSignal) {
      // 单信号满足，中等置信度 arrived
      return ExtractionResult(
        value: PackageStatus.arrived,
        confidence: 0.6,
        source: 'single_signal_arrived',
      );
    }

    // ── 默认：运送中 ──────────────────────────────────────────
    // 没有任何信号时，默认为运送中（最保守的推断）
    return ExtractionResult(
      value: PackageStatus.transit,
      confidence: 0.4,
      source: 'default_transit',
    );
  }

  /// 检查文本是否包含列表中的任意关键词
  static bool _containsAny(String text, List<String> keywords) {
    return keywords.any((kw) => text.contains(kw));
  }
}

/// 状态信号分析结果
class StatusSignals {
  final bool hasPickupCodeSignal;   // 取件码信号（真的提取到了取件码 AND 包含关键词）
  final bool hasLocationSignal;     // 驿站/地点信号
  final bool hasArrivedSignal;      // 已到达信号
  final bool hasPickupActionSignal; // 取件动作信号
  final bool hasPickedUpSignal;     // 已取件信号
  final bool hasDeliveringSignal;   // 派送中信号
  final bool hasTransitSignal;      // 运送中信号
  final bool hasBayFormat;          // Bay 格式取件码
  final bool hasDigitCode;          // 纯数字取件码

  const StatusSignals({
    required this.hasPickupCodeSignal,
    required this.hasLocationSignal,
    required this.hasArrivedSignal,
    required this.hasPickupActionSignal,
    required this.hasPickedUpSignal,
    required this.hasDeliveringSignal,
    required this.hasTransitSignal,
    required this.hasBayFormat,
    required this.hasDigitCode,
  });

  /// arrived 相关信号数量
  int get arrivedSignalCount {
    int count = 0;
    if (hasPickupCodeSignal) count++;
    if (hasLocationSignal) count++;
    if (hasArrivedSignal) count++;
    if (hasPickupActionSignal) count++;
    if (hasBayFormat) count++;
    return count;
  }
}
