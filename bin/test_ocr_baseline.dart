#!/usr/bin/env dart
// bin/test_ocr_baseline.dart
// 自动化 OCR 基线测试

import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;

void main() async {
  print('=== OCR 基线自动化测试 ===\n');
  
  // 读取标注数据
  final annotationsFile = File('test/fixtures/real_world/annotations.json');
  final content = await annotationsFile.readAsString();
  final Map<String, dynamic> annotations = json.decode(content);
  
  // 模拟器上的图片路径
  const emulatorImagePath = '/sdcard/Download/test_images';
  
  print('测试图片已推送到模拟器: $emulatorImagePath\n');
  print('请手动在应用中测试以下图片：\n');
  
  // 按来源分组
  Map<String, List<String>> bySource = {};
  annotations.forEach((imagePath, packages) {
    final source = imagePath.split('/')[0];
    bySource.putIfAbsent(source, () => []).add(imagePath);
  });
  
  bySource.forEach((source, images) {
    print('=== $source (${images.length} 张图) ===');
    images.forEach((imagePath) {
      final filename = imagePath.split('/').last;
      final packages = annotations[imagePath];
      print('  📷 $filename');
      print('     包裹数: ${packages.length}');
      packages.forEach((pkg) {
        final expected = pkg['expected'];
        print('     - ${expected['courier']} | 取件码: ${expected['pickupCode'] ?? '无'} | 状态: ${expected['status']}');
      });
    });
    print('');
  });
  
  print('=== 测试步骤 ===');
  print('1. 在模拟器中打开应用');
  print('2. 点击 "导入截图" 或 "拍照"');
  print('3. 从 /sdcard/Download/test_images/ 选择图片');
  print('4. 记录 OCR 识别结果');
  print('5. 与期望值对比');
  
  print('\n=== 结果记录模板 ===');
  print('图像: [文件名]');
  print('期望: courier=[快递商], pickupCode=[取件码], status=[状态]');
  print('实际: courier=[识别结果], pickupCode=[识别结果], status=[识别结果]');
  print('错误: [无/OCR错误/Parser错误]');
  print('');
  
  print('=== 快速验证命令 ===');
  print('# 查看模拟器上的图片');
  print('adb shell ls $emulatorImagePath');
  print('');
  print('# 查看应用日志');
  print('adb logcat -s flutter');
}
