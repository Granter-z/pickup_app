import 'package:uuid/uuid.dart';
import '../core/debug/debug_trace.dart';
import '../core/debug/metrics.dart';
import '../core/models/package.dart';
import '../core/parser/conflict_detector.dart';
import '../core/parser/parse_result.dart';
import '../core/parser/text_parser.dart' as core;
import '../core/sanitizer/text_sanitizer.dart';
import '../core/utils/text_normalizer.dart';
import '../models/package_model.dart';
import '../core/models/pending_confirmation.dart';
import 'ocr_service.dart';
import 'text_parser.dart';

class PackageOcrService {
  static const _uuid = Uuid();

  static Future<List<ParsedPackage>> processImage(String imagePath) async {
    final rawText = await OcrService.recognizeFromImage(imagePath);

    if (rawText.isEmpty) return [];

    return TextParser.parseMulti(rawText);
  }

  static Future<List<Package>> parseToPackages(
    String imagePath, {
    UrgencyLevel defaultUrgency = UrgencyLevel.normal,
  }) async {
    final parsedList = await processImage(imagePath);

    return parsedList.map((parsed) => Package(
      id: _uuid.v4(),
      trackingNumber: parsed.trackingNumber.isNotEmpty
          ? parsed.trackingNumber
          : 'OCR-${DateTime.now().millisecondsSinceEpoch}',
      courier: parsed.courier,
      pickupCode: parsed.pickupCode,
      location: parsed.location,
      description: _buildDescription(parsed),
      urgency: defaultUrgency,
      status: parsed.status,
      addedAt: DateTime.now(),
    )).toList();
  }

  /// 解析为待确认包裹（带置信度）
  static Future<OcrParseResult> parseToConfirmations(String imagePath) async {
    final rawText = await OcrService.recognizeFromImage(imagePath);

    Metrics.inc('ocr.attempt');

    if (rawText.isEmpty) {
      Metrics.inc('abort.empty');
      DebugTrace.abort('rawText empty');
      return OcrParseResult.empty();
    }

    // 文本清理
    DebugTrace.separator('TEXT SANITIZATION');
    final sanitizedResult = TextSanitizer.cleanWithAnalysis(rawText);
    print('original length: ${rawText.length}');
    print('cleaned length: ${sanitizedResult.cleaned.length}');
    print('keptLines: ${sanitizedResult.keptLines}');
    print('removedLines: ${sanitizedResult.removedLines}');
    if (sanitizedResult.noiseLines.isNotEmpty) {
      print('noiseLines: ${sanitizedResult.noiseLines.map((a) => a.text).take(3).toList()}...');
    }
    
    // 使用清理后的文本
    final sanitizedText = sanitizedResult.cleaned;

    // 冲突检测（基于清理后的文本）
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

    // ── 轻量熔断：Dashboard / 首页截图 ─────────────────────
    if (TextSanitizer.shouldAbortParse(sanitizedText)) {
      Metrics.inc('abort.dashboard');
      DebugTrace.abort('dashboard_like_screen');
      return OcrParseResult.empty();
    }

    // 使用核心 Parser 解析（基于清理后的文本）
    DebugTrace.separator('PARSING START');
    print('sanitizedText length: ${sanitizedText.length}');

    final coreParser = _getCoreParser();
    final parseResults = coreParser.parseMulti(sanitizedText);
    
    DebugTrace.separator('PARSING COMPLETE');
    print('parseResults count: ${parseResults.length}');

    final highConfidence = <Package>[];
    final lowConfidence = <PendingConfirmation>[];

    for (var i = 0; i < parseResults.length; i++) {
      try {
        final result = parseResults[i];
        final confidence = result.overallConfidence;
        final id = _uuid.v4();

        DebugTrace.parseResult(result, index: i);
        
        // 打印规范化文本和指纹
        final courierName = result.courier.value.toString().split('.').last;
        final normalized = TextNormalizer.normalize(rawText);
        final fingerprint = TextNormalizer.transitFingerprint(
          courierName, rawText,
          trackingNumber: result.trackingNumber.value,
        );
        DebugTrace.normalizedText(rawText, normalized, fingerprint ?? '(null)');

        // 判断是否应该自动入库
        // 优化策略：
        // 1. transit && 无取件码 → 静默创建（用户不需要操作）
        // 2. arrived && (无取件码 || 无地点) → 触发确认
        // 3. 高冲突 → 触发确认
        // 4. 低置信度 → 触发确认
        
        final isTransit = result.status.value == PackageStatus.transit || 
            result.status.value == PackageStatus.delivering;
        final isArrived = result.status.value == PackageStatus.arrived;
        final hasPickupCode = result.pickupCode.value.isNotEmpty;
        final hasLocation = result.location.value.isNotEmpty;
        
        // transit 且无取件码 → 静默创建
        if (isTransit && !hasPickupCode && confidence >= 0.5) {
          DebugTrace.separator('TRANSIT + NO PICKUP CODE → SILENT PACKAGE');
          highConfidence.add(_parseResultToPackage(result, id, rawText));
        }
        // arrived 且信息不完整 → 触发确认
        else if (isArrived && (!hasPickupCode || !hasLocation)) {
          DebugTrace.separator('ARRIVED + INCOMPLETE INFO → PENDING CONFIRMATION');
          lowConfidence.add(_parseResultToConfirmation(result, id, rawText));
        }
        // 高冲突 → 触发确认
        else if (conflictResult.isHighConflict) {
          DebugTrace.separator('HIGH CONFLICT → PENDING CONFIRMATION');
          lowConfidence.add(_parseResultToConfirmation(result, id, rawText));
        }
        // 高置信度且无冲突 → 自动入库
        else if (confidence >= 0.7) {
          DebugTrace.separator('HIGH CONFIDENCE → PACKAGE');
          highConfidence.add(_parseResultToPackage(result, id, rawText));
        }
        // 其他情况 → 触发确认
        else {
          DebugTrace.separator('LOW CONFIDENCE → PENDING CONFIRMATION');
          lowConfidence.add(_parseResultToConfirmation(result, id, rawText));
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
      rawText: rawText,
    );
  }

  static Package _parseResultToPackage(dynamic result, String id, String rawText) {
    // 生成 transit fingerprint
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
      description: _buildDescriptionFromResult(result),
      urgency: UrgencyLevel.normal,
      status: result.status.value,
      addedAt: DateTime.now(),
      transitFingerprint: fingerprint,
    );
  }

  static PendingConfirmation _parseResultToConfirmation(
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

  static String _buildDescriptionFromResult(dynamic result) {
    final parts = <String>[];
    if (result.pickupCode.value.isNotEmpty) {
      parts.add('取件码 ${result.pickupCode.value}');
    }
    if (result.location.value.isNotEmpty) {
      parts.add(result.location.value);
    }
    return parts.isNotEmpty ? parts.join(' · ') : 'OCR识别';
  }

  static dynamic _getCoreParser() {
    // 导入核心 Parser
    return _CoreParserAdapter();
  }

  static String _buildDescription(ParsedPackage parsed) {
    final parts = <String>[];

    if (parsed.phoneLast4.isNotEmpty) {
      parts.add('手机尾号 ${parsed.phoneLast4}');
    }

    if (parsed.pickupCode.isNotEmpty) {
      parts.add('取件码 ${parsed.pickupCode}');
    }

    return parts.isNotEmpty ? parts.join(' | ') : 'OCR识别导入';
  }
}

/// OCR 解析结果
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

/// 核心 Parser 适配器
class _CoreParserAdapter {
  List<ParseResult> parseMulti(String text) {
    // 使用核心层 TextParser
    return core.TextParser.parseMulti(text);
  }
}
