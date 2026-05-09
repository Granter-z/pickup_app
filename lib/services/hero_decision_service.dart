/// HeroCard决策服务 - 兼容层
/// 
/// 职责：
/// 1. 提供向后兼容的API
/// 2. 委托给核心层处理
/// 3. 将核心层结果转换为UI层可用的格式
library;

import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../models/package_model.dart';
import '../core/engine/hero_card_engine.dart';
import '../core/engine/hero_card_state.dart';

// 重新导出核心层类型
export '../core/engine/hero_card_state.dart' show HeroBadgeType, EmotionState, SuggestedAction, HeroEmotionState;

/// HeroCard标签（UI层）
class HeroBadge {
  final String label;
  final HeroBadgeType type;

  const HeroBadge({required this.label, required this.type});
}

/// HeroCard决策（UI层）
class HeroCardDecision {
  final String title;
  final String? subtitle;
  final List<HeroBadge> badges;
  final IconData icon;
  final Color color;

  const HeroCardDecision({
    required this.title,
    this.subtitle,
    this.badges = const [],
    this.icon = Icons.local_shipping_outlined,
    this.color = AppColors.primary,
  });
}

/// HeroCard决策服务
class HeroDecisionService {
  /// 生成HeroCard决策
  static HeroCardDecision decide(List<Package> allPackages) {
    // 使用核心层引擎
    final coreState = HeroCardEngine.decide(allPackages);
    
    // 转换为UI层格式
    return _convertToUIFormat(coreState);
  }

  /// 将核心层结果转换为UI层格式
  static HeroCardDecision _convertToUIFormat(HeroCardState state) {
    final badges = state.badges.map((coreBadge) => HeroBadge(
      label: coreBadge.label,
      type: coreBadge.type,
    )).toList();
    
    // 根据Hero情绪状态选择颜色和图标
    final color = _getColorForHeroEmotion(state.heroEmotionState);
    final icon = _getIconForHeroEmotion(state.heroEmotionState);
    
    return HeroCardDecision(
      title: state.title,
      subtitle: state.subtitle,
      badges: badges,
      icon: icon,
      color: color,
    );
  }

  /// 根据Hero情绪状态获取颜色
  static Color _getColorForHeroEmotion(HeroEmotionState emotion) {
    switch (emotion) {
      case HeroEmotionState.relaxed:
        return AppColors.success;
      case HeroEmotionState.normal:
        return AppColors.primary;
      case HeroEmotionState.urgent:
        return AppColors.urgent;
    }
  }

  /// 根据Hero情绪状态获取图标
  static IconData _getIconForHeroEmotion(HeroEmotionState emotion) {
    switch (emotion) {
      case HeroEmotionState.relaxed:
        return Icons.check_circle_outline;
      case HeroEmotionState.normal:
        return Icons.local_shipping_outlined;
      case HeroEmotionState.urgent:
        return Icons.warning_amber_rounded;
    }
  }
}
