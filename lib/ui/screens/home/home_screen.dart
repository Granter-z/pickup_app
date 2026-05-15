import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../constants/app_constants.dart';
import '../../../platform/notification/notification_listener_service.dart';
import 'widgets/date_header.dart';
import 'widgets/hero_card.dart';
import 'widgets/upload_button.dart';
import 'widgets/pending_confirmation_section.dart';
import 'widgets/package_list.dart';
import 'widgets/completed_section.dart';
import 'widgets/bottom_tab_bar.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkNotificationPermission();
    });
  }

  void _checkNotificationPermission() async {
    final service = ref.read(notificationListenerServiceProvider);
    final granted = await service.isPermissionGranted();
    if (!granted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('开启通知监听可自动捕获快递通知'),
          action: SnackBarAction(
            label: '去开启',
            onPressed: () => service.openSettings(),
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: AppSpacing.xl),
              DateHeader(),
              SizedBox(height: AppSpacing.lg),
              HeroCard(),
              SizedBox(height: AppSpacing.lg),
              UploadButton(),
              SizedBox(height: AppSpacing.xxl),
              PendingConfirmationSection(),
              SizedBox(height: AppSpacing.lg),
              PackageList(),
              SizedBox(height: AppSpacing.lg),
              CompletedSection(),
              SizedBox(height: AppSpacing.xxxl),
            ],
          ),
        ),
      ),
      bottomNavigationBar: HomeTabBar(
        currentIndex: _currentTab,
        onTap: (index) => setState(() => _currentTab = index),
      ),
    );
  }
}