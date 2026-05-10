import 'package:flutter_test/flutter_test.dart';
import 'package:pickup_app/core/models/package.dart';
import 'package:pickup_app/core/models/package_status.dart';
import 'package:pickup_app/ui/providers/package_provider.dart';

void main() {
  late PackageListNotifier notifier;

  setUp(() {
    notifier = PackageListNotifier();
  });

  test('同运单号不同取件码应该保留两个包裹（圆通快递场景）', () async {
    // Arrange: 初始状态为空
    expect(notifier.state.length, equals(0));

    // Act 1: 添加第一个圆通快递
    final package1 = Package(
      id: 'yt_001',
      trackingNumber: 'YT881234567890',
      courier: CourierType.yt,
      pickupCode: '3-5-1802',
      location: '绿城诚园',
      description: '书籍 x3',
      urgency: UrgencyLevel.normal,
      status: PackageStatus.arrived,
      addedAt: DateTime.now(),
    );

    notifier.addPackage(package1);

    // Assert 1: 应该有1个包裹
    expect(notifier.state.length, equals(1));
    expect(notifier.state[0].pickupCode, equals('3-5-1802'));
    print('✅ 第一个包裹添加成功: code=3-5-1802');

    // Act 2: 添加第二个圆通快递（相同运单号，不同取件码）
    final package2 = Package(
      id: 'yt_002',
      trackingNumber: 'YT881234567890', // 相同运单号
      courier: CourierType.yt,
      pickupCode: '2-4-1503', // 不同取件码
      location: '绿城诚园', // 相同地址
      description: '日用品套装',
      urgency: UrgencyLevel.warning,
      status: PackageStatus.arrived,
      addedAt: DateTime.now(),
    );

    notifier.addPackage(package2);

    // Assert 2: 应该有2个包裹（关键测试点！）
    expect(notifier.state.length, equals(2), reason: '同运单号不同取件码应该保留两个包裹');

    // 验证两个包裹都存在
    final codes = notifier.state.map((p) => p.pickupCode).toList();
    expect(codes, contains('3-5-1802'));
    expect(codes, contains('2-4-1503'));

    print('✅ 第二个包裹添加成功: code=2-4-1503');
    print('✅ 总共 ${notifier.state.length} 个包裹（未被覆盖）');
  });

  test('同运单号同取件码应该合并更新', () async {
    // Arrange
    final package1 = Package(
      id: 'sf_001',
      trackingNumber: 'SF1234567890',
      courier: CourierType.sf,
      pickupCode: '6-8-2301',
      location: '小区东门菜鸟驿站',
      description: 'Apple AirPods Pro',
      urgency: UrgencyLevel.normal,
      status: PackageStatus.delivering,
      addedAt: DateTime.now().subtract(const Duration(hours: 5)),
    );

    notifier.addPackage(package1);
    expect(notifier.state.length, equals(1));
    expect(notifier.state[0].status, equals(PackageStatus.delivering));
    print('✅ 第一个顺丰包裹: status=delivering');

    // Act: 添加相同运单号+取件码的更新
    final package2 = Package(
      id: 'sf_002',
      trackingNumber: 'SF1234567890',
      courier: CourierType.sf,
      pickupCode: '6-8-2301', // 相同取件码
      location: '小区东门菜鸟驿站（已更新）',
      description: 'Apple AirPods Pro 2',
      urgency: UrgencyLevel.urgent,
      status: PackageStatus.arrived, // 状态前进
      addedAt: DateTime.now(),
    );

    notifier.addPackage(package2);

    // Assert: 应该合并，仍然是1个包裹
    expect(notifier.state.length, equals(1), reason: '同运单号+同取件码应该合并');
    expect(notifier.state[0].status, equals(PackageStatus.arrived));
    expect(notifier.state[0].location, contains('已更新'));
    expect(notifier.state[0].urgency, equals(UrgencyLevel.urgent));

    print('✅ 包裹合并成功: status=arrived, location已更新');
  });

  test('无运单号时降级为仅取件码匹配', () async {
    // Arrange: 运单号为空的情况
    final package1 = Package(
      id: 'unknown_001',
      trackingNumber: '', // 无运单号
      courier: CourierType.other,
      pickupCode: '8812',
      location: '小区西门快递点',
      description: '未知包裹',
      urgency: UrgencyLevel.normal,
      status: PackageStatus.arrived,
      addedAt: DateTime.now(),
    );

    notifier.addPackage(package1);
    expect(notifier.state.length, equals(1));

    // Act: 添加相同取件码的包裹（无运单号）
    final package2 = Package(
      id: 'unknown_002',
      trackingNumber: '', // 无运单号
      courier: CourierType.other,
      pickupCode: '8812', // 相同取件码
      location: '小区西门快递点（更新）',
      description: '已识别包裹',
      urgency: UrgencyLevel.warning,
      status: PackageStatus.arrived,
      addedAt: DateTime.now(),
    );

    notifier.addPackage(package2);

    // Assert: 通过 Priority 2 (pickupCode + location) 匹配并合并
    expect(notifier.state.length, equals(1));
    expect(notifier.state[0].location, contains('更新'));

    print('✅ 无运单号时通过 pickupCode+location 匹配成功');
  });
}
