/// 空状态视图 - 极简设计
///
/// 设计理念：
/// 1. 不要用设计去填补空白
/// 2. "空"本身就是最大的心理释怀
/// 3. 极其克制，几乎退到幕后
library;

import 'package:flutter/material.dart';

class EmptyStateView extends StatelessWidget {
  const EmptyStateView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 90.0),
        child: Text(
          "今天已经没有需要惦记的取件码了。",
          style: TextStyle(
            fontSize: 14,
            color: Colors.black38, // 极其克制，几乎退到幕后
            letterSpacing: 0.1,
          ),
        ),
      ),
    );
  }
}
