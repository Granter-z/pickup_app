/// 文本预处理器 - 纯逻辑
/// 
/// 职责：
/// 1. 清洗OCR原始文本
/// 2. 去除噪音
/// 3. 标准化格式
library;

import 'regex_patterns.dart';

/// 文本预处理器
class TextPreprocessor {
  /// 预处理文本
  static String preprocess(String text) {
    var cleaned = text;
    
    // 去除中文字符之间的空格（OCR常见artifact）
    cleaned = cleaned.replaceAllMapped(
      RegexPatterns.chineseSpace,
      (m) => '${m[1]}${m[2]}',
    );
    
    // 去除UI噪音
    cleaned = cleaned.replaceAll(RegexPatterns.timeFormat, '');
    cleaned = cleaned.replaceAll(RegexPatterns.signalNoise, '');
    cleaned = cleaned.replaceAll(RegexPatterns.priceNoise, '');
    cleaned = cleaned.replaceAll(RegexPatterns.subsidyNoise, '');
    cleaned = cleaned.replaceAll(RegexPatterns.promoNoise, '');
    
    // 每行去除首尾空格，过滤空行
    cleaned = cleaned
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .join('\n');
    
    return cleaned;
  }

  /// 清理地址文本
  static String cleanLocation(String raw) {
    var cleaned = raw;
    
    // 移除换行符和多余空格
    cleaned = cleaned.replaceAll(RegexPatterns.whitespace, '');
    cleaned = cleaned.replaceAll('\n', '');
    
    // 移除常见的OCR误识别前缀
    final noisePrefixes = [
      '农场', '菜鸟', '官方', '推荐', '附近', '距离', '为您',
      '查看', '点击', '详情', '更多', '首页', '返回',
      '驿站', '取件', '包裹',
    ];

    for (final prefix in noisePrefixes) {
      if (cleaned.startsWith(prefix) && cleaned.length > prefix.length + 2) {
        cleaned = cleaned.substring(prefix.length);
        break;
      }
    }

    // 移除特殊字符前缀
    cleaned = cleaned.replaceAll(RegexPatterns.specialPrefix, '');
    cleaned = cleaned.replaceAll(RegexPatterns.alphaPrefix, '');

    return cleaned.trim();
  }

  /// 判断是否为广告文本
  static bool isAdText(String text) {
    final adKeywords = [
      '优惠', '补贴', '领券', '限时', '抢购', '补贴',
      '元', '¥', '￥', '折', '免费', '赠送',
      '广告', '推广', '推荐商品',
    ];
    return adKeywords.any((kw) => text.contains(kw));
  }
}
