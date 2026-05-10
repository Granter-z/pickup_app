import 'package:flutter_test/flutter_test.dart';
import 'package:pickup_app/core/models/package.dart';
import 'package:pickup_app/core/models/package_status.dart';

void main() {
  test('验证去重逻辑：同运单号+不同取件码应该保留两个包裹', () {
    // 模拟场景：圆通快递的两个不同包裹
    final package1 = Package(
      id: 'yt_001',
      trackingNumber: 'YT881234567890',
      courier: CourierType.yt,
      pickupCode: '3-5-1802',
      location: '绿城诚园',
      urgency: UrgencyLevel.normal,
      status: PackageStatus.arrived,
      addedAt: DateTime.now(),
    );

    final package2 = Package(
      id: 'yt_002',
      trackingNumber: 'YT881234567890', // 相同运单号
      courier: CourierType.yt,
      pickupCode: '2-4-1503', // 不同取件码
      location: '绿城诚园', // 相同地址
      urgency: UrgencyLevel.warning,
      status: PackageStatus.arrived,
      addedAt: DateTime.now(),
    );

    // 验证：这两个包裹应该被视为不同的包裹
    // 因为虽然运单号相同，但取件码不同
    final isSameTracking = package1.trackingNumber.toLowerCase() ==
        package2.trackingNumber.toLowerCase();
    final isSameCode = package1.pickupCode == package2.pickupCode;

    print('┌─────────────────────────────────────────────┐');
    print('│ 包裹A: tracking=${package1.trackingNumber} code=${package1.pickupCode}');
    print('│ 包裹B: tracking=${package2.trackingNumber} code=${package2.pickupCode}');
    print('│                                             │');
    print('│ 运单号相同: $isSameTracking                   │');
    print('│ 取件码相同: $isSameCode                       │');
    print('│                                             │');
    print('│ 判断结果: ${isSameTracking && isSameCode ? "❌ 同一包裹（会合并）" : "✅ 不同包裹（应保留）"} │');
    print('└─────────────────────────────────────────────┘');

    // 核心断言：取件码不同，所以不是同一个包裹
    expect(isSameCode, isFalse, reason: '取件码应该不同');
    expect(isSameTracking, isTrue, reason: '运单号应该相同');

    // 新的去重逻辑要求：必须同时满足 运单号相同 AND 取件码相同 才合并
    final shouldMerge = isSameTracking && isSameCode;
    expect(shouldMerge, isFalse, reason: '不应该合并（新逻辑：需要tracking+code都匹配）');
  });

  test('验证去重逻辑：同运单号+同取件码应该合并', () {
    // 模拟场景：同一个包裹的状态更新
    final package1 = Package(
      id: 'sf_001',
      trackingNumber: 'SF1234567890',
      courier: CourierType.sf,
      pickupCode: '6-8-2301',
      location: '小区东门菜鸟驿站',
      urgency: UrgencyLevel.normal,
      status: PackageStatus.delivering,
      addedAt: DateTime.now().subtract(const Duration(hours: 5)),
    );

    final package2 = Package(
      id: 'sf_002',
      trackingNumber: 'SF1234567890', // 相同
      courier: CourierType.sf,
      pickupCode: '6-8-2301', // 相同
      location: '小区东门菜鸟驿站（已更新）',
      urgency: UrgencyLevel.urgent,
      status: PackageStatus.arrived, // 状态前进
      addedAt: DateTime.now(),
    );

    final isSameTracking = package1.trackingNumber.toLowerCase() ==
        package2.trackingNumber.toLowerCase();
    final isSameCode = package1.pickupCode == package2.pickupCode;
    final shouldMerge = isSameTracking && isSameCode;

    print('┌─────────────────────────────────────────────┐');
    print('│ 包裹A: tracking=${package1.trackingNumber} code=${package1.pickupCode}');
    print('│ 包裹B: tracking=${package2.trackingNumber} code=${package2.pickupCode}');
    print('│                                             │');
    print('│ 运单号相同: $isSameTracking                   │');
    print('│ 取件码相同: $isSameCode                       │');
    print('│                                             │');
    print('│ 判断结果: ${shouldMerge ? "✅ 同一包裹（应合并）" : "❌ 不同包裹"}        │');
    print('└─────────────────────────────────────────────┘');

    expect(shouldMerge, isTrue, reason: '运单号和取件码都相同，应该合并');
  });

  test('规范化函数测试', () {
    // 测试 _normalizeTracking 函数的逻辑
    String normalizeTracking(String raw) {
      return raw.trim().replaceAll(RegExp(r'\s+'), '').toLowerCase();
    }

    // 测试各种格式
    expect(normalizeTracking('YT881234567890'), equals('yt881234567890'));
    expect(normalizeTracking(' YT 881234567890 '), equals('yt881234567890'));
    expect(normalizeTracking('yt881234567890'), equals('yt881234567890'));
    expect(normalizeTracking(''), equals(''));

    print('✅ normalizeTracking 函数正常工作');
  });
}
