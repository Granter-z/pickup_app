import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import '../../constants/app_constants.dart';
import '../../providers/package_provider.dart';
import '../../../core/models/package.dart';
import '../../../core/models/package_status.dart';

class PackagesPage extends ConsumerStatefulWidget {
  const PackagesPage({super.key});

  @override
  ConsumerState<PackagesPage> createState() => _PackagesPageState();
}

class _PackagesPageState extends ConsumerState<PackagesPage> {
  String _searchQuery = '';
  PackageStatus? _filterStatus;
  bool _groupByStation = false;

  @override
  Widget build(BuildContext context) {
    final packages = ref.watch(packageListProvider);

    final filtered = _applyFilters(packages);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
            _buildFilterChips(),
            Expanded(
              child: filtered.isEmpty
                  ? _buildEmptyState()
                  : _groupByStation
                      ? _buildStationGroupedList(filtered)
                      : _buildPackageList(_groupByStatus(filtered)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Text(
            '收件箱',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() => _groupByStation = !_groupByStation),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: _groupByStation
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                  color: _groupByStation
                      ? AppColors.primary
                      : AppColors.border,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    CupertinoIcons.group,
                    size: 14,
                    color: _groupByStation
                        ? AppColors.primary
                        : AppColors.textTertiary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '驿站',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _groupByStation
                          ? AppColors.primary
                          : AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              '${ref.watch(packageListProvider).length}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: TextField(
          onChanged: (value) => setState(() => _searchQuery = value),
          decoration: InputDecoration(
            hintText: '搜索取件码、快递单号...',
            hintStyle: TextStyle(color: AppColors.textTertiary),
            prefixIcon: Icon(
              CupertinoIcons.search,
              color: AppColors.textTertiary,
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? GestureDetector(
                    onTap: () => setState(() => _searchQuery = ''),
                    child: Icon(
                      CupertinoIcons.clear_circled_solid,
                      color: AppColors.textTertiary,
                    ),
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        children: [
          _buildFilterChip('全部', null),
          _buildFilterChip('待取', PackageStatus.arrived),
          _buildFilterChip('已取', PackageStatus.pickedUp),
          _buildFilterChip('运输中', PackageStatus.transit),
          _buildFilterChip('派送中', PackageStatus.delivering),
          _buildFilterChip('已归档', PackageStatus.archived),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, PackageStatus? status) {
    final isSelected = _filterStatus == status;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: GestureDetector(
        onTap: () => setState(() => _filterStatus = status),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.cube_box,
            size: 64,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            _searchQuery.isNotEmpty ? '没有找到匹配的包裹' : '暂无包裹',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackageList(Map<String, List<Package>> grouped) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final status = grouped.keys.elementAt(index);
        final packages = grouped[status]!;
        return _buildStatusGroup(status, packages);
      },
    );
  }

  Widget _buildStationGroupedList(List<Package> packages) {
    final grouped = <String, List<Package>>{};
    for (final package in packages) {
      final station = package.originalStation.isNotEmpty
          ? package.originalStation
          : '未知驿站';
      grouped.putIfAbsent(station, () => []).add(package);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final station = grouped.keys.elementAt(index);
        final stationPackages = grouped[station]!;
        return _buildStationGroup(station, stationPackages);
      },
    );
  }

  Widget _buildStationGroup(String station, List<Package> packages) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            children: [
              const Icon(
                CupertinoIcons.location_solid,
                size: 16,
                color: AppColors.textTertiary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  station,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${packages.length}',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
        ...packages.map((pkg) => _buildPackageCard(pkg)),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }

  Widget _buildStatusGroup(String status, List<Package> packages) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _getStatusColor(status),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                status,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${packages.length}',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
        ...packages.map((pkg) => _buildPackageCard(pkg)),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }

  Widget _buildPackageCard(Package package) {
    return Slidable(
      key: ValueKey(package.id),
      enabled: package.status != PackageStatus.pickedUp,
      endActionPane: ActionPane(
        motion: const StretchMotion(),
        children: [
          SlidableAction(
            onPressed: (_) async {
              final confirmed = await showCupertinoDialog<bool>(
                context: context,
                builder: (ctx) => CupertinoAlertDialog(
                  title: const Text('确认取件'),
                  content: Text('标记 ${package.courier.shortName} 包裹为已取件？'),
                  actions: [
                    CupertinoDialogAction(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('取消'),
                    ),
                    CupertinoDialogAction(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('确认'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                ref.read(packageListProvider.notifier).markPickedUp(package.id);
              }
            },
            backgroundColor: AppColors.success,
            foregroundColor: Colors.white,
            icon: Icons.check_circle,
            label: '已取件',
          ),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(AppSpacing.md),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getCourierColor(package.courier).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Center(
              child: Text(
                package.courier.displayName.substring(0, 1),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _getCourierColor(package.courier),
                ),
              ),
            ),
          ),
          title: Text(
            package.pickupCode.isNotEmpty ? package.pickupCode : package.trackingNumber,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 2),
              Text(
                package.displayLocation,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                DateFormat('MM/dd HH:mm').format(package.addedAt),
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          trailing: GestureDetector(
            onTap: () async {
              final confirmed = await showCupertinoDialog<bool>(
                context: context,
                builder: (ctx) => CupertinoAlertDialog(
                  title: const Text('确认取件'),
                  content: Text('标记 ${package.courier.shortName} 包裹为已取件？'),
                  actions: [
                    CupertinoDialogAction(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('取消'),
                    ),
                    CupertinoDialogAction(
                      isDestructiveAction: false,
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('确认'),
                    ),
                  ],
                ),
              );

              if (confirmed == true) {
                ref.read(packageListProvider.notifier).markPickedUp(package.id);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: _getStatusColor(package.status.label).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                package.status.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _getStatusColor(package.status.label),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Package> _applyFilters(List<Package> packages) {
    var result = packages;

    if (_filterStatus != null) {
      result = result.where((p) => p.status == _filterStatus).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result.where((p) {
        return p.pickupCode.toLowerCase().contains(query) ||
            p.trackingNumber.toLowerCase().contains(query) ||
            p.displayLocation.toLowerCase().contains(query);
      }).toList();
    }

    return result;
  }

  Map<String, List<Package>> _groupByStatus(List<Package> packages) {
    final grouped = <String, List<Package>>{};
    for (final package in packages) {
      final status = package.status.label;
      grouped.putIfAbsent(status, () => []).add(package);
    }
    return grouped;
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case '待取件':
        return AppColors.success;
      case '运输中':
        return AppColors.info;
      case '派送中':
        return AppColors.warning;
      case '已取件':
        return AppColors.textTertiary;
      case '已归档':
        return AppColors.textTertiary;
      default:
        return AppColors.textTertiary;
    }
  }

  Color _getCourierColor(CourierType courier) {
    switch (courier) {
      case CourierType.sf:
        return const Color(0xFFFF6600);
      case CourierType.jd:
        return const Color(0xFFE4393C);
      case CourierType.zto:
        return const Color(0xFF2B9AFF);
      case CourierType.yd:
        return const Color(0xFFFFA800);
      case CourierType.yt:
        return const Color(0xFF00B3FF);
      case CourierType.sto:
        return const Color(0xFFFF6600);
      case CourierType.ems:
        return const Color(0xFF006633);
      default:
        return AppColors.primary;
    }
  }
}
