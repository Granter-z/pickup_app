import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'adapters/hive_adapters.dart';
import 'core/debug/debug_trace.dart';
import 'models/package_model.dart';
import 'services/notification_service.dart';
import 'app.dart';

const String kPackagesBox = 'packages';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Hive 初始化 ───────────────────────────────────────────
  DebugTrace.separator('MAIN: Hive.initFlutter');
  await Hive.initFlutter();
  print('Hive.initFlutter done');

  Hive
    ..registerAdapter(PackageStatusAdapter())
    ..registerAdapter(UrgencyLevelAdapter())
    ..registerAdapter(CourierTypeAdapter())
    ..registerAdapter(HivePackageAdapter());
  print('Adapters registered (4)');

  DebugTrace.separator('MAIN: openBox');
  final box = await Hive.openBox<HivePackage>(kPackagesBox);
  print('box.name: ${box.name}');
  print('box.isOpen: ${box.isOpen}');
  print('box.length: ${box.length}');

  // ── 通知服务初始化 ────────────────────────────────────────
  DebugTrace.separator('MAIN: NotificationService');
  await NotificationService().initialize();
  print('NotificationService initialized');

  // ── 启动 App ──────────────────────────────────────────────
  DebugTrace.separator('MAIN: runApp');
  runApp(const ProviderScope(child: PickupApp()));
}
