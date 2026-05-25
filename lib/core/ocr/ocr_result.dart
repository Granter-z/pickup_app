library;

class OcrTextBox {
  final double left;
  final double top;
  final double right;
  final double bottom;

  const OcrTextBox({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  double get width => right - left;
  double get height => bottom - top;
  double get centerX => (left + right) / 2;
  double get centerY => (top + bottom) / 2;

  bool horizontallyOverlaps(OcrTextBox other) {
    return left <= other.right && right >= other.left;
  }
}

class OcrTextLine {
  final String text;
  final OcrTextBox box;

  const OcrTextLine({
    required this.text,
    required this.box,
  });
}

class OcrResult {
  final String rawText;
  final List<OcrTextLine> lines;
  final double confidence;
  final DateTime timestamp;
  final String? error;

  const OcrResult({
    required this.rawText,
    this.lines = const [],
    this.confidence = 0.0,
    required this.timestamp,
    this.error,
  });

  bool get isValid => rawText.isNotEmpty && error == null;
  bool get isEmpty => rawText.isEmpty;

  factory OcrResult.empty() =>
      OcrResult(rawText: '', timestamp: DateTime.now());

  factory OcrResult.error(String message) =>
      OcrResult(rawText: '', timestamp: DateTime.now(), error: message);
}
