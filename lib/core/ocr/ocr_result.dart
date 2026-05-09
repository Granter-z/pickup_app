library;

class OcrResult {
  final String rawText;
  final double confidence;
  final DateTime timestamp;
  final String? error;

  const OcrResult({
    required this.rawText,
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