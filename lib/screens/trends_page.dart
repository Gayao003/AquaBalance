import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/io_service.dart';
import '../services/auth_service.dart';

class TrendsPage extends StatefulWidget {
  const TrendsPage({super.key});

  @override
  State<TrendsPage> createState() => _TrendsPageState();
}

class _TrendsPageState extends State<TrendsPage> {
  final _ioService = IOService();
  final _authService = AuthService();
  late Future<Map<String, dynamic>> _trendDataFuture;
  int _selectedRange = 0; // 0: 7 days, 1: 14 days, 2: 30 days

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

  String _getRangeLabel() =>
      ['Last 7 Days', 'Last 14 Days', 'Last 30 Days'][_selectedRange];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Trends & History',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _trendDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Text(
                'Error loading trends',
                style: GoogleFonts.poppins(color: Colors.grey),
              ),
            );
          }

          final data = snapshot.data!;
          final summaries = data['summaries'] as List;

          if (summaries.isEmpty) {
            return Center(
              child: Text(
                'No data available',
                style: GoogleFonts.poppins(color: Colors.grey),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Range selector
                _buildRangeSelector(),

                const SizedBox(height: 24),

                // Summary stats
                _buildSummaryStats(summaries),

                const SizedBox(height: 24),

                // Intake vs Output bar chart
                _buildBarChart(summaries),

                const SizedBox(height: 24),

                // Average daily metrics
                _buildAverageMetrics(summaries),

                const SizedBox(height: 24),

                // Daily list
                _buildDailyList(summaries),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRangeSelector() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
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
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blue : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  ['7d', '14d', '30d'][index],
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: isSelected ? Colors.white : Colors.grey.shade700,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSummaryStats(List<dynamic> summaries) {
    final totalIntake = summaries.fold<double>(
      0,
      (sum, s) => sum + (s.totalIntake as double),
    );
    final totalOutput = summaries.fold<double>(
      0,
      (sum, s) => sum + (s.totalOutput as double),
    );
    final avgIntake = totalIntake / summaries.length;
    final avgOutput = totalOutput / summaries.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _getRangeLabel(),
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatItem(
                'Avg Daily\nIntake',
                '${avgIntake.toStringAsFixed(0)} ml',
                Colors.blue,
              ),
              _buildStatItem(
                'Avg Daily\nOutput',
                '${avgOutput.toStringAsFixed(0)} ml',
                Colors.orange,
              ),
              _buildStatItem(
                'Days\nTracked',
                '${summaries.length}',
                Colors.green,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: Colors.grey,
            height: 1.3,
          ),
        ),
      ],
    );
  }

  Widget _buildBarChart(List<dynamic> summaries) {
    final intakeData = summaries
        .take(7)
        .map((s) => (s.totalIntake as double) / 100)
        .toList();
    final outputData = summaries
        .take(7)
        .map((s) => (s.totalOutput as double) / 100)
        .toList();

    while (intakeData.length < 7) intakeData.add(0);
    while (outputData.length < 7) outputData.add(0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Daily Intake vs Output (Last 7 Days)',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 250,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 30,
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  show: true,
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt() * 100}',
                          style: const TextStyle(fontSize: 10),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final days = [
                          'Mon',
                          'Tue',
                          'Wed',
                          'Thu',
                          'Fri',
                          'Sat',
                          'Sun',
                        ];
                        final dayIndex = value.toInt() % days.length;
                        return Text(
                          days[dayIndex],
                          style: const TextStyle(fontSize: 10),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: List.generate(
                  intakeData.length,
                  (index) => BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: intakeData[index],
                        color: Colors.blue,
                        width: 8,
                      ),
                      BarChartRodData(
                        toY: outputData[index],
                        color: Colors.orange,
                        width: 8,
                      ),
                    ],
                    barsSpace: 3,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('Intake', Colors.blue),
              const SizedBox(width: 16),
              _buildLegendItem('Output', Colors.orange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.poppins(fontSize: 12)),
      ],
    );
  }

  Widget _buildAverageMetrics(List<dynamic> summaries) {
    final avgIntake =
        summaries.fold<double>(0, (sum, s) => sum + (s.totalIntake as double)) /
        summaries.length;
    final avgOutput =
        summaries.fold<double>(0, (sum, s) => sum + (s.totalOutput as double)) /
        summaries.length;
    final difference = avgIntake - avgOutput;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Average Metrics',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildMetricRow(
            'Avg Daily Intake',
            '${avgIntake.toStringAsFixed(0)} ml',
            Colors.blue,
          ),
          const SizedBox(height: 12),
          _buildMetricRow(
            'Avg Daily Output',
            '${avgOutput.toStringAsFixed(0)} ml',
            Colors.orange,
          ),
          const SizedBox(height: 12),
          _buildMetricRow(
            'Avg Difference (I-O)',
            '${difference.toStringAsFixed(0)} ml',
            difference >= 0 ? Colors.green : Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade700),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildDailyList(List<dynamic> summaries) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Daily Breakdown',
          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...summaries.asMap().entries.map((entry) {
          final index = entry.key;
          final summary = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Day ${index + 1}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'I: ${summary.totalIntake.toStringAsFixed(0)} ml',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.blue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'O: ${summary.totalOutput.toStringAsFixed(0)} ml',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
