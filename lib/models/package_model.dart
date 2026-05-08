import 'package:hive/hive.dart';

part 'package_model.g.dart';

enum PackageStatus {
  transit,
  delivering,
  arrived,
  pickedUp,
}

enum UrgencyLevel {
  urgent,
  warning,
  normal,
  low,
}

enum CourierType {
  sf,
  jd,
  zto,
  yd,
  yt,
  sto,
  ems,
  other,
}

extension CourierTypeX on CourierType {
  String get displayName {
    switch (this) {
      case CourierType.sf:
        return '顺丰速运';
      case CourierType.jd:
        return '京东快递';
      case CourierType.zto:
        return '中通快递';
      case CourierType.yd:
        return '韵达快递';
      case CourierType.yt:
        return '圆通速递';
      case CourierType.sto:
        return '申通快递';
      case CourierType.ems:
        return 'EMS';
      case CourierType.other:
        return '其他';
    }
  }

  String get shortName {
    switch (this) {
      case CourierType.sf:
        return '顺丰';
      case CourierType.jd:
        return '京东';
      case CourierType.zto:
        return '中通';
      case CourierType.yd:
        return '韵达';
      case CourierType.yt:
        return '圆通';
      case CourierType.sto:
        return '申通';
      case CourierType.ems:
        return 'EMS';
      case CourierType.other:
        return '其他';
    }
  }
}

extension UrgencyLevelX on UrgencyLevel {
  String get label {
    switch (this) {
      case UrgencyLevel.urgent:
        return '紧急';
      case UrgencyLevel.warning:
        return '今日取';
      case UrgencyLevel.normal:
        return '明后天';
      case UrgencyLevel.low:
        return '不急';
    }
  }
}

@HiveType(typeId: 3)
class Package {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String trackingNumber;
  @HiveField(2)
  final CourierType courier;
  @HiveField(3)
  final String pickupCode;
  @HiveField(4)
  final String location;
  @HiveField(5)
  final String description;
  @HiveField(6)
  final UrgencyLevel urgency;
  @HiveField(7)
  final PackageStatus status;
  @HiveField(8)
  final DateTime addedAt;
  @HiveField(9)
  final DateTime? pickedUpAt;
  @HiveField(10)
  final bool notifiedArrived;

  const Package({
    required this.id,
    required this.trackingNumber,
    required this.courier,
    this.pickupCode = '',
    this.location = '',
    this.description = '',
    required this.urgency,
    required this.status,
    required this.addedAt,
    this.pickedUpAt,
    this.notifiedArrived = false,
  });

  Package copyWith({
    String? id,
    String? trackingNumber,
    CourierType? courier,
    String? pickupCode,
    String? location,
    String? description,
    UrgencyLevel? urgency,
    PackageStatus? status,
    DateTime? addedAt,
    DateTime? pickedUpAt,
    bool? notifiedArrived,
  }) {
    return Package(
      id: id ?? this.id,
      trackingNumber: trackingNumber ?? this.trackingNumber,
      courier: courier ?? this.courier,
      pickupCode: pickupCode ?? this.pickupCode,
      location: location ?? this.location,
      description: description ?? this.description,
      urgency: urgency ?? this.urgency,
      status: status ?? this.status,
      addedAt: addedAt ?? this.addedAt,
      pickedUpAt: pickedUpAt ?? this.pickedUpAt,
      notifiedArrived: notifiedArrived ?? this.notifiedArrived,
    );
  }
}
