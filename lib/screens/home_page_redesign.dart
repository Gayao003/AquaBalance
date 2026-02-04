import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../services/auth_service.dart';
import '../services/schedule_service.dart';
import '../services/checkin_service.dart';
import '../models/hydration_models.dart';
import '../services/hybrid_sync_service.dart';
import '../models/io_models.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import 'intake_recording_page.dart';
import '../widgets/hydration_progress_ring.dart';
import '../widgets/hydration_wave_card.dart';
import '../util/volume_utils.dart';

class HomePageRedesign extends StatefulWidget {
  final VoidCallback? onOpenDrawer;

  const HomePageRedesign({super.key, this.onOpenDrawer});

  @override
  State<HomePageRedesign> createState() => _HomePageRedesignState();
}

class _HomePageRedesignState extends State<HomePageRedesign> {
  final _hybridSyncService = HybridSyncService();
  final _authService = AuthService();
  final _scheduleService = ScheduleService();
  final _checkInService = CheckInService();
  final _userService = UserService();
  late Future<DailyFluidSummary?> _summaryFuture;
  String _volumeUnit = 'ml';

  @override
  void initState() {
    super.initState();
    _loadSummary();
    _loadVolumeUnit();
  }

  void _loadVolumeUnit() {
    final userId = _authService.currentUser?.uid ?? '';
    if (userId.isEmpty) return;
    _userService.getUserProfile(userId).then((profile) {
      if (!mounted || profile == null) return;
      setState(() => _volumeUnit = profile.volumeUnit);
    });
  }

  bool _isScheduleActiveToday(HydrationSchedule schedule, DateTime today) {
    if (!schedule.enabled) return false;
    final dayStart = DateTime(today.year, today.month, today.day);
    final startDate = schedule.startDate == null
        ? null
        : DateTime(
            schedule.startDate!.year,
            schedule.startDate!.month,
            schedule.startDate!.day,
          );
    final endDate = schedule.endDate == null
        ? null
        : DateTime(
            schedule.endDate!.year,
            schedule.endDate!.month,
            schedule.endDate!.day,
          );

    if (startDate != null && startDate.isAfter(dayStart)) return false;
    if (endDate != null && endDate.isBefore(dayStart)) return false;
    return true;
  }

  double _dailyGoalFromSchedules(
    List<HydrationSchedule> schedules,
    DateTime today,
  ) {
    final activeSchedules = schedules.where(
      (s) => _isScheduleActiveToday(s, today),
    );
    final total = activeSchedules.fold<double>(0, (sum, s) => sum + s.amountMl);
    return total <= 0 ? 2000.0 : total;
  }

  void _loadSummary() {
    setState(() {
      _summaryFuture = _hybridSyncService.getDailySummary(
        userId: _authService.currentUser?.uid ?? '',
        date: DateTime.now(),
      );
    });
  }

  void _openIntakeDialog() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => IntakeRecordingPage(onSaved: _loadSummary),
      ),
    );
  }

  Future<void> _quickLogSchedule(HydrationSchedule schedule) async {
    final userId = _authService.currentUser?.uid ?? '';
    if (userId.isEmpty) return;

    final checkIn = HydrationCheckIn(
      id: const Uuid().v4(),
      userId: userId,
      scheduleId: schedule.id,
      beverageType: schedule.beverageType,
      amountMl: schedule.amountMl,
      timestamp: DateTime.now(),
    );

    await _checkInService.addCheckIn(userId, checkIn);
    _loadSummary();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Logged ${VolumeUtils.format(schedule.amountMl, _volumeUnit)} of ${schedule.beverageType}',
          ),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _skipSchedule(HydrationSchedule schedule) async {
    final userId = _authService.currentUser?.uid ?? '';
    if (userId.isEmpty) return;

    final checkIn = HydrationCheckIn(
      id: const Uuid().v4(),
      userId: userId,
      scheduleId: schedule.id,
      beverageType: 'Skipped',
      amountMl: 0,
      timestamp: DateTime.now(),
    );

    await _checkInService.addCheckIn(userId, checkIn);
    _loadSummary();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Schedule marked as skipped'),
          backgroundColor: AppColors.error,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Home',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        leading: widget.onOpenDrawer == null
            ? null
            : IconButton(
                icon: const Icon(Icons.menu),
                onPressed: widget.onOpenDrawer,
              ),
      ),
      body: FutureBuilder<DailyFluidSummary?>(
        future: _summaryFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          final summary = snapshot.data;

          return RefreshIndicator(
            onRefresh: () async => _loadSummary(),
            color: AppColors.primary,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildGreetingSection(),
                  const SizedBox(height: 20),
                  _buildHydrationOverview(summary),
                  const SizedBox(height: 20),
                  _buildTodayScheduleStatus(),
                  const SizedBox(height: 24),
                  _buildEstimatedOutputCard(summary),
                  const SizedBox(height: 24),
                  _buildRecentEntries(summary),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGreetingSection() {
    final now = DateTime.now();
    final hour = now.hour;
    String greeting;

    if (hour < 12) {
      greeting = 'Good Morning ☀️';
    } else if (hour < 17) {
      greeting = 'Good Afternoon 🌤️';
    } else {
      greeting = 'Good Evening 🌙';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          greeting,
          style: GoogleFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          DateFormat('EEEE, MMMM d, y').format(now),
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildEstimatedOutputCard(DailyFluidSummary? summary) {
    if (summary == null) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.accentLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accent.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Estimated Output',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    VolumeUtils.format(summary.estimatedOutput, _volumeUnit),
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.opacity, color: AppColors.accent, size: 32),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Confidence: ${summary.estimatedOutputConfidence}',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Based on your fluid intake and health factors',
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHydrationOverview(DailyFluidSummary? summary) {
    final userId = _authService.currentUser?.uid ?? '';
    final totalIntake = summary?.totalIntake ?? 0.0;
    const fallbackGoal = 2000.0;

    if (userId.isEmpty) {
      final progress = (totalIntake / fallbackGoal).clamp(0.0, 1.0);
      final remaining = (fallbackGoal - totalIntake).clamp(0.0, fallbackGoal);
      return Column(
        children: [
          _buildHydrationFocusCard(
            progress: progress,
            currentMl: totalIntake,
            goalMl: fallbackGoal,
            remainingMl: remaining,
          ),
          const SizedBox(height: 16),
          _buildHydrationWaveInline(progress, totalIntake, fallbackGoal),
        ],
      );
    }

    return StreamBuilder<List<HydrationSchedule>>(
      stream: _scheduleService.watchSchedules(userId),
      builder: (context, snapshot) {
        final schedules = snapshot.data ?? <HydrationSchedule>[];
        final goal = _dailyGoalFromSchedules(schedules, DateTime.now());
        final progress = (totalIntake / goal).clamp(0.0, 1.0);
        final remaining = (goal - totalIntake).clamp(0.0, goal);
        return Column(
          children: [
            _buildHydrationFocusCard(
              progress: progress,
              currentMl: totalIntake,
              goalMl: goal,
              remainingMl: remaining,
            ),
            const SizedBox(height: 16),
            _buildHydrationWaveInline(progress, totalIntake, goal),
          ],
        );
      },
    );
  }

  Widget _buildHydrationFocusCard({
    required double progress,
    required double currentMl,
    required double goalMl,
    required double remainingMl,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryLight.withOpacity(0.8),
            AppColors.primary.withOpacity(0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
          bottomLeft: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Today\'s Progress',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${(progress * 100).toInt()}%',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: HydrationProgressRing(
              progress: progress,
              currentMl: currentMl,
              goalMl: goalMl,
              unit: _volumeUnit,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text(
                    VolumeUtils.format(currentMl, _volumeUnit),
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Current',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
              Container(height: 40, width: 1, color: Colors.white30),
              Column(
                children: [
                  Text(
                    VolumeUtils.format(goalMl, _volumeUnit),
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Goal',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHydrationWaveInline(
    double progress,
    double currentMl,
    double goalMl,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.water_drop,
              color: AppColors.primary,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hydration Flow',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  progress >= 1.0
                      ? '🎉 Goal reached! Keep it up!'
                      : progress >= 0.75
                      ? 'Almost there! You\'re doing great!'
                      : progress >= 0.5
                      ? 'Halfway through your goal'
                      : 'Keep drinking to reach your goal',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: AppColors.border,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progress >= 1.0 ? AppColors.success : AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayScheduleStatus() {
    final userId = _authService.currentUser?.uid ?? '';
    if (userId.isEmpty) {
      return const SizedBox.shrink();
    }

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    return StreamBuilder<List<HydrationSchedule>>(
      stream: _scheduleService.watchSchedules(userId),
      builder: (context, scheduleSnapshot) {
        final schedules =
            (scheduleSnapshot.data ?? <HydrationSchedule>[])
                .where((s) => _isScheduleActiveToday(s, now))
                .toList()
              ..sort((a, b) {
                final aMinutes = a.hour * 60 + a.minute;
                final bMinutes = b.hour * 60 + b.minute;
                return aMinutes.compareTo(bMinutes);
              });

        return StreamBuilder<List<HydrationCheckIn>>(
          stream: _checkInService.watchCheckInsInRange(
            userId,
            startOfDay,
            endOfDay,
          ),
          builder: (context, checkInSnapshot) {
            final checkins = checkInSnapshot.data ?? <HydrationCheckIn>[];
            checkins.sort((a, b) => b.timestamp.compareTo(a.timestamp));

            final latestBySchedule = <int, HydrationCheckIn>{};
            for (final checkin in checkins) {
              final scheduleId = checkin.scheduleId;
              if (scheduleId == null) continue;
              latestBySchedule.putIfAbsent(scheduleId, () => checkin);
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Today's schedule",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                if (schedules.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      'No schedules yet. Add a schedule to see today\'s plan.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                else
                  ...schedules.map((schedule) {
                    final scheduledTime = DateTime(
                      now.year,
                      now.month,
                      now.day,
                      schedule.hour,
                      schedule.minute,
                    );

                    final latest = latestBySchedule[schedule.id];
                    String statusLabel;
                    Color statusColor;

                    if (latest != null) {
                      if ((latest.amountMl) == 0 ||
                          latest.beverageType.toLowerCase() == 'skipped') {
                        statusLabel = 'Skipped';
                        statusColor = AppColors.error;
                      } else {
                        statusLabel = 'Logged';
                        statusColor = AppColors.primary;
                      }
                    } else if (now.isBefore(scheduledTime)) {
                      statusLabel = 'Pending';
                      statusColor = AppColors.textSecondary;
                    } else {
                      statusLabel = 'Missed';
                      statusColor = AppColors.warning;
                    }

                    final canLog = latest == null;

                    return GestureDetector(
                      onTap: canLog
                          ? () => _showScheduleActions(schedule)
                          : null,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: canLog && !now.isBefore(scheduledTime)
                                ? AppColors.primary
                                : AppColors.border,
                            width: canLog && !now.isBefore(scheduledTime)
                                ? 2
                                : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              color: canLog && !now.isBefore(scheduledTime)
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        TimeOfDay(
                                          hour: schedule.hour,
                                          minute: schedule.minute,
                                        ).format(context),
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      if (canLog &&
                                          !now.isBefore(scheduledTime))
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            left: 8,
                                          ),
                                          child: Text(
                                            'Tap to log',
                                            style: GoogleFonts.poppins(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.primary,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    schedule.label.isEmpty
                                        ? 'Hydration reminder'
                                        : schedule.label,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${schedule.beverageType} • ${VolumeUtils.format(schedule.amountMl, _volumeUnit)}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                statusLabel,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            );
          },
        );
      },
    );
  }

  void _showScheduleActions(HydrationSchedule schedule) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              TimeOfDay(
                hour: schedule.hour,
                minute: schedule.minute,
              ).format(context),
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${schedule.beverageType} • ${VolumeUtils.format(schedule.amountMl, _volumeUnit)}',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _quickLogSchedule(schedule);
                },
                icon: const Icon(Icons.check_circle),
                label: Text(
                  'Log ${VolumeUtils.format(schedule.amountMl, _volumeUnit)}',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _skipSchedule(schedule);
                },
                icon: const Icon(Icons.close),
                label: Text(
                  'Mark as Skipped',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyStateCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.water_drop_outlined, color: AppColors.primary),
          const SizedBox(height: 8),
          Text(
            'No data yet',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Log your first intake to see progress here.',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentEntries(DailyFluidSummary? summary) {
    if (summary == null || summary.intakeEntries.isEmpty) {
      return const SizedBox();
    }

    final entries = [...summary.intakeEntries]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent entries',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ...entries
            .take(4)
            .map(
              (entry) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.water_drop, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.fluidType,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat('h:mm a').format(entry.timestamp),
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      VolumeUtils.format(entry.volume, _volumeUnit),
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
