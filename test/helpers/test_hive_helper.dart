import 'dart:io';
import 'package:hive/hive.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:pickup_app/platform/storage/hive_adapters.dart';
import 'package:pickup_app/platform/storage/hive_package.dart';

/// 测试用 Hive 初始化 helper
class TestHiveHelper {
  static late Directory _tempDir;
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    _tempDir = await Directory.systemTemp.createTemp('hive_test_');
    Hive.init(_tempDir.path);
    Hive
      ..registerAdapter(PackageStatusAdapter())
      ..registerAdapter(UrgencyLevelAdapter())
      ..registerAdapter(CourierTypeAdapter())
      ..registerAdapter(HivePackageAdapter());
    tz.initializeTimeZones();
    _initialized = true;
  }

  /// 删除并重新创建 box
  static Future<void> resetBox() async {
    // 关闭所有已打开的 box
    try {
      await Hive.close();
    } catch (_) {}
    // 删除 box 文件
    final boxPath = '${_tempDir.path}/packages.hive';
    final boxLockPath = '${_tempDir.path}/packages.lock';
    final boxFile = File(boxPath);
    final lockFile = File(boxLockPath);
    if (await boxFile.exists()) await boxFile.delete();
    if (await lockFile.exists()) await lockFile.delete();
    // 重新打开
    await Hive.openBox<HivePackage>('packages');
  }

  static Future<void> cleanup() async {
    if (!_initialized) return;
    await Hive.close();
    _tempDir.deleteSync(recursive: true);
    _initialized = false;
  }
}
