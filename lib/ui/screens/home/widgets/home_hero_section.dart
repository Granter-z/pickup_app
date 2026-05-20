/// 首页 Hero 区域 - 极简白话文案
///
/// 设计理念：
/// 1. 去掉所有图标装饰和设计师自嗨的符号
/// 2. 用最平实的日常白话："没拿"
/// 3. 让软件退化成生活本该有的背景板
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/package_provider.dart';
import '../../../../platform/storage/hive_package.dart';

class HomeHeroSection extends ConsumerWidget {
  const HomeHeroSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packages = ref.watch(pendingPackagesProvider);
    final remainingCount = packages.where((p) => p.status.isPending).length;
    final isCleared = remainingCount == 0;

    if (isCleared) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48.0),
        child: Center(
          child: Text(
            "今天的快递已经都处理好了。",
            style: TextStyle(
              fontSize: 14.5,
              color: Colors.black45,
              letterSpacing: 0.1,
            ),
          ),
        ),
      );
    }

    // 回归最朴素的生活白话：没拿。
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0),
      child: Text(
        "今天还有 $remainingCount 个快递没拿。",
        style: const TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w400, // 放弃加粗，用最平和的字重
          color: Colors.black87,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}
