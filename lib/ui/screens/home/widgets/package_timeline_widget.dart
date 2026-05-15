/// 包裹时间线 Widget - 显示物流事件流
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../constants/app_constants.dart';
import '../../../theme/status_extension.dart';
import '../../../../core/models/package.dart';
import '../../../../core/models/logistics_event.dart';
import '../../../providers/event_provider.dart';

/// 包裹时间线 Widget
class PackageTimelineWidget extends ConsumerWidget {
  final Package package;

  const PackageTimelineWidget({super.key, required this.package});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(packageEventsProvider(package.id));

    if (events.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '物流轨迹',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ...events.asMap().entries.map((entry) {
            final index = entry.key;
            final event = entry.value;
            return _TimelineItem(
              event: event,
              isFirst: index == 0,
              isLast: index == events.length - 1,
            );
          }),
        ],
      ),
    );
  }
}

/// 时间线单项
class _TimelineItem extends StatelessWidget {
  final LogisticsEvent event;
  final bool isFirst;
  final bool isLast;

  const _TimelineItem({
    required this.event,
    required this.isFirst,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 时间线竖线和点
        SizedBox(
          width: 40,
          child: Column(
            children: [
              if (!isFirst)
                Container(
                  width: 2,
                  height: 12,
                  color: AppColors.border,
                ),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: _eventColor(event.type),
                  shape: BoxShape.circle,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.only(top: 4),
                    color: AppColors.border,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        // 事件内容
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    event.type.displayName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _SourceBadge(source: event.source),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                _formatTime(event.time),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                ),
              ),
              if (event.rawText != null && event.rawText!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    event.rawText!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ],
    );
  }

  Color _eventColor(LogisticsEventType type) {
    switch (type) {
      case LogisticsEventType.packageCreated:
        return AppColors.info;
      case LogisticsEventType.shipped:
        return AppColors.primary;
      case LogisticsEventType.arrivedStation:
        return AppColors.success;
      case LogisticsEventType.outForDelivery:
        return AppColors.primary;
      case LogisticsEventType.pickupCodeGenerated:
        return AppColors.success;
      case LogisticsEventType.signed:
        return AppColors.success;
      case LogisticsEventType.delayed:
        return AppColors.warning;
      case LogisticsEventType.exception:
        return AppColors.error;
    }
  }

  String _formatTime(DateTime time) {
    return DateFormat('yyyy-MM-dd HH:mm').format(time);
  }
}

/// 来源标签
class _SourceBadge extends StatelessWidget {
  final String source;

  const _SourceBadge({required this.source});

  @override
  Widget build(BuildContext context) {
    final (text, color) = _getSourceStyle(source);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }

  (String, Color) _getSourceStyle(String source) {
    switch (source) {
      case 'ocr':
        return ('OCR', AppColors.primary);
      case 'manual':
        return ('手动', AppColors.info);
      case 'notification':
        return ('通知', AppColors.warning);
      case 'mock':
        return ('模拟', AppColors.textTertiary);
      default:
        return (source, AppColors.textSecondary);
    }
  }
}
