import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../constants/app_constants.dart';
import '../../providers/package_provider.dart';
import '../../../platform/notification/notification_listener_service.dart';
import 'help_feedback_page.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xl,
          ),
          children: [
            _buildHeader(),
            const SizedBox(height: AppSpacing.xxl),
            _buildSection(
              title: 'OCR 设置',
              children: [
                _buildSettingItem(
                  icon: CupertinoIcons.text_cursor,
                  title: '自动识别',
                  subtitle: '截图后自动识别快递信息',
                  trailing: CupertinoSwitch(
                    value: true,
                    onChanged: (value) {},
                    activeTrackColor: AppColors.primary,
                  ),
                ),
                _buildSettingItem(
                  icon: CupertinoIcons.gauge,
                  title: '识别置信度阈值',
                  subtitle: '低于阈值需要手动确认',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '70%',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        CupertinoIcons.chevron_right,
                        size: 16,
                        color: AppColors.textTertiary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),
            _buildSection(
              title: '数据管理',
              children: [
                _buildSettingItem(
                  icon: CupertinoIcons.delete,
                  title: '清除已完成包裹',
                  subtitle: '删除所有已取件和已归档的包裹',
                  onTap: () => _showClearDialog(context, ref),
                ),
                _buildSettingItem(
                  icon: CupertinoIcons.cloud_upload,
                  title: '导出数据',
                  subtitle: '导出所有包裹数据',
                  onTap: () {},
                ),
                _buildSettingItem(
                  icon: CupertinoIcons.cloud_download,
                  title: '导入数据',
                  subtitle: '从文件导入包裹数据',
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),
            _buildSection(
              title: '通知',
              children: [
                _buildSettingItem(
                  icon: CupertinoIcons.bell,
                  title: '到件通知',
                  subtitle: '包裹到达时发送通知',
                  trailing: CupertinoSwitch(
                    value: true,
                    onChanged: (value) {},
                    activeTrackColor: AppColors.primary,
                  ),
                ),
                _buildSettingItem(
                  icon: CupertinoIcons.clock,
                  title: '取件提醒',
                  subtitle: '24小时未取件时提醒',
                  trailing: CupertinoSwitch(
                    value: true,
                    onChanged: (value) {},
                    activeTrackColor: AppColors.primary,
                  ),
                ),
                _buildSettingItem(
                  icon: CupertinoIcons.antenna_radiowaves_left_right,
                  title: '通知监听',
                  subtitle: '自动捕获快递短信通知',
                  onTap: () async {
                    final service = ref.read(notificationListenerServiceProvider);
                    await service.openSettings();
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),
            _buildSection(
              title: '关于',
              children: [
                _buildSettingItem(
                  icon: CupertinoIcons.info_circle,
                  title: '版本',
                  subtitle: '1.0.0',
                ),
                _buildSettingItem(
                  icon: CupertinoIcons.question_circle,
                  title: '帮助与反馈',
                  subtitle: '查看使用说明或提交反馈',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HelpFeedbackPage(),
                      ),
                    );
                  },
                ),
                _buildSettingItem(
                  icon: CupertinoIcons.doc_text,
                  title: '隐私政策',
                  subtitle: '查看隐私政策',
                  onTap: () {},
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Text(
      '设置',
      style: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.sm,
            bottom: AppSpacing.sm,
          ),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    indent: 52,
                    color: AppColors.separator,
                  ),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing,
            if (trailing == null && onTap != null)
              Icon(
                CupertinoIcons.chevron_right,
                size: 16,
                color: AppColors.textTertiary,
              ),
          ],
        ),
      ),
    );
  }

  void _showClearDialog(BuildContext context, WidgetRef ref) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('清除已完成包裹'),
        content: const Text('确定要删除所有已取件和已归档的包裹吗？此操作不可撤销。'),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              ref.read(packageListProvider.notifier).clearCompleted();
              Navigator.pop(context);
            },
            child: const Text('清除'),
          ),
        ],
      ),
    );
  }
}
