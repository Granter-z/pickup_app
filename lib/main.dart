import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'platform/storage/hive_adapters.dart';
import 'core/debug/debug_trace.dart';
import 'platform/storage/hive_package.dart';
import 'platform/notification/notification_adapter.dart';
import 'ui/app.dart';

const String kPackagesBox = 'packages';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  DebugTrace.separator('MAIN: NotificationAdapter');
  await NotificationAdapter().initialize();
  print('NotificationAdapter initialized');

  DebugTrace.separator('MAIN: runApp');
  runApp(const ProviderScope(child: PickupApp()));
}