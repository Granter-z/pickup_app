library;

import '../ocr/ocr_result.dart';
import 'extractors.dart';
import 'parse_result.dart';

class OcrLayoutParser {
  static ParseResult enhance(ParseResult result, List<OcrTextLine> lines) {
    if (lines.isEmpty) return result;

    final anchorIndex = _findAnchorIndex(lines, result);
    if (anchorIndex == null) return result;

    final anchorLine = lines[anchorIndex];
    final window = _collectWindow(lines, anchorIndex);

    final pickupCode = _extractPickupCode(window) ?? result.pickupCode;
    final trackingNumber = _extractTrackingNumber(window) ?? result.trackingNumber;
    final courier = _extractCourier(window, trackingNumber.value) ?? result.courier;
    final station = _extractStation(window, anchorLine) ?? result.station;
    final location = _extractLocation(window, anchorLine, station.value) ?? result.location;
    final status = _extractStatus(window, pickupCode.value, result.status);

    final overallConfidence = _recalculateConfidence(
      courier: courier,
      pickupCode: pickupCode,
      trackingNumber: trackingNumber,
      location: location,
      status: status,
      phoneTail: result.phoneTail,
      station: station,
    );

    return result.copyWith(
      courier: courier,
      pickupCode: pickupCode,
      trackingNumber: trackingNumber,
      station: station,
      location: location,
      status: status,
      overallConfidence: overallConfidence,
    );
  }

  static int? _findAnchorIndex(List<OcrTextLine> lines, ParseResult result) {
    final targetCode = result.pickupCode.value.trim();
    if (targetCode.isNotEmpty) {
      for (var i = 0; i < lines.length; i++) {
        final extracted = PickupCodeExtractor.extract(lines[i].text).value;
        if (extracted.isNotEmpty && extracted == targetCode) return i;
        if (lines[i].text.contains(targetCode)) return i;
      }
    }

    final targetTracking = result.trackingNumber.value.trim();
    if (targetTracking.isNotEmpty) {
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].text.contains(targetTracking)) return i;
      }
    }

    for (var i = 0; i < lines.length; i++) {
      if (PickupCodeExtractor.extract(lines[i].text).value.isNotEmpty) return i;
    }

    return null;
  }

  static List<OcrTextLine> _collectWindow(List<OcrTextLine> lines, int anchorIndex) {
    final anchor = lines[anchorIndex];
    final window = <OcrTextLine>[anchor];

    for (var i = anchorIndex - 1; i >= 0; i--) {
      final line = lines[i];
      if (anchor.box.top - line.box.bottom > 360) break;
      window.insert(0, line);
    }

    for (var i = anchorIndex + 1; i < lines.length; i++) {
      final line = lines[i];
      if (line.box.top - anchor.box.bottom > 360) break;
      window.add(line);
    }

    return window;
  }

  static ExtractionResult<String>? _extractPickupCode(List<OcrTextLine> window) {
    for (final line in window) {
      final result = PickupCodeExtractor.extract(line.text);
      if (result.value.isNotEmpty) return result;
    }
    return null;
  }

  static ExtractionResult<String>? _extractTrackingNumber(List<OcrTextLine> window) {
    for (final line in window) {
      final result = TrackingNumberExtractor.extract(line.text);
      if (result.value.isNotEmpty) return result;
    }
    return null;
  }

  static ExtractionResult<CourierType>? _extractCourier(
    List<OcrTextLine> window,
    String trackingNumber,
  ) {
    for (final line in window) {
      final text = trackingNumber.isNotEmpty ? '${line.text} $trackingNumber' : line.text;
      final result = CourierExtractor.extract(text);
      if (result.value != CourierType.other) return result;
    }
    return null;
  }

  static ExtractionResult<String>? _extractStation(List<OcrTextLine> window, OcrTextLine anchor) {
    final candidates = <_LineCandidate>[];
    for (final line in window) {
      if (line.box.bottom > anchor.box.top) continue;
      final text = line.text.trim();
      if (!_looksLikeStation(text)) continue;
      final score = 1000 - (anchor.box.top - line.box.bottom).abs().round();
      candidates.add(_LineCandidate(text, score));
    }

    if (candidates.isEmpty) return null;

    candidates.sort((a, b) => b.score.compareTo(a.score));
    final value = _cleanStation(candidates.first.text);
    if (value.isEmpty) return null;
    return ExtractionResult(value: value, confidence: 0.92, source: 'layout_station');
  }

  static ExtractionResult<String>? _extractLocation(
    List<OcrTextLine> window,
    OcrTextLine anchor,
    String station,
  ) {
    final candidates = <_LineCandidate>[];

    for (final line in window) {
      final text = line.text.trim();
      if (text.isEmpty) continue;
      if (text.contains('\u8425\u4e1a\u65f6\u95f4')) continue;
      if (text.contains('\u53d6\u4ef6\u7801')) continue;
      if (text.contains('\u5f85\u53d6\u4ef6') ||
          text.contains('\u5df2\u653e\u81f3') ||
          text.contains('\u5df2\u5230\u8fbe')) continue;
      if (line.box.top > anchor.box.bottom) continue;

      final looksLikeDetail = _looksLikeDetailAddress(text);
      final isStation = _looksLikeStation(text);
      if (!looksLikeDetail && !isStation) continue;

      final score = 1000 - (anchor.box.top - line.box.bottom).abs().round();
      final value = isStation ? _cleanStation(text) : text;
      if (value.isEmpty) continue;

      candidates.add(_LineCandidate(value, score + (looksLikeDetail ? 30 : 0)));
    }

    if (candidates.isEmpty) return null;

    candidates.sort((a, b) => b.score.compareTo(a.score));
    final best = candidates.first.text;
    if (best == station && candidates.length > 1) {
      return ExtractionResult(value: candidates[1].text, confidence: 0.84, source: 'layout_detail');
    }
    return ExtractionResult(value: best, confidence: 0.88, source: 'layout_detail');
  }

  static ExtractionResult<PackageStatus> _extractStatus(
    List<OcrTextLine> window,
    String pickupCode,
    ExtractionResult<PackageStatus> fallback,
  ) {
    final joined = window.map((e) => e.text).join('\n');
    final status = StatusExtractor.extract(joined);
    if (status.value != fallback.value) return status;
    if (pickupCode.isNotEmpty && status.value == PackageStatus.pickedUp) {
      return ExtractionResult(
        value: PackageStatus.arrived,
        confidence: 0.95,
        source: 'layout_pickup_code_override',
      );
    }
    return fallback;
  }

  static double _recalculateConfidence({
    required ExtractionResult<CourierType> courier,
    required ExtractionResult<String> pickupCode,
    required ExtractionResult<String> trackingNumber,
    required ExtractionResult<String> location,
    required ExtractionResult<PackageStatus> status,
    required ExtractionResult<String> phoneTail,
    required ExtractionResult<String> station,
  }) {
    final confidences = <double>[
      courier.confidence,
      pickupCode.confidence,
      trackingNumber.confidence,
      location.confidence,
      status.confidence,
      phoneTail.confidence,
      station.confidence,
    ].where((c) => c > 0).toList();

    if (confidences.isEmpty) return 0.0;
    return confidences.reduce((a, b) => a + b) / confidences.length;
  }

  static bool _looksLikeStation(String text) {
    return text.contains('\u83dc\u9e1f') ||
        text.contains('\u9a7b\u7ad9') ||
        text.contains('\u5feb\u9012\u67dc') ||
        text.contains('\u7f51\u70b9') ||
        text.contains('\u95e8\u5e97') ||
        text.contains('\u4ee3\u6536\u70b9') ||
        text.contains('\u8425\u4e1a\u90e8') ||
        text.contains('\u81ea\u63d0\u70b9') ||
        text.contains('\u670d\u52a1\u70b9') ||
        text.contains('\u5feb\u9012\u70b9') ||
        text.contains('\u5317\u95e8') ||
        text.contains('\u5357\u95e8') ||
        text.contains('\u4e1c\u95e8') ||
        text.contains('\u897f\u95e8');
  }

  static bool _looksLikeDetailAddress(String text) {
    return text.contains('\u8def') ||
        text.contains('\u8857') ||
        text.contains('\u53f7') ||
        text.contains('\u5e62') ||
        text.contains('\u680b') ||
        text.contains('\u5355\u5143') ||
        text.contains('\u5ba4') ||
        text.contains('\u697c') ||
        text.contains('\u5730\u5e93') ||
        text.contains('\u5e95\u5546') ||
        text.contains('\u5bf9\u9762') ||
        text.contains('\u9644\u8fd1') ||
        text.contains('\u5357\u8fb9') ||
        text.contains('\u5317\u8fb9');
  }

  static String _cleanStation(String text) {
    var cleaned = text.trim();
    for (final prefix in const [
      '\u53d6\u4ef6\u70b9',
      '\u53d6\u4ef6\u5730\u5740',
      '\u5feb\u4ef6\u5730\u5740',
      '\u6536\u8d27\u5730\u5740',
      '\u5730\u5740',
    ]) {
      if (cleaned.startsWith(prefix)) {
        cleaned = cleaned.substring(prefix.length);
        break;
      }
    }
    cleaned = cleaned.trimLeft();
    while (cleaned.startsWith('-') || cleaned.startsWith(' ')) {
      cleaned = cleaned.substring(1).trimLeft();
    }
    return cleaned.trim();
  }
}

class _LineCandidate {
  final String text;
  final int score;

  const _LineCandidate(this.text, this.score);
}
