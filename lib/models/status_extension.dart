import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import 'package_model.dart';

extension PackageStatusX on PackageStatus {
  String get label {
    switch (this) {
      case PackageStatus.transit:
        return '运送中';
      case PackageStatus.delivering:
        return '派送中';
      case PackageStatus.arrived:
        return '待取件';
      case PackageStatus.pickedUp:
        return '已取件';
    }
  }

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
    }
  }

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
    }
  }

  /// HeroCard priority score: higher = more urgent
  int get urgencyScore {
    switch (this) {
      case PackageStatus.arrived:
        return 85;
      case PackageStatus.delivering:
        return 50;
      case PackageStatus.transit:
        return 20;
      case PackageStatus.pickedUp:
        return 0;
    }
  }

  bool get isArrived => this == PackageStatus.arrived;
  bool get isPending => this != PackageStatus.pickedUp;
  bool get isCompleted => this == PackageStatus.pickedUp;
}
