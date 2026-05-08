import '../models/package_model.dart';

class ParsedPackage {
  final CourierType courier;
  final String pickupCode;
  final String trackingNumber;
  final String phoneLast4;
  final String location;
  final PackageStatus status;

  const ParsedPackage({
    required this.courier,
    required this.pickupCode,
    this.trackingNumber = '',
    this.phoneLast4 = '',
    required this.location,
    required this.status,
  });
}

class TextParser {
  // ── 1. preprocess ────────────────────────────────────────────

  static String preprocess(String text) {
    var cleaned = text;
    // 去除中文字符之间的空格（OCR 常见 artifact）
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'([一-鿿])\s+([一-鿿])'),
      (m) => '${m[1]}${m[2]}',
    );
    // 去除 UI 噪音
    cleaned = cleaned.replaceAll(RegExp(r'\d{1,2}:\d{2}\s*[APMapm]*'), '');
    cleaned =
        cleaned.replaceAll(RegExp(r'(?:5G|4G|LTE|WiFi?|信号|电量|\d+%)', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'[¥￥]\d+\.?\d*'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\d+亿补贴', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(
        RegExp(r'(?:领券后|抢购|立享|补贴|优惠券|限时)[^。\n]{0,30}'), '');
    // 每行去除首尾空格，过滤空行
    cleaned = cleaned
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .join('\n');
    return cleaned;
  }

  // ── 2. platform aliases ──────────────────────────────────────

  static const _platformAliases = {
    '菜鸟': '菜鸟驿站',
    '菜鸟裹裹': '菜鸟驿站',
    '顺丰': '顺丰速运',
    'SF': '顺丰速运',
    '京东': '京东快递',
    'JD': '京东快递',
    '中通': '中通快递',
    'ZTO': '中通快递',
    '圆通': '圆通速递',
    'YT': '圆通速递',
    '韵达': '韵达快递',
    '申通': '申通快递',
    '极兔': '极兔速递',
    '邮政': '邮政EMS',
    'EMS': '邮政EMS',
    '中国邮政': '邮政EMS',
    '德邦': '德邦快递',
    '百世': '百世快递',
    '拼多多': '拼多多',
    '淘宝': '淘宝',
    '天猫': '淘宝',
  };

  static const _specificCouriers = [
    '申通', '圆通', '中通', '韵达', '极兔', '顺丰', '邮政', '德邦', '百世', '京东',
  ];

  // ── 3. stage map ─────────────────────────────────────────────

  static const _stageMap = {
    '已签收': PackageStatus.pickedUp,
    '签收': PackageStatus.pickedUp,
    '代收': PackageStatus.pickedUp,
    '已到驿站': PackageStatus.arrived,
    '入驿站': PackageStatus.arrived,
    '到驿站': PackageStatus.arrived,
    '驿站入库': PackageStatus.arrived,
    '菜鸟驿站': PackageStatus.arrived,
    '已到菜鸟': PackageStatus.arrived,
    '入柜': PackageStatus.arrived,
    '已入柜': PackageStatus.arrived,
    '快递柜': PackageStatus.arrived,
    '丰巢': PackageStatus.arrived,
    '待取件': PackageStatus.arrived,
    '到营业部': PackageStatus.arrived,
    '营业部': PackageStatus.arrived,
    '网点': PackageStatus.arrived,
    '前台代收': PackageStatus.pickedUp,
    '物业代收': PackageStatus.pickedUp,
    '门卫代收': PackageStatus.pickedUp,
    '派送中': PackageStatus.delivering,
    '配送中': PackageStatus.delivering,
    '正在派送': PackageStatus.delivering,
    '已揽收': PackageStatus.transit,
    '揽收': PackageStatus.transit,
    '运输中': PackageStatus.transit,
    '已发出': PackageStatus.transit,
    '已发货': PackageStatus.transit,
    '已到达分拣': PackageStatus.transit,
    '分拣': PackageStatus.transit,
  };

  // ── 4. single parse ──────────────────────────────────────────

  static ParsedPackage parse(String text) {
    final raw = preprocess(text);

    return ParsedPackage(
      courier: _extractCourier(raw),
      pickupCode: _extractPickupCode(raw),
      trackingNumber: _extractTrackingNumber(raw),
      phoneLast4: _extractPhoneLast4(raw),
      location: _extractLocation(raw),
      status: _extractStatus(raw),
    );
  }

  // ── 5. multi-parse ───────────────────────────────────────────

  static List<ParsedPackage> parseMulti(String text) {
    final raw = preprocess(text);
    final boundaries = _findBoundaries(raw);

    if (boundaries.length <= 1) {
      return [parse(text)];
    }

    final commonHeader = boundaries[0] > 10 ? raw.substring(0, boundaries[0]) : '';

    final results = <ParsedPackage>[];
    for (var i = 0; i < boundaries.length; i++) {
      final start = boundaries[i];
      final end = i + 1 < boundaries.length ? boundaries[i + 1] : raw.length;
      var segment = raw.substring(start, end);
      if (commonHeader.isNotEmpty) segment = '$commonHeader\n$segment';
      results.add(parse(segment));
    }
    return results;
  }

  /// Returns start indices of each package boundary (pickup codes / bay codes).
  static List<int> _findBoundaries(String text) {
    final positions = <int>[];

    // 取件码 / 取货码
    final codeRe = RegExp(r'(?:取件码|取货码|提取码|验证码)[：:\s]*([A-Za-z0-9\-]{2,20})');
    for (final m in codeRe.allMatches(text)) {
      positions.add(m.start);
    }

    // 裸 bay 码 X-X-XXXX
    final bayRe = RegExp(r'\b(\d{1,2})-(\d{1,2})-(\d{2,4})\b');
    for (final m in bayRe.allMatches(text)) {
      if (!positions.any((p) => (p - m.start).abs() < 5)) {
        positions.add(m.start);
      }
    }

    positions.sort();
    return positions;
  }

  // ── extractors ───────────────────────────────────────────────

  static CourierType _extractCourier(String text) {
    final lower = text.toLowerCase();
    String? found;
    var maxLen = 0;

    for (final entry in _platformAliases.entries) {
      if (!lower.contains(entry.key.toLowerCase())) continue;
      final isSpecific =
          _specificCouriers.any((s) => entry.key.contains(s) || s.contains(entry.key));
      if (isSpecific || entry.key.length > maxLen) {
        maxLen = isSpecific ? 999 : entry.key.length;
        found = entry.value;
      }
    }

    if (found == null) return CourierType.other;
    return _courierFromName(found);
  }

  static CourierType _courierFromName(String name) {
    if (name.contains('顺丰')) return CourierType.sf;
    if (name.contains('京东')) return CourierType.jd;
    if (name.contains('中通')) return CourierType.zto;
    if (name.contains('韵达')) return CourierType.yd;
    if (name.contains('圆通')) return CourierType.yt;
    if (name.contains('申通')) return CourierType.sto;
    if (name.contains('EMS') || name.contains('邮政')) return CourierType.ems;
    return CourierType.other;
  }

  static String _extractPickupCode(String text) {
    // Priority 1: 取件码/取货码 + code
    final labelRe = RegExp(r'(?:取件码|取货码|提取码|验证码)[：:\s]*([A-Za-z0-9\-]{2,20})');
    final labelMatch = labelRe.firstMatch(text);
    if (labelMatch != null) {
      final code = labelMatch.group(1)!;
      if (!RegExp(r'^\d{10,}$').hasMatch(code)) return code;
    }

    // Priority 2: 码：XXXX
    final shortRe = RegExp(r'码[：:\s]*([A-Za-z0-9\-]{2,20})');
    final shortMatch = shortRe.firstMatch(text);
    if (shortMatch != null) {
      final code = shortMatch.group(1)!;
      if (!RegExp(r'^\d{10,}$').hasMatch(code)) return code;
    }

    // Priority 3: X-X-XXXX bay format
    final bayRe = RegExp(r'\b(\d{1,2})-(\d{1,2})-(\d{2,4})\b');
    final bayMatch = bayRe.firstMatch(text);
    if (bayMatch != null) return bayMatch.group(0)!;

    // Priority 4: 4-8 digit code (exclude tracking numbers)
    final digitRe = RegExp(r'\b(\d{4,8})\b');
    for (final m in digitRe.allMatches(text)) {
      final code = m.group(1)!;
      final before = text.substring(0, m.start);
      if (!RegExp(r'(?:单号|运单|订单|快递)\s*$').hasMatch(before) &&
          !RegExp(r'^(?:SF|JD|YT|ZTO)').hasMatch(code)) {
        return code;
      }
    }

    return '';
  }

  static String _extractLocation(String text) {
    // Priority 1: 菜鸟驿站标题格式 - "城市+区域+具体位置+店/驿站"
    final titlePatterns = [
      // 邢台信都区绿城诚园北门店
      RegExp(r'([\u4e00-\u9fa5]{2,6}(?:市|省|区|县|镇)[\u4e00-\u9fa5]{2,15}(?:店|驿站|网点|营业部|快递柜))'),
      // 绿城诚园北门对面大院驿站
      RegExp(r'([\u4e00-\u9fa5]{4,20}(?:驿站|营业部|网点|配送站|自提点|快递柜))'),
    ];

    for (final pattern in titlePatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        var loc = match.group(1)!.trim();
        loc = _cleanLocation(loc);
        if (loc.length >= 6 && !_isAdText(loc)) return loc;
      }
    }

    // Priority 2: "已到[XXXX]" / "入[XXXX]" 格式
    final bracketRe = RegExp(r'(?:到[达了]?|已到|入[了]?)[【\[]?([^】\]，。！\n]{2,30}?[站店柜中心部])');
    final bracketMatch = bracketRe.firstMatch(text);
    if (bracketMatch != null) {
      var loc = bracketMatch.group(1) ?? bracketMatch.group(0) ?? '';
      loc = loc.replaceFirst(RegExp(r'^[到达了入]+'), '').trim();
      loc = _cleanLocation(loc);
      if (loc.length >= 3 && !_isAdText(loc)) return loc;
    }

    // Priority 3: 扩展关键词搜索
    final keywords = [
      '驿站', '营业部', '网点', '配送站', '自提点', '快递柜',
      '店', '门面', '服务点', '代收点',
    ];

    String? bestLocation;
    var bestLength = 0;

    for (final kw in keywords) {
      final idx = text.indexOf(kw);
      if (idx != -1) {
        // 增加上下文范围至30个字符
        final start = (idx - 30).clamp(0, text.length);
        var candidate = text.substring(start, idx + kw.length).trim();

        // 清理候选地址
        candidate = _cleanLocation(candidate);

        // 选择最长的有效地址
        if (candidate.length > bestLength && candidate.length >= 4 && !_isAdText(candidate)) {
          bestLocation = candidate;
          bestLength = candidate.length;
        }
      }
    }

    return bestLocation ?? '';
  }

  /// 清理地址文本，移除常见的前缀噪音
  static String _cleanLocation(String raw) {
    var cleaned = raw;

    // 移除换行符和多余空格（解决地址断行问题）
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), '');
    cleaned = cleaned.replaceAll('\n', '');

    // 移除常见的 OCR 误识别前缀（图标文字、按钮文字等）
    final noisePrefixes = [
      '农场', '菜鸟', '官方', '推荐', '附近', '距离', '为您',
      '查看', '点击', '详情', '更多', '首页', '返回',
      '驿站', '取件', '包裹',
    ];

    for (final prefix in noisePrefixes) {
      if (cleaned.startsWith(prefix) && cleaned.length > prefix.length + 2) {
        cleaned = cleaned.substring(prefix.length);
        break; // 只移除第一个匹配的前缀
      }
    }

    // 移除特殊字符前缀
    cleaned = cleaned.replaceAll(RegExp(r'^[>\s\-•·]+'), '');
    cleaned = cleaned.replaceAll(RegExp(r'^[A-Za-z0-9]{1,3}[\s\-]'), '');

    return cleaned.trim();
  }

  /// 判断是否为广告或无关文本
  static bool _isAdText(String text) {
    final adKeywords = [
      '优惠', '补贴', '领券', '限时', '抢购', '补贴',
      '元', '¥', '￥', '折', '免费', '赠送',
      '广告', '推广', '推荐商品',
    ];
    return adKeywords.any((kw) => text.contains(kw));
  }

  static PackageStatus _extractStatus(String text) {
    // Longest keyword match
    PackageStatus? found;
    var bestLen = 0;

    for (final entry in _stageMap.entries) {
      if (!text.contains(entry.key)) continue;
      if (entry.key.length > bestLen) {
        found = entry.value;
        bestLen = entry.key.length;
      }
    }

    // Override: pickup code → force arrived
    final hasCode = RegExp(r'(?:取件码|取货码|提取码)').hasMatch(text) ||
        RegExp(r'\b\d{1,2}-\d{1,2}-\d{2,4}\b').hasMatch(text);
    if (hasCode) return PackageStatus.arrived;

    // Fallback
    if (found != null) return found;
    if (RegExp(r'签收[^0-9]|代收[^0-9]|已收[^0-9]').hasMatch(text)) return PackageStatus.pickedUp;
    if (RegExp(r'取件|提取|提货').hasMatch(text)) return PackageStatus.arrived;
    if (RegExp(r'派送|配送').hasMatch(text)) return PackageStatus.delivering;
    return PackageStatus.arrived;
  }

  // ── 6. tracking number extractor ──────────────────────────────

  static String _extractTrackingNumber(String text) {
    // Priority 1: explicit labels
    final labelPatterns = [
      RegExp(r'(?:快递单号|运单号|物流单号|包裹编号|单号)[：:\s]*([A-Za-z0-9]{10,25})'),
      RegExp(r'(?:中通速递|圆通速递|申通快递|韵达快递|极兔速递|顺丰速运)[^0-9]{0,10}([A-Za-z0-9]{10,20})'),
    ];

    for (final pattern in labelPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) return match.group(1)!;
    }

    // Priority 2: courier prefix patterns
    final courierPatterns = [
      RegExp(r'\b(SF\d{8,20})\b'), // SF Express
      RegExp(r'\b(JD\d{8,20})\b'), // JD Express
      RegExp(r'\b(ZTO?\d{10,20})\b', caseSensitive: false), // ZTO
      RegExp(r'\b(YT\d{8,20})\b'), // YTO
      RegExp(r'\b(YT88\d{10,20})\b'), // YTO new format
      RegExp(r'\b(\d{14,22})\b'), // Pure numeric long numbers
    ];

    for (final pattern in courierPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final number = match.group(1)!;
        // Exclude phone numbers (11 digits starting with 1)
        if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(number)) {
          return number;
        }
      }
    }

    return '';
  }

  // ── 7. phone number extractor ─────────────────────────────────

  static String _extractPhoneLast4(String text) {
    // Pattern 1: explicit "手机尾号" or "尾号" + 4 digits
    final tailRe = RegExp(r'(?:手机尾号|尾号|末四位)[号：:\s]*(\d{4})');
    final tailMatch = tailRe.firstMatch(text);
    if (tailMatch != null) return tailMatch.group(1)!;

    // Pattern 2: "手机号" or "电话" + masked number like 195****8491
    final maskedRe = RegExp(r'(?:手机|电话|机主)[号：:\s]*[\*]*1[3-9]\d[*\s]*(\d{4})');
    final maskedMatch = maskedRe.firstMatch(text);
    if (maskedMatch != null) return maskedMatch.group(1)!;

    // Pattern 3: full phone number (extract last 4 digits)
    final phoneRe = RegExp(r'\b(1[3-9]\d{9})\b');
    final phoneMatch = phoneRe.firstMatch(text);
    if (phoneMatch != null) {
      final full = phoneMatch.group(1)!;
      return full.substring(full.length - 4);
    }

    // Pattern 4: generic 4-digit code near "本人" or "收件人"
    final ownerRe = RegExp(r'(?:本人|收件人|机主)[^0-9]{0,20}(\d{4})\b');
    final ownerMatch = ownerRe.firstMatch(text);
    if (ownerMatch != null) return ownerMatch.group(1)!;

    return '';
  }
}
