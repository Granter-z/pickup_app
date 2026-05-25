import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:pickup_app/platform/ocr/mlkit_ocr_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('OCR Baseline Test', () {
    const imageDir = 'test/fixtures/real_world';
    const outputPath = '$imageDir/ocr_output.json';

    final imageFolders = ['cainiao', 'douyin', 'pdd'];
    final results = <String, dynamic>{};
    final ocr = MlKitOcrAdapter();

    test('Run OCR on all real_world images', () async {
      for (final folder in imageFolders) {
        final dir = Directory('$imageDir/$folder');
        if (!dir.existsSync()) continue;

        for (final file in dir.listSync()) {
          if (file is File && file.path.endsWith('.jpg')) {
            final imagePath = file.path;
            print('Processing: $imagePath');

            try {
              final ocrResult = await ocr.recognizeFromImage(imagePath);
              if (ocrResult.error?.contains('MissingPluginException') ?? false) {
                print('Skipping OCR baseline: ML Kit plugin is not available in this test environment.');
                return;
              }

              final relativePath = '$folder/${file.uri.pathSegments.last}';

              results[relativePath] = {
                'ocr_text': ocrResult.rawText,
                'confidence': ocrResult.confidence,
                'timestamp': ocrResult.timestamp.toIso8601String(),
                'is_empty': ocrResult.rawText.isEmpty,
              };

              print('  -> OCR text length: ${ocrResult.rawText.length}');
              print('  -> First 100 chars: ${ocrResult.rawText.substring(0, ocrResult.rawText.length.clamp(0, 100))}');
            } on MissingPluginException {
              print('Skipping OCR baseline: ML Kit plugin is not available in this test environment.');
              return;
            } catch (e) {
              print('  -> ERROR: $e');
              final relativePath = '$folder/${file.uri.pathSegments.last}';
              results[relativePath] = {
                'error': e.toString(),
                'is_empty': true,
              };
            }
          }
        }
      }

      final outputFile = File(outputPath);
      outputFile.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(results),
      );
      print('\nOCR output saved to: $outputPath');
      print('Total images processed: ${results.length}');
    }, timeout: const Timeout(Duration(minutes: 10)));
  });
}
