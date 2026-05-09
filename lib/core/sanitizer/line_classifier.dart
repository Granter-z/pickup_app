/// 行分类器
/// 
/// 职责：
/// 1. 对 OCR 文本的每一行进行分类
/// 2. 区分物流信息、噪音、广告等
library;

import 'noise_dictionary.dart';
import 'logistics_keywords.dart';

/// 行类型
enum LineType {
  /// 物流信息行
  logistics,
  
  /// 取件码行
  pickupCode,
  
  /// 取件地点行
  pickupLocation,
  
  /// 地址行
  address,
  
  /// 联系信息行
  contact,
  
  /// 噪音行（广告、商品、UI等）
  noise,
  
  /// 未知行
  unknown,
}

/// 行分析结果
class LineAnalysis {
  final String text;
  final LineType type;
  final double confidence;
  final String? reason;

  const LineAnalysis({
    required this.text,
    required this.type,
    this.confidence = 0.5,
    this.reason,
  });

  /// 是否为有效物流信息
  bool get isLogisticsInfo => 
      type == LineType.logistics || 
      type == LineType.pickupCode || 
      type == LineType.pickupLocation;

  /// 是否为噪音
  bool get isNoise => type == LineType.noise;
}

/// 行分类器
class LineClassifier {
  /// 分析单行文本
  static LineAnalysis analyze(String line) {
    final trimmed = line.trim();
    
    // 空行
    if (trimmed.isEmpty) {
      return LineAnalysis(text: line, type: LineType.noise, confidence: 1.0, reason: 'empty');
    }

    // 太短的行（可能是噪音）
    if (trimmed.length < 3) {
      return LineAnalysis(text: line, type: LineType.noise, confidence: 0.8, reason: 'too_short');
    }

    // 检查是否为噪音
    if (_isNoiseLine(trimmed)) {
      return LineAnalysis(text: line, type: LineType.noise, confidence: 0.9, reason: 'noise_keywords');
    }

    // 检查是否为取件码行
    if (_isPickupCodeLine(trimmed)) {
      return LineAnalysis(text: line, type: LineType.pickupCode, confidence: 0.9, reason: 'pickup_code');
    }

    // 检查是否为取件地点行
    if (_isPickupLocationLine(trimmed)) {
      return LineAnalysis(text: line, type: LineType.pickupLocation, confidence: 0.8, reason: 'pickup_location');
    }

    // 检查是否为物流信息行
    if (_isLogisticsLine(trimmed)) {
      return LineAnalysis(text: line, type: LineType.logistics, confidence: 0.8, reason: 'logistics_keywords');
    }

    // 检查是否为地址行
    if (_isAddressLine(trimmed)) {
      return LineAnalysis(text: line, type: LineType.address, confidence: 0.7, reason: 'address_pattern');
    }

    // 检查是否为联系信息行
    if (_isContactLine(trimmed)) {
      return LineAnalysis(text: line, type: LineType.contact, confidence: 0.7, reason: 'contact_pattern');
    }

    // 未知行
    return LineAnalysis(text: line, type: LineType.unknown, confidence: 0.5, reason: 'unknown');
  }

  /// 分析多行文本
  static List<LineAnalysis> analyzeLines(String text) {
    final lines = text.split('\n');
    return lines.map((line) => analyze(line)).toList();
  }

  /// 检查是否为噪音行
  static bool _isNoiseLine(String line) {
    return NoiseDictionary.containsNoise(line);
  }

  /// 检查是否为取件码行
  static bool _isPickupCodeLine(String line) {
    // 包含取件码关键词
    if (LogisticsKeywords.pickupCodeKeywords.any((kw) => line.contains(kw))) {
      return true;
    }
    // 包含 bay 格式（如 15-3-6007）
    if (RegExp(r'\b\d{1,2}-\d{1,2}-\d{2,4}\b').hasMatch(line)) {
      return true;
    }
    return false;
  }

  /// 检查是否为取件地点行
  static bool _isPickupLocationLine(String line) {
    // 包含取件地点关键词
    if (LogisticsKeywords.pickupLocations.any((kw) => line.contains(kw))) {
      // 但排除物流节点
      if (!LogisticsKeywords.isLogisticsNode(line)) {
        return true;
      }
    }
    return false;
  }

  /// 检查是否为物流信息行
  static bool _isLogisticsLine(String line) {
    // 包含快递公司名称
    if (LogisticsKeywords.courierNames.any((kw) => line.contains(kw))) {
      return true;
    }
    // 包含运输状态
    if (LogisticsKeywords.transitStatus.any((kw) => line.contains(kw))) {
      return true;
    }
    // 包含取件状态
    if (LogisticsKeywords.arrivalStatus.any((kw) => line.contains(kw))) {
      return true;
    }
    return false;
  }

  /// 检查是否为地址行
  static bool _isAddressLine(String line) {
    // 包含地址关键词
    final addressKeywords = ['路', '街', '巷', '号', '栋', '单元', '室', '村', '镇', '区', '市', '省'];
    return addressKeywords.any((kw) => line.contains(kw));
  }

  /// 检查是否为联系信息行
  static bool _isContactLine(String line) {
    // 包含手机号
    if (RegExp(r'1[3-9]\d{9}').hasMatch(line)) {
      return true;
    }
    // 包含联系关键词
    if (LogisticsKeywords.contactKeywords.any((kw) => line.contains(kw))) {
      return true;
    }
    return false;
  }
}
