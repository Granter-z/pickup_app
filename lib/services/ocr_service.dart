import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
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
}
