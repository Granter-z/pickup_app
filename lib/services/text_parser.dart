/// 文本解析服务 - 兼容层
/// 
/// 职责：
/// 1. 提供向后兼容的API
/// 2. 委托给核心层处理
library;

import '../core/parser/text_parser.dart' as core;
import '../core/parser/parse_result.dart';
import '../core/parser/text_preprocessor.dart' as preprocessor;

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
    return core.TextParser.parseLegacy(text);
  }

  /// 解析多条文本
  static List<ParsedPackage> parseMulti(String text) {
    return core.TextParser.parseMultiLegacy(text);
  }
}
