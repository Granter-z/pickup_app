/// 状态UI扩展 - 仅用于UI层
/// 
/// 职责：
/// 1. 提供颜色、图标等视觉属性
/// 2. 不包含业务逻辑
/// 3. 依赖Flutter Material Design
library;

import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../../core/models/package_status.dart';

/// 状态视觉属性扩展
extension PackageStatusUI on PackageStatus {
  /// 状态颜色
  Color get color {
    switch (this) {
      case PackageStatus.transit:
        return AppColors.textSecondary;
      case PackageStatus.delivering:
        return AppColors.warning;
      case PackageStatus.arrived:
        return AppColors.urgent;
      case PackageStatus.pickedUp:
        return AppColors.success;
      case PackageStatus.archived:
        return AppColors.textTertiary;
    }
  }

  /// 状态背景颜色
  Color get bgColor {
    switch (this) {
      case PackageStatus.transit:
        return const Color(0xFFF2F2F7);
      case PackageStatus.delivering:
        return AppColors.warningBg;
      case PackageStatus.arrived:
        return AppColors.urgentBg;
      case PackageStatus.pickedUp:
        return AppColors.successBg;
      case PackageStatus.archived:
        return const Color(0xFFF2F2F7);
    }
  }
}
