import 'package:flutter/material.dart';
import '../../../constants/app_constants.dart';

class DateHeader extends StatelessWidget {
  const DateHeader({super.key});

  static const _weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateStr = '${now.month}月${now.day}日 ${_weekdays[now.weekday - 1]}';
    final hour = now.hour;

    String greeting;
    if (hour < 6) {
      greeting = '夜深了';
    } else if (hour < 12) {
      greeting = '早上好';
    } else if (hour < 14) {
      greeting = '中午好';
    } else if (hour < 18) {
      greeting = '下午好';
    } else {
      greeting = '晚上好';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          dateStr,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '$greeting，今天有快递要取吗？',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
      ],
    );
  }
}
