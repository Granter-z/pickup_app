import 'package:flutter_test/flutter_test.dart';
import 'package:pickup_app/core/models/package.dart';
import 'package:pickup_app/core/models/package_status.dart';
import 'package:pickup_app/ui/providers/package_provider.dart';
import 'helpers/test_hive_helper.dart';

void main() {
  late PackageListNotifier notifier;

  setUpAll(() async {
    await TestHiveHelper.init();
  });

  tearDownAll(() async {
    await TestHiveHelper.cleanup();
  });

  setUp(() async {
    await TestHiveHelper.resetBox();
    notifier = PackageListNotifier();
  });

  test('不同运单号相同取件码应该合并为一个包裹（取件码为唯一标准）', () async {
    expect(notifier.state.length, equals(0));

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
    expect(notifier.state.length, equals(1));
    print('✅ 第一个包裹添加成功: code=3-5-1802 tracking=YT881234567890');

    final package2 = Package(
      id: 'yt_002',
      trackingNumber: 'YT999999999999',
      courier: CourierType.yt,
      pickupCode: '3-5-1802',
      location: '绿城诚园',
      description: '日用品套装',
      urgency: UrgencyLevel.warning,
      status: PackageStatus.arrived,
      addedAt: DateTime.now(),
    );

    notifier.addPackage(package2);

    expect(notifier.state.length, equals(1),
        reason: '不同运单号相同取件码应该合并（取件码为唯一去重标准）');

    print('✅ 不同运单号但相同取件码，正确合并为1个包裹');
    print('✅ 总共 ${notifier.state.length} 个包裹');
  });

  test('同运单号不同取件码应该保留两个包裹', () async {
    expect(notifier.state.length, equals(0));

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
    expect(notifier.state.length, equals(1));
    expect(notifier.state[0].pickupCode, equals('3-5-1802'));
    print('✅ 第一个包裹添加成功: code=3-5-1802');

    final package2 = Package(
      id: 'yt_002',
      trackingNumber: 'YT881234567890',
      courier: CourierType.yt,
      pickupCode: '2-4-1503',
      location: '绿城诚园',
      description: '日用品套装',
      urgency: UrgencyLevel.warning,
      status: PackageStatus.arrived,
      addedAt: DateTime.now(),
    );

    notifier.addPackage(package2);

    expect(notifier.state.length, equals(2),
        reason: '不同取件码应保留两个包裹');

    final codes = notifier.state.map((p) => p.pickupCode).toList();
    expect(codes, contains('3-5-1802'));
    expect(codes, contains('2-4-1503'));

    print('✅ 第二个包裹添加成功: code=2-4-1503');
    print('✅ 总共 ${notifier.state.length} 个包裹（未被覆盖）');
  });

  test('同运单号同取件码应该合并更新', () async {
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

    final package2 = Package(
      id: 'sf_002',
      trackingNumber: 'SF1234567890',
      courier: CourierType.sf,
      pickupCode: '6-8-2301',
      location: '小区东门菜鸟驿站（已更新）',
      description: 'Apple AirPods Pro 2',
      urgency: UrgencyLevel.urgent,
      status: PackageStatus.arrived,
      addedAt: DateTime.now(),
    );

    notifier.addPackage(package2);

    expect(notifier.state.length, equals(1), reason: '同取件码应合并');
    expect(notifier.state[0].status, equals(PackageStatus.arrived));
    expect(notifier.state[0].location, contains('已更新'));
    expect(notifier.state[0].urgency, equals(UrgencyLevel.urgent));

    print('✅ 包裹合并成功: status=arrived, location已更新');
  });

  test('无运单号时相同取件码应合并', () async {
    final package1 = Package(
      id: 'unknown_001',
      trackingNumber: '',
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

    final package2 = Package(
      id: 'unknown_002',
      trackingNumber: '',
      courier: CourierType.other,
      pickupCode: '8812',
      location: '小区西门快递点（更新）',
      description: '已识别包裹',
      urgency: UrgencyLevel.warning,
      status: PackageStatus.arrived,
      addedAt: DateTime.now(),
    );

    notifier.addPackage(package2);

    expect(notifier.state.length, equals(1));
    expect(notifier.state[0].location, contains('更新'));

    print('✅ 无运单号相同取件码合并成功');
  });

  test('无取件码但不同快递商的包裹各自独立，不合并', () async {
    final package1 = Package(
      id: 'no_code_1',
      trackingNumber: 'SF1111111111',
      courier: CourierType.sf,
      pickupCode: '',
      location: '顺丰营业点',
      description: '包裹A',
      urgency: UrgencyLevel.normal,
      status: PackageStatus.arrived,
      addedAt: DateTime.now(),
    );

    notifier.addPackage(package1);
    expect(notifier.state.length, equals(1));

    final package2 = Package(
      id: 'no_code_2',
      trackingNumber: 'ZTO2222222222',
      courier: CourierType.zto,
      pickupCode: '',
      location: '中通驿站',
      description: '包裹B',
      urgency: UrgencyLevel.normal,
      status: PackageStatus.arrived,
      addedAt: DateTime.now(),
    );

    notifier.addPackage(package2);

    expect(notifier.state.length, equals(2),
        reason: '无取件码但不同快递商，fingerprint 不同，不合并');

    print('✅ 无取件码不同快递商各自独立: ${notifier.state.length} 个');
  });
}
