import 'package:uuid/uuid.dart';
import '../models/package_model.dart';
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
