/// Mock 数据导入对话框
library;

import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/mock_data_loader.dart';
import '../../../../app/ocr_pipeline.dart';
import '../../../../core/engine/event_aggregator.dart';
import '../../../../core/models/logistics_event.dart';
import '../../../../core/models/package.dart';
import '../../../constants/app_constants.dart';
import '../../../providers/event_provider.dart';
import '../../../providers/package_provider.dart';

class MockImportDialog extends ConsumerStatefulWidget {
  const MockImportDialog({super.key});

  @override
  ConsumerState<MockImportDialog> createState() => _MockImportDialogState();
}

class _MockImportDialogState extends ConsumerState<MockImportDialog> {
  String? _selectedFile;
  bool _loading = false;
  bool _runningAllTests = false;
  String? _testProgress;
  int _testIndex = 0;

  /// 按类别分组文件
  Map<String, List<String>> get _groupedFiles {
    final groups = <String, List<String>>{};
    for (final file in MockDataLoader.testFiles) {
      final info = MockDataLoader.getFileInfo(file);
      final category = info['category']!;
      if (!groups.containsKey(category)) {
        groups[category] = [];
      }
      groups[category]!.add(file);
    }
    return groups;
  }

  /// 导入单个测试文件
  Future<void> _importFile(String filename) async {
    debugPrint('[MockImportDialog] _importFile called: $filename');
    setState(() => _loading = true);

    try {
      final rawText = await MockDataLoader.loadFile(filename);
      debugPrint('[MockImportDialog] loaded rawText: ${rawText.length} chars');

      if (rawText.isEmpty) {
        if (mounted) _showError('文件内容为空');
        return;
      }

      final result = await OcrPipeline.parseRawText(rawText);
      debugPrint('[MockImportDialog] parse result: ${result.totalCount} packages');

      if (result.isEmpty) {
        if (mounted) _showError('未识别到快递信息');
        return;
      }

      final aggregator = ref.read(eventAggregatorProvider);
      final notifier = ref.read(packageListProvider.notifier);
      final existingPackages = ref.read(packageListProvider);
      debugPrint('[MockImportDialog] existing packages: ${existingPackages.length}');

      // 处理高置信度包裹
      if (result.highConfidencePackages.isNotEmpty) {
        for (final package in result.highConfidencePackages) {
          debugPrint('[MockImportDialog] processing package: ${package.id}');
          
          // 使用新的流程处理包裹
          final processedPackage = aggregator.processPackage(
            incomingPackage: package,
            existingPackages: existingPackages,
            rawText: rawText,
            source: 'mock',
          );
          
          // 添加或更新到包裹列表
          notifier.addPackage(processedPackage);
        }
      }

      // 处理低置信度包裹
      if (result.lowConfidenceConfirmations.isNotEmpty) {
        debugPrint('[MockImportDialog] adding ${result.lowConfidenceConfirmations.length} low confidence packages');
        ref
            .read(pendingConfirmationsProvider.notifier)
            .addAll(result.lowConfidenceConfirmations);
      }

      if (mounted) {
        _showSuccess(result, filename);
      }
    } catch (e, stack) {
      debugPrint('[MockImportDialog] ERROR importing file: $e');
      debugPrint('[MockImportDialog] Stack trace: $stack');
      if (mounted) _showError('导入失败: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 运行所有测试
  Future<void> _runAllTests() async {
    debugPrint('[MockImportDialog] _runAllTests called');
    setState(() {
      _runningAllTests = true;
      _testIndex = 0;
      _testProgress = '准备开始...';
    });

    int successCount = 0;
    int failCount = 0;

    for (int i = 0; i < MockDataLoader.testFiles.length; i++) {
      final filename = MockDataLoader.testFiles[i];
      debugPrint('[MockImportDialog] === Testing $filename (${i+1}/${MockDataLoader.testFiles.length}) ===');

      setState(() {
        _testIndex = i;
        _testProgress = '正在处理: $filename (${i+1}/${MockDataLoader.testFiles.length})';
      });

      try {
        final rawText = await MockDataLoader.loadFile(filename);
        final result = await OcrPipeline.parseRawText(rawText);

        if (result.isEmpty) {
          debugPrint('[MockImportDialog] WARNING: No packages found for $filename');
          failCount++;
        } else {
          final aggregator = ref.read(eventAggregatorProvider);
          final notifier = ref.read(packageListProvider.notifier);
          final existingPackages = ref.read(packageListProvider);

          for (final package in result.highConfidencePackages) {
            // 使用新的流程处理包裹
            final processedPackage = aggregator.processPackage(
              incomingPackage: package,
              existingPackages: existingPackages,
              rawText: rawText,
              source: 'mock',
            );
            
            // 添加或更新到包裹列表
            notifier.addPackage(processedPackage);
          }

          if (result.lowConfidenceConfirmations.isNotEmpty) {
            ref
                .read(pendingConfirmationsProvider.notifier)
                .addAll(result.lowConfidenceConfirmations);
          }

          successCount++;
          debugPrint('[MockImportDialog] ✓ $filename: ${result.totalCount} packages');
        }
      } catch (e) {
        debugPrint('[MockImportDialog] ✗ ERROR processing $filename: $e');
        failCount++;
      }

      // 短暂延迟，避免 UI 阻塞
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // 测试完成
    setState(() {
      _runningAllTests = false;
      _testProgress = null;
    });

    debugPrint('[MockImportDialog] === Test completed ===');
    debugPrint('[MockImportDialog] Success: $successCount, Failed: $failCount');

    if (mounted) {
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('批量测试完成'),
          content: Text('成功: $successCount\n失败: $failCount\n\n'
              '总事件数: ${ref.read(eventAggregatorProvider).eventCount}\n'
              '总包裹数: ${ref.read(packageListProvider).length}'),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text('完成'),
            ),
          ],
        ),
      );
    }
  }

  void _showSuccess(OcrParseResult result, String filename) {
    final highCount = result.highConfidencePackages.length;
    final lowCount = result.lowConfidenceConfirmations.length;

    String message;
    if (lowCount == 0) {
      message = '成功导入 $filename\n'
          '共识别到 $highCount 个快递，已自动添加到包裹列表。';
    } else if (highCount == 0) {
      message = '成功导入 $filename\n'
          '共识别到 $lowCount 个快递，但置信度较低。\n\n'
          '已移入「待确认」区域，请确认后再添加。';
    } else {
      message = '成功导入 $filename\n'
          '识别结果：\n'
          '• $highCount 个高置信度，已自动添加\n'
          '• $lowCount 个低置信度，需确认\n\n'
          '低置信度的包裹已移入「待确认」区域。';
    }

    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('导入成功'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
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
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 标题栏
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '导入测试短信',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.pop(context),
                    child: const Icon(CupertinoIcons.xmark_circle_fill, color: AppColors.textTertiary),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: AppColors.separator),

            // 批量测试按钮
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
              child: CupertinoButton.filled(
                onPressed: _runningAllTests ? null : _runAllTests,
                child: _runningAllTests
                    ? const CupertinoActivityIndicator(color: AppColors.surface)
                    : const Text('批量测试 (运行全部)'),
              ),
            ),

            // 进度显示
            if (_testProgress != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Text(
                  _testProgress!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),

            Divider(height: 1, color: AppColors.separator),

            // 文件列表 - 使用固定高度的 SizedBox 来避免布局问题
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.5,
              child: _loading
                  ? const Center(child: CupertinoActivityIndicator())
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      itemCount: _groupedFiles.entries.length,
                      itemBuilder: (context, sectionIndex) {
                        final entry = _groupedFiles.entries.elementAt(sectionIndex);
                        final category = entry.key;
                        final files = entry.value;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                top: AppSpacing.md,
                                left: AppSpacing.lg,
                                right: AppSpacing.lg,
                                bottom: AppSpacing.sm,
                              ),
                              child: Text(
                                category,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ),
                            ...files.asMap().entries.map((fileEntry) {
                              final fileIndex = fileEntry.key;
                              final file = fileEntry.value;
                              final isSelected = _selectedFile == file;
                              final isInProgress = _runningAllTests && fileIndex == _testIndex;

                              return CupertinoListTile(
                                backgroundColor: isSelected
                                    ? AppColors.primary.withValues(alpha: 0.08)
                                    : Colors.transparent,
                                title: Row(
                                  children: [
                                    if (isInProgress)
                                      const Padding(
                                        padding: EdgeInsets.only(right: AppSpacing.sm),
                                        child: CupertinoActivityIndicator(radius: 8),
                                      ),
                                    Expanded(
                                      child: Text(
                                        file.replaceAll('.txt', ''),
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: isSelected
                                    ? Icon(
                                        CupertinoIcons.checkmark_circle_fill,
                                        color: AppColors.primary,
                                      )
                                    : null,
                                onTap: _runningAllTests
                                    ? null
                                    : () {
                                        setState(() => _selectedFile = file);
                                        _importFile(file);
                                      },
                              );
                            }),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 显示 Mock 导入对话框
void showMockImportDialog(BuildContext context) {
  showCupertinoModalPopup(
    context: context,
    builder: (_) => const MockImportDialog(),
  );
}
