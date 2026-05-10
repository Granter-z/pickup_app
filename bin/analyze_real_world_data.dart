#!/usr/bin/env dart

// bin/analyze_real_world_data.dart
// 快速分析真实数据集的统计信息

import 'dart:io';
import 'dart:convert';

void main() {
  print('📊 真实数据集分析');
  print('=' * 50);

  final annotationsFile = File('test/fixtures/real_world/annotations.json');
  if (!annotationsFile.existsSync()) {
    print('❌ annotations.json 未找到');
    exit(1);
  }

  final content = annotationsFile.readAsStringSync();
  final annotations = jsonDecode(content) as Map<String, dynamic>;

  // 统计数据
  final bySource = <String, int>{};
  final byStatus = <String, int>{};
  final byHasPickupCode = <bool, int>{};
  final couriers = <String, int>{};
  final addressSet = <String>{};
  int multiPackageImages = 0;
  int totalPackages = 0;

  annotations.forEach((imagePath, expectedList) {
    final source = imagePath.split('/').first;
    bySource[source] = (bySource[source] ?? 0) + (expectedList as List).length;

    // 检查多包裹
    if ((expectedList as List).length > 1) {
      multiPackageImages++;
    }

    for (final item in expectedList as List) {
      final expected = item['expected'] as Map;
      totalPackages++;

      final status = expected['status'] as String;
      byStatus[status] = (byStatus[status] ?? 0) + 1;

      final courier = expected['courier'] as String;
      couriers[courier] = (couriers[courier] ?? 0) + 1;

      final hasPickupCode = expected['pickupCode'] != null;
      byHasPickupCode[hasPickupCode] = (byHasPickupCode[hasPickupCode] ?? 0) + 1;

      addressSet.add(expected['address'] as String? ?? 'null');
    }
  });

  print('\n📈 总体统计:');
  print('  图像总数: ${annotations.length}');
  print('  包裹总数: $totalPackages');
  print('  多包裹图像: $multiPackageImages');
  print('  平均每图包裹数: ${(totalPackages / annotations.length).toStringAsFixed(2)}');

  print('\n🏢 来源分布:');
  bySource.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value))
    ..forEach((e) {
      print('  ${e.key.padRight(12)}: ${e.value.toString().padLeft(3)} 个');
    });

  print('\n📦 快递商覆盖:');
  couriers.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value))
    ..forEach((e) {
      print('  ${e.key.padRight(12)}: ${e.value.toString().padLeft(3)} 次');
    });

  print('\n📍 状态分布:');
  byStatus.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value))
    ..forEach((e) {
      print('  ${e.key.padRight(12)}: ${e.value.toString().padLeft(3)} 个');
    });

  print('\n🔑 取件码分布:');
  print('  有取件码: ${byHasPickupCode[true] ?? 0}');
  print('  无取件码: ${byHasPickupCode[false] ?? 0}');

  print('\n🗺️ 地址多样性:');
  print('  不同地址数: ${addressSet.length}');
  addressSet.toList().forEach((addr) {
    print('    - $addr');
  });

  // 预期的错误类型统计
  print('\n⚠️ 潜在错误场景:');

  int transitWithPickupCode = 0;
  int arrivedWithoutPickupCode = 0;
  int transitWithoutPickupCode = 0;

  annotations.forEach((imagePath, expectedList) {
    for (final item in expectedList as List) {
      final expected = item['expected'] as Map;
      final status = expected['status'] as String;
      final hasPickupCode = expected['pickupCode'] != null;

      if (status == 'in_transit' && hasPickupCode) {
        transitWithPickupCode++;
      } else if (status == 'arrived' && !hasPickupCode) {
        arrivedWithoutPickupCode++;
      } else if (status == 'in_transit' && !hasPickupCode) {
        transitWithoutPickupCode++;
      }
    }
  });

  print('  转运中但有取件码: $transitWithPickupCode (数据质量问题？)');
  print('  已到达但无取件码: $arrivedWithoutPickupCode (数据质量问题？)');
  print('  转运中且无取件码: $transitWithoutPickupCode (正常)');

  print('\n✅ 数据集质量评分: ');

  bool hasVariety = couriers.length >= 5;
  bool hasMultiPackage = multiPackageImages > 0;
  bool hasStatusVariety = byStatus.length >= 2;

  int qualityScore = 0;
  if (hasVariety) {
    qualityScore += 30;
    print('  ✅ 快递商覆盖充分 (+30)');
  }
  if (hasMultiPackage) {
    qualityScore += 30;
    print('  ✅ 包含多包裹粘连 (+30)');
  }
  if (hasStatusVariety) {
    qualityScore += 20;
    print('  ✅ 状态种类多样 (+20)');
  }
  if (byHasPickupCode[false] ?? 0 > 0) {
    qualityScore += 20;
    print('  ✅ 包含缺失字段场景 (+20)');
  }

  print('\n📊 总体质量: $qualityScore/100');

  if (qualityScore >= 80) {
    print('  🟢 高质量数据集');
  } else if (qualityScore >= 60) {
    print('  🟡 中等质量数据集');
  } else {
    print('  🔴 低质量数据集');
  }
}
