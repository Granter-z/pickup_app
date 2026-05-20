import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../constants/app_constants.dart';
import '../../../../platform/storage/hive_package.dart';
import '../../../../core/models/pickup_urgency.dart';
import '../../../providers/package_classifier_provider.dart';

class PriorityQueueSection extends ConsumerWidget {
  const PriorityQueueSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final urgentPackages = ref.watch(urgentPackagesProvider);

    if (urgentPackages.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              CupertinoIcons.exclamationmark_triangle_fill,
              size: 18,
              color: AppColors.urgent,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '即将超时',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: AppColors.urgentBg,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                '${urgentPackages.length}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.urgent,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        ...urgentPackages.map((pkg) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _UrgentPackageCard(package: pkg),
            )),
      ],
    );
  }
}

class _UrgentPackageCard extends StatelessWidget {
  final Package package;

  const _UrgentPackageCard({required this.package});

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
        color: AppColors.urgentBg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.urgent.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: urgencyColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Center(
              child: Text(
                '!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: urgencyColor,
                ),
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
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: urgencyColor,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              package.pickupUrgency.label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
