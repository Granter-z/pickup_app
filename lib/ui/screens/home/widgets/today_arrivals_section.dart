import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../constants/app_constants.dart';
import '../../../../platform/storage/hive_package.dart';
import '../../../../core/models/pickup_urgency.dart';
import '../../../providers/package_classifier_provider.dart';

class TodayArrivalsSection extends ConsumerWidget {
  const TodayArrivalsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packages = ref.watch(todayPickupListProvider);

    if (packages.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              CupertinoIcons.clock_fill,
              size: 18,
              color: AppColors.info,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '今日到达',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '${packages.length} 件',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        ...packages.map((pkg) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _TodayArrivalCard(package: pkg),
            )),
      ],
    );
  }
}

class _TodayArrivalCard extends StatelessWidget {
  final Package package;

  const _TodayArrivalCard({required this.package});

  Color _getUrgencyColor() {
    switch (package.pickupUrgency) {
      case PickupUrgency.critical:
        return AppColors.urgent;
      case PickupUrgency.high:
        return AppColors.warning;
      case PickupUrgency.medium:
        return AppColors.info;
      case PickupUrgency.low:
        return AppColors.textTertiary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final urgencyColor = _getUrgencyColor();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.successBg,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Center(
              child: Icon(
                CupertinoIcons.cube_box_fill,
                size: 18,
                color: AppColors.success,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${package.courier.shortName} ${package.pickupCode}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  package.displayLocation,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            width: 4,
            height: 36,
            decoration: BoxDecoration(
              color: urgencyColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            package.pickupUrgency.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: urgencyColor,
            ),
          ),
        ],
      ),
    );
  }
}
