library;

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../core/ocr/ocr_service.dart';
import '../../core/ocr/ocr_result.dart';
import '../../core/debug/debug_trace.dart';

class MlKitOcrAdapter implements OcrService {
  @override
  Future<OcrResult> recognizeFromImage(String imagePath) async {
    DebugTrace.separator('ML KIT OCR RECOGNITION');
    print('input image: $imagePath');

    final inputImage = InputImage.fromFilePath(imagePath);
    final recognizer = TextRecognizer(script: TextRecognitionScript.chinese);

    try {
      final recognized = await recognizer.processImage(inputImage);
      final rawText = recognized.text;
      DebugTrace.ocrResult(rawText);
      print('OCR result length: ${rawText.length}');

      if (rawText.isEmpty) {
        return OcrResult.empty();
      }

      return OcrResult(
        rawText: rawText,
        confidence: 0.8,
        timestamp: DateTime.now(),
      );
    } catch (e, stackTrace) {
      DebugTrace.error('ML Kit OCR error', error: e, stackTrace: stackTrace);
      return OcrResult.error('OCR识别失败: $e');
    } finally {
      await recognizer.close();
    }
  }
}