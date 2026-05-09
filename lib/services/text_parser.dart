/// 文本解析服务 - 兼容层
/// 
/// 职责：
/// 1. 提供向后兼容的API
/// 2. 委托给核心层处理
library;

import '../core/debug/debug_trace.dart';
import '../core/parser/text_parser.dart' as core;
import '../core/parser/parse_result.dart';
import '../core/parser/text_preprocessor.dart' as preprocessor;
import '../core/utils/text_normalizer.dart';

// 重新导出核心层
export '../core/parser/parse_result.dart' show ParsedPackage;
export '../core/parser/parse_result.dart' show ParseResult;

/// 文本解析服务（向后兼容）
class TextParser {
  /// 预处理文本
  static String preprocess(String text) {
    return preprocessor.TextPreprocessor.preprocess(text);
  }

  /// 解析单条文本
  static ParsedPackage parse(String text) {
    final result = core.TextParser.parse(text);
    DebugTrace.parseResult(result);
    return result.toParsedPackage();
  }

  /// 解析多条文本
  static List<ParsedPackage> parseMulti(String text) {
    final results = core.TextParser.parseMulti(text);
    for (var i = 0; i < results.length; i++) {
      DebugTrace.parseResult(results[i], index: i);
      
      // 打印规范化文本
      final normalized = TextNormalizer.normalize(text);
      final fingerprint = TextNormalizer.transitFingerprint(
        results[i].courier.value.toString().split('.').last,
        text,
      );
      DebugTrace.normalizedText(text, normalized, fingerprint ?? '(null)');
    }
    return results.map((r) => r.toParsedPackage()).toList();
  }
}
