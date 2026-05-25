library;

import 'dart:io';
import 'dart:ui';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import '../../core/ocr/ocr_service.dart';
import '../../core/ocr/ocr_result.dart';
import '../../core/debug/debug_trace.dart';

class MlKitOcrAdapter implements OcrService {
  /// 单例复用，避免每次创建的初始化开销
  static final MlKitOcrAdapter _instance = MlKitOcrAdapter._();
  factory MlKitOcrAdapter() => _instance;
  MlKitOcrAdapter._();

  /// 复用 TextRecognizer 实例（初始化耗时 50~200ms）
  TextRecognizer? _recognizer;

  TextRecognizer get recognizer {
    _recognizer ??= TextRecognizer(script: TextRecognitionScript.chinese);
    return _recognizer!;
  }

  /// 长边最大像素（超过则压缩）
  static const int _maxLongEdge = 1080;

  @override
  Future<OcrResult> recognizeFromImage(String imagePath) async {
    DebugTrace.separator('ML KIT OCR RECOGNITION');
    print('input image: $imagePath');

    final sw = Stopwatch()..start();

    // 预处理：压缩大图
    final processedPath = await _preprocessImage(imagePath);
    print('preprocess: ${sw.elapsedMilliseconds}ms');

    final inputImage = InputImage.fromFilePath(processedPath);

    try {
      final recognized = await recognizer.processImage(inputImage);
      sw.stop();
      print('OCR process: ${sw.elapsedMilliseconds}ms');
      print('total (preprocess+OCR): ${sw.elapsedMilliseconds}ms');

      final rawText = recognized.text;
      final lines = _extractLines(recognized);
      DebugTrace.ocrResult(rawText);
      print('OCR result length: ${rawText.length}');

      // 清理临时文件
      if (processedPath != imagePath) {
        try { File(processedPath).delete(); } catch (_) {}
      }

      if (rawText.isEmpty) {
        return OcrResult.empty();
      }

      return OcrResult(
        rawText: rawText,
        lines: lines,
        confidence: 0.8,
        timestamp: DateTime.now(),
      );
    } catch (e, stackTrace) {
      DebugTrace.error('ML Kit OCR error', error: e, stackTrace: stackTrace);
      return OcrResult.error('OCR识别失败: $e');
    }
  }

  List<OcrTextLine> _extractLines(RecognizedText recognized) {
    final lines = <OcrTextLine>[];

    for (final block in recognized.blocks) {
      for (final line in block.lines) {
        final box = line.boundingBox;
        if (box == null) {
          continue;
        }
        lines.add(
          OcrTextLine(
            text: line.text,
            box: OcrTextBox(
              left: box.left.toDouble(),
              top: box.top.toDouble(),
              right: box.right.toDouble(),
              bottom: box.bottom.toDouble(),
            ),
          ),
        );
      }
    }

    lines.sort((a, b) {
      final dy = (a.box.top - b.box.top).abs();
      if (dy > 8) {
        return a.box.top.compareTo(b.box.top);
      }
      return a.box.left.compareTo(b.box.left);
    });

    return lines;
  }

  /// 预处理图片：压缩大图，返回处理后的路径
  ///
  /// 逻辑：
  /// - 小图（长边 <= 1080）→ 直接用原图
  /// - 大图（长边 > 1080）→ 缩放到 1080，质量 85%
  Future<String> _preprocessImage(String imagePath) async {
    try {
      final file = File(imagePath);
      final bytes = await file.readAsBytes();
      final decoded = img.decodeImage(bytes);

      if (decoded == null) return imagePath;

      final longEdge = decoded.width > decoded.height
          ? decoded.width
          : decoded.height;

      // 小图不需要压缩
      if (longEdge <= _maxLongEdge) {
        print('image size: ${decoded.width}x${decoded.height} (no compress)');
        return imagePath;
      }

      // 计算缩放比例
      final scale = _maxLongEdge / longEdge;
      final newWidth = (decoded.width * scale).round();
      final newHeight = (decoded.height * scale).round();

      // 缩放
      final resized = img.copyResize(
        decoded,
        width: newWidth,
        height: newHeight,
        interpolation: img.Interpolation.linear,
      );

      // 保存为临时文件
      final compressedBytes = img.encodeJpg(resized, quality: 85);
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/ocr_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(compressedBytes);

      print('image compressed: ${decoded.width}x${decoded.height} → ${newWidth}x$newHeight');
      print('size: ${(bytes.length / 1024).round()}KB → ${(compressedBytes.length / 1024).round()}KB');

      return tempFile.path;
    } catch (e) {
      // 压缩失败，用原图
      print('image compress failed, using original: $e');
      return imagePath;
    }
  }

  /// 释放资源（应用退出时调用）
  Future<void> dispose() async {
    await _recognizer?.close();
    _recognizer = null;
  }
}
