import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../constants/app_constants.dart';
import '../../providers/package_provider.dart';
import '../../../core/models/package.dart';
import '../../../core/models/logistics_event.dart';

class RoutesPage extends ConsumerWidget {
  const RoutesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packages = ref.watch(packageListProvider);
    final events = _collectEvents(packages);
    final grouped = _groupByDate(events);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: grouped.isEmpty
                  ? _buildEmptyState()
                  : _buildTimeline(grouped),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          Text(
            '物流动态',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  CupertinoIcons.time,
                  size: 14,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  '时间线',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.map,
            size: 64,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            '暂无物流动态',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '添加包裹后将显示物流轨迹',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(Map<String, List<_TimelineEvent>> grouped) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final date = grouped.keys.elementAt(index);
        final events = grouped[date]!;
        return _buildDateGroup(date, events);
      },
    );
  }

  Widget _buildDateGroup(String date, List<_TimelineEvent> events) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: _isToday(date) ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  date,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _isToday(date) ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${events.length} 条动态',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
        ...events.asMap().entries.map((entry) {
          final index = entry.key;
          final event = entry.value;
          final isLast = index == events.length - 1;
          return _buildTimelineItem(event, isLast);
        }),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }

  Widget _buildTimelineItem(_TimelineEvent event, bool isLast) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _getEventColor(event.type),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1,
                      color: AppColors.separator,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          event.courierName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        DateFormat('HH:mm').format(event.time),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    event.description,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (event.location != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          CupertinoIcons.location,
                          size: 12,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            event.location!,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textTertiary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<_TimelineEvent> _collectEvents(List<Package> packages) {
    final events = <_TimelineEvent>[];

    for (final package in packages) {
      for (final event in package.events) {
        events.add(_TimelineEvent(
          time: event.time,
          courierName: package.courier.displayName,
          description: event.type.displayName,
          location: event.rawText ?? '',
          type: event.type,
        ));
      }

      events.add(_TimelineEvent(
        time: package.addedAt,
        courierName: package.courier.displayName,
        description: '包裹添加到系统',
        location: package.displayLocation,
        type: LogisticsEventType.packageCreated,
      ));
    }

    events.sort((a, b) => b.time.compareTo(a.time));

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    return events.where((e) {
      final eventDate = DateTime(e.time.year, e.time.month, e.time.day);
      return eventDate.isAtSameMomentAs(today) || eventDate.isAtSameMomentAs(yesterday);
    }).toList();
  }

  Map<String, List<_TimelineEvent>> _groupByDate(List<_TimelineEvent> events) {
    final grouped = <String, List<_TimelineEvent>>{};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (final event in events) {
      final eventDate = DateTime(event.time.year, event.time.month, event.time.day);
      String dateStr;

      if (eventDate.isAtSameMomentAs(today)) {
        dateStr = '今天';
      } else if (eventDate.isAtSameMomentAs(yesterday)) {
        dateStr = '昨天';
      } else {
        dateStr = DateFormat('MM/dd').format(event.time);
      }

      grouped.putIfAbsent(dateStr, () => []).add(event);
    }

    return grouped;
  }

  bool _isToday(String date) => date == '今天';

  Color _getEventColor(LogisticsEventType type) {
    switch (type) {
      case LogisticsEventType.packageCreated:
        return AppColors.primary;
      case LogisticsEventType.signed:
        return AppColors.success;
      case LogisticsEventType.shipped:
        return AppColors.info;
      case LogisticsEventType.outForDelivery:
        return AppColors.warning;
      case LogisticsEventType.arrivedStation:
        return AppColors.success;
      case LogisticsEventType.pickupCodeGenerated:
        return AppColors.info;
      case LogisticsEventType.delayed:
        return AppColors.warning;
      case LogisticsEventType.exception:
        return AppColors.error;
      default:
        return AppColors.textTertiary;
    }
  }
}

class _TimelineEvent {
  final DateTime time;
  final String courierName;
  final String description;
  final String? location;
  final LogisticsEventType type;

  const _TimelineEvent({
    required this.time,
    required this.courierName,
    required this.description,
    this.location,
    required this.type,
  });
}
