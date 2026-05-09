import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../constants/app_constants.dart';
import '../../../../platform/storage/hive_package.dart';
import '../../../providers/package_provider.dart';
import 'package_card.dart';

class PackageList extends ConsumerWidget {
  const PackageList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packages = ref.watch(pendingPackagesProvider);
    final groupedPackages = ref.watch(groupedPendingPackagesProvider);

    if (packages.isEmpty) {
      return const _EmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '待取件',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              '${packages.length} 件',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        ...groupedPackages.entries.map((entry) =>
            _LocationGroup(
              location: entry.key,
              packages: entry.value,
            )),
      ],
    );
  }
}

class _LocationGroup extends StatelessWidget {
  final String location;
  final List<Package> packages;

  const _LocationGroup({
    required this.location,
    required this.packages,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 地址分组标题
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            children: [
              const Icon(
                Icons.location_on,
                size: 16,
                color: AppColors.textTertiary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  location,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${packages.length}件',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
        // 该地址下的包裹列表
        ...packages.map((pkg) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: PackageCard(package: pkg),
            )),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
        child: Column(
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              size: 48,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '没有待取的包裹',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textTertiary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
