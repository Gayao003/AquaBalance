import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../services/hybrid_sync_service.dart';
import '../models/io_models.dart';
import 'intake_recording_page.dart';
import 'output_recording_page.dart';
import 'shift_summary_page.dart';
import 'trends_page.dart';
import 'settings_page.dart';

class MainAppPage extends StatefulWidget {
  const MainAppPage({super.key});

  @override
  State<MainAppPage> createState() => _MainAppPageState();
}

class _MainAppPageState extends State<MainAppPage> {
  int _selectedIndex = 0;
  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const HomePage(),
      const ShiftSummaryPage(),
      const TrendsPage(),
      const SettingsPage(),
    ];
  }

  void _showAddMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Add Entry',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.water_drop, color: Colors.blue),
              title: Text('Record Intake', style: GoogleFonts.poppins()),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        IntakeRecordingPage(onSaved: _refreshPages),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.opacity, color: Colors.orange),
              title: Text('Record Output', style: GoogleFonts.poppins()),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        OutputRecordingPage(onSaved: _refreshPages),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _refreshPages() {
    setState(() {
      _pages = [
        const HomePage(),
        const ShiftSummaryPage(),
        const TrendsPage(),
        const SettingsPage(),
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() => _selectedIndex = index);
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.grid_3x3), label: 'Shifts'),
          BottomNavigationBarItem(
            icon: Icon(Icons.trending_up),
            label: 'Trends',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddMenu(context),
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _hybridSyncService = HybridSyncService();
  final _authService = AuthService();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'I&O Tracker',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadSummary),
        ],
      ),
      body: FutureBuilder<DailyFluidSummary?>(
        future: _summaryFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final summary = snapshot.data;

          return RefreshIndicator(
            onRefresh: () async => _loadSummary(),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Today's summary card
                  _buildSummaryCard(summary),

                  const SizedBox(height: 24),

                  // Quick stats
                  _buildQuickStats(summary),

                  const SizedBox(height: 24),

                  // Recent entries
                  _buildRecentEntries(summary),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(DailyFluidSummary? summary) {
    if (summary == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Center(
          child: Text(
            'No data recorded yet. Start by adding entries!',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: Colors.grey.shade700),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade400, Colors.blue.shade600],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            'Today\'s Summary',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSummaryItem(
                'Total Intake',
                '${summary.totalIntake.toStringAsFixed(0)} ml',
                Colors.white,
              ),
              Container(width: 1, height: 60, color: Colors.white30),
              _buildSummaryItem(
                'Total Output',
                '${summary.totalOutput.toStringAsFixed(0)} ml',
                Colors.white,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStats(DailyFluidSummary? summary) {
    if (summary == null) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Shift Breakdown',
          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildShiftCard('Morning (6-14)', summary.morningShift),
        const SizedBox(height: 8),
        _buildShiftCard('Afternoon (14-22)', summary.afternoonShift),
        const SizedBox(height: 8),
        _buildShiftCard('Night (22-6)', summary.nightShift),
      ],
    );
  }

  Widget _buildShiftCard(String shiftName, ShiftData shift) {
    return Container(
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
            shiftName,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          Row(
            children: [
              Text(
                'I: ${shift.totalIntake.toStringAsFixed(0)} ml',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.blue,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'O: ${shift.totalOutput.toStringAsFixed(0)} ml',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.orange,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentEntries(DailyFluidSummary? summary) {
    if (summary == null ||
        (summary.intakeEntries.isEmpty && summary.outputEntries.isEmpty)) {
      return const SizedBox();
    }

    final allEntries = <(String, double, String)>[];
    for (var e in summary.intakeEntries) {
      allEntries.add(('Intake', e.volume, e.fluidType));
    }
    for (var e in summary.outputEntries) {
      allEntries.add(('Output', e.volume, e.outputType));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Entries',
          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...allEntries.take(5).map((entry) {
          final type = entry.$1;
          final volume = entry.$2;
          final typeLabel = entry.$3;
          final isIntake = type == 'Intake';

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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      typeLabel,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${volume.toStringAsFixed(0)} ml',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isIntake ? Colors.blue : Colors.orange,
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
