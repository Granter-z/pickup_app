library;

import 'package:uuid/uuid.dart';
import '../core/models/package.dart';
import '../core/models/package_status.dart';
import '../core/models/pending_confirmation.dart';
import '../core/parser/text_parser.dart' as core;
import '../core/parser/conflict_detector.dart';
import '../core/sanitizer/text_sanitizer.dart';
import '../core/utils/text_normalizer.dart';
import '../core/debug/debug_trace.dart';
import '../core/debug/metrics.dart';
import '../platform/ocr/mlkit_ocr_adapter.dart';

class OcrPipeline {
  static const _uuid = Uuid();
  static final _ocr = MlKitOcrAdapter();

  static Future<OcrParseResult> run(String imagePath) async {
    final rawText = await _ocr.recognizeFromImage(imagePath);
    final ocrText = rawText.rawText;

    Metrics.inc('ocr.attempt');

    if (ocrText.isEmpty) {
      Metrics.inc('abort.empty');
      DebugTrace.abort('rawText empty');
      return OcrParseResult.empty();
    }

    DebugTrace.separator('TEXT SANITIZATION');

    print('===============================================');
    print('  [LAYER 1] OCR RAW TEXT');
    print('===============================================');
    print(ocrText);
    print('  length: ${ocrText.length}');
    print('');

    final sanitizedResult = TextSanitizer.cleanWithAnalysis(ocrText);
    print('===============================================');
    print('  [LAYER 2] SANITIZED TEXT');
    print('===============================================');
    print(sanitizedResult.cleaned);
    print('  original length: ${ocrText.length}');
    print('  cleaned length: ${sanitizedResult.cleaned.length}');
    print('  keptLines: ${sanitizedResult.keptLines}');
    print('  removedLines: ${sanitizedResult.removedLines}');
    if (sanitizedResult.noiseLines.isNotEmpty) {
      print('  noiseLines: ${sanitizedResult.noiseLines.map((a) => a.text).take(5).toList()}...');
    }
    print('');

    final sanitizedText = sanitizedResult.cleaned;

    final conflictResult = ConflictDetector.analyze(sanitizedText);
    DebugTrace.separator('CONFLICT ANALYSIS');
    print('hasTransitSignals: ${conflictResult.hasTransitSignals}');
    print('hasArrivalSignals: ${conflictResult.hasArrivalSignals}');
    print('conflictLevel: ${conflictResult.level}');
    if (conflictResult.detectedTransitKeywords.isNotEmpty) {
      print('transitKeywords: ${conflictResult.detectedTransitKeywords}');
    }
    if (conflictResult.detectedArrivalKeywords.isNotEmpty) {
      print('arrivalKeywords: ${conflictResult.detectedArrivalKeywords}');
    }

    if (TextSanitizer.shouldAbortParse(sanitizedText)) {
      Metrics.inc('abort.dashboard');
      DebugTrace.abort('dashboard_like_screen');
      return OcrParseResult.empty();
    }

    DebugTrace.separator('PARSING START');
    print('sanitizedText length: ${sanitizedText.length}');

    final parseResults = core.TextParser.parseMulti(sanitizedText);

    DebugTrace.separator('PARSING COMPLETE');
    print('parseResults count: ${parseResults.length}');

    print('');
    print('===============================================');
    print('  [LAYER 3] PARSE RESULTS');
    print('===============================================');

    final highConfidence = <Package>[];
    final lowConfidence = <PendingConfirmation>[];

    for (var i = 0; i < parseResults.length; i++) {
      try {
        final result = parseResults[i];
        final confidence = result.overallConfidence;
        final id = _uuid.v4();

        DebugTrace.parseResult(result, index: i);

        final courierName = result.courier.value.toString().split('.').last;
        print('');
        print('  +-----------------------------------------');
        print('  | $i');
        print('  +-----------------------------------------');
        print('  | courier:       $courierName (conf: ${result.courier.confidence})');
        print('  | pickupCode:    "${result.pickupCode.value}" (conf: ${result.pickupCode.confidence})');
        print('  | trackingNumber: "${result.trackingNumber.value}" (conf: ${result.trackingNumber.confidence})');
        print('  | location:      "${result.location.value}" (conf: ${result.location.confidence})');
        print('  | status:        ${result.status.value} (conf: ${result.status.confidence})');
        print('  | overallConf:   ${confidence.toStringAsFixed(2)}');
        print('  | isValid:       ${result.isValid}');
        print('  +-----------------------------------------');

        final normalized = TextNormalizer.normalize(ocrText);
        final fingerprint = TextNormalizer.transitFingerprint(
          courierName, ocrText,
          trackingNumber: result.trackingNumber.value,
        );
        print('  | normalized:    "$normalized"');
        print('  | fingerprint:   "$fingerprint"');
        DebugTrace.normalizedText(ocrText, normalized, fingerprint ?? '(null)');

        final isTransit = result.status.value == PackageStatus.transit ||
            result.status.value == PackageStatus.delivering;
        final isArrived = result.status.value == PackageStatus.arrived;
        final hasPickupCode = result.pickupCode.value.isNotEmpty;
        final hasLocation = result.location.value.isNotEmpty;

        if (isTransit && !hasPickupCode && confidence >= 0.5) {
          DebugTrace.separator('TRANSIT + NO PICKUP CODE -> SILENT PACKAGE');
          highConfidence.add(_toPackage(result, id, ocrText));
        } else if (isArrived && (!hasPickupCode || !hasLocation)) {
          DebugTrace.separator('ARRIVED + INCOMPLETE INFO -> PENDING CONFIRMATION');
          lowConfidence.add(_toConfirmation(result, id, ocrText));
        } else if (conflictResult.isHighConflict) {
          DebugTrace.separator('HIGH CONFLICT -> PENDING CONFIRMATION');
          lowConfidence.add(_toConfirmation(result, id, ocrText));
        } else if (confidence >= 0.7) {
          DebugTrace.separator('HIGH CONFIDENCE -> PACKAGE');
          highConfidence.add(_toPackage(result, id, ocrText));
        } else {
          DebugTrace.separator('LOW CONFIDENCE -> PENDING CONFIRMATION');
          lowConfidence.add(_toConfirmation(result, id, ocrText));
        }
      } catch (e, stackTrace) {
        DebugTrace.error('Error processing parseResult #$i', error: e, stackTrace: stackTrace);
      }
    }

    if (highConfidence.isNotEmpty || lowConfidence.isNotEmpty) {
      Metrics.inc('parse.success');
    } else {
      Metrics.inc('parse.fail');
    }

    return OcrParseResult(
      highConfidencePackages: highConfidence,
      lowConfidenceConfirmations: lowConfidence,
      rawText: ocrText,
    );
  }

  static Package _toPackage(dynamic result, String id, String rawText) {
    final courierName = result.courier.value.toString().split('.').last;
    final fingerprint = TextNormalizer.transitFingerprint(
      courierName, rawText,
      trackingNumber: result.trackingNumber.value,
    );

    DebugTrace.packageCreated(Package(
      id: id,
      trackingNumber: result.trackingNumber.value,
      courier: result.courier.value,
      pickupCode: result.pickupCode.value,
      location: result.location.value,
      urgency: UrgencyLevel.normal,
      status: result.status.value,
      addedAt: DateTime.now(),
      transitFingerprint: fingerprint,
    ));

    return Package(
      id: id,
      trackingNumber: result.trackingNumber.value.isNotEmpty
          ? result.trackingNumber.value
          : 'OCR-${DateTime.now().millisecondsSinceEpoch}',
      courier: result.courier.value,
      pickupCode: result.pickupCode.value,
      location: result.location.value,
      description: _buildDescription(result),
      urgency: UrgencyLevel.normal,
      status: result.status.value,
      addedAt: DateTime.now(),
      transitFingerprint: fingerprint,
    );
  }

  static PendingConfirmation _toConfirmation(
    dynamic result,
    String id,
    String rawText,
  ) {
    DebugTrace.confirmationCreated(
      id: id,
      confidence: result.overallConfidence,
      courier: result.courier.value,
      pickupCode: result.pickupCode.value,
      location: result.location.value,
      status: result.status.value,
    );

    return PendingConfirmation(
      id: id,
      courier: result.courier.value,
      pickupCode: result.pickupCode.value,
      trackingNumber: result.trackingNumber.value,
      location: result.location.value,
      status: result.status.value,
      confidence: result.overallConfidence,
      fieldConfidence: FieldConfidence(
        courier: result.courier.confidence,
        pickupCode: result.pickupCode.confidence,
        trackingNumber: result.trackingNumber.confidence,
        location: result.location.confidence,
        status: result.status.confidence,
      ),
      rawText: rawText,
      warnings: result.allWarnings,
      createdAt: DateTime.now(),
    );
  }

  static String _buildDescription(dynamic result) {
    final parts = <String>[];
    if (result.pickupCode.value.isNotEmpty) {
      parts.add('${result.pickupCode.value}');
    }
    if (result.location.value.isNotEmpty) {
      parts.add(result.location.value);
    }
    return parts.isNotEmpty ? parts.join(' · ') : 'OCR';
  }
}

class OcrParseResult {
  final List<Package> highConfidencePackages;
  final List<PendingConfirmation> lowConfidenceConfirmations;
  final String rawText;

  const OcrParseResult({
    this.highConfidencePackages = const [],
    this.lowConfidenceConfirmations = const [],
    this.rawText = '',
  });

  factory OcrParseResult.empty() => const OcrParseResult();

  bool get isEmpty =>
      highConfidencePackages.isEmpty && lowConfidenceConfirmations.isEmpty;

  int get totalCount =>
      highConfidencePackages.length + lowConfidenceConfirmations.length;
}