library;

import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import '../core/models/package.dart';
import '../core/models/package_status.dart';
import '../core/models/pending_confirmation.dart';
import '../core/parser/text_parser.dart' as core;
import '../core/parser/conflict_detector.dart';
import '../core/sanitizer/text_sanitizer.dart';
import '../core/utils/text_normalizer.dart';
import '../core/debug/debug_trace.dart';
import '../core/debug/metrics.dart';
import '../core/debug/performance_trace.dart';
import '../core/confidence/auto_confirm_engine.dart';
import '../platform/ocr/mlkit_ocr_adapter.dart';

class OcrPipeline {
  static const _uuid = Uuid();
  static final _ocr = MlKitOcrAdapter();

  /// 是否启用详细日志（生产环境关闭）
  static bool _verboseLogging = kDebugMode;

  /// 设置是否启用详细日志
  static void setVerboseLogging(bool enabled) {
    _verboseLogging = enabled;
  }

  static Future<OcrParseResult> run(String imagePath) async {
    final trace = PerformanceTrace(name: 'OcrPipeline');

    // OCR 阶段
    trace.startStage('OCR');
    final rawText = await _ocr.recognizeFromImage(imagePath);
    trace.endStage();

    final ocrText = rawText.rawText;
    GlobalPerformanceTrace.record('OCR', trace.getStageTime('OCR') ?? 0);

    Metrics.inc('ocr.attempt');

    if (ocrText.isEmpty) {
      Metrics.inc('abort.empty');
      DebugTrace.abort('rawText empty');
      return OcrParseResult.empty();
    }

    final result = await parseRawText(ocrText, trace: trace);

    // 打印性能报告
    if (_verboseLogging) {
      trace.printReport();
    }

    return result;
  }

  static Future<OcrParseResult> parseRawText(String rawText, {PerformanceTrace? trace}) async {
    trace ??= PerformanceTrace(name: 'OcrPipeline');

    DebugTrace.separator('TEXT SANITIZATION');

    if (_verboseLogging) {
      print('===============================================');
      print('  [LAYER 1] RAW TEXT');
      print('===============================================');
      print(rawText);
      print('  length: ${rawText.length}');
      print('');
    }

    // 清洗阶段
    trace.startStage('Sanitize');
    final sanitizedResult = TextSanitizer.cleanWithAnalysis(rawText);
    trace.endStage();

    if (_verboseLogging) {
      print('===============================================');
      print('  [LAYER 2] SANITIZED TEXT');
      print('===============================================');
      print(sanitizedResult.cleaned);
      print('  original length: ${rawText.length}');
      print('  cleaned length: ${sanitizedResult.cleaned.length}');
      print('  keptLines: ${sanitizedResult.keptLines}');
      print('  removedLines: ${sanitizedResult.removedLines}');
      if (sanitizedResult.noiseLines.isNotEmpty) {
        print('  noiseLines: ${sanitizedResult.noiseLines.map((a) => a.text).take(5).toList()}...');
      }
      print('');
    }

    final sanitizedText = sanitizedResult.cleaned;

    // 冲突检测阶段
    trace.startStage('ConflictDetection');
    final conflictResult = ConflictDetector.analyze(sanitizedText);
    trace.endStage();

    final resolvedStatus = conflictResult.resolvedStatus;

    if (_verboseLogging) {
      DebugTrace.separator('CONFLICT ANALYSIS');
      print('hasTransitSignals: ${conflictResult.hasTransitSignals}');
      print('hasArrivalSignals: ${conflictResult.hasArrivalSignals}');
      print('conflictLevel: ${conflictResult.level}');
      print('resolvedStatus: ${resolvedStatus.status.label}');
      print('hasTrueConflict: ${resolvedStatus.hasConflict}');
      if (resolvedStatus.detectedStatuses.isNotEmpty) {
        print('signals: ${resolvedStatus.detectedStatuses.map((s) => '${s.source}(${s.status.name})').toList()}');
      }
      if (conflictResult.detectedTransitKeywords.isNotEmpty) {
        print('transitKeywords: ${conflictResult.detectedTransitKeywords}');
      }
      if (conflictResult.detectedArrivalKeywords.isNotEmpty) {
        print('arrivalKeywords: ${conflictResult.detectedArrivalKeywords}');
      }
    }

    if (TextSanitizer.shouldAbortParse(sanitizedText)) {
      Metrics.inc('abort.dashboard');
      DebugTrace.abort('dashboard_like_screen');
      return OcrParseResult.empty();
    }

    // 解析阶段
    trace.startStage('Parse');
    if (_verboseLogging) {
      DebugTrace.separator('PARSING START');
      print('sanitizedText length: ${sanitizedText.length}');
    }

    final parseResults = core.TextParser.parseMulti(sanitizedText);
    trace.endStage();

    if (_verboseLogging) {
      DebugTrace.separator('PARSING COMPLETE');
      print('parseResults count: ${parseResults.length}');

      print('');
      print('===============================================');
      print('  [LAYER 3] PARSE RESULTS');
      print('===============================================');
    }

    final highConfidence = <Package>[];
    final lowConfidence = <PendingConfirmation>[];

    // 状态解析阶段
    trace.startStage('StatusResolve');

    for (var i = 0; i < parseResults.length; i++) {
      try {
        final result = parseResults[i];
        final confidence = result.overallConfidence;
        final id = _uuid.v4();

        if (_verboseLogging) {
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
          print('  | station:       "${result.station.value}" (conf: ${result.station.confidence})');
          final finalStatus = resolvedStatus.status;
          print('  | status:        ${finalStatus.name} (resolved from ${result.status.value})');
          print('  | overallConf:   ${confidence.toStringAsFixed(2)}');
          print('  | isValid:       ${result.isValid}');
          print('  +-----------------------------------------');
        }

        final normalized = TextNormalizer.normalize(rawText);
        final fingerprint = TextNormalizer.transitFingerprint(
          result.courier.value.toString().split('.').last, rawText,
          trackingNumber: result.trackingNumber.value,
        );

        if (_verboseLogging) {
          print('  | normalized:    "$normalized"');
          print('  | fingerprint:   "$fingerprint"');
          DebugTrace.normalizedText(rawText, normalized, fingerprint ?? '(null)');
        }

        final finalStatus = resolvedStatus.status;
        final isTransit = finalStatus == PackageStatus.transit ||
            finalStatus == PackageStatus.delivering;
        final isArrived = finalStatus == PackageStatus.arrived;
        final hasPickupCode = result.pickupCode.value.isNotEmpty;
        final hasLocation = result.location.value.isNotEmpty;

        // 置信度计算阶段
        trace.startStage('Confidence');

        if (isTransit && !hasPickupCode && confidence >= 0.5) {
          trace.endStage();
          DebugTrace.separator('TRANSIT + NO PICKUP CODE -> SILENT PACKAGE');
          highConfidence.add(_toPackage(result, id, rawText, resolvedStatus: finalStatus));
        } else if (isArrived && (!hasPickupCode || !hasLocation)) {
          trace.endStage();
          DebugTrace.separator('ARRIVED + INCOMPLETE INFO -> PENDING CONFIRMATION');
          lowConfidence.add(_toConfirmation(result, id, rawText));
        } else if (conflictResult.isHighConflict) {
          trace.endStage();
          DebugTrace.separator('HIGH CONFLICT -> PENDING CONFIRMATION');
          lowConfidence.add(_toConfirmation(result, id, rawText));
        } else if (confidence >= 0.7) {
          // 使用 AutoConfirmEngine 评估
          final package = _toPackage(result, id, rawText, resolvedStatus: finalStatus);
          final engine = AutoConfirmEngine();
          final autoConfirmResult = engine.evaluate(package);
          trace.endStage();

          if (_verboseLogging) {
            DebugTrace.separator('AUTO CONFIRM EVALUATION');
            print('  trustScore: ${autoConfirmResult.trustScore.toStringAsFixed(2)}');
            print('  shouldAutoConfirm: ${autoConfirmResult.shouldAutoConfirm}');
            print('  reasons: ${autoConfirmResult.reasons}');
          }

          if (autoConfirmResult.shouldAutoConfirm) {
            DebugTrace.separator('AUTO CONFIRMED -> PACKAGE');
            highConfidence.add(package);
          } else {
            DebugTrace.separator('AUTO CONFIRM DENIED -> PENDING CONFIRMATION');
            lowConfidence.add(_toConfirmation(result, id, rawText));
          }
        } else {
          trace.endStage();
          DebugTrace.separator('LOW CONFIDENCE -> PENDING CONFIRMATION');
          lowConfidence.add(_toConfirmation(result, id, rawText));
        }
      } catch (e, stackTrace) {
        DebugTrace.error('Error processing parseResult #$i', error: e, stackTrace: stackTrace);
      }
    }
    trace.endStage();

    if (highConfidence.isNotEmpty || lowConfidence.isNotEmpty) {
      Metrics.inc('parse.success');
    } else {
      Metrics.inc('parse.fail');
    }

    return OcrParseResult(
      highConfidencePackages: highConfidence,
      lowConfidenceConfirmations: lowConfidence,
      rawText: rawText,
    );
  }

  static Package _toPackage(dynamic result, String id, String rawText, {PackageStatus? resolvedStatus}) {
    final courierName = result.courier.value.toString().split('.').last;
    final fingerprint = TextNormalizer.transitFingerprint(
      courierName, rawText,
      trackingNumber: result.trackingNumber.value,
    );

    final cleanedLocation = result.location.value;
    final locationConfidence = Package.calculateLocationConfidence(cleanedLocation);
    final finalStatus = resolvedStatus ?? result.status.value;

    DebugTrace.packageCreated(Package(
      id: id,
      trackingNumber: result.trackingNumber.value,
      courier: result.courier.value,
      pickupCode: result.pickupCode.value,
      location: cleanedLocation,
      originalStation: result.station.value,
      urgency: UrgencyLevel.normal,
      status: finalStatus,
      addedAt: DateTime.now(),
      transitFingerprint: fingerprint,
      rawLocation: cleanedLocation,
      cleanedLocation: cleanedLocation,
      canonicalLocation: cleanedLocation,
      locationConfidence: locationConfidence,
    ));

    return Package(
      id: id,
      trackingNumber: result.trackingNumber.value.isNotEmpty
          ? result.trackingNumber.value
          : 'OCR-${DateTime.now().millisecondsSinceEpoch}',
      courier: result.courier.value,
      pickupCode: result.pickupCode.value,
      location: cleanedLocation,
      originalStation: result.station.value,
      description: _buildDescription(result),
      urgency: UrgencyLevel.normal,
      status: result.status.value,
      addedAt: DateTime.now(),
      transitFingerprint: fingerprint,
      rawLocation: cleanedLocation,
      cleanedLocation: cleanedLocation,
      canonicalLocation: cleanedLocation,
      locationConfidence: locationConfidence,
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
      originalStation: result.station.value,
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
      rawLocation: result.location.value,
      cleanedLocation: result.location.value,
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