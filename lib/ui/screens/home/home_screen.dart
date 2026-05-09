import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../constants/app_constants.dart';
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