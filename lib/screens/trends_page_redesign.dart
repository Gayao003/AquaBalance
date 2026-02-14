import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/checkin_service.dart';
import '../services/schedule_service.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../models/hydration_models.dart';
import '../theme/app_theme.dart';
import '../util/volume_utils.dart';

class TrendsPageRedesign extends StatefulWidget {
  final VoidCallback? onOpenDrawer;

  const TrendsPageRedesign({super.key, this.onOpenDrawer});

  @override
  State<TrendsPageRedesign> createState() => _TrendsPageRedesignState();
}

class _TrendsPageRedesignState extends State<TrendsPageRedesign>
    with SingleTickerProviderStateMixin {
  final _checkInService = CheckInService();
  final _scheduleService = ScheduleService();
  final _authService = AuthService();
  final _userService = UserService();
  String _volumeUnit = 'ml';
  int _selectedRange = 7; // 7, 14, or 30 days
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _loadVolumeUnit();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadVolumeUnit() async {
    final userId = _authService.currentUser?.uid ?? '';
    if (userId.isEmpty) return;
    final profile = await _userService.getUserProfile(userId);
    if (profile != null && mounted) {
      setState(() => _volumeUnit = profile.volumeUnit);
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
            'Insights',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
        ),
        body: Center(
          child: Text(
            'Sign in to view insights',
            style: GoogleFonts.poppins(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: _selectedRange - 1));
    final todayStart = DateTime(now.year, now.month, now.day);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Insights',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        leading: widget.onOpenDrawer == null
            ? null
            : IconButton(
                icon: const Icon(Icons.menu),
                onPressed: widget.onOpenDrawer,
              ),
      ),
      body: StreamBuilder<List<HydrationSchedule>>(
        stream: _scheduleService.watchSchedules(userId),
        builder: (context, scheduleSnapshot) {
          final dailyGoal = (scheduleSnapshot.data ?? [])
              .where((s) => s.enabled)
              .fold<double>(0, (sum, s) => sum + s.amountMl);

          return FadeTransition(
            opacity: _fadeAnimation,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildRangeSelector(),
                  const SizedBox(height: 20),
                  _buildTodayQuickStats(userId, todayStart, dailyGoal),
                  const SizedBox(height: 20),
                  _buildStreakCard(userId, startDate, dailyGoal),
                  const SizedBox(height: 20),
                  _buildWeeklyChart(userId, startDate, now),
                  const SizedBox(height: 20),
                  _buildKeyMetrics(userId, startDate, now, dailyGoal),
                  const SizedBox(height: 20),
                  _buildBeverageBreakdown(userId, startDate, now),
                  const SizedBox(height: 20),
                  _buildTimeOfDayAnalysis(userId, startDate, now),
                  const SizedBox(height: 20),
                  _buildRecommendations(userId, startDate, now, dailyGoal),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRangeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [7, 14, 30].map((days) {
          final isSelected = _selectedRange == days;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedRange = days),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${days}d',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTodayQuickStats(
    String userId,
    DateTime todayStart,
    double dailyGoal,
  ) {
    final todayEnd = todayStart.add(const Duration(days: 1));

    return StreamBuilder<List<HydrationCheckIn>>(
      stream: _checkInService.watchCheckInsInRange(
        userId,
        todayStart,
        todayEnd,
      ),
      builder: (context, snapshot) {
        final checkIns = snapshot.data ?? [];
        final todayIntake = checkIns
            .where((c) => c.beverageType != 'Skipped')
            .fold<double>(0, (sum, c) => sum + c.amountMl);
        final percentage = dailyGoal > 0
            ? (todayIntake / dailyGoal * 100).clamp(0, 100)
            : 0;
        final remaining = (dailyGoal - todayIntake)
            .clamp(0.0, double.infinity)
            .toDouble();

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.today,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Today\'s Progress',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        DateFormat('EEEE, MMM d').format(DateTime.now()),
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Consumed',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          VolumeUtils.format(todayIntake, _volumeUnit),
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: Colors.white.withOpacity(0.3),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Remaining',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            VolumeUtils.format(remaining, _volumeUnit),
                            style: GoogleFonts.poppins(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: percentage / 100,
                  minHeight: 8,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${percentage.toInt()}% of daily goal',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStreakCard(String userId, DateTime startDate, double dailyGoal) {
    return StreamBuilder<List<HydrationCheckIn>>(
      stream: _checkInService.watchCheckInsInRange(
        userId,
        startDate.subtract(const Duration(days: 365)),
        DateTime.now(),
      ),
      builder: (context, snapshot) {
        final allCheckIns = snapshot.data ?? [];

        // Calculate current streak
        int currentStreak = 0;
        int bestStreak = 0;
        int tempStreak = 0;

        final today = DateTime.now();
        for (int i = 0; i < 365; i++) {
          final checkDate = today.subtract(Duration(days: i));
          final dayStart = DateTime(
            checkDate.year,
            checkDate.month,
            checkDate.day,
          );
          final dayEnd = dayStart.add(const Duration(days: 1));

          final dayIntake = allCheckIns
              .where(
                (c) =>
                    c.timestamp.isAfter(dayStart) &&
                    c.timestamp.isBefore(dayEnd) &&
                    c.beverageType != 'Skipped',
              )
              .fold<double>(0, (sum, c) => sum + c.amountMl);

          if (dayIntake >= dailyGoal * 0.8) {
            // Met at least 80% of goal
            tempStreak++;
            if (i == 0 || currentStreak > 0) {
              currentStreak = tempStreak;
            }
            if (tempStreak > bestStreak) {
              bestStreak = tempStreak;
            }
          } else {
            tempStreak = 0;
          }
        }

        return Row(
          children: [
            Expanded(
              child: _buildStreakMiniCard(
                'Current Streak',
                currentStreak,
                Icons.local_fire_department,
                AppColors.accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStreakMiniCard(
                'Best Streak',
                bestStreak,
                Icons.emoji_events,
                AppColors.warning,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStreakMiniCard(
    String label,
    int days,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            '$days',
            style: GoogleFonts.poppins(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            days == 1 ? 'day' : 'days',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyChart(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) {
    return StreamBuilder<List<HydrationCheckIn>>(
      stream: _checkInService.watchCheckInsInRange(userId, startDate, endDate),
      builder: (context, snapshot) {
        final checkIns = snapshot.data ?? [];

        // Group by day
        final Map<String, double> dailyIntake = {};
        for (int i = 0; i < _selectedRange; i++) {
          final date = startDate.add(Duration(days: i));
          final dateKey = DateFormat('MMM d').format(date);
          final dayStart = DateTime(date.year, date.month, date.day);
          final dayEnd = dayStart.add(const Duration(days: 1));

          final intake = checkIns
              .where(
                (c) =>
                    c.timestamp.isAfter(dayStart) &&
                    c.timestamp.isBefore(dayEnd) &&
                    c.beverageType != 'Skipped',
              )
              .fold<double>(0, (sum, c) => sum + c.amountMl);

          dailyIntake[dateKey] = intake;
        }

        final maxIntake = dailyIntake.values.isEmpty
            ? 2000.0
            : dailyIntake.values.reduce((a, b) => a > b ? a : b);

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.bar_chart, color: AppColors.primary, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'Daily Intake Trend',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 200,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxIntake * 1.2,
                    barTouchData: BarTouchData(enabled: false),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final keys = dailyIntake.keys.toList();
                            if (value.toInt() >= 0 &&
                                value.toInt() < keys.length) {
                              final label = keys[value.toInt()];
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  label.split(' ')[1], // Just day number
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                              );
                            }
                            return const SizedBox();
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              VolumeUtils.format(value, _volumeUnit),
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: AppColors.textTertiary,
                              ),
                            );
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: maxIntake / 4,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(color: AppColors.border, strokeWidth: 1);
                      },
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: dailyIntake.entries.toList().asMap().entries.map(
                      (entry) {
                        final index = entry.key;
                        final intake = entry.value.value;
                        return BarChartGroupData(
                          x: index,
                          barRods: [
                            BarChartRodData(
                              toY: intake,
                              color: AppColors.primary,
                              width: _selectedRange > 14 ? 12 : 16,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(6),
                                topRight: Radius.circular(6),
                              ),
                            ),
                          ],
                        );
                      },
                    ).toList(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildKeyMetrics(
    String userId,
    DateTime startDate,
    DateTime endDate,
    double dailyGoal,
  ) {
    return StreamBuilder<List<HydrationCheckIn>>(
      stream: _checkInService.watchCheckInsInRange(userId, startDate, endDate),
      builder: (context, snapshot) {
        final checkIns = snapshot.data ?? [];
        final validCheckIns = checkIns
            .where((c) => c.beverageType != 'Skipped')
            .toList();

        final totalIntake = validCheckIns.fold<double>(
          0,
          (sum, c) => sum + c.amountMl,
        );
        final avgIntake = validCheckIns.isEmpty
            ? 0.0
            : totalIntake / _selectedRange;

        // Calculate consistency (days met goal)
        int daysMetGoal = 0;
        for (int i = 0; i < _selectedRange; i++) {
          final date = startDate.add(Duration(days: i));
          final dayStart = DateTime(date.year, date.month, date.day);
          final dayEnd = dayStart.add(const Duration(days: 1));

          final dayIntake = checkIns
              .where(
                (c) =>
                    c.timestamp.isAfter(dayStart) &&
                    c.timestamp.isBefore(dayEnd) &&
                    c.beverageType != 'Skipped',
              )
              .fold<double>(0, (sum, c) => sum + c.amountMl);

          if (dayIntake >= dailyGoal) daysMetGoal++;
        }

        final consistency = dailyGoal > 0
            ? (daysMetGoal / _selectedRange * 100)
            : 0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Key Metrics',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Total Intake',
                    VolumeUtils.format(totalIntake, _volumeUnit),
                    Icons.water_drop,
                    AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    'Daily Average',
                    VolumeUtils.format(avgIntake, _volumeUnit),
                    Icons.show_chart,
                    AppColors.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Consistency',
                    '${consistency.toInt()}%',
                    Icons.emoji_events,
                    AppColors.warning,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    'Days Met Goal',
                    '$daysMetGoal/$_selectedRange',
                    Icons.check_circle,
                    AppColors.accent,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBeverageBreakdown(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) {
    return StreamBuilder<List<HydrationCheckIn>>(
      stream: _checkInService.watchCheckInsInRange(userId, startDate, endDate),
      builder: (context, snapshot) {
        final checkIns = snapshot.data ?? [];
        final validCheckIns = checkIns
            .where((c) => c.beverageType != 'Skipped')
            .toList();

        final Map<String, double> beverageIntake = {};
        for (var checkIn in validCheckIns) {
          beverageIntake[checkIn.beverageType] =
              (beverageIntake[checkIn.beverageType] ?? 0) + checkIn.amountMl;
        }

        if (beverageIntake.isEmpty) {
          return const SizedBox();
        }

        final total = beverageIntake.values.fold<double>(
          0,
          (sum, v) => sum + v,
        );

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.pie_chart, color: AppColors.primary, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'Beverage Breakdown',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...beverageIntake.entries.map((entry) {
                final percentage = (entry.value / total * 100);
                final color = _getBeverageColor(entry.key);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            entry.key,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            '${percentage.toInt()}%',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: percentage / 100,
                          minHeight: 8,
                          backgroundColor: AppColors.border,
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTimeOfDayAnalysis(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) {
    return StreamBuilder<List<HydrationCheckIn>>(
      stream: _checkInService.watchCheckInsInRange(userId, startDate, endDate),
      builder: (context, snapshot) {
        final checkIns = snapshot.data ?? [];
        final validCheckIns = checkIns
            .where((c) => c.beverageType != 'Skipped')
            .toList();

        if (validCheckIns.isEmpty) {
          return const SizedBox();
        }

        // Group by time period
        final Map<String, double> timeIntake = {
          'Morning\n(6AM-12PM)': 0,
          'Afternoon\n(12PM-6PM)': 0,
          'Evening\n(6PM-12AM)': 0,
          'Night\n(12AM-6AM)': 0,
        };

        for (var checkIn in validCheckIns) {
          final hour = checkIn.timestamp.hour;
          if (hour >= 6 && hour < 12) {
            timeIntake['Morning\n(6AM-12PM)'] =
                timeIntake['Morning\n(6AM-12PM)']! + checkIn.amountMl;
          } else if (hour >= 12 && hour < 18) {
            timeIntake['Afternoon\n(12PM-6PM)'] =
                timeIntake['Afternoon\n(12PM-6PM)']! + checkIn.amountMl;
          } else if (hour >= 18 && hour < 24) {
            timeIntake['Evening\n(6PM-12AM)'] =
                timeIntake['Evening\n(6PM-12AM)']! + checkIn.amountMl;
          } else {
            timeIntake['Night\n(12AM-6AM)'] =
                timeIntake['Night\n(12AM-6AM)']! + checkIn.amountMl;
          }
        }

        final maxValue = timeIntake.values.reduce((a, b) => a > b ? a : b);

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.schedule, color: AppColors.primary, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'Time of Day Analysis',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: timeIntake.entries.map((entry) {
                  final height = maxValue > 0
                      ? (entry.value / maxValue * 120)
                      : 0.0;
                  return Column(
                    children: [
                      Text(
                        VolumeUtils.format(entry.value, _volumeUnit),
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 50,
                        height: height.clamp(20, 120),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.primary, AppColors.primaryLight],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(8),
                            topRight: Radius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: 70,
                        child: Text(
                          entry.key,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            color: AppColors.textSecondary,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecommendations(
    String userId,
    DateTime startDate,
    DateTime endDate,
    double dailyGoal,
  ) {
    return StreamBuilder<List<HydrationCheckIn>>(
      stream: _checkInService.watchCheckInsInRange(userId, startDate, endDate),
      builder: (context, snapshot) {
        final checkIns = snapshot.data ?? [];
        final validCheckIns = checkIns
            .where((c) => c.beverageType != 'Skipped')
            .toList();

        final avgIntake = validCheckIns.isEmpty
            ? 0.0
            : validCheckIns.fold<double>(0, (sum, c) => sum + c.amountMl) /
                  _selectedRange;

        final recommendations = <Map<String, dynamic>>[];

        // Recommendation based on average vs goal
        if (avgIntake < dailyGoal * 0.8) {
          recommendations.add({
            'icon': Icons.trending_down,
            'color': AppColors.error,
            'title': 'Increase Daily Intake',
            'description':
                'You\'re averaging ${VolumeUtils.format(avgIntake, _volumeUnit)} per day. Try to reach your goal of ${VolumeUtils.format(dailyGoal, _volumeUnit)}.',
          });
        } else if (avgIntake >= dailyGoal) {
          recommendations.add({
            'icon': Icons.celebration,
            'color': AppColors.success,
            'title': 'Great Job!',
            'description':
                'You\'re consistently meeting your daily goal. Keep up the excellent work!',
          });
        }

        // Check for morning hydration
        final morningCheckIns = validCheckIns
            .where((c) => c.timestamp.hour >= 6 && c.timestamp.hour < 10)
            .length;
        if (morningCheckIns < _selectedRange * 0.5) {
          recommendations.add({
            'icon': Icons.wb_sunny,
            'color': AppColors.warning,
            'title': 'Start Your Day Right',
            'description':
                'Try drinking water first thing in the morning to kickstart your hydration.',
          });
        }

        // Check for variety
        final beverageTypes = validCheckIns.map((c) => c.beverageType).toSet();
        if (beverageTypes.length == 1 && beverageTypes.first == 'Water') {
          recommendations.add({
            'icon': Icons.local_cafe,
            'color': AppColors.primaryLight,
            'title': 'Mix It Up',
            'description':
                'Consider tracking other beverages like tea or coffee to get a complete picture.',
          });
        }

        if (recommendations.isEmpty) {
          recommendations.add({
            'icon': Icons.star,
            'color': AppColors.accent,
            'title': 'Doing Well',
            'description':
                'Your hydration habits look good! Keep logging to maintain your streak.',
          });
        }

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.lightbulb, color: AppColors.primary, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'Recommendations',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...recommendations.map((rec) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: rec['color'].withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(rec['icon'], color: rec['color'], size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rec['title'],
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              rec['description'],
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        );
      },
    );
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
      default:
        return AppColors.accent;
    }
  }
}
