import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../constants/app_constants.dart';
import '../../../models/package_model.dart';
import '../../../providers/package_provider.dart';

class CompletedSection extends ConsumerStatefulWidget {
  const CompletedSection({super.key});

  @override
  ConsumerState<CompletedSection> createState() => _CompletedSectionState();
}

class _CompletedSectionState extends ConsumerState<CompletedSection> {
  bool _expanded = false;

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
          const Icon(
            CupertinoIcons.checkmark_circle_fill,
            color: AppColors.success,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${package.courier.shortName} · ${package.description}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                    decoration: TextDecoration.lineThrough,
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
