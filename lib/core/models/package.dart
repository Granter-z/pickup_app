/// 包裹核心模型 - 纯Dart，不依赖Flutter
/// 
/// 职责：
/// 1. 定义包裹数据结构
/// 2. 提供不可变的数据操作
/// 3. 提供业务逻辑判断
library;

import 'package_status.dart';
import 'logistics_event.dart';
import 'pickup_urgency.dart';

/// 快递公司类型
enum CourierType {
  sf,    // 顺丰
  jd,    // 京东
  zto,   // 中通
  yd,    // 韵达
  yt,    // 圆通
  sto,   // 申通
  ems,   // EMS
  jt,    // 极兔
  db,    // 德邦
  best,  // 百世
  other, // 其他
}

/// 快递公司信息
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
      case CourierType.jt:
        return '极兔速递';
      case CourierType.db:
        return '德邦快递';
      case CourierType.best:
        return '百世快递';
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
      case CourierType.jt:
        return '极兔';
      case CourierType.db:
        return '德邦';
      case CourierType.best:
        return '百世';
      case CourierType.other:
        return '其他';
    }
  }
}

/// 紧急程度
enum UrgencyLevel {
  low,     // 不急
  normal,  // 明后天
  warning, // 今日取
  urgent,  // 紧急
}

extension UrgencyLevelX on UrgencyLevel {
  String get label {
    switch (this) {
      case UrgencyLevel.low:
        return '不急';
      case UrgencyLevel.normal:
        return '明后天';
      case UrgencyLevel.warning:
        return '今日取';
      case UrgencyLevel.urgent:
        return '紧急';
    }
  }
  
  /// 紧急程度评分
  int get score {
    switch (this) {
      case UrgencyLevel.low:
        return 0;
      case UrgencyLevel.normal:
        return 1;
      case UrgencyLevel.warning:
        return 2;
      case UrgencyLevel.urgent:
        return 3;
    }
  }
}

/// 包裹核心模型
class Package {
  final String id;
  final String trackingNumber;
  final CourierType courier;
  final String pickupCode;
  final String location;
  final String originalStation;
  final String description;
  final UrgencyLevel urgency;
  final PackageStatus status;
  final DateTime addedAt;
  final DateTime? pickedUpAt;
  final DateTime? archivedAt;
  final bool notifiedArrived;
  final List<StatusTransition> statusHistory;
  final String? transitFingerprint;  // transit 阶段的弱身份标识
  final List<LogisticsEvent> events;
  final String fingerprint;  // 包裹唯一识别指纹
  final DateTime? timeoutAt; // 预估/解析出的超时截止时间

  // ── 三层地址系统 ─────────────────────────────────────────────
  final String rawLocation;        // OCR 原始提取，永不覆盖
  final String cleanedLocation;    // regex 清洗后
  final String canonicalLocation;  // 最终可信地址（历史收敛）
  final double locationConfidence; // 地址置信度

  /// 显示用地址：canonicalLocation > cleanedLocation > rawLocation > '未知地点'
  String get displayLocation {
    final addr = canonicalLocation.isNotEmpty
        ? canonicalLocation
        : cleanedLocation.isNotEmpty
            ? cleanedLocation
            : rawLocation.isNotEmpty
                ? rawLocation
                : '';
    if (addr.isNotEmpty && originalStation.isNotEmpty) return '$originalStation · $addr';
    if (addr.isNotEmpty) return addr;
    if (originalStation.isNotEmpty) return originalStation;
    return '未知驿站';
  }

  /// 取件紧迫度（行动系统的核心）
  PickupUrgency get pickupUrgency {
    return PickupUrgencyCalculator.calculate(
      addedAt: addedAt,
      isPickedUp: status == PackageStatus.pickedUp,
      timeoutAt: timeoutAt,
    );
  }

  Package({
    required this.id,
    required this.trackingNumber,
    required this.courier,
    this.pickupCode = '',
    this.location = '',
    this.originalStation = '',
    this.description = '',
    required this.urgency,
    required this.status,
    required this.addedAt,
    this.pickedUpAt,
    this.archivedAt,
    this.notifiedArrived = false,
    this.statusHistory = const [],
    this.transitFingerprint,
    this.events = const [],
    String? fingerprint,
    this.timeoutAt,
    this.rawLocation = '',
    this.cleanedLocation = '',
    this.canonicalLocation = '',
    this.locationConfidence = 0.0,
  }) : this.fingerprint = fingerprint ?? buildFingerprintStatic(pickupCode, courier);

  /// 构建包裹指纹
  /// 优先级：pickupCode > courier (carrier) > phoneTail
  static String buildFingerprintStatic(String pickupCode, CourierType courier) {
    final carrierName = courier.displayName;
    return '${pickupCode}_${carrierName}'
        .toLowerCase()
        .trim();
  }

  /// 构建包裹指纹（带 phoneTail）
  static String buildFingerprint({
    required String pickupCode,
    String? carrier,
    String? phoneTail,
  }) {
    return '${pickupCode}_${carrier ?? ''}_${phoneTail ?? ''}'
        .toLowerCase()
        .trim();
  }

  Package copyWith({
    String? id,
    String? trackingNumber,
    CourierType? courier,
    String? pickupCode,
    String? location,
    String? originalStation,
    String? description,
    UrgencyLevel? urgency,
    PackageStatus? status,
    DateTime? addedAt,
    DateTime? pickedUpAt,
    DateTime? archivedAt,
    bool? notifiedArrived,
    List<StatusTransition>? statusHistory,
    String? transitFingerprint,
    List<LogisticsEvent>? events,
    String? fingerprint,
    DateTime? timeoutAt,
    String? rawLocation,
    String? cleanedLocation,
    String? canonicalLocation,
    double? locationConfidence,
  }) {
    return Package(
      id: id ?? this.id,
      trackingNumber: trackingNumber ?? this.trackingNumber,
      courier: courier ?? this.courier,
      pickupCode: pickupCode ?? this.pickupCode,
      location: location ?? this.location,
      originalStation: originalStation ?? this.originalStation,
      description: description ?? this.description,
      urgency: urgency ?? this.urgency,
      status: status ?? this.status,
      addedAt: addedAt ?? this.addedAt,
      pickedUpAt: pickedUpAt ?? this.pickedUpAt,
      archivedAt: archivedAt ?? this.archivedAt,
      notifiedArrived: notifiedArrived ?? this.notifiedArrived,
      statusHistory: statusHistory ?? this.statusHistory,
      transitFingerprint: transitFingerprint ?? this.transitFingerprint,
      events: events ?? this.events,
      fingerprint: fingerprint ?? this.fingerprint,
      timeoutAt: timeoutAt ?? this.timeoutAt,
      rawLocation: rawLocation ?? this.rawLocation,
      cleanedLocation: cleanedLocation ?? this.cleanedLocation,
      canonicalLocation: canonicalLocation ?? this.canonicalLocation,
      locationConfidence: locationConfidence ?? this.locationConfidence,
    );
  }

  /// 转换状态，自动记录历史
  Package transitionTo(PackageStatus newStatus, {String? reason}) {
    final transition = StatusTransition(
      from: status,
      to: newStatus,
      timestamp: DateTime.now(),
      reason: reason,
    );
    
    if (!transition.isValid) {
      throw StateError('Invalid status transition: ${status.label} → ${newStatus.label}');
    }
    
    return copyWith(
      status: newStatus,
      pickedUpAt: newStatus == PackageStatus.pickedUp ? DateTime.now() : pickedUpAt,
      archivedAt: newStatus == PackageStatus.archived ? DateTime.now() : archivedAt,
      statusHistory: [...statusHistory, transition],
    );
  }

  /// 是否需要自动归档（已取件超过7天）
  bool get shouldAutoArchive {
    if (status != PackageStatus.pickedUp) return false;
    if (pickedUpAt == null) return false;
    return DateTime.now().difference(pickedUpAt!).inDays >= 7;
  }

  /// 是否与其他包裹在同一取件点
  bool isSameLocation(Package other) {
    if (location.isEmpty || other.location.isEmpty) return false;
    return location == other.location;
  }

  /// 是否为同一快递（基于快递公司和运单号）
  bool isSamePackage(Package other) {
    return courier == other.courier && trackingNumber == other.trackingNumber;
  }

  /// 综合紧急程度评分（状态 + 紧急级别）
  int get compositeUrgencyScore {
    return status.urgencyScore + urgency.score * 10;
  }

  // ── 地址收敛逻辑 ─────────────────────────────────────────────

  /// 计算地址置信度 (0.0 ~ 1.0)
  static double calculateLocationConfidence(String location) {
    if (location.isEmpty) return 0.0;
    double score = 0.0;

    // 加分项
    if (RegExp(r'省|市|区|县').hasMatch(location)) score += 0.2;
    if (RegExp(r'小区|花园|公寓|家园|苑|庄|村').hasMatch(location)) score += 0.2;
    if (RegExp(r'门店|驿站|快递柜|超市|代收点').hasMatch(location)) score += 0.2;
    if (location.length > 10) score += 0.1;

    // 减分项
    if (RegExp(r'[^\u4e00-\u9fa5a-zA-Z0-9\s·\-_]').hasMatch(location)) score -= 0.2;
    if (location.length < 4) score -= 0.2;

    return score.clamp(0.0, 1.0);
  }

  /// 收敛 canonicalLocation
  /// 规则：
  /// 1. 新地址更长 → 替换
  /// 2. 新地址包含旧地址 → 替换
  /// 3. 新地址置信度更高 → 替换
  static String resolveCanonicalLocation({
    required String existing,
    required String incoming,
    required double existingConfidence,
    required double incomingConfidence,
  }) {
    if (incoming.isEmpty) return existing;
    if (existing.isEmpty) return incoming;

    // 规则1: 新地址更长（更完整）
    if (incoming.length > existing.length) return incoming;

    // 规则2: 新地址包含旧地址（更具体）
    if (incoming.contains(existing)) return incoming;

    // 规则3: 新地址置信度更高
    if (incomingConfidence > existingConfidence) return incoming;

    return existing;
  }
}
