/// OCR 冲突检测器
/// 
/// 职责：
/// 1. 检测 OCR 文本中的信号冲突
/// 2. 判断 transit signals 和 arrival signals 是否同时存在
/// 3. 返回冲突级别
library;

/// 冲突级别
enum ParseConflictLevel {
  /// 无冲突
  none,
  
  /// 低冲突（可能有噪音）
  low,
  
  /// 高冲突（transit 和 arrival 同时存在）
  high,
}

/// 冲突分析结果
class ConflictAnalysisResult {
  /// 是否存在运输中信号
  final bool hasTransitSignals;
  
  /// 是否存在已到达信号
  final bool hasArrivalSignals;
  
  /// 是否存在取件信号
  final bool hasPickupSignals;
  
  /// 冲突级别
  final ParseConflictLevel level;
  
  /// 检测到的运输中关键词
  final List<String> detectedTransitKeywords;
  
  /// 检测到的已到达关键词
  final List<String> detectedArrivalKeywords;

  const ConflictAnalysisResult({
    required this.hasTransitSignals,
    required this.hasArrivalSignals,
    required this.hasPickupSignals,
    required this.level,
    this.detectedTransitKeywords = const [],
    this.detectedArrivalKeywords = const [],
  });

  /// 是否存在高冲突
  bool get isHighConflict => level == ParseConflictLevel.high;
  
  /// 是否应该进入待确认区
  bool get shouldPendingConfirmation => isHighConflict;
}

/// OCR 冲突检测器
class ConflictDetector {
  /// 运输中信号关键词
  static const List<String> _transitSignals = [
    '运输中', '已发往', '离开转运中心', '运输路线',
    '已发出', '已发货', '已揽收', '分拣中',
    '在路上', '运输途中', '物流运输',
    '转运中心', '分拨中心', '集运仓',
  ];

  /// 已到达/待取件信号关键词
  static const List<String> _arrivalSignals = [
    '待取件', '已放至代收点', '已到驿站', '请及时领取',
    '已到达', '已入库', '请取件', '来取',
    '驿站', '快递柜', '丰巢', '营业部',
    '取件码', '收件码', '凭码',
  ];

  /// 取件动作信号关键词
  static const List<String> _pickupSignals = [
    '取件', '提取', '提货', '领取', '收取',
    '签收', '代收', '已收', '已取',
  ];

  /// 分析文本中的信号冲突
  static ConflictAnalysisResult analyze(String text) {
    final detectedTransit = <String>[];
    final detectedArrival = <String>[];
    
    // 检测运输中信号
    for (final keyword in _transitSignals) {
      if (text.contains(keyword)) {
        detectedTransit.add(keyword);
      }
    }
    
    // 检测已到达信号
    for (final keyword in _arrivalSignals) {
      if (text.contains(keyword)) {
        detectedArrival.add(keyword);
      }
    }
    
    // 检测取件动作信号
    final hasPickupSignals = _pickupSignals.any((kw) => text.contains(kw));
    
    final hasTransitSignals = detectedTransit.isNotEmpty;
    final hasArrivalSignals = detectedArrival.isNotEmpty;
    
    // 判断冲突级别
    final level = _determineConflictLevel(
      hasTransitSignals: hasTransitSignals,
      hasArrivalSignals: hasArrivalSignals,
      hasPickupSignals: hasPickupSignals,
      detectedTransit: detectedTransit,
      detectedArrival: detectedArrival,
    );
    
    return ConflictAnalysisResult(
      hasTransitSignals: hasTransitSignals,
      hasArrivalSignals: hasArrivalSignals,
      hasPickupSignals: hasPickupSignals,
      level: level,
      detectedTransitKeywords: detectedTransit,
      detectedArrivalKeywords: detectedArrival,
    );
  }

  /// 确定冲突级别
  static ParseConflictLevel _determineConflictLevel({
    required bool hasTransitSignals,
    required bool hasArrivalSignals,
    required bool hasPickupSignals,
    required List<String> detectedTransit,
    required List<String> detectedArrival,
  }) {
    // 高冲突：transit 和 arrival 同时存在
    if (hasTransitSignals && hasArrivalSignals) {
      return ParseConflictLevel.high;
    }
    
    // 低冲突：只有 arrival，但没有取件动作
    if (hasArrivalSignals && !hasPickupSignals) {
      return ParseConflictLevel.low;
    }
    
    // 无冲突
    return ParseConflictLevel.none;
  }
}
