import 'package:uuid/uuid.dart';
import '../core/parser/parse_result.dart';
import '../core/parser/text_parser.dart' as core;
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

    if (rawText.isEmpty) {
      return OcrParseResult.empty();
    }

    // 使用核心 Parser 解析
    final coreParser = _getCoreParser();
    final parseResults = coreParser.parseMulti(rawText);

    final highConfidence = <Package>[];
    final lowConfidence = <PendingConfirmation>[];

    for (final result in parseResults) {
      final confidence = result.overallConfidence;
      final id = _uuid.v4();

      if (confidence >= 0.7) {
        // 高置信度，直接转为 Package
        highConfidence.add(_parseResultToPackage(result, id));
      } else {
        // 低置信度，转为待确认
        lowConfidence.add(_parseResultToConfirmation(result, id, rawText));
      }
    }

    return OcrParseResult(
      highConfidencePackages: highConfidence,
      lowConfidenceConfirmations: lowConfidence,
      rawText: rawText,
    );
  }

  static Package _parseResultToPackage(dynamic result, String id) {
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
    );
  }

  static PendingConfirmation _parseResultToConfirmation(
    dynamic result,
    String id,
    String rawText,
  ) {
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
