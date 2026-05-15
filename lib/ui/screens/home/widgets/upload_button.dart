import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../constants/app_constants.dart';
import '../../../providers/package_provider.dart';
import '../../../../app/ocr_pipeline.dart';
import 'mock_import_dialog.dart';

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
      // 使用新的解析方法，区分高/低置信度
      final result = await OcrPipeline.run(image.path);

      if (result.isEmpty) {
        if (mounted) _showError('未识别到快递信息，请重试');
        return;
      }

      // 高置信度的直接添加
      if (result.highConfidencePackages.isNotEmpty) {
        final notifier = ref.read(packageListProvider.notifier);
        for (final package in result.highConfidencePackages) {
          notifier.addPackage(package);
        }
      }

      // 低置信度的进入待确认区
      if (result.lowConfidenceConfirmations.isNotEmpty) {
        ref
            .read(pendingConfirmationsProvider.notifier)
            .addAll(result.lowConfidenceConfirmations);
      }

      if (mounted) {
        _showConfidenceResult(result);
      }
    } catch (_) {
      if (mounted) {
        _showError('识别失败，请重试');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showConfidenceResult(OcrParseResult result) {
    final highCount = result.highConfidencePackages.length;
    final lowCount = result.lowConfidenceConfirmations.length;

    String message;
    if (lowCount == 0) {
      message = '共识别到 $highCount 个快递，已自动添加到包裹列表。';
    } else if (highCount == 0) {
      message = '共识别到 $lowCount 个快递，但置信度较低。\n\n已移入「待确认」区域，请确认后再添加。';
    } else {
      message = '识别结果：\n'
          '• $highCount 个高置信度，已自动添加\n'
          '• $lowCount 个低置信度，需确认\n\n'
          '低置信度的包裹已移入「待确认」区域。';
    }

    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('识别完成'),
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
                    CupertinoActionSheetAction(
                      onPressed: () {
                        Navigator.pop(context);
                        showMockImportDialog(context);
                      },
                      child: const Text('导入测试短信'),
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
