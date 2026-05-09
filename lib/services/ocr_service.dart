/// OCR服务 - 兼容层
/// 
/// 职责：
/// 1. 提供向后兼容的API
/// 2. 委托给核心层处理
library;

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../core/ocr/ocr_result.dart';
import '../core/ocr/ocr_service.dart' as core;

/// OCR服务（向后兼容）
class OcrService {
  static final core.OcrService _coreService = core.OcrService();

  /// 从图片识别文本（返回原始文本，向后兼容）
  static Future<String> recognizeFromImage(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final recognizer = TextRecognizer(script: TextRecognitionScript.chinese);

    try {
      final recognized = await recognizer.processImage(inputImage);
      return recognized.text;
    } catch (_) {
      return '';
    } finally {
      await recognizer.close();
    }
  }

  /// 从图片识别文本（返回OcrResult，新API）
  static Future<OcrResult> recognizeFromImageWithResult(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final recognizer = TextRecognizer(script: TextRecognitionScript.chinese);

    try {
      final recognized = await recognizer.processImage(inputImage);
      final rawText = recognized.text;
      
      if (rawText.isEmpty) {
        return OcrResult.empty();
      }
      
      return _processOcrText(rawText);
    } catch (e) {
      return OcrResult.error('OCR识别失败: $e');
    } finally {
      await recognizer.close();
    }
  }

  /// 处理OCR文本
  static OcrResult _processOcrText(String rawText) {
    // 使用核心层处理
    return _coreService.recognizeFromImage('').then((_) {
      // 这里需要实际调用核心层
      // 目前返回简单结果
      return OcrResult(
        rawText: rawText,
        confidence: 0.8, // 假设置信度
        timestamp: DateTime.now(),
      );
    }).catchError((_) {
      return OcrResult(
        rawText: rawText,
        confidence: 0.5,
        timestamp: DateTime.now(),
      );
    }) as OcrResult;
  }
}
