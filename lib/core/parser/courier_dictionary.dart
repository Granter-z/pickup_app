/// 快递公司词典 - 纯数据配置
/// 
/// 职责：
/// 1. 定义快递公司关键词映射
/// 2. 定义平台别名
/// 3. 不包含任何逻辑
library;

import '../models/package.dart';

/// 快递公司词典
class CourierDictionary {
  /// 平台别名映射：关键词 → 标准名称
  static const Map<String, String> platformAliases = {
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
    'JT': '极兔速递',
    '邮政': '邮政EMS',
    'EMS': '邮政EMS',
    '中国邮政': '邮政EMS',
    '德邦': '德邦快递',
    'DB': '德邦快递',
    '百世': '百世快递',
    '拼多多': '拼多多',
    '淘宝': '淘宝',
    '天猫': '淘宝',
  };

  /// 具体快递公司关键词（优先级更高）
  static const List<String> specificCouriers = [
    '申通', '圆通', '中通', '韵达', '极兔', '顺丰', '邮政', '德邦', '百世', '京东',
  ];

  /// 标准名称 → CourierType 映射
  static const Map<String, CourierType> nameToType = {
    '顺丰速运': CourierType.sf,
    '京东快递': CourierType.jd,
    '中通快递': CourierType.zto,
    '韵达快递': CourierType.yd,
    '圆通速递': CourierType.yt,
    '申通快递': CourierType.sto,
    '邮政EMS': CourierType.ems,
    '极兔速递': CourierType.jt,
    '德邦快递': CourierType.db,
    '百世快递': CourierType.best,
  };

  /// 从标准名称获取CourierType
  static CourierType getCourierType(String name) {
    for (final entry in nameToType.entries) {
      if (name.contains(entry.key)) {
        return entry.value;
      }
    }
    return CourierType.other;
  }
}
