import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../constants/app_constants.dart';
import '../../../../platform/storage/hive_package.dart';
import '../../../providers/package_provider.dart';

final recentActivityProvider = Provider<List<Package>>((ref) {
  final packages = ref.watch(packageListProvider);
  final sorted = List<Package>.from(packages)
    ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
  return sorted.take(5).toList();
});

class RecentActivitySection extends ConsumerWidget {
  const RecentActivitySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentActivityProvider);

    if (recent.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '最近活动',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: AppSpacing.md),
        ...recent.map((pkg) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _ActivityItem(package: pkg),
            )),
      ],
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final Package package;

  const _ActivityItem({required this.package});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          Icon(
            _statusIcon,
            size: 16,
            color: _statusColor,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${package.courier.shortName} · ${package.status.label}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (package.displayLocation.isNotEmpty)
                  Text(
                    package.displayLocation,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Text(
            _formatTime(package.addedAt),
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  IconData get _statusIcon {
    switch (package.status) {
      case PackageStatus.transit:
        return CupertinoIcons.car_fill;
      case PackageStatus.delivering:
        return CupertinoIcons.person_fill;
      case PackageStatus.arrived:
        return CupertinoIcons.cube_box_fill;
      case PackageStatus.pickedUp:
        return CupertinoIcons.checkmark_circle_fill;
      case PackageStatus.archived:
        return CupertinoIcons.archivebox_fill;
    }
  }

  Color get _statusColor {
    switch (package.status) {
      case PackageStatus.transit:
        return AppColors.info;
      case PackageStatus.delivering:
        return AppColors.warning;
      case PackageStatus.arrived:
        return AppColors.success;
      case PackageStatus.pickedUp:
        return AppColors.textTertiary;
      case PackageStatus.archived:
        return AppColors.textTertiary;
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return DateFormat('MM/dd').format(dateTime);
  }
}
