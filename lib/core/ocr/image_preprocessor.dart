library;

import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

class ImagePreprocessor {
  static const _defaultContrast = 1.2;
  static const _defaultBrightness = 0.1;
  static const _defaultThreshold = 128;

  final bool enableGrayscale;
  final bool enableContrastEnhancement;
  final bool enableNoiseReduction;
  final bool enableBinarization;
  final bool enableSharpening;
  final double contrast;
  final double brightness;
  final int threshold;

  const ImagePreprocessor({
    this.enableGrayscale = true,
    this.enableContrastEnhancement = true,
    this.enableNoiseReduction = true,
    this.enableBinarization = true,
    this.enableSharpening = false,
    this.contrast = _defaultContrast,
    this.brightness = _defaultBrightness,
    this.threshold = _defaultThreshold,
  });

  Future<img.Image?> processImage(String imagePath, {String? outputPath}) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        return null;
      }

      final bytes = await file.readAsBytes();
      var image = img.decodeImage(bytes);
      if (image == null) {
        return null;
      }

      image = _applyProcessing(image);

      if (outputPath != null) {
        final outputFile = File(outputPath);
        await outputFile.writeAsBytes(img.encodePng(image));
      }

      return image;
    } catch (e) {
      return null;
    }
  }

  img.Image? processImageFromMemory(Uint8List bytes) {
    try {
      var image = img.decodeImage(bytes);
      if (image == null) {
        return null;
      }

      return _applyProcessing(image);
    } catch (e) {
      return null;
    }
  }

  img.Image _applyProcessing(img.Image image) {
    if (enableGrayscale) {
      image = _grayscale(image);
    }

    if (enableContrastEnhancement) {
      image = _enhanceContrast(image, contrast, brightness);
    }

    if (enableNoiseReduction) {
      image = _reduceNoise(image);
    }

    if (enableSharpening) {
      image = _sharpen(image);
    }

    if (enableBinarization) {
      image = _binarize(image, threshold);
    }

    return image;
  }

  img.Image _grayscale(img.Image image) {
    return img.grayscale(image);
  }

  img.Image _enhanceContrast(img.Image image, double contrast, double brightness) {
    return img.adjustColor(
      image,
      contrast: contrast,
      brightness: brightness,
    );
  }

  img.Image _reduceNoise(img.Image image) {
    return img.gaussianBlur(image, radius: 1);
  }

  img.Image _sharpen(img.Image image) {
    final width = image.width;
    final height = image.height;
    final output = img.Image(width: width, height: height);

    for (var y = 1; y < height - 1; y++) {
      for (var x = 1; x < width - 1; x++) {
        final center = image.getPixel(x, y);
        final sumR = center.r * 5 -
            image.getPixel(x - 1, y).r -
            image.getPixel(x + 1, y).r -
            image.getPixel(x, y - 1).r -
            image.getPixel(x, y + 1).r;
        final sumG = center.g * 5 -
            image.getPixel(x - 1, y).g -
            image.getPixel(x + 1, y).g -
            image.getPixel(x, y - 1).g -
            image.getPixel(x, y + 1).g;
        final sumB = center.b * 5 -
            image.getPixel(x - 1, y).b -
            image.getPixel(x + 1, y).b -
            image.getPixel(x, y - 1).b -
            image.getPixel(x, y + 1).b;

        output.setPixel(x, y, img.ColorRgb8(
          (sumR.clamp(0, 255) as int),
          (sumG.clamp(0, 255) as int),
          (sumB.clamp(0, 255) as int),
        ));
      }
    }

    return output;
  }

  img.Image _binarize(img.Image image, int threshold) {
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final luminance = (pixel.r * 0.299 + pixel.g * 0.587 + pixel.b * 0.114).toInt();
        final newValue = luminance >= threshold ? 255 : 0;
        image.setPixel(x, y, img.ColorRgb8(newValue, newValue, newValue));
      }
    }
    return image;
  }

  static Future<bool> saveImage(img.Image image, String path) async {
    try {
      final file = File(path);
      await file.writeAsBytes(img.encodePng(image));
      return true;
    } catch (e) {
      return false;
    }
  }

  static ImagePreprocessor createDefault() {
    return const ImagePreprocessor(
      enableGrayscale: true,
      enableContrastEnhancement: true,
      enableNoiseReduction: true,
      enableBinarization: true,
      enableSharpening: false,
      contrast: 1.3,
      brightness: 0.05,
      threshold: 130,
    );
  }

  static ImagePreprocessor createEnhanced() {
    return const ImagePreprocessor(
      enableGrayscale: true,
      enableContrastEnhancement: true,
      enableNoiseReduction: true,
      enableBinarization: true,
      enableSharpening: true,
      contrast: 1.5,
      brightness: 0.1,
      threshold: 128,
    );
  }

  static ImagePreprocessor createLight() {
    return const ImagePreprocessor(
      enableGrayscale: true,
      enableContrastEnhancement: true,
      enableNoiseReduction: false,
      enableBinarization: false,
      enableSharpening: false,
      contrast: 1.15,
      brightness: 0.02,
    );
  }
}