import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'adapters/hive_adapters.dart';
import 'models/package_model.dart';
import 'app.dart';

const String kPackagesBox = 'packages';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();

  Hive
    ..registerAdapter(PackageStatusAdapter())
    ..registerAdapter(UrgencyLevelAdapter())
    ..registerAdapter(CourierTypeAdapter())
    ..registerAdapter(PackageAdapter());

  await Hive.openBox<Package>(kPackagesBox);

  runApp(const ProviderScope(child: PickupApp()));
}
