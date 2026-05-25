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

  Package buildPackage({
    required String id,
    required CourierType courier,
    required String pickupCode,
    required PackageStatus status,
    String trackingNumber = '',
    String location = '',
    UrgencyLevel urgency = UrgencyLevel.normal,
  }) {
    return Package(
      id: id,
      trackingNumber: trackingNumber,
      courier: courier,
      pickupCode: pickupCode,
      location: location,
      urgency: urgency,
      status: status,
      addedAt: DateTime.now(),
    );
  }

  test('same pickup code and same courier merge into one package', () async {
    notifier.addPackage(
      buildPackage(
        id: 'sf_001',
        courier: CourierType.sf,
        pickupCode: '6-8-2301',
        status: PackageStatus.delivering,
        trackingNumber: 'SF1234567890',
        location: 'Station A',
      ),
    );

    notifier.addPackage(
      buildPackage(
        id: 'sf_002',
        courier: CourierType.sf,
        pickupCode: '6-8-2301',
        status: PackageStatus.arrived,
        trackingNumber: 'SF9999999999',
        location: 'Station A (updated)',
        urgency: UrgencyLevel.urgent,
      ),
    );

    expect(notifier.state.length, 1);
    expect(notifier.state.single.courier, CourierType.sf);
    expect(notifier.state.single.pickupCode, '6-8-2301');
    expect(notifier.state.single.status, PackageStatus.arrived);
    expect(notifier.state.single.urgency, UrgencyLevel.urgent);
  });

  test('same pickup code but different couriers stay separate', () async {
    notifier.addPackage(
      buildPackage(
        id: 'sf_001',
        courier: CourierType.sf,
        pickupCode: '3-5-1802',
        status: PackageStatus.arrived,
        trackingNumber: 'SF1234567890',
      ),
    );

    notifier.addPackage(
      buildPackage(
        id: 'yt_001',
        courier: CourierType.yt,
        pickupCode: '3-5-1802',
        status: PackageStatus.arrived,
        trackingNumber: 'YT1234567890',
      ),
    );

    expect(notifier.state.length, 2);
    expect(
      notifier.state.map((p) => '${p.courier.name}:${p.pickupCode}'),
      containsAll(['sf:3-5-1802', 'yt:3-5-1802']),
    );
  });

  test('same courier but different pickup codes stay separate', () async {
    notifier.addPackage(
      buildPackage(
        id: 'yt_001',
        courier: CourierType.yt,
        pickupCode: '3-5-1802',
        status: PackageStatus.arrived,
      ),
    );

    notifier.addPackage(
      buildPackage(
        id: 'yt_002',
        courier: CourierType.yt,
        pickupCode: '2-4-1503',
        status: PackageStatus.arrived,
      ),
    );

    expect(notifier.state.length, 2);
  });

  test('empty pickup codes do not merge', () async {
    notifier.addPackage(
      buildPackage(
        id: 'no_code_1',
        courier: CourierType.sf,
        pickupCode: '',
        status: PackageStatus.arrived,
      ),
    );

    notifier.addPackage(
      buildPackage(
        id: 'no_code_2',
        courier: CourierType.yt,
        pickupCode: '',
        status: PackageStatus.arrived,
      ),
    );

    expect(notifier.state.length, 2);
  });
}
