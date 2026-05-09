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
  /// OCR错字映射表
  ///
  /// 形近字修正：在预处理阶段把常见 OCR 误认字替换为正确字
  static const Map<String, String> _ocrTypoMap = {
    // 极兔
    '极免': '极兔',
    '兔兔': '极兔',
    '極兔': '极兔',
    // 圆通
    '園通': '圆通',
    '圓通': '圆通',
    '圆运': '圆通',
    // 中通
    '中過': '中通',
    '中兔': '中通',
    '中遁': '中通',
    '中道': '中通',
    '中逹': '中通',
    // 韵达
    '韵逹': '韵达',
    '韵達': '韵达',
    '韵运': '韵达',
    '韵选': '韵达',
    // 申通
    '申兔': '申通',
    '甲通': '申通',
    '申逹': '申通',
    // 顺丰
    '须丰': '顺丰',
    '豐巢': '丰巢',
    '順丰': '顺丰',
    '順豐': '顺丰',
    // 德邦
    '德帮': '德邦',
  };

  /// 预处理文本
  static String preprocess(String text) {
    var cleaned = text;
    
    // OCR错字修正
    for (final entry in _ocrTypoMap.entries) {
      cleaned = cleaned.replaceAll(entry.key, entry.value);
    }
    
    // 去除中文字符间的空格（OCR常见artifact）
    // 注意：只去除空格和制表符，保留换行符以维持文本结构
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'([一-鿿])[ \t]+([一-鿿])'),
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
