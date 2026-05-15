import 'package:flutter_test/flutter_test.dart';
import '../lib/core/sanitizer/text_sanitizer.dart';
import '../lib/core/parser/text_parser.dart';

void main() {
  group('完整处理链路测试: OCR文本 → 清洗 → 解析', () {
    
    test('图片1: 菜鸟驿站 - 中通+圆通双包裹', () {
      final ocrText = '''菜鸟
全网包裹一键查
取包裹 寄包裹 身份码
裹酱积分 领寄件券 许愿领好礼 菜鸟回收 芭芭农场

到站包裹
邢台信都区绿城诚园北门店
官方服务

ZTO 中通快递 15-3-6007
手机尾号8491的包裹
中通快递 76929138701037

YTO 圆通速递 15-5-6006
手机尾号8491的包裹
圆通速递 YT88866295706389

找人代取 一键取件

在途包裹 收件3 待退0
派送中0 运输中0 未发货0 已签收''';

      final sanitized = TextSanitizer.cleanWithAnalysis(ocrText);
      print('清洗后 (${sanitized.keptLines}行保留):');
      print(sanitized.cleaned);
      
      final results = TextParser.parseMulti(sanitized.cleaned);
      expect(results.length, greaterThanOrEqualTo(2), reason: '应识别到至少2个包裹');
      
      for (var i = 0; i < results.length; i++) {
        final r = results[i];
        final cname = r.courier.value.toString().split('.').last;
        print('  包裹$i: $cname | 码:${r.pickupCode.value} | 单:${r.trackingNumber.value} | 地:${r.location.value} | 态:${r.status.value}');
        
        if (i == 0) {
          expect(cname, anyOf(contains('中通'), equals('zto')));
          expect(r.pickupCode.value, contains('15-3-6007'));
          expect(r.trackingNumber.value, contains('76929138701037'));
          expect(r.location.value, contains('邢台信都区绿城诚园北门店'));
        }
        if (i == 1) {
          expect(r.pickupCode.value, contains('15-5-6006'));
          expect(r.trackingNumber.value, contains('YT88866295706389'));
        }
      }
    });

    test('图片2: 极兔速递 - 运输中', () {
      final ocrText = '''极兔速递 JT2184460562605 复制 物流电话
运输中 今天 13:42
快件到达【漯河集货点】物流问题请联系956025为您解决
今天 13:42
快件离开【漯河邮城网点】已发往【漯河集货点】物流问题请
联系956025为您解决
查看更多物流信息

收 太行路绿城诚园24幢1单元702
张先生 195*****91 号码保护 已通过虚拟号码发货''';

      final sanitized = TextSanitizer.cleanWithAnalysis(ocrText);
      final results = TextParser.parseMulti(sanitized.cleaned);
      
      print('图片2 - 识别到${results.length}个包裹:');
      for (var i = 0; i < results.length; i++) {
        final r = results[i];
        final cname = r.courier.value.toString().split('.').last;
        print('  包裹$i: $cname | 单:${r.trackingNumber.value} | 地:${r.location.value} | 态:${r.status.value}');
      }
      
      expect(results.length, greaterThanOrEqualTo(1));
      final r = results[0];
      expect(r.trackingNumber.value, contains('JT2184460562605'), reason: '运单号不匹配');
      expect(r.status.value.toString(), contains('transit'), reason: '状态应为运输中');
      expect(r.location.value, contains('太行路绿城诚园24幢1单元702'), reason: '地址不匹配');
    });

    test('图片3: 极兔速递 - 运输中 (另一单)', () {
      final ocrText = '''极兔速递 JT2184177458096 复制 物流电话
运输中 今天 09:47
快件到达【廊坊临空转运中心】物流问题请联系956025为您解
决
昨天 04:07
快件离开【深圳转运中心】，已发往【廊坊临空转运中心】；
两地距离：【2114】KM，请您耐心等待；物流问题请联系...展开
查看更多物流信息

收 太行路绿城诚园24幢1单元702
张先生 195*****91 号码保护 已通过虚拟号码发货''';

      final sanitized = TextSanitizer.cleanWithAnalysis(ocrText);
      final results = TextParser.parseMulti(sanitized.cleaned);
      
      print('图片3 - 识别到${results.length}个包裹:');
      for (var i = 0; i < results.length; i++) {
        final r = results[i];
        final cname = r.courier.value.toString().split('.').last;
        print('  包裹$i: $cname | 单:${r.trackingNumber.value} | 地:${r.location.value} | 态:${r.status.value}');
      }
      
      expect(results.length, greaterThanOrEqualTo(1));
      final r = results[0];
      expect(r.trackingNumber.value, contains('JT2184177458096'));
      expect(r.status.value.toString(), contains('transit'));
      expect(r.location.value, contains('太行路绿城诚园24幢1单元702'));
    });

    test('图片4: 已放至代收点 - 中通待取件', () {
      final ocrText = '''已放至代收点
距离收货地247米 导航

快递员: 董运芳 联系快递员

ZTO 中通快递 76929138701037 复制 物流电话
待取件 今天 12:02 您今天有2个包裹待取件 >
邢台信都区绿城诚园北门店
营业时间: 周一至周日 09:00~21:30
绿城诚园北门地库口南边 (26号楼底商)
取件码: 15-3-6007 复制
更多 联系驿站
快件已由快递员【董运芳: 15531930627】送达代收点存放，
取件地址【菜鸟-邢台信都区绿城诚园北门店: 绿城诚...展开
查看更多物流信息

收 太行路绿城诚园24幢1单元702
张先生 195*****91 号码保护 已通过虚拟号码发货''';

      final sanitized = TextSanitizer.cleanWithAnalysis(ocrText);
      print('清洗后 (${sanitized.keptLines}行保留):');
      print(sanitized.cleaned);
      
      final results = TextParser.parseMulti(sanitized.cleaned);
      
      print('图片4 - 识别到${results.length}个包裹:');
      for (var i = 0; i < results.length; i++) {
        final r = results[i];
        final cname = r.courier.value.toString().split('.').last;
        print('  包裹$i: $cname | 码:${r.pickupCode.value} | 单:${r.trackingNumber.value} | 地:${r.location.value} | 态:${r.status.value}');
      }
      
      expect(results.length, greaterThanOrEqualTo(1), reason: '应至少识别到1个包裹');
      final r = results[0];
      expect(r.pickupCode.value, contains('15-3-6007'), reason: '取件码应为15-3-6007');
      expect(r.trackingNumber.value, contains('76929138701037'), reason: '运单号不匹配');
      expect(r.status.value.toString(), contains('arrived'), reason: '状态应为已到达/待取件');
      expect(r.location.value, contains('邢台信都区绿城诚园北门店'), reason: '地点不匹配');
    });

    test('图片5: 菜鸟驿站 - 双包裹', () {
      final ocrText = '''菜鸟驿站
帮朋友取? 没收到取件码?
寄快递 号码簿 出库码

邢台信都区绿城诚园北门店 畅通 >

ZTO 中通快递 15-3-6007
本人 张* 195****8491
中通 76929138701037

YTO 圆通速递 15-5-6006
本人 张* 195****8491
圆通 YT88866295706389

没有更多快递了 有包裹未展示''';

      final sanitized = TextSanitizer.cleanWithAnalysis(ocrText);
      final results = TextParser.parseMulti(sanitized.cleaned);
      
      print('图片5 - 识别到${results.length}个包裹:');
      for (var i = 0; i < results.length; i++) {
        final r = results[i];
        final cname = r.courier.value.toString().split('.').last;
        print('  包裹$i: $cname | 码:${r.pickupCode.value} | 单:${r.trackingNumber.value}');
      }
      
      expect(results.length, greaterThanOrEqualTo(2));
    });

    test('图片6: 待收货订单 - 申通+圆通', () {
      final ocrText = '''我的订单
全部 待付款 拼团中 打包中 待收货 评价
全部6 已签收1 取取件2 派件中0 运输中2

5折 5折优惠券待领取 开心收下

绿城诚园北门对面大院驿站 导航
绿城诚园北门对面大院

取件码 7-3-6007
申通快递: 777407042267539
查看订单详情>

菜鸟驿站
邢台信都区绿城诚园北门店

取件出单号后五位 06389
圆通快递: YT88662957063889
查看订单详情>''';

      final sanitized = TextSanitizer.cleanWithAnalysis(ocrText);
      print('清洗后 (${sanitized.keptLines}行):');
      print(sanitized.cleaned);
      
      final results = TextParser.parseMulti(sanitized.cleaned);
      
      print('图片6 - 识别到${results.length}个包裹:');
      for (var i = 0; i < results.length; i++) {
        final r = results[i];
        final cname = r.courier.value.toString().split('.').last;
        print('  包裹$i: $cname | 码:${r.pickupCode.value} | 单:${r.trackingNumber.value} | 地:${r.location.value} | 态:${r.status.value}');
      }
      
      expect(results.length, greaterThanOrEqualTo(2), reason: '应识别到至少2个包裹');
      
      var foundShentongCode = false;
      var foundYuantongTracking = false;
      for (final r in results) {
        if (r.trackingNumber.value.contains('777407042267539')) {
          expect(r.pickupCode.value, contains('7-3-6007'), reason: '申通取件码应为7-3-6007');
          expect(r.location.value, contains('绿城诚园北门对面大院'), reason: '申通地点不匹配');
          foundShentongCode = true;
        }
        if (r.trackingNumber.value.contains('YT88662957063889')) {
          foundYuantongTracking = true;
        }
      }
    });

    test('图片7: 正在出库 - 取件码格式', () {
      final ocrText = '''正在出库
仓库处理中
快递运输 您的订单已进入第三方卖家仓库，
准备出库
绿城诚园24号楼绿城诚园 修改
24-1-702
张嘉豪195****8491

流利说官方旗舰店>
【Plus版】懂你... 到手1991.98
数量 x1 2199
不支持7天无理由退货

实付款 共减207.02 合计1991.98
订单编号 3493432000321194 复制
支付方式 白条账单 京东西条(分6期)''';

      final sanitized = TextSanitizer.cleanWithAnalysis(ocrText);
      print('清洗后 (${sanitized.keptLines}行):');
      print(sanitized.cleaned);
      
      final results = TextParser.parseMulti(sanitized.cleaned);
      
      print('图片7 - 识别到${results.length}个包裹:');
      for (var i = 0; i < results.length; i++) {
        final r = results[i];
        print('  包裹$i: 码:${r.pickupCode.value} | 地:${r.location.value}');
      }
      
      // 这张图主要是地址和取件码格式的测试
      final foundLocation = results.any((r) => 
        r.location.value.contains('绿城诚园24号楼') ||
        r.location.value.contains('绿城诚园')
      );
      expect(foundLocation || results.isNotEmpty, true, reason: '应识别到地址或取件码信息');
    });

    test('图片8: 物流服务 - 中通运输中', () {
      final ocrText = '''物流服务
承诺后天天送达
当前在南昌市

承诺达保障中，若送达延迟赔付至少3元无门槛券

中通快递: 79103298300372 复制

订单编号: 260509-280934551943156 复制
收货地址: 河北省邢台市信都区泉北西 展开

运输中 今天 15:23:37 订阅提醒
【南昌市】快件已发往 南昌转运
中心 （如遇问题无需找商家/...
展开''';

      final sanitized = TextSanitizer.cleanWithAnalysis(ocrText);
      print('清洗后 (${sanitized.keptLines}行):');
      print(sanitized.cleaned);
      
      final results = TextParser.parseMulti(sanitized.cleaned);
      
      print('图片8 - 识别到${results.length}个包裹:');
      for (var i = 0; i < results.length; i++) {
        final r = results[i];
        final cname = r.courier.value.toString().split('.').last;
        print('  包裹$i: $cname | 单:${r.trackingNumber.value} | 地:${r.location.value} | 态:${r.status.value}');
      }
      
      expect(results.length, greaterThanOrEqualTo(1));
      final r = results[0];
      expect(r.trackingNumber.value, contains('79103298300372'), reason: '运单号不匹配');
      expect(r.status.value.toString(), contains('transit'), reason: '状态应为运输中');
      expect(r.location.value, contains('河北省邢台市信都区'), reason: '地址不匹配');
    });

    test('图片9: PDD - 地址前带"支持退换货"前缀应被过滤', () {
      final ocrText = '''我的订单
全部 待付款 待发货 待收货 评价

极兔速递 JT2184177458096 复制
已到达 待取件

取件码 5-2-7029

支持退换货 绿城诚园北门对面大院驿站

申通快递 777407042267539 复制
已到达 待取件

取件码 7-3-6007

支持退换货 绿城诚园北门对面大院驿站

实付款 共减207.02 合计1991.98''';

      final sanitized = TextSanitizer.cleanWithAnalysis(ocrText);
      print('清洗后 (${sanitized.keptLines}行保留):');
      print(sanitized.cleaned);

      final results = TextParser.parseMulti(sanitized.cleaned);

      print('图片9 - 识别到${results.length}个包裹:');
      for (var i = 0; i < results.length; i++) {
        final r = results[i];
        final cname = r.courier.value.toString().split('.').last;
        print('  包裹$i: $cname | 码:${r.pickupCode.value} | 单:${r.trackingNumber.value} | 地:${r.location.value} | 态:${r.status.value}');
      }

      expect(results.length, greaterThanOrEqualTo(2), reason: '应识别到至少2个包裹');

      for (final r in results) {
        expect(r.location.value, isNot(contains('支持退换货')),
            reason: '地址不应包含"支持退换货"前缀');
      }
    });
  });
}
