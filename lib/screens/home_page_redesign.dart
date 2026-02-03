import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/schedule_service.dart';
import '../services/checkin_service.dart';
import '../models/hydration_models.dart';
import '../services/hybrid_sync_service.dart';
import '../models/io_models.dart';
import '../theme/app_theme.dart';
import 'intake_recording_page.dart';
import '../widgets/hydration_progress_ring.dart';
import '../widgets/hydration_wave_card.dart';

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
  late Future<DailyFluidSummary?> _summaryFuture;

  @override
  void initState() {
    super.initState();
    _loadSummary();
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

  void _openIntakeDialogWithVolume(double volume) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            IntakeRecordingPage(onSaved: _loadSummary, initialVolume: volume),
      ),
    );
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
                  _buildHydrationFocus(summary),
                  const SizedBox(height: 20),
                  _buildTodayScheduleStatus(),
                  const SizedBox(height: 20),
                  _buildHydrationWave(summary),
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

  Widget _buildIntakeProgressCard(DailyFluidSummary? summary) {
    if (summary == null) {
      return _buildEmptyStateCard();
    }

    final totalIntake = summary.totalIntake;
    const dailyGoal = 2000.0;
    final progress = (totalIntake / dailyGoal).clamp(0.0, 1.5);
    final percentage = (progress * 100).toStringAsFixed(0);
    final isAboveGoal = totalIntake > dailyGoal;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
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
                    'Today\'s Intake',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${totalIntake.toStringAsFixed(0)} ml',
                    style: GoogleFonts.poppins(
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Goal: ${dailyGoal.toStringAsFixed(0)} ml',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white60,
                    ),
                  ),
                ],
              ),
              // Circular progress indicator
              SizedBox(
                width: 100,
                height: 100,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: CircularProgressIndicator(
                        value: progress <= 1 ? progress : 1,
                        strokeWidth: 8,
                        backgroundColor: Colors.white12,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isAboveGoal ? Colors.greenAccent : Colors.white,
                        ),
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          percentage,
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '%',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(
                isAboveGoal ? Colors.greenAccent : Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Status text
          Text(
            isAboveGoal
                ? '✓ Great! You\'ve reached your daily goal'
                : 'Keep going! You\'re doing great',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: isAboveGoal ? Colors.greenAccent : Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
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
                    '${summary.estimatedOutput.toStringAsFixed(0)} ml',
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

  Widget _buildQuickActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                icon: Icons.water_drop,
                label: 'Log Water',
                color: AppColors.primary,
                onTap: _openIntakeDialog,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                icon: Icons.show_chart,
                label: 'View Shifts',
                color: AppColors.accent,
                onTap: () {
                  // Navigate to shift summary
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShiftBreakdown(DailyFluidSummary? summary) {
    if (summary == null) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Shift Breakdown',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        _buildShiftCard('Morning', summary.morningShift, '6:00 - 2:00 PM'),
        const SizedBox(height: 10),
        _buildShiftCard('Afternoon', summary.afternoonShift, '2:00 - 10:00 PM'),
        const SizedBox(height: 10),
        _buildShiftCard('Night', summary.nightShift, '10:00 PM - 6:00 AM'),
      ],
    );
  }

  Widget _buildShiftCard(String shift, ShiftData data, String timeRange) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                shift,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                timeRange,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'I: ${data.totalIntake.toStringAsFixed(0)} ml',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              Text(
                'E: ${data.estimatedOutput.toStringAsFixed(0)} ml',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHydrationFocus(DailyFluidSummary? summary) {
    final totalIntake = summary?.totalIntake ?? 0.0;
    const dailyGoal = 2000.0;
    final progress = (totalIntake / dailyGoal).clamp(0.0, 1.0);
    final remaining = (dailyGoal - totalIntake).clamp(0.0, dailyGoal);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current Hydration',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: HydrationProgressRing(
              progress: progress,
              currentMl: totalIntake,
              goalMl: dailyGoal,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${remaining.toStringAsFixed(0)} ml remaining',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppColors.textSecondary,
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
                .where((s) => s.enabled)
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

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.access_time, color: AppColors.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
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
                    );
                  }),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildHydrationWave(DailyFluidSummary? summary) {
    final totalIntake = summary?.totalIntake ?? 0.0;
    const dailyGoal = 2000.0;
    final progress = (totalIntake / dailyGoal).clamp(0.0, 1.0);
    return HydrationWaveCard(
      progress: progress,
      title: 'Hydration flow',
      subtitle: 'Stay consistent to build your streak.',
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
                            '${entry.timestamp.hour.toString().padLeft(2, '0')}:${entry.timestamp.minute.toString().padLeft(2, '0')}',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${entry.volume.toStringAsFixed(0)} ml',
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
