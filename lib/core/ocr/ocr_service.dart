/// OCR服务 - 核心层
/// 
/// 职责：
/// 1. 提供OCR识别接口
/// 2. 处理识别结果
/// 3. 提供容错机制
library;

import 'ocr_result.dart';
import '../parser/text_parser.dart';

/// OCR服务接口
abstract class OcrServiceInterface {
  /// 从图片识别文本
  Future<OcrResult> recognizeFromImage(String imagePath);
}

/// OCR服务实现
class OcrService implements OcrServiceInterface {
  @override
  Future<OcrResult> recognizeFromImage(String imagePath) async {
    try {
      // 这里会调用实际的OCR引擎（如Google ML Kit）
      // 目前返回模拟结果
      final rawText = await _performOcr(imagePath);
      
      if (rawText.isEmpty) {
        return OcrResult.empty();
      }
      
      return _processOcrText(rawText);
    } catch (e) {
      return OcrResult.error('OCR识别失败: $e');
    }
  }

  /// 执行OCR识别（子类需要实现）
  Future<String> _performOcr(String imagePath) async {
    // 默认实现：返回空字符串
    // 实际实现应该调用Google ML Kit或其他OCR引擎
    return '';
  }

  /// 处理OCR文本
  OcrResult _processOcrText(String rawText) {
    final candidates = <ParseCandidate>[];
    final warnings = <ParseWarning>[];
    
    // 尝试解析
    try {
      final parseResult = TextParser.parse(rawText);
      
      if (parseResult.isValid) {
        candidates.add(ParseCandidate(
          result: parseResult,
          confidence: parseResult.overallConfidence,
          source: 'single_parse',
          rank: 0,
        ));
      }
      
      // 添加解析警告
      for (final warning in parseResult.allWarnings) {
        warnings.add(ParseWarning.warning(warning, source: 'parser'));
      }
    } catch (e) {
      warnings.add(ParseWarning.error('解析失败: $e', source: 'parser'));
    }
    
    // 计算总体置信度
    final confidence = candidates.isEmpty 
        ? 0.0 
        : candidates.first.confidence;
    
    return OcrResult(
      rawText: rawText,
      confidence: confidence,
      candidates: candidates,
      warnings: warnings,
      timestamp: DateTime.now(),
    );
  }
}

/// OCR服务工厂
class OcrServiceFactory {
  static OcrServiceInterface create() {
    return OcrService();
  }
}
