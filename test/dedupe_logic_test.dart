import 'package:flutter_test/flutter_test.dart';
import 'package:pickup_app/core/models/package.dart';
import 'package:pickup_app/core/models/package_status.dart';

void main() {
  test('same pickup code and same courier share the same fingerprint', () {
    final package1 = Package(
      id: 'sf_001',
      trackingNumber: 'SF1234567890',
      courier: CourierType.sf,
      pickupCode: '6-8-2301',
      location: 'Station A',
      urgency: UrgencyLevel.normal,
      status: PackageStatus.arrived,
      addedAt: DateTime.now(),
    );

    final package2 = Package(
      id: 'sf_002',
      trackingNumber: 'SF9999999999',
      courier: CourierType.sf,
      pickupCode: '6-8-2301',
      location: 'Station A (updated)',
      urgency: UrgencyLevel.urgent,
      status: PackageStatus.arrived,
      addedAt: DateTime.now(),
    );

    expect(package1.fingerprint, package2.fingerprint);
  });

  test('same pickup code but different couriers have different fingerprints', () {
    final package1 = Package(
      id: 'sf_001',
      trackingNumber: 'SF1234567890',
      courier: CourierType.sf,
      pickupCode: '6-8-2301',
      location: 'Station A',
      urgency: UrgencyLevel.normal,
      status: PackageStatus.arrived,
      addedAt: DateTime.now(),
    );

    final package2 = Package(
      id: 'yt_001',
      trackingNumber: 'YT1234567890',
      courier: CourierType.yt,
      pickupCode: '6-8-2301',
      location: 'Station A',
      urgency: UrgencyLevel.warning,
      status: PackageStatus.arrived,
      addedAt: DateTime.now(),
    );

    expect(package1.fingerprint, isNot(package2.fingerprint));
  });

  test('empty pickup codes still include courier in the fingerprint', () {
    final package1 = Package(
      id: 'no_code_1',
      trackingNumber: 'SF1111111111',
      courier: CourierType.sf,
      pickupCode: '',
      location: 'Station A',
      urgency: UrgencyLevel.normal,
      status: PackageStatus.arrived,
      addedAt: DateTime.now(),
    );

    final package2 = Package(
      id: 'no_code_2',
      trackingNumber: 'YT2222222222',
      courier: CourierType.yt,
      pickupCode: '',
      location: 'Station A',
      urgency: UrgencyLevel.normal,
      status: PackageStatus.arrived,
      addedAt: DateTime.now(),
    );

    expect(package1.fingerprint, isNot(package2.fingerprint));
  });
}
