import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'adapters/hive_adapters.dart';
import 'models/package_model.dart';
import 'services/notification_service.dart';
import 'app.dart';

const String kPackagesBox = 'packages';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Hive 初始化
  await Hive.initFlutter();

  Hive
    ..registerAdapter(PackageStatusAdapter())
    ..registerAdapter(UrgencyLevelAdapter())
    ..registerAdapter(CourierTypeAdapter())
    ..registerAdapter(HivePackageAdapter());

  await Hive.openBox<HivePackage>(kPackagesBox);

  // 通知服务初始化
  await NotificationService().initialize();

  runApp(const ProviderScope(child: PickupApp()));
}
