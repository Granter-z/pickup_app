library;

/// Mock 数据加载器
/// 用于读取测试短信内容
class MockDataLoader {
  /// 所有可用的测试文件名称
  static const List<String> testFiles = [
    'arrival_sms.txt',
    'duplicate_sms.txt',
    'signed_sms.txt',
    'delay_sms.txt',
    'bad_ocr.txt',
    'bad_ocr_2.txt',
    'bad_ocr_3.txt',
    'bad_ocr_4.txt',
    'sto_arrival.txt',
    'yt_arrival.txt',
    'zto_arrival.txt',
    'jd_delivering.txt',
    'sf_pickup.txt',
    'pdd_arrival.txt',
    'douyin_arrival.txt',
    'multi_package.txt',
    'exception.txt',
    'partial_info.txt',
    'code_only.txt',
    'complex_code.txt',
  ];

  /// 获取测试文件的元信息（名称、分类）
  static Map<String, String> getFileInfo(String filename) {
    String category;

    if (filename.contains('arrival') || filename.contains('pickup')) {
      category = '到达通知';
    } else if (filename.contains('delivering') || filename.contains('delay')) {
      category = '配送状态';
    } else if (filename.contains('bad_ocr')) {
      category = 'OCR错误测试';
    } else if (filename.contains('signed') || filename.contains('exception')) {
      category = '特殊事件';
    } else if (filename.contains('multi') || filename.contains('code')) {
      category = '复杂场景';
    } else if (filename.contains('pdd') || filename.contains('douyin')) {
      category = '电商平台';
    } else if (filename.contains('sto') || filename.contains('yt') || filename.contains('zto')) {
      category = '快递商测试';
    } else {
      category = '其他';
    }

    return {
      'name': filename,
      'category': category,
    };
  }

  /// 读取测试文件内容
  static Future<String> loadFile(String filename) async {
    return _getContent(filename);
  }

  /// 获取测试内容
  static String _getContent(String filename) {
    switch (filename) {
      case 'arrival_sms.txt':
        return '【菜鸟】您的快递已到邢台信都区绿城诚园北门店，取件码4431，请及时领取。';
      case 'duplicate_sms.txt':
        return '【菜鸟】尾号1234的包裹已到站，取件码4431。';
      case 'signed_sms.txt':
        return '【顺丰速运】您的快件已由物业代收，感谢使用顺丰。';
      case 'delay_sms.txt':
        return '【韵达快递】您的快递因天气原因延迟送达，预计明天到达，请留意后续通知。';
      case 'bad_ocr.txt':
        return '您的块递已到形台绿成城园北们店，码443I';
      case 'bad_ocr_2.txt':
        return '您的快弟已到邢合绿成诚园北门店，码4431及吋领职';
      case 'bad_ocr_3.txt':
        return '【菜乌】您的包裏已到邢合信都区绿城诚园北门店，取件码4431请及吋领取';
      case 'bad_ocr_4.txt':
        return '【园通速递】您的快仲已到刑台信都绿诚园北门店，取件码7—3—6O07';
      case 'sto_arrival.txt':
        return '【申通快递】您的包裹已到达邢台市桥西区世纪花园南门驿站，请凭取件码5-1-1008取件。';
      case 'yt_arrival.txt':
        return '【圆通速递】您的快件已送达，请凭取件码7-3-6007到邢台信都区锦绣鹏程东门店领取。';
      case 'zto_arrival.txt':
        return '【中通快递】您的快递已到邢台桥东区阳光国际北门快递站，取件码8812，请于24小时内取件。';
      case 'jd_delivering.txt':
        return '【京东物流】您的京东订单正在派送中，配送员张师傅，电话13812345678，预计14:00前送达。';
      case 'sf_pickup.txt':
        return '【顺丰速运】您的快件SF1234567890已到达顺丰速运营业点，请凭有效证件领取。';
      case 'pdd_arrival.txt':
        return '【拼多多】您在拼多多购买的商品已发货，运单号YT8866295706389，预计3天内送达。';
      case 'douyin_arrival.txt':
        return '【抖音电商】您的订单已发货，物流单号为中通73186452345678，请注意查收。';
      case 'multi_package.txt':
        return '【菜鸟驿站】您有2个包裹到达邢台信都区绿城诚园北门店，取件码分别为4431和4432，请及时取件。';
      case 'exception.txt':
        return '【韵达快递】您的快递出现异常，联系不上收件人，请尽快联系快递员确认收货地址。';
      case 'partial_info.txt':
        return '取件码5566，请到小区西门快递点取件';
      case 'code_only.txt':
        return '取件码：8812';
      case 'complex_code.txt':
        return '【丰巢】您的快递已存入丰巢柜，请凭取件码A2-2301到邢台市信都区绿城诚园北门店丰巢柜取件。';
      default:
        return '';
    }
  }
}
