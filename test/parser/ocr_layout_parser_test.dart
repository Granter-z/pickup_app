import 'package:flutter_test/flutter_test.dart';
import 'package:pickup_app/core/models/package.dart';
import 'package:pickup_app/core/models/package_status.dart';
import 'package:pickup_app/core/ocr/ocr_result.dart';
import 'package:pickup_app/core/parser/extractors.dart';
import 'package:pickup_app/core/parser/location_type.dart';
import 'package:pickup_app/core/parser/ocr_layout_parser.dart';
import 'package:pickup_app/core/parser/parse_result.dart';

void main() {
  test('layout parser prefers the pickup card title above the pickup code', () {
    final lines = <OcrTextLine>[
      const OcrTextLine(
        text: '\u4e2d\u901a\u5feb\u9012 76929138701037',
        box: OcrTextBox(left: 20, top: 10, right: 300, bottom: 40),
      ),
      const OcrTextLine(
        text: '\u5f85\u53d6\u4ef6 \u4eca\u5929 12:02',
        box: OcrTextBox(left: 20, top: 55, right: 220, bottom: 85),
      ),
      const OcrTextLine(
        text: '\u90b1\u53f0\u4fe1\u90fd\u533a\u7eff\u57ce\u8bda\u56ed\u5317\u95e8\u5e97',
        box: OcrTextBox(left: 40, top: 110, right: 310, bottom: 145),
      ),
      const OcrTextLine(
        text: '\u8425\u4e1a\u65f6\u95f4\uff1a\u5468\u4e00\u81f3\u5468\u65e5 09:00~21:30',
        box: OcrTextBox(left: 40, top: 150, right: 340, bottom: 180),
      ),
      const OcrTextLine(
        text: '\u7eff\u57ce\u8bda\u56ed\u5317\u95e8\u5730\u5e93\u53e3\u5357\u8fb9\uff0826\u53f7\u697c\u5e95\u5546\uff09',
        box: OcrTextBox(left: 40, top: 190, right: 360, bottom: 230),
      ),
      const OcrTextLine(
        text: '\u53d6\u4ef6\u7801\uff1a15-3-6007',
        box: OcrTextBox(left: 40, top: 260, right: 300, bottom: 305),
      ),
      const OcrTextLine(
        text: '\u6536 \u592a\u884c\u8def\u7eff\u57ce\u8bda\u56ed24\u5e623\u5355\u5143702',
        box: OcrTextBox(left: 20, top: 510, right: 360, bottom: 545),
      ),
    ];

    final base = ParseResult(
      courier: const ExtractionResult(value: CourierType.other, confidence: 0.0),
      pickupCode: const ExtractionResult(value: '', confidence: 0.0),
      trackingNumber: const ExtractionResult(value: '', confidence: 0.0),
      phoneTail: const ExtractionResult(value: '', confidence: 0.0),
      location: const ExtractionResult(value: '', confidence: 0.0),
      locationType: LocationType.unknown,
      station: const ExtractionResult(value: '', confidence: 0.0),
      status: const ExtractionResult(value: PackageStatus.arrived, confidence: 0.6),
      overallConfidence: 0.2,
    );

    final enhanced = OcrLayoutParser.enhance(base, lines);

    expect(enhanced.pickupCode.value, '15-3-6007');
    expect(enhanced.trackingNumber.value, '76929138701037');
    expect(enhanced.location.value, contains('\u90b1\u53f0\u4fe1\u90fd\u533a\u7eff\u57ce\u8bda\u56ed\u5317\u95e8\u5e97'));
    expect(enhanced.location.value, isNot(contains('\u592a\u884c\u8def\u7eff\u57ce\u8bda\u56ed24\u5e623\u5355\u5143702')));
    expect(enhanced.status.value, PackageStatus.arrived);
    expect(enhanced.overallConfidence, greaterThan(base.overallConfidence));
  });
}
