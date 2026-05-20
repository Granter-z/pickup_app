import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../constants/app_constants.dart';
import '../../../platform/notification/notification_listener_service.dart';
import 'widgets/date_header.dart';
import 'widgets/home_hero_section.dart';
import 'widgets/empty_state_view.dart';
import 'widgets/upload_button.dart';
import 'widgets/pending_confirmation_section.dart';
import 'widgets/priority_queue_section.dart';
import 'widgets/today_arrivals_section.dart';
import 'widgets/recent_activity_section.dart';
import 'widgets/bottom_tab_bar.dart';
import '../packages/packages_page.dart';
import '../routes/routes_page.dart';
import '../settings/settings_page.dart';

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

  Widget _buildCurrentPage() {
    switch (_currentTab) {
      case 0:
        return _buildHomePage();
      case 1:
        return const PackagesPage();
      case 2:
        return const RoutesPage();
      case 3:
        return const SettingsPage();
      default:
        return _buildHomePage();
    }
  }

  Widget _buildHomePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: AppSpacing.xl),
          DateHeader(),
          SizedBox(height: AppSpacing.lg),
          HomeHeroSection(), // 极简白话文案，替代原有的 HeroCard
          SizedBox(height: AppSpacing.xxl),
          PriorityQueueSection(),
          SizedBox(height: AppSpacing.lg),
          TodayArrivalsSection(),
          SizedBox(height: AppSpacing.lg),
          PendingConfirmationSection(),
          SizedBox(height: AppSpacing.lg),
          UploadButton(),
          SizedBox(height: AppSpacing.xxl),
          RecentActivitySection(),
          SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _buildCurrentPage(),
      ),
      bottomNavigationBar: HomeTabBar(
        currentIndex: _currentTab,
        onTap: (index) => setState(() => _currentTab = index),
      ),
    );
  }
}