import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/hydration_models.dart';
import '../services/auth_service.dart';
import '../services/checkin_service.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import '../util/volume_utils.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final _authService = AuthService();
  final _checkInService = CheckInService();
  final _userService = UserService();
  String _volumeUnit = 'ml';

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

  @override
  Widget build(BuildContext context) {
    final userId = _authService.currentUser?.uid ?? '';

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    final weekStart = todayStart.subtract(const Duration(days: 6));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Reports',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      body: userId.isEmpty
          ? const Center(child: Text('Sign in to view reports'))
          : StreamBuilder<List<HydrationCheckIn>>(
              stream: _checkInService.watchCheckInsInRange(
                userId,
                weekStart,
                todayEnd,
              ),
              builder: (context, snapshot) {
                final checkIns = snapshot.data ?? [];
                final todayCheckIns = checkIns
                    .where(
                      (c) =>
                          c.timestamp.isAfter(todayStart) &&
                          c.timestamp.isBefore(todayEnd),
                    )
                    .toList();

                final beverageCounts = <String, int>{};
                for (final checkIn in checkIns) {
                  beverageCounts.update(
                    checkIn.beverageType,
                    (value) => value + 1,
                    ifAbsent: () => 1,
                  );
                }

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildSummaryCard(
                      'Today',
                      '${todayCheckIns.length} check-ins',
                      'Last 24 hours',
                    ),
                    const SizedBox(height: 16),
                    _buildSummaryCard(
                      'This week',
                      '${checkIns.length} check-ins',
                      'Past 7 days',
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Beverage breakdown',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (beverageCounts.isEmpty)
                      _buildEmptyState()
                    else
                      ...beverageCounts.entries.map(
                        (entry) => _buildBreakdownTile(entry.key, entry.value),
                      ),
                    const SizedBox(height: 24),
                    Text(
                      'Recent check-ins',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (checkIns.isEmpty)
                      _buildEmptyState()
                    else
                      ...checkIns
                          .take(5)
                          .map((checkIn) => _buildRecentTile(checkIn)),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildSummaryCard(String title, String value, String subtitle) {
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
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownTile(String label, int count) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_drink, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Text(
            '$count',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTile(HydrationCheckIn checkIn) {
    return Container(
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
                  checkIn.beverageType,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${checkIn.timestamp.hour.toString().padLeft(2, '0')}:${checkIn.timestamp.minute.toString().padLeft(2, '0')}',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            VolumeUtils.format(checkIn.amountMl, _volumeUnit),
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.insert_chart_outlined, color: AppColors.primary),
          const SizedBox(height: 8),
          Text(
            'No data yet',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Check-ins will appear here once you start logging.',
            textAlign: TextAlign.center,
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
