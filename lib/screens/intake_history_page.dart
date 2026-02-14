import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/checkin_service.dart';
import '../services/user_service.dart';
import '../services/schedule_service.dart';
import '../models/hydration_models.dart';
import '../theme/app_theme.dart';
import '../util/volume_utils.dart';
import 'intake_recording_page.dart';

class IntakeHistoryPage extends StatefulWidget {
  const IntakeHistoryPage({super.key});

  @override
  State<IntakeHistoryPage> createState() => _IntakeHistoryPageState();
}

class _IntakeHistoryPageState extends State<IntakeHistoryPage> {
  final _authService = AuthService();
  final _checkInService = CheckInService();
  final _userService = UserService();
  final _scheduleService = ScheduleService();
  String _volumeUnit = 'ml';
  String _selectedFilter = 'All';

  final List<String> _beverageFilters = [
    'All',
    'Water',
    'Coffee',
    'Tea',
    'Juice',
    'Milk',
    'Sports Drink',
    'Other',
    'Skipped',
  ];

  @override
  void initState() {
    super.initState();
    _loadVolumeUnit();
  }

  Future<void> _loadVolumeUnit() async {
    final userId = _authService.currentUser?.uid ?? '';
    if (userId.isEmpty) return;

    final profile = await _userService.getUserProfile(userId);
    if (profile != null && mounted) {
      setState(() => _volumeUnit = profile.volumeUnit);
    }
  }

  Map<String, List<HydrationCheckIn>> _groupByBeverageType(
    List<HydrationCheckIn> checkIns,
  ) {
    final Map<String, List<HydrationCheckIn>> grouped = {};
    for (final checkIn in checkIns) {
      if (checkIn.beverageType == 'Skipped') continue; // Skip skipped entries
      final type = checkIn.beverageType;
      if (!grouped.containsKey(type)) {
        grouped[type] = [];
      }
      grouped[type]!.add(checkIn);
    }
    return grouped;
  }

  IconData _getBeverageIcon(String beverageType) {
    switch (beverageType.toLowerCase()) {
      case 'water':
        return Icons.water_drop;
      case 'coffee':
        return Icons.coffee;
      case 'tea':
        return Icons.emoji_food_beverage;
      case 'juice':
        return Icons.local_drink;
      case 'milk':
        return Icons.local_drink;
      case 'sports drink':
        return Icons.sports_bar;
      default:
        return Icons.local_cafe;
    }
  }

  Color _getBeverageColor(String beverageType) {
    switch (beverageType.toLowerCase()) {
      case 'water':
        return AppColors.primary;
      case 'coffee':
        return Colors.brown;
      case 'tea':
        return Colors.green.shade700;
      case 'juice':
        return Colors.orange;
      case 'milk':
        return Colors.blue.shade200;
      case 'sports drink':
        return Colors.purple;
      case 'skipped':
        return AppColors.textTertiary;
      default:
        return AppColors.accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = _authService.currentUser?.uid ?? '';

    if (userId.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            'Intake History',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
        ),
        body: const Center(child: Text('Sign in to view intake history')),
      );
    }

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Intake History',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      body: StreamBuilder<List<HydrationCheckIn>>(
        stream: _checkInService.watchCheckInsInRange(
          userId,
          todayStart,
          todayEnd,
        ),
        builder: (context, checkInSnapshot) {
          if (checkInSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          var allCheckIns = checkInSnapshot.data ?? [];

          // Calculate total intake (excluding skipped) BEFORE filtering
          final totalIntake = allCheckIns
              .where((c) => c.beverageType != 'Skipped')
              .fold<double>(0, (sum, checkIn) => sum + checkIn.amountMl);

          // Now apply beverage filter for display (keep skipped/missed visible)
          var filteredCheckIns = allCheckIns;
          if (_selectedFilter != 'All' && _selectedFilter != 'Skipped') {
            filteredCheckIns = allCheckIns
                .where((c) => c.beverageType == _selectedFilter)
                .toList();
          } else if (_selectedFilter == 'Skipped') {
            filteredCheckIns = allCheckIns
                .where((c) => c.beverageType == 'Skipped')
                .toList();
          }

          return StreamBuilder<List<HydrationSchedule>>(
            stream: _scheduleService.watchSchedules(userId),
            builder: (context, scheduleSnapshot) {
              final schedules = scheduleSnapshot.data ?? [];
              final dailyGoal = schedules.fold<double>(
                0,
                (sum, s) => sum + (s.enabled ? s.amountMl : 0),
              );

              final percentage = dailyGoal > 0
                  ? ((totalIntake / dailyGoal) * 100).clamp(0, 100).toInt()
                  : 0;

              final grouped = _groupByBeverageType(filteredCheckIns);

              return Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSummaryCard(totalIntake, percentage, dailyGoal),
                    const SizedBox(height: 16),
                    _buildBeverageFilter(),
                    const SizedBox(height: 20),
                    Text(
                      'Today\'s Intake by Type',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filteredCheckIns.isEmpty
                          ? _buildEmptyState()
                          : ListView(
                              children: [
                                if (_selectedFilter == 'All')
                                  ..._buildGroupedEntries(grouped)
                                else
                                  ..._buildFilteredEntries(filteredCheckIns),
                              ],
                            ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) =>
                  IntakeRecordingPage(onSaved: () => setState(() {})),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Log Intake'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Widget _buildBeverageFilter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _beverageFilters.map((filter) {
          final isSelected = _selectedFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(filter),
              selected: isSelected,
              onSelected: (selected) {
                setState(() => _selectedFilter = filter);
              },
              backgroundColor: AppColors.surface,
              selectedColor: AppColors.primary.withOpacity(0.2),
              checkmarkColor: AppColors.primary,
              labelStyle: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  List<Widget> _buildGroupedEntries(
    Map<String, List<HydrationCheckIn>> grouped,
  ) {
    final entries = <Widget>[];

    grouped.forEach((beverageType, checkIns) {
      final totalForType = checkIns.fold<double>(
        0,
        (sum, c) => sum + c.amountMl,
      );
      final color = _getBeverageColor(beverageType);
      final icon = _getBeverageIcon(beverageType);

      entries.add(
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(icon, color: color, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        beverageType,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      VolumeUtils.format(totalForType, _volumeUnit),
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              ...checkIns.map((checkIn) => _buildCheckInTile(checkIn, color)),
            ],
          ),
        ),
      );
    });

    return entries;
  }

  List<Widget> _buildFilteredEntries(List<HydrationCheckIn> checkIns) {
    final sorted = [...checkIns]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final color = _getBeverageColor(_selectedFilter);

    return sorted.map((checkIn) => _buildCheckInTile(checkIn, color)).toList();
  }

  Widget _buildCheckInTile(HydrationCheckIn checkIn, Color color) {
    final isSkipped = checkIn.beverageType == 'Skipped';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isSkipped ? AppColors.errorLight.withOpacity(0.3) : null,
        border: Border(
          bottom: BorderSide(color: AppColors.border.withOpacity(0.5)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      DateFormat('h:mm a').format(checkIn.timestamp),
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSkipped
                            ? AppColors.textSecondary
                            : AppColors.textPrimary,
                        decoration: isSkipped
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    if (isSkipped) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'SKIPPED',
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (checkIn.scheduleId != null)
                  Text(
                    'From schedule',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            isSkipped ? '—' : VolumeUtils.format(checkIn.amountMl, _volumeUnit),
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isSkipped ? AppColors.textTertiary : color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(double totalMl, int percentage, double goalMl) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary.withOpacity(0.8), AppColors.primary],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Intake Today',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    VolumeUtils.format(totalMl, _volumeUnit),
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$percentage%',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Daily Goal:',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                Text(
                  VolumeUtils.format(goalMl, _volumeUnit),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.water_drop_outlined,
            size: 64,
            color: AppColors.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No intake logged today',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the button below to log your first drink',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
