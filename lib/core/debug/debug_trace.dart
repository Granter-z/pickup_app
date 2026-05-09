/// Debug 追踪工具
/// 
/// 职责：
/// 1. 在关键层打印调试信息
/// 2. 帮助定位识别失败的原因
library;

import '../models/package.dart';
import '../models/package_status.dart';
import '../parser/parse_result.dart';

/// Debug 追踪器
class DebugTrace {
  static bool enabled = true;

  /// 打印分隔线
  static void separator(String label) {
    if (!enabled) return;
    print('');
    print('═══════════════════════════════════════════════════');
    print('  $label');
    print('═══════════════════════════════════════════════════');
  }

  /// 打印 OCR 结果
  static void ocrResult(String rawText) {
    if (!enabled) return;
    separator('OCR RESULT');
    print('rawText:');
    print('  ${rawText.isEmpty ? "(empty)" : rawText}');
    print('  length: ${rawText.length}');
  }

  /// 打印 Parser 结果
  static void parseResult(ParseResult result, {int? index}) {
    if (!enabled) return;
    separator('PARSE RESULT ${index != null ? "#$index" : ""}');
    
    print('courier:');
    print('  value: ${result.courier.value.displayName}');
    print('  confidence: ${result.courier.confidence}');
    print('  source: ${result.courier.source}');
    
    print('pickupCode:');
    print('  value: ${result.pickupCode.value.isEmpty ? "(empty)" : result.pickupCode.value}');
    print('  confidence: ${result.pickupCode.confidence}');
    print('  source: ${result.pickupCode.source}');
    
    print('trackingNumber:');
    print('  value: ${result.trackingNumber.value.isEmpty ? "(empty)" : result.trackingNumber.value}');
    print('  confidence: ${result.trackingNumber.confidence}');
    
    print('location:');
    print('  value: ${result.location.value.isEmpty ? "(empty)" : result.location.value}');
    print('  confidence: ${result.location.confidence}');
    print('  source: ${result.location.source}');
    
    print('status:');
    print('  value: ${result.status.value.label}');
    print('  confidence: ${result.status.confidence}');
    print('  source: ${result.status.source}');
    
    print('overallConfidence: ${result.overallConfidence}');
    
    if (result.allWarnings.isNotEmpty) {
      print('warnings:');
      for (final w in result.allWarnings) {
        print('  - $w');
      }
    }
    
    print('isValid: ${result.isValid}');
    print('canCreatePackage: ${result.canCreatePackage}');
  }

  /// 打印规范化文本
  static void normalizedText(String original, String normalized, String fingerprint) {
    if (!enabled) return;
    separator('NORMALIZED TEXT');
    print('original: $original');
    print('normalized: $normalized');
    print('fingerprint: $fingerprint');
  }

  /// 打印去重结果
  static void dedupeResult({
    required String method,
    required bool isDuplicate,
    int? existingIndex,
    String? existingId,
    String? reason,
  }) {
    if (!enabled) return;
    separator('DEDUPE RESULT');
    print('method: $method');
    print('isDuplicate: $isDuplicate');
    if (existingIndex != null) print('existingIndex: $existingIndex');
    if (existingId != null) print('existingId: $existingId');
    if (reason != null) print('reason: $reason');
  }

  /// 打印 Package 创建
  static void packageCreated(Package package) {
    if (!enabled) return;
    separator('PACKAGE CREATED');
    print('id: ${package.id}');
    print('courier: ${package.courier.displayName}');
    print('trackingNumber: ${package.trackingNumber}');
    print('pickupCode: ${package.pickupCode.isEmpty ? "(empty)" : package.pickupCode}');
    print('location: ${package.location.isEmpty ? "(empty)" : package.location}');
    print('status: ${package.status.label}');
    print('transitFingerprint: ${package.transitFingerprint ?? "(null)"}');
  }

  /// 打印 PendingConfirmation 创建
  static void confirmationCreated({
    required String id,
    required double confidence,
    required CourierType courier,
    required String pickupCode,
    required String location,
    required PackageStatus status,
  }) {
    if (!enabled) return;
    separator('PENDING CONFIRMATION CREATED');
    print('id: $id');
    print('confidence: $confidence');
    print('courier: ${courier.displayName}');
    print('pickupCode: ${pickupCode.isEmpty ? "(empty)" : pickupCode}');
    print('location: ${location.isEmpty ? "(empty)" : location}');
    print('status: ${status.label}');
  }

  /// 打印错误
  static void error(String message, {Object? error, StackTrace? stackTrace}) {
    if (!enabled) return;
    separator('ERROR');
    print('message: $message');
    if (error != null) print('error: $error');
    if (stackTrace != null) print('stackTrace: $stackTrace');
  }
}
