#!/usr/bin/env dart
// bin/analyze_annotations.dart
// 分析 annotations.json 并统计预期结果

import 'dart:io';
import 'dart:convert';

void main() async {
  final file = File('test/fixtures/real_world/annotations.json');
  final content = await file.readAsString();
  final Map<String, dynamic> annotations = json.decode(content);
  
  print('=== 数据集分析 ===\n');
  
  int totalImages = annotations.length;
  num totalPackages = 0;
  num multiPackageImages = 0;
  
  Map<String, num> courierCount = {};
  Map<String, num> statusCount = {};
  Map<String, num> sourceCount = {};
  
  List<String> transitAddresses = [];
  List<String> pickupCodeFormats = [];
  
  annotations.forEach((imagePath, packages) {
    totalPackages += packages.length;
    
    if (packages.length > 1) {
      multiPackageImages++;
    }
    
    // 统计来源
    final source = imagePath.split('/')[0];
    sourceCount[source] = (sourceCount[source] ?? 0) + packages.length;
    
    packages.forEach((pkg) {
      final expected = pkg['expected'];
      
      // 统计快递商
      final courier = expected['courier'];
      courierCount[courier] = (courierCount[courier] ?? 0) + 1;
      
      // 统计状态
      final status = expected['status'];
      statusCount[status] = (statusCount[status] ?? 0) + 1;
      
      // 收集转运中心地址
      if (status == 'in_transit') {
        transitAddresses.add(expected['address']);
      }
      
      // 收集取件码格式
      if (expected['pickupCode'] != null) {
        pickupCodeFormats.add(expected['pickupCode']);
      }
    });
  });
  
  print('总体统计:');
  print('- 图像总数: $totalImages');
  print('- 包裹总数: $totalPackages');
  print('- 多包裹图像: $multiPackageImages 张');
  print('- 平均每图包裹数: ${(totalPackages / totalImages).toStringAsFixed(2)}');
  
  print('\n--- 来源分布 ---');
  sourceCount.forEach((source, count) {
    final percentage = (count / totalPackages * 100).toStringAsFixed(0);
    print('$source: $count 个 ($percentage%)');
  });
  
  print('\n--- 快递商分布 ---');
  courierCount.forEach((courier, count) {
    final percentage = (count / totalPackages * 100).toStringAsFixed(0);
    print('$courier: $count 次 ($percentage%)');
  });
  
  print('\n--- 状态分布 ---');
  statusCount.forEach((status, count) {
    final percentage = (count / totalPackages * 100).toStringAsFixed(0);
    print('$status: $count 个 ($percentage%)');
  });
  
  print('\n--- 转运中心地址（需要过滤）---');
  transitAddresses.forEach((addr) {
    print('- $addr');
  });
  
  print('\n--- 取件码格式 ---');
  pickupCodeFormats.forEach((code) {
    print('- $code');
  });
  
  print('\n=== 测试建议 ===');
  print('1. 修复 TextSanitizer 过滤转运中心地址');
  print('2. 改进 PickupCodeExtractor 支持短格式');
  print('3. 测试多包裹分割逻辑');
  print('4. 运行 OCR 基线测试获取实际输出');
}
