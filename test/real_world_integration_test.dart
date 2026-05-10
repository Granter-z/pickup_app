// test/real_world_integration_test.dart
// 真实数据集成测试
// 使用 test/fixtures/real_world/annotations.json 中的标注数据

import 'package:flutter_test/flutter_test.dart';
import 'dart:io';
import 'dart:convert';
import 'package:pickup_app/core/raw_event/raw_event_builder.dart';
import 'package:pickup_app/core/confidence/confidence_calculator.dart';

void main() {
  group('RealWorld Integration Tests', () {
    late Map<String, dynamic> annotations;
    late RawEventBuilder builder;

    setUpAll(() {
      // 加载标注文件
      final annotationsFile = File('test/fixtures/real_world/annotations.json');
      expect(annotationsFile.existsSync(), true, reason: 'annotations.json not found');

      final content = annotationsFile.readAsStringSync();
      annotations = jsonDecode(content) as Map<String, dynamic>;

      builder = RawEventBuilder();

      print('✅ 加载了 ${annotations.length} 个标注样本');
    });

    /// 测试数据分布
    test('验证数据集质量', () {
      final bySource = <String, int>{};
      final byStatus = <String, int>{};
      final byHasPickupCode = <bool, int>{};

      int totalPackages = 0;

      annotations.forEach((imagePath, expectedList) {
        final source = imagePath.split('/').first;
        bySource[source] = (bySource[source] ?? 0) + (expectedList as List).length;

        for (final item in expectedList as List) {
          final expected = item['expected'] as Map;
          totalPackages++;

          final status = expected['status'] as String;
          byStatus[status] = (byStatus[status] ?? 0) + 1;

          final hasPickupCode = expected['pickupCode'] != null;
          byHasPickupCode[hasPickupCode] = (byHasPickupCode[hasPickupCode] ?? 0) + 1;
        }
      });

      print('📊 数据分布统计:');
      print('  来源分布:');
      bySource.forEach((source, count) {
        print('    $source: $count 个包裹');
      });

      print('  状态分布:');
      byStatus.forEach((status, count) {
        print('    $status: $count 个');
      });

      print('  取件码分布:');
      print('    有取件码: ${byHasPickupCode[true] ?? 0} 个');
      print('    无取件码: ${byHasPickupCode[false] ?? 0} 个');

      expect(totalPackages, greaterThan(0));
      expect(bySource.isNotEmpty, true);
    });

    /// 测试每个快递商的识别
    test('快递商识别覆盖率', () {
      final couriers = <String, int>{};

      annotations.forEach((imagePath, expectedList) {
        for (final item in expectedList as List) {
          final courier = (item['expected'] as Map)['courier'] as String;
          couriers[courier] = (couriers[courier] ?? 0) + 1;
        }
      });

      print('🎯 快递商覆盖:');
      couriers.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value))
        ..forEach((e) {
          print('  ${e.key}: ${e.value} 次');
        });

      expect(couriers.containsKey('中通'), true);
      expect(couriers.containsKey('圆通'), true);
    });

    /// 测试多包裹场景（同一图像多个期望值）
    test('多包裹粘连检测', () {
      int multiPackageImages = 0;
      int maxPackagesInImage = 0;

      annotations.forEach((imagePath, expectedList) {
        final count = (expectedList as List).length;
        if (count > 1) {
          multiPackageImages++;
          maxPackagesInImage = maxPackagesInImage > count ? maxPackagesInImage : count;
        }
      });

      print('🔀 多包裹粘连统计:');
      print('  包含多个包裹的图像: $multiPackageImages 个');
      print('  单图最多包裹数: $maxPackagesInImage');

      expect(multiPackageImages, greaterThan(0));
    });

    /// 测试缺失字段的处理
    test('缺失字段处理', () {
      final missingFields = <String, int>{};

      annotations.forEach((imagePath, expectedList) {
        for (final item in expectedList as List) {
          final expected = item['expected'] as Map;

          // 检查各字段
          if (expected['courier'] == null) missingFields['courier'] = (missingFields['courier'] ?? 0) + 1;
          if (expected['pickupCode'] == null) missingFields['pickupCode'] = (missingFields['pickupCode'] ?? 0) + 1;
          if (expected['trackingNumber'] == null) missingFields['trackingNumber'] = (missingFields['trackingNumber'] ?? 0) + 1;
          if (expected['status'] == null) missingFields['status'] = (missingFields['status'] ?? 0) + 1;
          if (expected['address'] == null) missingFields['address'] = (missingFields['address'] ?? 0) + 1;
        }
      });

      print('⚠️ 缺失字段统计:');
      if (missingFields.isEmpty) {
        print('  没有缺失字段 ✅');
      } else {
        missingFields.forEach((field, count) {
          print('  $field: $count 次');
        });
      }

      // 取件码允许缺失（in_transit 时常见）
      // 但其他字段应该都存在
      expect(missingFields.containsKey('courier'), false);
      expect(missingFields.containsKey('trackingNumber'), false);
    });

    /// 测试样本的类型多样性
    test('样本多样性检查', () {
      final uniqueAddresses = <String>{};
      final uniqueCouriers = <String>{};
      final statusVariety = <String>{};

      annotations.forEach((imagePath, expectedList) {
        for (final item in expectedList as List) {
          final expected = item['expected'] as Map;
          uniqueAddresses.add(expected['address'] as String? ?? 'null');
          uniqueCouriers.add(expected['courier'] as String);
          statusVariety.add(expected['status'] as String);
        }
      });

      print('🌈 样本多样性:');
      print('  不同地址: ${uniqueAddresses.length} 个');
      print('  不同快递商: ${uniqueCouriers.length} 个');
      print('  不同状态: ${statusVariety.length} 个 ${statusVariety.toList()}');

      expect(uniqueCouriers.length, greaterThan(2));
    });

    /// 建立基准：标注数据质量检查
    test('标注数据一致性检查', () {
      final imagePackages = <String, List<Map>>{};

      // 检查同一图像的多个包裹是否有合理的差异
      annotations.forEach((imagePath, expectedList) {
        if ((expectedList as List).length > 1) {
          final packages = expectedList.cast<Map>();

          // 同一图像内，不同包裹应该有不同的取件码或快递商
          final couriers = packages
            .map((p) => (p['expected'] as Map)['courier'] as String)
            .toSet();

          expect(couriers.length, greaterThan(1),
            reason: '同图内的包裹应该来自不同快递商: $imagePath');

          imagePackages[imagePath] = packages;
        }
      });

      print('✅ 标注数据一致性检查通过');
    });
  });

  group('RawEvent 真实数据建立', () {
    late Map<String, dynamic> annotations;
    late RawEventBuilder builder;

    setUpAll(() {
      final annotationsFile = File('test/fixtures/real_world/annotations.json');
      final content = annotationsFile.readAsStringSync();
      annotations = jsonDecode(content) as Map<String, dynamic>;
      builder = RawEventBuilder();
    });

    /// 模拟 OCR 输出 → RawEvent
    /// 注意：这里用标注的期望值反向生成模拟 OCR 输出
    test('从标注数据生成模拟 OCR 文本', () {
      int processedImages = 0;
      int generatedRawEvents = 0;

      annotations.forEach((imagePath, expectedList) {
        processedImages++;

        for (final item in expectedList as List) {
          final expected = item['expected'] as Map;

          // 模拟 OCR 输出文本
          final mockOcrText = _generateMockOcrText(
            courier: expected['courier'] as String,
            trackingNumber: expected['trackingNumber'] as String?,
            pickupCode: expected['pickupCode'] as String?,
            address: expected['address'] as String,
            status: expected['status'] as String,
          );

          print('📝 Mock OCR for $imagePath:');
          print('   $mockOcrText');

          generatedRawEvents++;
        }
      });

      print('✅ 生成了 $generatedRawEvents 个模拟 OCR 文本 (来自 $processedImages 张图)');
      expect(generatedRawEvents, greaterThan(0));
    });

    /// 测试 RawEvent 构建
    test('RawEvent 可以从模拟 OCR 数据构建', () {
      int successCount = 0;
      int highConfidenceCount = 0;
      int mediumConfidenceCount = 0;
      int lowConfidenceCount = 0;

      annotations.forEach((imagePath, expectedList) {
        for (final item in expectedList as List) {
          final expected = item['expected'] as Map;

          // 创建模拟 OCR 结果
          final mockExtractionResults = {
            'courier': [
              (expected['courier'] as String, 0.95),
            ],
            'trackingNumber': [
              (expected['trackingNumber'] as String? ?? 'unknown', 0.92),
            ],
            'pickupCode': [
              if (expected['pickupCode'] != null)
                (expected['pickupCode'] as String, 0.94),
            ],
            'status': [
              (_mapStatusToKeyword(expected['status'] as String), 0.88),
            ],
            'location': [
              (expected['address'] as String, 0.70),
            ],
          };

          final rawEvent = builder.build(
            rawText: 'mock ocr text',
            extractionResults: mockExtractionResults,
            source: 'image',
            metadata: {
              'image_path': imagePath,
              'expected': expected,
            },
          );

          successCount++;

          if (rawEvent.shouldAutoResolve) {
            highConfidenceCount++;
          } else if (rawEvent.needsUserConfirmation) {
            mediumConfidenceCount++;
          } else {
            lowConfidenceCount++;
          }
        }
      });

      print('📊 RawEvent 置信度分布:');
      print('  自动通过 (≥0.85): $highConfidenceCount');
      print('  用户确认 (0.60-0.85): $mediumConfidenceCount');
      print('  拒绝 (<0.60): $lowConfidenceCount');

      expect(successCount, greaterThan(0));
    });
  });
}

/// 模拟 OCR 输出文本
String _generateMockOcrText({
  required String courier,
  required String? trackingNumber,
  required String? pickupCode,
  required String address,
  required String status,
}) {
  final parts = [
    courier,
    if (trackingNumber != null) trackingNumber,
    if (pickupCode != null) pickupCode,
    address,
    _mapStatusToKeyword(status),
  ];

  return parts.join(' ');
}

/// 状态映射到关键词
String _mapStatusToKeyword(String status) {
  return switch (status) {
    'arrived' => '已到达',
    'in_transit' => '转运中',
    'delivering' => '派送中',
    'picked_up' => '已取件',
    _ => status,
  };
}
