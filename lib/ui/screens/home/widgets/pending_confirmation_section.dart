import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../constants/app_constants.dart';
import '../../../../platform/storage/hive_package.dart';
import '../../../../core/models/pending_confirmation.dart';
import '../../../providers/package_provider.dart';

/// 待确认包裹区域
class PendingConfirmationSection extends ConsumerWidget {
  const PendingConfirmationSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final confirmations = ref.watch(pendingConfirmationsProvider);

    if (confirmations.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              CupertinoIcons.question_circle,
              size: 18,
              color: AppColors.warning,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '待确认',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(width: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: AppColors.warningBg,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                '${confirmations.length}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.warning,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '以下识别结果置信度较低，请确认后再加入包裹列表',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textTertiary,
              ),
        ),
        const SizedBox(height: AppSpacing.md),
        ...confirmations.map((c) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: PendingConfirmationCard(confirmation: c),
            )),
      ],
    );
  }
}

/// 待确认包裹卡片
class PendingConfirmationCard extends ConsumerStatefulWidget {
  final PendingConfirmation confirmation;

  const PendingConfirmationCard({super.key, required this.confirmation});

  @override
  ConsumerState<PendingConfirmationCard> createState() =>
      _PendingConfirmationCardState();
}

class _PendingConfirmationCardState
    extends ConsumerState<PendingConfirmationCard> {
  bool _expanded = false;

  PendingConfirmation get confirmation => widget.confirmation;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: _confidenceColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          // 主内容区
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: AppSpacing.md),
                _buildFields(),
                if (confirmation.warnings.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _buildWarnings(),
                ],
              ],
            ),
          ),
          // 操作按钮
          _buildActions(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        // 快递公司图标
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _confidenceColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(
            _courierIcon,
            color: _confidenceColor,
            size: 18,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                confirmation.courier.displayName,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  _buildConfidenceBadge(),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '整体置信度 ${_formatConfidence(confirmation.confidence)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // 展开/收起按钮
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: AnimatedRotation(
            turns: _expanded ? 0.5 : 0,
            duration: const Duration(milliseconds: 200),
            child: const Icon(
              CupertinoIcons.chevron_down,
              size: 16,
              color: AppColors.textTertiary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFields() {
    return Column(
      children: [
        _buildFieldRow('取件码', confirmation.pickupCode,
            confirmation.fieldConfidence.pickupCode),
        _buildFieldRow('取货地点', confirmation.location,
            confirmation.fieldConfidence.location),
        _buildFieldRow('运单号', confirmation.trackingNumber,
            confirmation.fieldConfidence.trackingNumber),
        _buildFieldRow('状态', confirmation.status.label,
            confirmation.fieldConfidence.status),
      ],
    );
  }

  Widget _buildFieldRow(String label, String value, double confidence) {
    if (value.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textTertiary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          _buildFieldConfidence(confidence),
        ],
      ),
    );
  }

  Widget _buildFieldConfidence(double confidence) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _getFieldConfidenceColor(confidence).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        _formatConfidence(confidence),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _getFieldConfidenceColor(confidence),
        ),
      ),
    );
  }

  Widget _buildConfidenceBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _confidenceColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        confirmation.confidenceLabel,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _confidenceColor,
        ),
      ),
    );
  }

  Widget _buildWarnings() {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.warningBg,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          children: [
            const Icon(
              CupertinoIcons.exclamationmark_triangle,
              size: 14,
              color: AppColors.warning,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                '${confirmation.warnings.length} 个警告',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.warning,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.separator, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // 拒绝按钮
          Expanded(
            child: GestureDetector(
              onTap: _reject,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                decoration: const BoxDecoration(
                  border: Border(
                    right: BorderSide(color: AppColors.separator, width: 0.5),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.xmark,
                      size: 16,
                      color: AppColors.destructive,
                    ),
                    SizedBox(width: AppSpacing.xs),
                    Text(
                      '丢弃',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.destructive,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 确认按钮
          Expanded(
            child: GestureDetector(
              onTap: _confirm,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                color: AppColors.success.withValues(alpha: 0.1),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.checkmark,
                      size: 16,
                      color: AppColors.success,
                    ),
                    SizedBox(width: AppSpacing.xs),
                    Text(
                      '确认添加',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirm() {
    final package = ref
        .read(pendingConfirmationsProvider.notifier)
        .confirm(confirmation.id);
    if (package != null) {
      ref.read(packageListProvider.notifier).addPackage(package);
    }
  }

  void _reject() {
    ref.read(pendingConfirmationsProvider.notifier).reject(confirmation.id);
  }

  String _formatConfidence(double value) {
    return '${(value * 100).round()}%';
  }

  Color get _confidenceColor {
    if (confirmation.confidence >= 0.7) return AppColors.warning;
    if (confirmation.confidence >= 0.5) return AppColors.warning;
    return AppColors.destructive;
  }

  Color _getFieldConfidenceColor(double confidence) {
    if (confidence >= 0.8) return AppColors.success;
    if (confidence >= 0.6) return AppColors.warning;
    return AppColors.destructive;
  }

  IconData get _courierIcon {
    switch (confirmation.courier) {
      case CourierType.sf:
        return CupertinoIcons.cube_box_fill;
      case CourierType.jd:
        return CupertinoIcons.cart_fill;
      default:
        return Icons.inventory_2;
    }
  }
}
