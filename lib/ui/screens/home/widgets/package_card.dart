import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../constants/app_constants.dart';
import '../../../../platform/storage/hive_package.dart';
import '../../../providers/package_provider.dart';
import '../../../providers/event_provider.dart';
import '../package_detail_page.dart';

class PackageCard extends ConsumerWidget {
  final Package package;

  const PackageCard({super.key, required this.package});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Dismissible(
        key: ValueKey(package.id),
        direction: DismissDirection.endToStart,
        dismissThresholds: const {DismissDirection.endToStart: 0.45},

        // 关键：拉长离场和缩回的节奏，让它有一个极其舒缓的物理退场过程
        movementDuration: const Duration(milliseconds: 500), // 缓慢平滑地划走
        resizeDuration: const Duration(milliseconds: 400), // 列表用非常柔和的曲线慢慢收拢

        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 32),
          decoration: BoxDecoration(
            color: Colors.grey.shade50, // 仅仅是极浅的底色过渡，无声无息
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.done_rounded,
            color: Colors.grey.shade200, // 灰到几乎看不见，不邀功，不显眼
            size: 18,
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                package.courier.shortName,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w400, // 放弃加粗，用最平和的字重
                                  color: Colors.black87,
                                ),
                              ),
                              if (package.pickupCode.isNotEmpty) ...[
                                const SizedBox(width: AppSpacing.sm),
                                Text(
                                  '取件码 ${package.pickupCode}',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            package.description.isNotEmpty
                                ? package.description
                                : package.trackingNumber,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _timeAgo(package.addedAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
                if (package.displayLocation.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    package.displayLocation,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.grey.shade400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
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
