// test/raw_event_test.dart
// RawEvent 单元测试示例

import 'package:flutter_test/flutter_test.dart';
import 'package:pickup_app/core/models/raw_event.dart';
import 'package:pickup_app/core/raw_event/raw_event_builder.dart';
import 'package:pickup_app/core/confidence/confidence_calculator.dart';

void main() {
  group('RawEvent', () {
    late RawEventBuilder builder;

    setUp(() {
      builder = RawEventBuilder();
    });

    group('自动生成 Package (置信度 >= 0.85)', () {
      test('高置信场景：清晰的顺丰单号', () {
        final event = builder.build(
          rawText: '顺丰 SF123456789012 15-3-6007 已到达',
          extractionResults: {
            'courier': [('顺丰', 0.98)],
            'trackingNumber': [('SF123456789012', 0.99)],
            'pickupCode': [('15-3-6007', 0.96)],
            'status': [('arrived', 0.95)],
            'location': [('自提柜', 0.70)],
          },
          source: 'sms',
        );

        expect(event.shouldAutoResolve, true);
        expect(event.overallConfidence, greaterThanOrEqualTo(0.85));
        expect(event.topCourier, '顺丰');
        expect(event.topPickupCode, '15-3-6007');
      });

      test('极兔单号前缀匹配', () {
        final event = builder.build(
          rawText: '极兔 JT1234567890123 99-8-7777',
          extractionResults: {
            'courier': [('极兔', 0.95)],
            'trackingNumber': [('JT1234567890123', 0.98)],
            'pickupCode': [('99-8-7777', 0.94)],
            'status': [('arrived', 0.92)],
            'location': [('菜鸟驿站', 0.75)],
          },
          source: 'image',
        );

        expect(event.shouldAutoResolve, true);
        expect(event.topCourier, '极兔');
      });
    });

    group('用户确认流程 (0.60 <= 置信度 < 0.85)', () {
      test('中等置信：状态有歧义', () {
        final event = builder.build(
          rawText: '顺丰 SF123456 15-3-6007 派送中',
          extractionResults: {
            'courier': [('顺丰', 0.95)],
            'trackingNumber': [('SF123456', 0.98)],
            'pickupCode': [('15-3-6007', 0.96)],
            'status': [('delivering', 0.60), ('arrived', 0.30)],
            'location': [('未知', 0.40)],
          },
          source: 'sms',
          conflictSignals: ['delivering_signal', 'old_message'],
        );

        expect(event.needsUserConfirmation, true);
        expect(event.overallConfidence, inInclusiveRange(0.60, 0.85));
      });

      test('取件码不清晰，需要用户选择', () {
        final event = builder.build(
          rawText: '顺丰 SF1234 ???-?-???? 已到达',
          extractionResults: {
            'courier': [('顺丰', 0.92)],
            'trackingNumber': [('SF1234', 0.85)],
            'pickupCode': [
              ('15-3-6007', 0.65),
              ('15-3-0007', 0.55),
              ('15-2-6007', 0.50),
            ],
            'status': [('arrived', 0.88)],
            'location': [('自提柜', 0.72)],
          },
          source: 'image',
        );

        expect(event.needsUserConfirmation, true);
        expect(event.possiblePickupCodes.length, 3);
        // 用户可以从多个选项中选择
      });
    });

    group('拒绝场景 (置信度 < 0.60)', () {
      test('模糊图像，无法识别', () {
        final event = builder.build(
          rawText: '???? ?????????? ???-?-???? ???',
          extractionResults: {
            'courier': [('未知', 0.15)],
            'trackingNumber': [('未知', 0.10)],
            'pickupCode': [('未知', 0.20)],
            'status': [('未知', 0.15)],
            'location': [('未知', 0.10)],
          },
          source: 'image',
        );

        expect(event.shouldReject, true);
        expect(event.overallConfidence, lessThan(0.60));
      });

      test('信息不足：没有取件码', () {
        final event = builder.build(
          rawText: '京东 123456789 已到达',
          extractionResults: {
            'courier': [('京东', 0.92)],
            'trackingNumber': [('123456789', 0.88)],
            'pickupCode': [], // 缺失
            'status': [('arrived', 0.90)],
            'location': [('自提柜', 0.70)],
          },
          source: 'sms',
        );

        expect(event.shouldReject, true);
        // 取件码缺失导致整体置信度下降
      });
    });

    group('冲突检测', () {
      test('同时出现"已取件"和"待取件"信号', () {
        final event = builder.build(
          rawText: '顺丰已取件。哦等等，快递还在柜子里。',
          extractionResults: {
            'courier': [('顺丰', 0.95)],
            'trackingNumber': [('SF123456', 0.98)],
            'pickupCode': [('15-3-6007', 0.96)],
            'status': [('picked_up', 0.50), ('arrived', 0.50)],
            'location': [('自提柜', 0.75)],
          },
          source: 'sms',
          conflictSignals: ['picked_up', 'still_in_cabinet'],
        );

        expect(event.hasConflict, true);
        expect(event.conflictSignals.contains('picked_up'), true);
        // 冲突信号会降低状态字段的置信度
      });
    });

    group('多包裹场景', () {
      test('两个取件码候选', () {
        final event = builder.build(
          rawText: '顺丰 SF111 15-1-1111 SF222 15-2-2222',
          extractionResults: {
            'courier': [('顺丰', 0.95)],
            'trackingNumber': [('SF111', 0.90), ('SF222', 0.88)],
            'pickupCode': [('15-1-1111', 0.92), ('15-2-2222', 0.91)],
            'status': [('arrived', 0.94)],
            'location': [('自提柜', 0.75)],
          },
          source: 'sms',
        );

        // 应该生成两个独立的 RawEvent/Package，而不是合并
        expect(event.possiblePickupCodes.length, 2);
      });
    });

    group('元数据追踪', () {
      test('RawEvent 记录完整元数据', () {
        final event = builder.build(
          rawText: '顺丰 SF123456',
          extractionResults: {
            'courier': [('顺丰', 0.95)],
            'trackingNumber': [('SF123456', 0.98)],
            'pickupCode': [('15-3-6007', 0.96)],
            'status': [('arrived', 0.95)],
            'location': [('自提柜', 0.70)],
          },
          source: 'image',
          metadata: {
            'ocr_engine': 'ml_kit',
            'image_quality': 'good',
            'device_model': 'Android 13',
          },
        );

        expect(event.metadata.containsKey('ocr_engine'), true);
        expect(event.metadata['image_quality'], 'good');
      });
    });

    group('决策方法', () {
      test('getDecisionReason 返回用户友好的文本', () {
        final highConfidence = builder.build(
          rawText: '顺丰 SF123456789012 15-3-6007',
          extractionResults: {
            'courier': [('顺丰', 0.98)],
            'trackingNumber': [('SF123456789012', 0.99)],
            'pickupCode': [('15-3-6007', 0.96)],
            'status': [('arrived', 0.95)],
            'location': [('自提柜', 0.70)],
          },
          source: 'sms',
        );

        expect(
          highConfidence.toTopCandidate().decision.toString(),
          contains('autoResolve'),
        );
      });
    });

    group('复制和修改', () {
      test('copyWith 生成新的 RawEvent', () {
        final original = builder.build(
          rawText: '顺丰 SF123456',
          extractionResults: {
            'courier': [('顺丰', 0.95)],
            'trackingNumber': [('SF123456', 0.98)],
            'pickupCode': [('15-3-6007', 0.96)],
            'status': [('arrived', 0.95)],
            'location': [('自提柜', 0.70)],
          },
          source: 'sms',
        );

        final modified = original.copyWith(
          rawText: '修正后的文本',
          overallConfidence: 0.99,
        );

        expect(modified.rawText, '修正后的文本');
        expect(modified.overallConfidence, 0.99);
        expect(modified.id, original.id); // ID 保持不变
      });
    });
  });
}
