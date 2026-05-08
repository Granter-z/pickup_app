import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../models/package_model.dart';
import '../models/status_extension.dart';

class HeroBadge {
  final String label;
  final HeroBadgeType type;

  const HeroBadge({required this.label, required this.type});
}

enum HeroBadgeType { count, urgent, location }

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

class HeroDecisionService {
  static HeroCardDecision decide(List<Package> allPackages) {
    final pending =
        allPackages.where((p) => p.status.isPending).toList();

    // 0件 → 今天暂无快递
    if (pending.isEmpty) {
      return const HeroCardDecision(
        title: '今天暂无快递',
        icon: Icons.check_circle_outline,
        color: AppColors.success,
      );
    }

    final arrived =
        pending.where((p) => p.status.isArrived).toList();
    final badges = <HeroBadge>[];

    badges.add(HeroBadge(
      label: '${pending.length} 件待处理',
      type: HeroBadgeType.count,
    ));

    final hasHighUrgency =
        pending.any((p) => p.status.urgencyScore > 80);
    if (hasHighUrgency) {
      badges.add(const HeroBadge(
        label: '紧急',
        type: HeroBadgeType.urgent,
      ));
    }

    final locationGroups = _groupByLocation(pending);
    final hasCluster = locationGroups.values.any((g) => g.length > 1);

    // Build title: arrived件数优先
    final title = arrived.isNotEmpty
        ? '有 ${arrived.length} 件快递待取件'
        : '有 ${pending.length} 个包裹在路上';

    // Build subtitle: 按优先级决策
    String? subtitle;
    if (hasHighUrgency) {
      subtitle = '建议立即取件';
    } else if (hasCluster) {
      subtitle = '建议一起取，节省跑腿';
    }

    return HeroCardDecision(
      title: title,
      subtitle: subtitle,
      badges: badges,
      icon: hasHighUrgency ? Icons.warning_amber_rounded : Icons.local_shipping_outlined,
      color: hasHighUrgency ? AppColors.urgent : AppColors.primary,
    );
  }

  static Map<String, List<Package>> _groupByLocation(List<Package> packages) {
    final map = <String, List<Package>>{};
    for (final p in packages) {
      final key = p.location.isNotEmpty ? p.location : 'unknown';
      map.putIfAbsent(key, () => []).add(p);
    }
    return map;
  }
}
