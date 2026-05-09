import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../constants/app_constants.dart';
import '../../../../platform/storage/hive_package.dart';
import '../../../providers/package_provider.dart';

class CompletedSection extends ConsumerStatefulWidget {
  const CompletedSection({super.key});

  @override
  ConsumerState<CompletedSection> createState() => _CompletedSectionState();
}

class _CompletedSectionState extends ConsumerState<CompletedSection> {
  bool _expanded = false;

  void _showClearDialog(BuildContext context, int count) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('清除已完成'),
        content: Text('确定清除 $count 件已完成的包裹？'),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(packageListProvider.notifier).clearCompleted();
            },
            child: const Text('清除'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final completed = ref.watch(completedPackagesProvider);

    if (completed.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          behavior: HitTestBehavior.opaque,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    '已完成',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '${completed.length}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
              Row(
                children: [
                  GestureDetector(
                    onTap: () => _showClearDialog(context, completed.length),
                    child: const Icon(
                      CupertinoIcons.delete,
                      size: 18,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      CupertinoIcons.chevron_down,
                      size: 18,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Column(
            children: [
              const SizedBox(height: AppSpacing.md),
              ...completed.map((pkg) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _CompletedCard(package: pkg),
                  )),
            ],
          ),
          crossFadeState:
              _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }
}

class _CompletedCard extends StatelessWidget {
  final Package package;

  const _CompletedCard({required this.package});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(
            package.status == PackageStatus.archived
                ? CupertinoIcons.archivebox_fill
                : CupertinoIcons.checkmark_circle_fill,
            color: package.status == PackageStatus.archived
                ? AppColors.textTertiary
                : AppColors.success,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${package.courier.shortName} · ${package.description}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: package.status == PackageStatus.archived
                        ? AppColors.textTertiary
                        : AppColors.textSecondary,
                    decoration: package.status == PackageStatus.archived
                        ? TextDecoration.none
                        : TextDecoration.lineThrough,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (package.pickedUpAt != null)
                  Text(
                    '取件于 ${DateFormat('MM/dd HH:mm').format(package.pickedUpAt!)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
