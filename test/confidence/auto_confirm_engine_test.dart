import 'package:flutter_test/flutter_test.dart';
import 'package:pickup_app/core/confidence/auto_confirm_engine.dart';
import 'package:pickup_app/core/models/package.dart';
import 'package:pickup_app/core/models/package_status.dart';

/// 测试用历史仓库
class MockHistoryRepository implements HistoryRepository {
  final Map<String, int> _locationCounts;
  final Map<String, int> _pickupCodeCounts;

  MockHistoryRepository({
    Map<String, int>? locationCounts,
    Map<String, int>? pickupCodeCounts,
  })  : _locationCounts = locationCounts ?? {},
        _pickupCodeCounts = pickupCodeCounts ?? {};

  @override
  int getLocationCount(String location) => _locationCounts[location] ?? 0;

  @override
  int getPickupCodeCount(String pickupCode) => _pickupCodeCounts[pickupCode] ?? 0;

  @override
  bool isNewLocation(String location) => !_locationCounts.containsKey(location);
}

void main() {
  group('AutoConfirmEngine — 自动确认决策', () {
    // ── Rule 1: 缺少取件码 ──────────────────────────────────

    test('Case 1: 缺少取件码绝不自动确认', () {
      final engine = AutoConfirmEngine();
      final package = Package(
        id: 'test-1',
        trackingNumber: 'SF1234567890',
        courier: CourierType.sf,
        pickupCode: '', // 缺少取件码
        location: '邢台信都区绿城诚园北门店',
        cleanedLocation: '邢台信都区绿城诚园北门店',
        urgency: UrgencyLevel.normal,
        status: PackageStatus.arrived,
        addedAt: DateTime.now(),
      );

      final result = engine.evaluate(package);
      expect(result.shouldAutoConfirm, false);
      expect(result.reasons, anyElement(contains('取件码')));
    });

    // ── Rule 2: 缺少运单号 ──────────────────────────────────

    test('Case 2: 缺少运单号绝不自动确认', () {
      final engine = AutoConfirmEngine();
      final package = Package(
        id: 'test-2',
        trackingNumber: '', // 缺少运单号
        courier: CourierType.sf,
        pickupCode: '15-3-6007',
        location: '邢台信都区绿城诚园北门店',
        cleanedLocation: '邢台信都区绿城诚园北门店',
        urgency: UrgencyLevel.normal,
        status: PackageStatus.arrived,
        addedAt: DateTime.now(),
      );

      final result = engine.evaluate(package);
      expect(result.shouldAutoConfirm, false);
      expect(result.reasons, anyElement(contains('运单号')));
    });

    // ── Rule 3: 地址可信度不足 ──────────────────────────────

    test('Case 3: 地址可信度不足不自动确认', () {
      final engine = AutoConfirmEngine();
      final package = Package(
        id: 'test-3',
        trackingNumber: 'SF1234567890',
        courier: CourierType.sf,
        pickupCode: '15-3-6007',
        location: '北门', // 太短，可信度低
        cleanedLocation: '北门',
        urgency: UrgencyLevel.normal,
        status: PackageStatus.arrived,
        addedAt: DateTime.now(),
      );

      final result = engine.evaluate(package);
      expect(result.shouldAutoConfirm, false);
      expect(result.reasons, anyElement(contains('可信度')));
    });

    // ── Rule 4: 包含可疑词 ──────────────────────────────────

    test('Case 4: 包含可疑词不自动确认', () {
      final engine = AutoConfirmEngine();
      final package = Package(
        id: 'test-4',
        trackingNumber: 'SF1234567890',
        courier: CourierType.sf,
        pickupCode: '15-3-6007',
        location: '绿城诚园北门面对面大院驿站',
        cleanedLocation: '绿城诚园北门面对面大院驿站',
        urgency: UrgencyLevel.normal,
        status: PackageStatus.arrived,
        addedAt: DateTime.now(),
      );

      final result = engine.evaluate(package);
      expect(result.shouldAutoConfirm, false);
      expect(result.reasons, anyElement(contains('可疑词')));
    });

    // ── Rule 5: 历史稳定性不足 ──────────────────────────────

    test('Case 5: 新地址历史稳定性不足', () {
      final historyRepo = MockHistoryRepository(
        locationCounts: {}, // 空历史
      );
      final engine = AutoConfirmEngine(historyRepository: historyRepo);
      final package = Package(
        id: 'test-5',
        trackingNumber: 'SF1234567890',
        courier: CourierType.sf,
        pickupCode: '15-3-6007',
        location: '邢台信都区绿城诚园北门店',
        cleanedLocation: '邢台信都区绿城诚园北门店',
        urgency: UrgencyLevel.normal,
        status: PackageStatus.arrived,
        addedAt: DateTime.now(),
      );

      final result = engine.evaluate(package);
      expect(result.shouldAutoConfirm, false);
      expect(result.reasons, anyElement(contains('稳定性')));
    });

    // ── 正常情况：应该自动确认 ──────────────────────────────

    test('Case 6: 正常地址应该自动确认', () {
      final historyRepo = MockHistoryRepository(
        locationCounts: {
          '邢台信都区绿城诚园北门店': 5, // 出现 5 次
        },
        pickupCodeCounts: {
          '15-3-6007': 3,
        },
      );
      final engine = AutoConfirmEngine(historyRepository: historyRepo);
      final package = Package(
        id: 'test-6',
        trackingNumber: 'SF1234567890',
        courier: CourierType.sf,
        pickupCode: '15-3-6007',
        location: '邢台信都区绿城诚园北门店',
        cleanedLocation: '邢台信都区绿城诚园北门店',
        urgency: UrgencyLevel.normal,
        status: PackageStatus.arrived,
        addedAt: DateTime.now(),
      );

      final result = engine.evaluate(package);
      expect(result.shouldAutoConfirm, true);
      expect(result.trustScore, greaterThan(0.7));
    });

    // ── 信任分数计算 ──────────────────────────────────────

    test('Case 7: 信任分数计算正确', () {
      final historyRepo = MockHistoryRepository(
        locationCounts: {
          '邢台信都区绿城诚园北门店': 5,
        },
        pickupCodeCounts: {
          '15-3-6007': 3,
        },
      );
      final engine = AutoConfirmEngine(historyRepository: historyRepo);
      final package = Package(
        id: 'test-7',
        trackingNumber: 'SF1234567890',
        courier: CourierType.sf,
        pickupCode: '15-3-6007',
        location: '邢台信都区绿城诚园北门店',
        cleanedLocation: '邢台信都区绿城诚园北门店',
        urgency: UrgencyLevel.normal,
        status: PackageStatus.arrived,
        addedAt: DateTime.now(),
      );

      final result = engine.evaluate(package);
      expect(result.fieldConfidence, greaterThan(0.0));
      expect(result.semanticConfidence, greaterThan(0.0));
      expect(result.historicalStability, greaterThan(0.0));
      expect(result.trustScore, greaterThan(0.0));
    });

    // ── 边界情况：空地址 ──────────────────────────────────

    test('Case 8: 空地址不自动确认', () {
      final engine = AutoConfirmEngine();
      final package = Package(
        id: 'test-8',
        trackingNumber: 'SF1234567890',
        courier: CourierType.sf,
        pickupCode: '15-3-6007',
        location: '',
        cleanedLocation: '',
        urgency: UrgencyLevel.normal,
        status: PackageStatus.arrived,
        addedAt: DateTime.now(),
      );

      final result = engine.evaluate(package);
      expect(result.shouldAutoConfirm, false);
    });
  });
}
