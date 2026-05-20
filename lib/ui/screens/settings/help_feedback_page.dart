import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants/app_constants.dart';

class HelpFeedbackPage extends StatelessWidget {
  const HelpFeedbackPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '帮助与反馈',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xl,
          ),
          children: [
            _buildHeaderCard(),
            const SizedBox(height: AppSpacing.xxl),
            _buildUsageSection(),
            const SizedBox(height: AppSpacing.xxl),
            _buildFaqSection(context),
            const SizedBox(height: AppSpacing.xxl),
            _buildFeedbackSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF5856D6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Center(
                  child: Icon(
                    CupertinoIcons.cube_box,
                    size: 28,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pickup App',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '智能快递取件助手',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text(
            '通过 OCR 智能识别快递截图，自动提取取件码、驿站地址等信息，帮你轻松管理待取包裹，再也不用担心忘记取快递！',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: AppSpacing.sm, bottom: AppSpacing.sm),
          child: Text(
            '使用说明',
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
              _buildUsageItem(
                icon: CupertinoIcons.photo,
                title: '上传截图',
                description: '选择包含取件码、驿站地址或快递通知的截图',
                step: '1',
              ),
              Divider(height: 1, indent: 52, color: AppColors.separator),
              _buildUsageItem(
                icon: CupertinoIcons.text_badge_checkmark,
                title: 'OCR 自动识别',
                description: '系统自动提取取件码、驿站、快递公司等信息',
                step: '2',
              ),
              Divider(height: 1, indent: 52, color: AppColors.separator),
              _buildUsageItem(
                icon: CupertinoIcons.checkmark_circle,
                title: '生成待取件事件',
                description: '自动加入待领取列表，并支持提醒与管理',
                step: '3',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUsageItem({
    required IconData icon,
    required String title,
    required String description,
    required String step,
  }) {
    return Padding(
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
              child: Text(
                step,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
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
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
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

  Widget _buildFaqSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: AppSpacing.sm, bottom: AppSpacing.sm),
          child: Text(
            '常见问题',
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
              _buildFaqItem(
                question: '如何识别快递截图？',
                answer: '打开应用后，点击首页的"上传截图"按钮，选择包含快递信息的截图。系统会自动使用 OCR 技术识别截图中的取件码、驿站地址、快递公司等信息，并生成待取件事件。',
              ),
              Divider(height: 1, indent: 16, color: AppColors.separator),
              _buildFaqItem(
                question: '支持哪些快递平台？',
                answer: '目前支持主流快递平台，包括顺丰、中通、圆通、韵达、申通、极兔、京东、菜鸟、邮政等。我们会持续更新支持更多平台。',
              ),
              Divider(height: 1, indent: 16, color: AppColors.separator),
              _buildFaqItem(
                question: '为什么有些截图识别不准确？',
                answer: '识别准确度受截图质量影响。建议：1. 确保截图清晰，文字不模糊；2. 避免截取过多无关内容；3. 确保截图中包含完整的快递信息。如果识别不准确，可以手动编辑修正。',
              ),
              Divider(height: 1, indent: 16, color: AppColors.separator),
              _buildFaqItem(
                question: '为什么包裹进入"待确认"？',
                answer: '当系统识别置信度低于设定阈值（默认70%）时，包裹会进入"待确认"状态。这是为了确保信息准确性，您可以手动确认或修正信息后，包裹会转入正式的待取件列表。',
              ),
              Divider(height: 1, indent: 16, color: AppColors.separator),
              _buildFaqItem(
                question: '如何开启自动通知识别？',
                answer: '进入"设置"页面，在"OCR 设置"部分开启"自动识别"开关。开启后，当您截取包含快递信息的截图时，系统会自动识别并生成待取件事件。',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFaqItem({required String question, required String answer}) {
    return Theme(
      data: ThemeData(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        title: Text(
          question,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        children: [
          Text(
            answer,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: AppSpacing.sm, bottom: AppSpacing.sm),
          child: Text(
            '意见反馈',
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
              _buildSettingItem(
                icon: CupertinoIcons.mail,
                title: '发送邮件',
                subtitle: '2106162627@qq.com',
                onTap: () => _showEmailOptions(context),
              ),
              Divider(height: 1, indent: 52, color: AppColors.separator),
              _buildSettingItem(
                icon: CupertinoIcons.doc_text,
                title: '反馈建议',
                subtitle: '描述您遇到的问题或建议',
                onTap: () => _showFeedbackDialog(context),
              ),
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
                child: Icon(icon, size: 18, color: AppColors.primary),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_right,
              size: 16,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  void _showEmailOptions(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('联系邮箱'),
        message: const Text('2106162627@qq.com'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Clipboard.setData(const ClipboardData(text: '2106162627@qq.com'));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('邮箱已复制到剪贴板'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('复制邮箱地址'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      ),
    );
  }

  void _showFeedbackDialog(BuildContext context) {
    final TextEditingController controller = TextEditingController();
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('反馈建议'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            maxLines: 5,
            placeholder: '请描述您遇到的问题或建议...',
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('感谢您的反馈！'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('提交'),
          ),
        ],
      ),
    );
  }
}
