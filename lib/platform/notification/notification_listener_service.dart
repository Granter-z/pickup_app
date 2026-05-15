import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/ocr_pipeline.dart';
import '../../core/debug/debug_trace.dart';
import '../../core/models/pending_confirmation.dart';
import '../../platform/storage/hive_package.dart';
import '../../ui/providers/package_provider.dart';

class NotificationListenerService {
  static const _channel = MethodChannel('com.example.pickup_app/notifications');

  final void Function(Package) onHighConfidencePackage;
  final void Function(PendingConfirmation) onLowConfidenceConfirmation;

  NotificationListenerService({
    required this.onHighConfidencePackage,
    required this.onLowConfidenceConfirmation,
  });

  void initialize() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<bool> isPermissionGranted() async {
    return await _channel.invokeMethod<bool>('isNotificationListenerEnabled') ?? false;
  }

  Future<void> openSettings() async {
    await _channel.invokeMethod<void>('openNotificationListenerSettings');
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onNotification') {
      final title = call.arguments['title'] as String? ?? '';
      final text = call.arguments['text'] as String? ?? '';
      final packageName = call.arguments['packageName'] as String? ?? '';
      await _processNotification(title, text, packageName);
    }
  }

  Future<void> _processNotification(
    String title,
    String text,
    String packageName,
  ) async {
    final combinedText = [title, text].where((s) => s.isNotEmpty).join('\n');
    if (combinedText.isEmpty) return;

    DebugTrace.separator('NOTIFICATION CAPTURED');
    print('source package: $packageName');
    print('text: $combinedText');

    final result = await OcrPipeline.parseRawText(combinedText);

    for (final package in result.highConfidencePackages) {
      onHighConfidencePackage(package);
    }
    for (final confirmation in result.lowConfidenceConfirmations) {
      onLowConfidenceConfirmation(confirmation);
    }
  }
}

final notificationListenerServiceProvider = Provider<NotificationListenerService>((ref) {
  final service = NotificationListenerService(
    onHighConfidencePackage: (package) {
      ref.read(packageListProvider.notifier).addPackage(package);
    },
    onLowConfidenceConfirmation: (confirmation) {
      ref.read(pendingConfirmationsProvider.notifier).add(confirmation);
    },
  );
  service.initialize();
  return service;
});
