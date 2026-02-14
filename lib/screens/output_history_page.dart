import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../services/checkin_service.dart';
import '../services/user_service.dart';
import '../models/hydration_models.dart';
import '../theme/app_theme.dart';
import '../util/volume_utils.dart';

class OutputHistoryPage extends StatefulWidget {
  const OutputHistoryPage({super.key});

  @override
  State<OutputHistoryPage> createState() => _OutputHistoryPageState();
}

class _OutputHistoryPageState extends State<OutputHistoryPage> {
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

  double _estimateUrinaryOutput(double intakeMl) {
    // Typical urinary output is approximately 60-70% of fluid intake
    return intakeMl * 0.65; // Using 65% as average estimation
  }

  @override
  Widget build(BuildContext context) {
    final userId = _authService.currentUser?.uid ?? '';

    if (userId.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            'Output History',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
        ),
        body: const Center(child: Text('Sign in to view output history')),
      );
    }

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Output History',
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

          final checkIns = checkInSnapshot.data ?? [];
          final totalIntake = checkIns.fold<double>(
            0,
            (sum, checkIn) => sum + checkIn.amountMl,
          );
          final estimatedOutput = _estimateUrinaryOutput(totalIntake);

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryCard(totalIntake, estimatedOutput),
                const SizedBox(height: 20),
                _buildDisclaimerCard(),
                const SizedBox(height: 20),
                Text(
                  'Output Breakdown',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: totalIntake == 0
                      ? _buildEmptyState()
                      : ListView(
                          children: [
                            _buildOutputEstimateCard(
                              'Urinary Output',
                              estimatedOutput,
                              Icons.water_drop,
                              AppColors.primary,
                              '~65% of intake',
                            ),
                            _buildOutputEstimateCard(
                              'Perspiration & Respiration',
                              totalIntake * 0.25,
                              Icons.air,
                              AppColors.warning,
                              '~25% of intake',
                            ),
                            _buildOutputEstimateCard(
                              'Other Losses',
                              totalIntake * 0.10,
                              Icons.more_horiz,
                              AppColors.primaryLight,
                              '~10% of intake',
                            ),
                          ],
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(double intakeMl, double estimatedOutputMl) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.accent.withOpacity(0.8), AppColors.accent],
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
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    VolumeUtils.format(intakeMl, _volumeUnit),
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const Icon(Icons.trending_up, color: Colors.white, size: 32),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Estimated Total Output',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      VolumeUtils.format(estimatedOutputMl, _volumeUnit),
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const Icon(Icons.trending_down, color: Colors.white, size: 28),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimerCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withOpacity(0.3), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: AppColors.warning, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'These are estimated values based on your fluid intake. Actual output varies based on physical activity, temperature, diet, metabolism, and individual health factors. Consult a healthcare provider for accurate tracking.',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutputEstimateCard(
    String title,
    double amountMl,
    IconData icon,
    Color color,
    String subtitle,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            VolumeUtils.format(amountMl, _volumeUnit),
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
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
            Icons.water_damage_outlined,
            size: 64,
            color: AppColors.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No intake data available',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Log your fluid intake to see\nestimated output data',
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
