/// 包裹详情页
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/models/package.dart';
import '../../../core/models/logistics_event.dart';
import '../../../core/models/package_status.dart';
import '../../../ui/constants/app_constants.dart';
import '../../../ui/theme/status_extension.dart';

/// 包裹详情页
class PackageDetailPage extends StatelessWidget {
  final Package package;

  const PackageDetailPage(this.package, {super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('${package.courier.shortName}详情'),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 顶部包裹信息
            _buildPackageInfo(),
            const Divider(height: 1),
            // 事件列表
            Expanded(
              child: _buildEventList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPackageInfo() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 状态和取件码
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: package.status.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  package.status.label,
                  style: TextStyle(
                    color: package.status.color,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              if (package.pickupCode.isNotEmpty)
                Expanded(
                  child: Text(
                    '取件码: ${package.pickupCode}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // 驿站
          if (package.displayLocation.isNotEmpty)
            Row(
              children: [
                const Icon(
                  CupertinoIcons.location_solid,
                  size: 16,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    package.displayLocation,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildEventList() {
    // 按时间排序，最新在最上面
    final events = [...package.events];
    events.sort((a, b) => b.time.compareTo(a.time));

    if (events.isEmpty) {
      return const Center(
        child: Text(
          '暂无事件记录',
          style: TextStyle(
            color: AppColors.textTertiary,
            fontSize: 15,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        return CupertinoListTile(
          title: Text(
            getEventTitle(event.type),
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textPrimary,
            ),
          ),
          subtitle: Text(
            _formatTime(event.time),
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textTertiary,
            ),
          ),
        );
      },
    );
  }

  String getEventTitle(LogisticsEventType type) {
    switch (type) {
      case LogisticsEventType.packageCreated:
        return '包裹已创建';
      case LogisticsEventType.shipped:
        return '已发货';
      case LogisticsEventType.arrivedStation:
        return '已到站';
      case LogisticsEventType.outForDelivery:
        return '派送中';
      case LogisticsEventType.pickupCodeGenerated:
        return '已生成取件码';
      case LogisticsEventType.signed:
        return '已签收';
      case LogisticsEventType.delayed:
        return '包裹延迟';
      case LogisticsEventType.exception:
        return '包裹异常';
    }
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    final month = time.month.toString().padLeft(2, '0');
    final day = time.day.toString().padLeft(2, '0');
    return '$month-$day $hour:$minute';
  }
}
