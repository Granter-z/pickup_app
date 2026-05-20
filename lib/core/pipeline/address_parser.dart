/// 地址解析器（后缀识别方式）
///
/// 职责：
/// 1. 从文本中识别地址后缀
/// 2. 提取 city、district、community、poi 等字段
/// 3. 纯 Dart，不依赖 Flutter SDK
/// 4. 使用后缀识别，不使用 regex
library;

import '../address/parsed_address.dart';
import '../knowledge/address_suffixes.dart';

/// 地址解析器
///
/// 影子流水线策略：旧系统继续跑，新 pipeline 并行输出
class AddressParser {
  /// 解析地址文本
  ///
  /// 输入：地址文本（如 "邢台信都区绿城诚园北门店"）
  /// 输出：ParsedAddress 对象
  static ParsedAddress parse(String text) {
    if (text.isEmpty) {
      return ParsedAddress(rawText: text);
    }

    String? city;
    String? district;
    String? community;
    String? poi;

    // 提取城市
    city = _extractCity(text);

    // 提取区/县
    district = _extractDistrict(text);

    // 提取小区
    community = _extractCommunity(text);

    // 提取 POI
    poi = _extractPOI(text);

    return ParsedAddress(
      city: city,
      district: district,
      community: community,
      poi: poi,
      rawText: text,
    );
  }

  /// 提取城市
  ///
  /// 从文本中查找已知城市名称
  static String? _extractCity(String text) {
    // 常见城市列表（简化版）
    const cities = [
      '北京', '天津', '上海', '重庆',
      '石家庄', '唐山', '秦皇岛', '邯郸', '邢台', '保定', '张家口', '承德', '沧州', '廊坊', '衡水',
      '太原', '大同', '阳泉', '长治', '晋城', '朔州', '晋中', '运城', '忻州', '临汾', '吕梁',
      '呼和浩特', '包头', '乌海', '赤峰', '通辽', '鄂尔多斯', '呼伦贝尔', '巴彦淖尔', '乌兰察布',
      '沈阳', '大连', '鞍山', '抚顺', '本溪', '丹东', '锦州', '营口', '阜新', '辽阳', '盘锦', '铁岭', '朝阳', '葫芦岛',
      '长春', '吉林', '四平', '辽源', '通化', '白山', '松原', '白城',
      '哈尔滨', '齐齐哈尔', '鸡西', '鹤岗', '双鸭山', '大庆', '伊春', '佳木斯', '七台河', '牡丹江', '黑河', '绥化',
      '南京', '无锡', '徐州', '常州', '苏州', '南通', '连云港', '淮安', '盐城', '扬州', '镇江', '泰州', '宿迁',
      '杭州', '宁波', '温州', '嘉兴', '湖州', '绍兴', '金华', '衢州', '舟山', '台州', '丽水',
      '合肥', '芜湖', '蚌埠', '淮南', '马鞍山', '淮北', '铜陵', '安庆', '黄山', '滁州', '阜阳', '宿州', '六安', '亳州', '池州', '宣城',
      '福州', '厦门', '莆田', '三明', '泉州', '漳州', '南平', '龙岩', '宁德',
      '南昌', '景德镇', '萍乡', '九江', '新余', '鹰潭', '赣州', '吉安', '宜春', '抚州', '上饶',
      '济南', '青岛', '淄博', '枣庄', '东营', '烟台', '潍坊', '济宁', '泰安', '威海', '日照', '临沂', '德州', '聊城', '滨州', '菏泽',
      '郑州', '开封', '洛阳', '平顶山', '安阳', '鹤壁', '新乡', '焦作', '濮阳', '许昌', '漯河', '三门峡', '南阳', '商丘', '信阳', '周口', '驻马店',
      '武汉', '黄石', '十堰', '宜昌', '襄阳', '鄂州', '荆门', '孝感', '荆州', '黄冈', '咸宁', '随州',
      '长沙', '株洲', '湘潭', '衡阳', '邵阳', '岳阳', '常德', '张家界', '益阳', '郴州', '永州', '怀化', '娄底',
      '广州', '韶关', '深圳', '珠海', '汕头', '佛山', '江门', '湛江', '茂名', '肇庆', '惠州', '梅州', '汕尾', '河源', '阳江', '清远', '东莞', '中山', '潮州', '揭阳', '云浮',
      '南宁', '柳州', '桂林', '梧州', '北海', '防城港', '钦州', '贵港', '玉林', '百色', '贺州', '河池', '来宾', '崇左',
      '海口', '三亚', '三沙', '儋州',
      '成都', '自贡', '攀枝花', '泸州', '德阳', '绵阳', '广元', '遂宁', '内江', '乐山', '南充', '眉山', '宜宾', '广安', '达州', '雅安', '巴中', '资阳',
      '贵阳', '六盘水', '遵义', '安顺', '毕节', '铜仁',
      '昆明', '曲靖', '玉溪', '保山', '昭通', '丽江', '普洱', '临沧',
      '拉萨', '日喀则', '昌都', '林芝', '山南', '那曲',
      '西安', '铜川', '宝鸡', '咸阳', '渭南', '延安', '汉中', '榆林', '安康', '商洛',
      '兰州', '嘉峪关', '金昌', '白银', '天水', '武威', '张掖', '平凉', '酒泉', '庆阳', '定西', '陇南',
      '西宁', '海东',
      '银川', '石嘴山', '吴忠', '固原', '中卫',
      '乌鲁木齐', '克拉玛依', '吐鲁番', '哈密',
    ];

    for (final city in cities) {
      if (text.contains(city)) {
        return city;
      }
    }
    return null;
  }

  /// 提取区/县
  ///
  /// 使用后缀识别方式，从文本中提取区/县
  static String? _extractDistrict(String text) {
    for (final suffix in AddressSuffixes.districtSuffixes) {
      final index = text.lastIndexOf(suffix);
      if (index > 0) {
        // 向前查找 2-4 个汉字作为区/县名
        final start = _findStartIndex(text, index, 2, 4);
        if (start >= 0) {
          return text.substring(start, index + suffix.length);
        }
      }
    }
    return null;
  }

  /// 提取小区
  ///
  /// 使用后缀识别方式，从文本中提取小区
  static String? _extractCommunity(String text) {
    for (final suffix in AddressSuffixes.communitySuffixes) {
      final index = text.lastIndexOf(suffix);
      if (index > 0) {
        // 向前查找 2-6 个汉字作为小区名
        final start = _findStartIndex(text, index, 2, 6);
        if (start >= 0) {
          return text.substring(start, index + suffix.length);
        }
      }
    }
    return null;
  }

  /// 提取 POI
  ///
  /// 使用后缀识别方式，从文本中提取 POI
  static String? _extractPOI(String text) {
    for (final suffix in AddressSuffixes.poiSuffixes) {
      final index = text.lastIndexOf(suffix);
      if (index > 0) {
        // 向前查找 2-4 个汉字作为 POI 名
        final start = _findStartIndex(text, index, 2, 4);
        if (start >= 0) {
          return text.substring(start, index + suffix.length);
        }
      }
    }
    return null;
  }

  /// 查找起始索引
  ///
  /// 从 endIndex 向前查找 minLen-maxLen 个汉字
  static int _findStartIndex(String text, int endIndex, int minLen, int maxLen) {
    int count = 0;
    int start = endIndex;

    // 向前查找汉字
    while (start > 0 && count < maxLen) {
      start--;
      if (_isChinese(text[start])) {
        count++;
      } else {
        break;
      }
    }

    // 检查是否满足最小长度
    if (count >= minLen) {
      return start;
    }

    return -1;
  }

  /// 判断是否为汉字
  static bool _isChinese(String char) {
    if (char.isEmpty) return false;
    final code = char.codeUnitAt(0);
    return code >= 0x4e00 && code <= 0x9fa5;
  }
}
