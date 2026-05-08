import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../constants/app_constants.dart';
import '../../../models/package_model.dart';
import '../../../models/status_extension.dart';
import '../../../providers/package_provider.dart';
import '../../../services/package_ocr_service.dart';

class UploadButton extends ConsumerStatefulWidget {
  const UploadButton({super.key});

  @override
  ConsumerState<UploadButton> createState() => _UploadButtonState();
}

class _UploadButtonState extends ConsumerState<UploadButton> {
  bool _loading = false;

  Future<void> _pickAndRecognize(ImageSource source) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (image == null) return;

    setState(() => _loading = true);

    try {
      final packages = await PackageOcrService.parseToPackages(
        image.path,
        defaultUrgency: UrgencyLevel.warning,
      );

      if (packages.isEmpty) {
        if (mounted) _showError('未识别到快递信息，请重试');
        return;
      }

      final notifier = ref.read(packageListProvider.notifier);
      for (final package in packages) {
        notifier.addPackage(package);
      }

      if (mounted) {
        _showResult(packages);
      }
    } catch (_) {
      if (mounted) {
        _showError('识别失败，请重试');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showResult(List<Package> results) {
    final buffer = StringBuffer('共识别到 ${results.length} 个快递：\n\n');
    for (var i = 0; i < results.length; i++) {
      final p = results[i];
      buffer.writeln('【${i + 1}】${p.courier.displayName}');
      if (p.pickupCode.isNotEmpty) buffer.writeln('  取件码: ${p.pickupCode}');
      if (p.trackingNumber.isNotEmpty && !p.trackingNumber.startsWith('OCR-')) {
        buffer.writeln('  快递单号: ${p.trackingNumber}');
      }
      if (p.location.isNotEmpty) buffer.writeln('  位置: ${p.location}');
      if (p.description.isNotEmpty && p.description.contains('手机尾号')) {
        buffer.writeln('  ${p.description}');
      }
      buffer.writeln('  状态: ${p.status.label}');
      if (i < results.length - 1) buffer.writeln();
    }
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('识别完成'),
        content: Text(buffer.toString()),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('好的'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('出错了'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('好的'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _loading
          ? null
          : () {
              showCupertinoModalPopup(
                context: context,
                builder: (_) => CupertinoActionSheet(
                  title: const Text('添加包裹'),
                  message: const Text('选择添加方式'),
                  actions: [
                    CupertinoActionSheetAction(
                      onPressed: () {
                        Navigator.pop(context);
                        _pickAndRecognize(ImageSource.gallery);
                      },
                      child: const Text('从相册选择截图'),
                    ),
                    CupertinoActionSheetAction(
                      onPressed: () {
                        Navigator.pop(context);
                        _pickAndRecognize(ImageSource.camera);
                      },
                      child: const Text('拍照识别'),
                    ),
                  ],
                  cancelButton: CupertinoActionSheetAction(
                    onPressed: () => Navigator.pop(context),
                    isDefaultAction: true,
                    child: const Text('取消'),
                  ),
                ),
              );
            },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: _loading ? AppColors.primary : AppColors.separator,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_loading)
              const CupertinoActivityIndicator(radius: 10)
            else
              Icon(
                CupertinoIcons.camera_fill,
                color: AppColors.primary,
                size: 20,
              ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              _loading ? '识别中...' : '上传快递截图',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
