/// 候选地址提取器
///
/// 职责：
/// 1. 从文本中提取地址候选
/// 2. 正向特征：区县路街小区苑号店驿站加分
/// 3. 负向特征：点击查看详情联系扣分
/// 4. score >= 1 为候选
library;

/// 候选地址提取器
class CandidateExtractor {
  // ── 正向特征权重 ──────────────────────────────────────────────

  /// 区/县
  static const double _districtWeight = 2.0;

  /// 路/街
  static const double _roadWeight = 2.0;

  /// 小区/苑/花园
  static const double _communityWeight = 1.5;

  /// 号/楼/栋/单元
  static const double _numberWeight = 1.0;

  /// 店/驿站/快递点
  static const double _pickupWeight = 1.5;

  // ── 负向特征权重 ──────────────────────────────────────────────

  /// 点击/查看/详情
  static const double _clickPenalty = -2.0;

  /// 联系/电话/客服
  static const double _contactPenalty = -1.5;

  // ── 候选阈值 ──────────────────────────────────────────────

  /// 最小候选分数
  static const double _minScore = 1.0;

  // ── 正向特征词库 ──────────────────────────────────────────────

  /// 区县后缀
  static const List<String> _districtSuffixes = [
    '区', '县', '市', '镇', '乡', '街道', '办事处',
  ];

  /// 路街后缀
  static const List<String> _roadSuffixes = [
    '路', '街', '道', '大道', '大街', '巷', '弄', '胡同',
  ];

  /// 小区苑后缀
  static const List<String> _communitySuffixes = [
    '小区', '苑', '花园', '公寓', '家园', '新村', '山庄', '别墅',
    '大厦', '广场', '中心', '城', '湾', '岛', '庭', '院', '坊',
  ];

  /// 号楼栋后缀
  static const List<String> _numberSuffixes = [
    '号', '楼', '栋', '单元', '室', '层', '层楼',
  ];

  /// 店驿站后缀
  static const List<String> _pickupSuffixes = [
    '店', '驿站', '快递点', '代收点', '自提点', '柜', '快递柜',
    '菜鸟', '妈妈驿站', '兔喜', '快递超市',
  ];

  // ── 负向特征词库 ──────────────────────────────────────────────

  /// 点击查看详情类
  static const List<String> _clickWords = [
    '点击', '查看', '详情', '了解', '更多', '展开', '收起',
    '立即', '马上', '赶紧', '赶快',
  ];

  /// 联系电话类
  static const List<String> _contactWords = [
    '联系', '电话', '客服', '热线', '咨询', '拨打', '致电',
    '微信', 'QQ', '在线',
  ];

  // ── 提取方法 ──────────────────────────────────────────────

  /// 从文本中提取候选地址列表
  ///
  /// 输入：OCR 原始文本或清洗后文本
  /// 输出：候选地址列表（按分数降序）
  static List<Candidate> extract(String text) {
    if (text.isEmpty) return [];

    // 按行分割
    final lines = text.split('\n');
    final candidates = <Candidate>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      // 计算分数
      final score = _calculateScore(line);

      // 判断是否为候选
      if (score >= _minScore) {
        candidates.add(Candidate(
          text: line,
          score: score,
          lineIndex: i,
        ));
      }
    }

    // 按分数降序排序
    candidates.sort((a, b) => b.score.compareTo(a.score));

    return candidates;
  }

  /// 从文本中提取最佳候选地址
  ///
  /// 返回分数最高的候选地址
  static Candidate? extractBest(String text) {
    final candidates = extract(text);
    return candidates.isNotEmpty ? candidates.first : null;
  }

  // ── 评分方法 ──────────────────────────────────────────────

  /// 计算候选分数
  static double _calculateScore(String text) {
    double score = 0.0;

    // 正向特征：区县
    for (final suffix in _districtSuffixes) {
      if (text.contains(suffix)) {
        score += _districtWeight;
        break;
      }
    }

    // 正向特征：路街
    for (final suffix in _roadSuffixes) {
      if (text.contains(suffix)) {
        score += _roadWeight;
        break;
      }
    }

    // 正向特征：小区苑
    for (final suffix in _communitySuffixes) {
      if (text.contains(suffix)) {
        score += _communityWeight;
        break;
      }
    }

    // 正向特征：号楼栋
    for (final suffix in _numberSuffixes) {
      if (text.contains(suffix)) {
        score += _numberWeight;
        break;
      }
    }

    // 正向特征：店驿站
    for (final suffix in _pickupSuffixes) {
      if (text.contains(suffix)) {
        score += _pickupWeight;
        break;
      }
    }

    // 负向特征：点击查看详情
    for (final word in _clickWords) {
      if (text.contains(word)) {
        score += _clickPenalty;
        break;
      }
    }

    // 负向特征：联系电话
    for (final word in _contactWords) {
      if (text.contains(word)) {
        score += _contactPenalty;
        break;
      }
    }

    return score;
  }
}

/// 候选地址
class Candidate {
  /// 候选文本
  final String text;

  /// 候选分数
  final double score;

  /// 行索引
  final int lineIndex;

  const Candidate({
    required this.text,
    required this.score,
    required this.lineIndex,
  });

  @override
  String toString() {
    return 'Candidate(text: $text, score: ${score.toStringAsFixed(2)}, lineIndex: $lineIndex)';
  }
}