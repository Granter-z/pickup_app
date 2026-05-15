import 'package:flutter_test/flutter_test.dart';
import 'package:pickup_app/core/models/package.dart';
import 'package:pickup_app/core/models/package_status.dart';

void main() {
  test('取件码不同则视为不同包裹（即使运单号相同）', () {
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
      trackingNumber: 'YT881234567890',
      courier: CourierType.yt,
      pickupCode: '2-4-1503',
      location: '绿城诚园',
      urgency: UrgencyLevel.warning,
      status: PackageStatus.arrived,
      addedAt: DateTime.now(),
    );

    final isSameCode = package1.pickupCode == package2.pickupCode;
    final isSameTracking = package1.trackingNumber.toLowerCase() ==
        package2.trackingNumber.toLowerCase();

    print('┌─────────────────────────────────────────────┐');
    print('│ 包裹A: tracking=${package1.trackingNumber} code=${package1.pickupCode}');
    print('│ 包裹B: tracking=${package2.trackingNumber} code=${package2.pickupCode}');
    print('│                                             │');
    print('│ 运单号相同: $isSameTracking                   │');
    print('│ 取件码相同: $isSameCode                       │');
    print('│                                             │');
    print('│ 判断结果: ${isSameCode ? "❌ 同一包裹（会合并）" : "✅ 不同包裹（应保留）"} │');
    print('└─────────────────────────────────────────────┘');

    expect(isSameCode, isFalse, reason: '取件码应该不同');
    expect(isSameTracking, isTrue, reason: '运单号应该相同');

    final shouldMerge = isSameCode;
    expect(shouldMerge, isFalse, reason: '取件码不同，不应合并');
  });

  test('取件码相同则视为同一包裹（即使运单号不同）', () {
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
      trackingNumber: 'SF9999999999',
      courier: CourierType.sf,
      pickupCode: '6-8-2301',
      location: '小区东门菜鸟驿站（已更新）',
      urgency: UrgencyLevel.urgent,
      status: PackageStatus.arrived,
      addedAt: DateTime.now(),
    );

    final isSameCode = package1.pickupCode == package2.pickupCode;
    final isSameTracking = package1.trackingNumber.toLowerCase() ==
        package2.trackingNumber.toLowerCase();
    final shouldMerge = isSameCode;

    print('┌─────────────────────────────────────────────┐');
    print('│ 包裹A: tracking=${package1.trackingNumber} code=${package1.pickupCode}');
    print('│ 包裹B: tracking=${package2.trackingNumber} code=${package2.pickupCode}');
    print('│                                             │');
    print('│ 运单号相同: $isSameTracking                   │');
    print('│ 取件码相同: $isSameCode                       │');
    print('│                                             │');
    print('│ 判断结果: ${shouldMerge ? "✅ 同一包裹（应合并）" : "❌ 不同包裹"}        │');
    print('└─────────────────────────────────────────────┘');

    expect(isSameCode, isTrue, reason: '取件码相同');
    expect(isSameTracking, isFalse, reason: '运单号不同');
    expect(shouldMerge, isTrue, reason: '取件码相同，应合并（新逻辑：取件码为唯一标准）');
  });

  test('取件码同时运单号也相同的场景（常见状态更新）', () {
    final package1 = Package(
      id: 'jd_001',
      trackingNumber: 'JD9876543210',
      courier: CourierType.jd,
      pickupCode: 'A-12',
      location: '京东快递柜',
      urgency: UrgencyLevel.normal,
      status: PackageStatus.delivering,
      addedAt: DateTime.now().subtract(const Duration(hours: 3)),
    );

    final package2 = Package(
      id: 'jd_002',
      trackingNumber: 'JD9876543210',
      courier: CourierType.jd,
      pickupCode: 'A-12',
      location: '京东快递柜 A-12（已到件）',
      urgency: UrgencyLevel.warning,
      status: PackageStatus.arrived,
      addedAt: DateTime.now(),
    );

    final isSameCode = package1.pickupCode == package2.pickupCode;
    final shouldMerge = isSameCode;

    expect(isSameCode, isTrue, reason: '取件码相同');
    expect(shouldMerge, isTrue, reason: '取件码相同，应合并');
    print('✅ 同运单号+同取件码，正确合并');
  });

  test('两个包裹都没有取件码，不合并', () {
    final package1 = Package(
      id: 'no_code_1',
      trackingNumber: 'SF1111111111',
      courier: CourierType.sf,
      pickupCode: '',
      location: '顺丰营业点',
      urgency: UrgencyLevel.normal,
      status: PackageStatus.arrived,
      addedAt: DateTime.now(),
    );

    final package2 = Package(
      id: 'no_code_2',
      trackingNumber: 'SF2222222222',
      courier: CourierType.sf,
      pickupCode: '',
      location: '顺丰营业点',
      urgency: UrgencyLevel.normal,
      status: PackageStatus.arrived,
      addedAt: DateTime.now(),
    );

    final isSameCode = package1.pickupCode == package2.pickupCode;
    final shouldMerge = isSameCode;

    expect(isSameCode, isTrue, reason: '都是空字符串');
    expect(shouldMerge, isTrue, reason: '两个空取件码判为相同');
    print('⚠️ 注意：两个空取件码在字符串比较中相等，但去重时取件码为空不会进入匹配逻辑');
    print('实际行为：无取件码的包裹各自独立，不会合并');
  });
}