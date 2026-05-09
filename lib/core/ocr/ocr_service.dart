library;

import 'ocr_result.dart';

abstract class OcrService {
  Future<OcrResult> recognizeFromImage(String imagePath);
}