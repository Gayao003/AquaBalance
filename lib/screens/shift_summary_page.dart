import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/io_models.dart';
import '../services/io_service.dart';
import '../services/auth_service.dart';

class ShiftSummaryPage extends StatefulWidget {
  const ShiftSummaryPage({super.key});

  @override
  State<ShiftSummaryPage> createState() => _ShiftSummaryPageState();
}

class _ShiftSummaryPageState extends State<ShiftSummaryPage> {
  final _ioService = IOService();
  final _authService = AuthService();
  late Future<DailyFluidSummary?> _summaryFuture;
  int _selectedTab = 0; // 0: Morning, 1: Afternoon, 2: Night

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  void _loadSummary() {
    setState(() {
      _summaryFuture = _ioService.getDailySummary(
        userId: _authService.currentUser?.uid ?? '',
        date: DateTime.now(),
      );
    });
  }

  String _getShiftLabel(int index) =>
      ['Morning (6-14)', 'Afternoon (14-22)', 'Night (22-6)'][index];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Shift Summary',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      body: FutureBuilder<DailyFluidSummary?>(
        future: _summaryFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final summary = snapshot.data;

          if (summary == null) {
            return Center(
              child: Text(
                'No data recorded yet',
                style: GoogleFonts.poppins(color: Colors.grey),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Date indicator
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Today\'s Summary',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                // Daily totals
                _buildDailyTotalsCard(summary),

                const SizedBox(height: 24),

                // Shift tabs
                _buildShiftTabs(),

                const SizedBox(height: 16),

                // Shift details
                _buildShiftDetailsCard(summary),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDailyTotalsCard(DailyFluidSummary summary) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildTotalCard(
                'Total Intake',
                '${summary.totalIntake.toStringAsFixed(0)} ml',
                Colors.blue,
              ),
              _buildTotalCard(
                'Total Output',
                '${summary.estimatedOutput.toStringAsFixed(0)} ml (Est.)',
                Colors.orange,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTotalCard(
            'Difference (I - O)',
            '${(summary.totalIntake - summary.estimatedOutput).toStringAsFixed(0)} ml',
            _getDifferenceColor(summary.totalIntake - summary.estimatedOutput),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShiftTabs() {
    return Row(
      children: List.generate(3, (index) {
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedTab = index),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: _selectedTab == index
                        ? Colors.blue
                        : Colors.transparent,
                    width: 3,
                  ),
                ),
              ),
              child: Text(
                _getShiftLabel(index).split(' ')[0],
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: _selectedTab == index
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: _selectedTab == index ? Colors.blue : Colors.grey,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildShiftDetailsCard(DailyFluidSummary summary) {
    final shifts = [
      summary.morningShift,
      summary.afternoonShift,
      summary.nightShift,
    ];
    final shiftData = shifts[_selectedTab];

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
            _getShiftLabel(_selectedTab),
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Intake details
          _buildShiftMetricCard(
            'Intake',
            shiftData.totalIntake,
            Colors.blue,
            shiftData.intakeCount,
          ),
          const SizedBox(height: 12),

          // Output details
          _buildShiftMetricCard(
            'Output',
            shiftData.estimatedOutput,
            Colors.orange,
            shiftData
                .intakeCount, // Show intake count since output count doesn't exist
          ),
          const SizedBox(height: 16),

          // Status indicator
          _buildStatusIndicator(summary),
        ],
      ),
    );
  }

  Widget _buildShiftMetricCard(
    String label,
    double value,
    Color color,
    int count,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${value.toStringAsFixed(0)} ml',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          Text(
            '$count entries',
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(DailyFluidSummary summary) {
    final intakeStatus = summary.intakeStatus;
    // Output status removed - using intake-based estimation instead

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Status',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildStatusBadge(
                'Intake: ${intakeStatus.getStatusText()}',
                intakeStatus,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: _buildStatusBadge('Intake', summary.intakeStatus)),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String label, FluidStatus status) {
    final color = status == FluidStatus.within
        ? Colors.green
        : status == FluidStatus.below
        ? Colors.orange
        : Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Color _getDifferenceColor(double difference) {
    if (difference == 0) return Colors.green;
    if (difference < 0) return Colors.orange;
    return Colors.blue;
  }
}
