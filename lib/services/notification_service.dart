/// 通知服务 - 事件驱动
/// 
/// 职责：
/// 1. 到件立即通知（仅触发一次）
/// 2. 24小时延迟提醒
/// 3. 取消通知
/// 
/// 设计原则：
/// - 只捕捉用户扫描时的瞬时状态
/// - 通知触发点是"事件"，不是"状态变化"
/// - 不做后台轮询、状态变化监听、API 调用
library;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../core/models/package.dart';
import '../core/debug/debug_trace.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  
  /// 通知 ID 基础值（用于生成唯一通知 ID）
  static const int _arrivedBaseId = 10000;
  static const int _reminderBaseId = 20000;

  /// 初始化通知服务
  Future<void> initialize() async {
    // 初始化时区
    tz.initializeTimeZones();
    
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );
    
    DebugTrace.separator('NOTIFICATION SERVICE INITIALIZED');
  }

  /// 通知点击回调
  void _onNotificationResponse(NotificationResponse response) {
    // TODO: 可以在这里处理通知点击事件，跳转到对应包裹
    DebugTrace.separator('NOTIFICATION CLICKED');
    print('payload: ${response.payload}');
  }

  /// 到件立即通知（仅触发一次）
  /// 
  /// 触发时机：用户扫描识别到 arrived 时
  /// 标题："📦 快递到了！"
  /// 内容：有取件码："${courier} 取件码：${pickupCode}"
  ///       无取件码："${courier} 已到 ${location}，请尽快取件"
  Future<void> showArrivedNotification(Package package) async {
    DebugTrace.separator('SHOW ARRIVED NOTIFICATION');
    print('package: ${package.courier.shortName} ${package.pickupCode}');
    
    final title = '📦 快递到了！';
    final body = _buildArrivedBody(package);
    final notificationId = _arrivedBaseId + package.id.hashCode.abs() % 10000;
    
    await _showNotification(
      id: notificationId,
      title: title,
      body: body,
      payload: 'arrived:${package.id}',
    );
  }

  /// 构建到件通知内容
  String _buildArrivedBody(Package package) {
    final courier = package.courier.shortName;
    
    if (package.pickupCode.isNotEmpty) {
      return '$courier 取件码：${package.pickupCode}';
    } else if (package.location.isNotEmpty) {
      return '$courier 已到 ${package.location}，请尽快取件';
    } else {
      return '$courier 已到达，请尽快取件';
    }
  }

  /// 24小时延迟提醒
  /// 
  /// 触发时机：showArrivedNotification 同时调度
  /// 延迟：24小时
  /// 标题："⏰ 快递还在等你"
  /// 内容："${courier} 已等待超过 24 小时"
  Future<void> scheduleReminderNotification(Package package) async {
    DebugTrace.separator('SCHEDULE REMINDER NOTIFICATION');
    print('package: ${package.courier.shortName}');
    
    final title = '⏰ 快递还在等你';
    final body = '${package.courier.shortName} 已等待超过 24 小时';
    final notificationId = _reminderBaseId + package.id.hashCode.abs() % 10000;
    
    await _scheduleNotification(
      id: notificationId,
      title: title,
      body: body,
      payload: 'reminder:${package.id}',
      delay: const Duration(hours: 24),
    );
  }

  /// 取消通知
  /// 
  /// 取消立即通知 + 24h提醒
  Future<void> cancelNotification(String packageId) async {
    DebugTrace.separator('CANCEL NOTIFICATION');
    print('packageId: $packageId');
    
    final arrivedId = _arrivedBaseId + packageId.hashCode.abs() % 10000;
    final reminderId = _reminderBaseId + packageId.hashCode.abs() % 10000;
    
    await _plugin.cancel(arrivedId);
    await _plugin.cancel(reminderId);
  }

  /// 显示立即通知
  Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const android = AndroidNotificationDetails(
      'pickup_channel',
      '快递通知',
      channelDescription: '包裹到达提醒',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(android: android, iOS: ios);
    
    await _plugin.show(id, title, body, details, payload: payload);
  }

  /// 调度延迟通知
  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    required Duration delay,
  }) async {
    const android = AndroidNotificationDetails(
      'pickup_channel',
      '快递通知',
      channelDescription: '包裹到达提醒',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(android: android, iOS: ios);
    
    // 使用 zonedSchedule 调度延迟通知
    final scheduledDate = tz.TZDateTime.now(tz.local).add(delay);
    
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      details,
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}
