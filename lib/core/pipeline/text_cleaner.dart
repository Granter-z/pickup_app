/// OCR 文本清洗器
///
/// 职责：
/// 1. 去除 \r
/// 2. 多空格转单空格
/// 3. 去除特殊符号
/// 4. trim
/// 5. splitLines
library;

/// OCR 文本清洗器
class TextCleaner {
  /// 清洗 OCR 文本
  ///
  /// 流程：
  /// 1. 去除 \r
  /// 2. 多空格转单空格
  /// 3. 去除特殊符号
  /// 4. trim
  static String clean(String rawText) {
    if (rawText.isEmpty) return rawText;

    var cleaned = rawText;

    // 去除 \r
    cleaned = cleaned.replaceAll('\r', '');

    // 多空格转单空格
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');

    // 去除特殊符号（保留中文、字母、数字、常见标点）
    cleaned = cleaned.replaceAll(RegExp(r'[^\w\s\u4e00-\u9fa5]'), '');

    // trim
    cleaned = cleaned.trim();

    return cleaned;
  }

  /// 按行分割文本
  ///
  /// 返回清洗后的行列表，每行已 trim
  static List<String> splitLines(String rawText) {
    if (rawText.isEmpty) return [];

    final cleaned = clean(rawText);
    final lines = cleaned.split('\n');
    
    return lines
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  /// 清洗并分割文本
  ///
  /// 返回清洗后的文本和行列表
  static CleanResult cleanAndSplit(String rawText) {
    final cleaned = clean(rawText);
    final lines = splitLines(rawText);

    return CleanResult(
      original: rawText,
      cleaned: cleaned,
      lines: lines,
    );
  }
}

/// 清洗结果
class CleanResult {
  /// 原始文本
  final String original;

  /// 清洗后的文本
  final String cleaned;

  /// 清洗后的行列表
  final List<String> lines;

  const CleanResult({
    required this.original,
    required this.cleaned,
    required this.lines,
  });

  /// 是否有有效内容
  bool get hasContent => lines.isNotEmpty;

  /// 行数
  int get lineCount => lines.length;
}