#!/usr/bin/env dart
// bin/run_ocr_baseline.dart
// 对 real_world 图像运行 OCR 并保存结果

import 'dart:io';
import 'dart:convert';

void main() async {
  final annotationsFile = File('test/fixtures/real_world/annotations.json');
  final content = await annotationsFile.readAsString();
  final Map<String, dynamic> annotations = json.decode(content);
  
  print('=== OCR 基线测试 ===\n');
  print('需要对以下图像运行 ML Kit OCR：\n');
  
  annotations.forEach((imagePath, packages) {
    final fullPath = 'test/fixtures/real_world/$imagePath';
    print('图像: $imagePath');
    print('  包裹数: ${packages.length}');
    
    for (var i = 0; i < packages.length; i++) {
      final pkg = packages[i];
      final expected = pkg['expected'];
      print('  包裹 ${i + 1}:');
      print('    期望快递商: ${expected['courier']}');
      print('    期望取件码: ${expected['pickupCode'] ?? '无'}');
      print('    期望状态: ${expected['status']}');
    }
    print('');
  });
  
  print('=== 下一步 ===');
  print('1. 在 Android 设备上运行应用');
  print('2. 对每张图像进行 OCR 识别');
  print('3. 保存 OCR 原始输出到 test/fixtures/real_world/ocr_output.json');
  print('4. 运行对比分析');
  
  print('\n=== 建议修复优先级 ===');
  print('🔴 高优先级：');
  print('   - 修复 TextSanitizer 过滤转运中心地址');
  print('   - 改进 PickupCodeExtractor 支持短格式 (793167, 418226)');
  print('');
  print('🟡 中优先级：');
  print('   - 测试多包裹分割逻辑 (7 张图)');
  print('   - 改进 StatusExtractor 区分 in_transit vs arrived');
  print('');
  print('🟢 低优先级：');
  print('   - 支持更多运单号格式');
  print('   - 优化 UI 显示');
}
