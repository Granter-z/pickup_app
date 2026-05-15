import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../constants/app_constants.dart';
import '../../../theme/status_extension.dart';
import '../../../../platform/storage/hive_package.dart';
import '../../../providers/package_provider.dart';
import '../../../providers/event_provider.dart';
import 'package_timeline_widget.dart';
import '../package_detail_page.dart';

class PackageCard extends ConsumerWidget {
  final Package package;

  const PackageCard({super.key, required this.package});

  IconData get _courierIcon {
    switch (package.courier) {
      case CourierType.sf:
        return CupertinoIcons.cube_box_fill;
      case CourierType.jd:
        return CupertinoIcons.cart_fill;
      default:
        return Icons.inventory_2;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(packageEventsProvider(package.id));
    final hasEvents = events.isNotEmpty;

    return Dismissible(
      key: ValueKey(package.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.xl),
        decoration: BoxDecoration(
          color: AppColors.success,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: const Icon(
          CupertinoIcons.checkmark_circle_fill,
          color: Colors.white,
          size: 28,
        ),
      ),
      confirmDismiss: (_) async {
        final confirmed = await showCupertinoDialog<bool>(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('确认取件'),
            content: Text('标记 ${package.courier.shortName} 包裹为已取件？'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消'),
              ),
              CupertinoDialogAction(
                isDestructiveAction: false,
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('确认'),
              ),
            ],
          ),
        );

        if (confirmed == true) {
          // 创建签收事件
          final aggregator = ref.read(eventAggregatorProvider);
          aggregator.createSignedEvent(package, source: 'manual');
          ref.read(packageListProvider.notifier).markPickedUp(package.id);
        }
        return false;
      },
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PackageDetailPage(package),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: package.status.bgColor,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Icon(
                      _courierIcon,
                      color: package.status.color,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              package.courier.shortName,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            if (package.pickupCode.isNotEmpty) ...[
                              const SizedBox(width: AppSpacing.sm),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.sm),
                                ),
                                child: Text(
                                  '取件码 ${package.pickupCode}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                            if (hasEvents) ...[
                              const SizedBox(width: AppSpacing.sm),
                              Icon(
                                CupertinoIcons.clock,
                                size: 14,
                                color: AppColors.textTertiary,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          package.description.isNotEmpty
                              ? package.description
                              : package.trackingNumber,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  _StatusBadge(status: package.status),
                ],
              ),
              if (package.displayLocation.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    const Icon(
                      CupertinoIcons.location_solid,
                      size: 14,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        package.displayLocation,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textTertiary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      _timeAgo(package.addedAt),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showTimelineDialog(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${package.courier.shortName} - 物流轨迹',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.pop(ctx),
                      child: const Icon(CupertinoIcons.xmark_circle_fill, color: AppColors.textTertiary),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: AppColors.separator),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.5,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: PackageTimelineWidget(package: package),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return DateFormat('MM/dd').format(dateTime);
  }
}

class _StatusBadge extends StatelessWidget {
  final PackageStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: status.bgColor,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: status.color,
        ),
      ),
    );
  }
}
