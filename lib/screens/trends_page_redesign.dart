import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/io_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/hydration_progress_ring.dart';

class TrendsPageRedesign extends StatefulWidget {
  final VoidCallback? onOpenDrawer;

  const TrendsPageRedesign({super.key, this.onOpenDrawer});

  @override
  State<TrendsPageRedesign> createState() => _TrendsPageRedesignState();
}

class _TrendsPageRedesignState extends State<TrendsPageRedesign> {
  final _ioService = IOService();
  final _authService = AuthService();
  late Future<Map<String, dynamic>> _trendDataFuture;
  int _selectedRange = 0;

  @override
  void initState() {
    super.initState();
    _loadTrendData();
  }

  void _loadTrendData() {
    final endDate = DateTime.now();
    final days = [7, 14, 30][_selectedRange];
    final startDate = endDate.subtract(Duration(days: days - 1));

    setState(() {
      _trendDataFuture = _ioService
          .getSummaryForDateRange(
            userId: _authService.currentUser?.uid ?? '',
            startDate: startDate,
            endDate: endDate,
          )
          .then((summaries) async {
            return {
              'summaries': summaries,
              'startDate': startDate,
              'endDate': endDate,
              'days': days,
            };
          });
    });
  }

  @override
  Widget build(BuildContext context) {
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
      body: FutureBuilder<Map<String, dynamic>>(
        future: _trendDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Text(
                'Error loading trends',
                style: GoogleFonts.poppins(color: AppColors.textSecondary),
              ),
            );
          }

          final data = snapshot.data!;
          final summaries = data['summaries'] as List;

          if (summaries.isEmpty) {
            return Center(
              child: Text(
                'No data available',
                style: GoogleFonts.poppins(color: AppColors.textSecondary),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRangeSelector(),
                const SizedBox(height: 20),
                _buildHydrationScoreCard(summaries),
                const SizedBox(height: 20),
                _buildSummaryStatsCards(summaries),
                const SizedBox(height: 20),
                _buildIntakeTrendChart(summaries),
                const SizedBox(height: 20),
                _buildStatisticsGrid(summaries),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHydrationScoreCard(List<dynamic> summaries) {
    const goal = 2000.0;
    final totalIntake = summaries.fold<double>(
      0,
      (sum, s) => sum + (s.totalIntake ?? 0),
    );
    final avgIntake = totalIntake / summaries.length;
    final progress = (avgIntake / goal).clamp(0.0, 1.0);

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
          Text(
            'Hydration score',
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
              currentMl: avgIntake,
              goalMl: goal,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Based on your average intake over the selected range.',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRangeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: List.generate(3, (index) {
          final isSelected = _selectedRange == index;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedRange = index);
                _loadTrendData();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  ['7d', '14d', '30d'][index],
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSummaryStatsCards(List<dynamic> summaries) {
    final totalIntake = summaries.fold<double>(
      0,
      (sum, s) => sum + (s.totalIntake ?? 0),
    );
    final avgIntake = totalIntake / summaries.length;
    final maxIntake = summaries.fold<double>(
      0,
      (max, s) => (s.totalIntake ?? 0) > max ? (s.totalIntake ?? 0) : max,
    );

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total',
                '${totalIntake.toStringAsFixed(0)} ml',
                Icons.water_drop,
                AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Average',
                '${avgIntake.toStringAsFixed(0)} ml',
                Icons.trending_up,
                AppColors.accent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Peak',
                '${maxIntake.toStringAsFixed(0)} ml',
                Icons.show_chart,
                Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Days',
                '${summaries.length}',
                Icons.calendar_today,
                Colors.purple,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntakeTrendChart(List<dynamic> summaries) {
    final chartData = <FlSpot>[];
    for (int i = 0; i < summaries.length; i++) {
      chartData.add(
        FlSpot(i.toDouble(), (summaries[i].totalIntake ?? 0).toDouble()),
      );
    }

    final avgIntake =
        summaries.fold<double>(0, (sum, s) => sum + (s.totalIntake ?? 0)) /
        summaries.length;

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
            'Intake Trend',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 500,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: AppColors.border.withOpacity(0.5),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) => Text(
                        '${value.toInt()}',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) => Text(
                        '${value.toInt()}',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: chartData,
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 3,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.primary.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Average: ${avgIntake.toStringAsFixed(0)} ml/day',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
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

  Widget _buildStatisticsGrid(List<dynamic> summaries) {
    final daysAboveGoal = summaries
        .where((s) => (s.totalIntake ?? 0) >= 2000)
        .length;
    final consecutiveDays = _getConsecutiveDays(summaries);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Insights',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        _buildInsightTile(
          'Days at Goal',
          '$daysAboveGoal/${summaries.length} days met 2L target',
          Icons.check_circle,
          Colors.green,
        ),
        const SizedBox(height: 10),
        _buildInsightTile(
          'Streak',
          '$consecutiveDays day streak',
          Icons.local_fire_department,
          Colors.red,
        ),
      ],
    );
  }

  Widget _buildInsightTile(
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _getConsecutiveDays(List<dynamic> summaries) {
    int streak = 0;
    for (int i = summaries.length - 1; i >= 0; i--) {
      if ((summaries[i].totalIntake ?? 0) >= 2000) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }
}
