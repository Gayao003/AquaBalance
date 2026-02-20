import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../services/alarm_service.dart';
import '../services/app_preferences_service.dart';
import '../services/hybrid_sync_service.dart';
import '../models/io_models.dart';
import '../theme/app_theme.dart';
import 'schedule_page.dart';
import 'trends_page_redesign.dart';
import 'home_page_redesign.dart' as home;
import 'settings_page_redesign.dart';
import 'login_page_new.dart';
import 'register_page_new.dart';
import 'profile_page.dart';
import 'intake_history_page.dart';
import 'output_history_page.dart';
import 'help_support_page.dart';
import 'about_page.dart';
import 'reports_page.dart';
import '../widgets/app_drawer.dart';

class MainAppPage extends StatefulWidget {
  const MainAppPage({super.key});

  @override
  State<MainAppPage> createState() => _MainAppPageState();
}

class _MainAppPageState extends State<MainAppPage> {
  int _selectedIndex = 0;
  late List<Widget> _pages;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _preferencesService = AppPreferencesService();
  final _alarmService = AlarmService();

  @override
  void initState() {
    super.initState();
    _pages = [
      home.HomePageRedesign(onOpenDrawer: _openDrawer),
      SchedulePage(onOpenDrawer: _openDrawer),
      TrendsPageRedesign(onOpenDrawer: _openDrawer),
      SettingsPageRedesign(onOpenDrawer: _openDrawer),
    ];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAndCheckNotificationPrompt();
    });
  }

  Future<void> _initializeAndCheckNotificationPrompt() async {
    await _preferencesService.loadPreferences();
    await _alarmService.initialize();

    if (!mounted) return;

    final systemEnabled = await _alarmService.areNotificationsEnabled();
    final appEnabled = _preferencesService.notificationsEnabledNotifier.value;
    if (!mounted || (appEnabled && systemEnabled)) return;

    await _showNotificationPrompt();
  }

  Future<void> _showNotificationPrompt() async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enable Notifications'),
        content: const Text(
          'Notifications are currently off. Turn them on to receive hydration reminders.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () async {
              final granted = await _alarmService.requestNotificationPermission();
              await _preferencesService.setNotificationsEnabled(granted);
              if (mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('Enable'),
          ),
        ],
      ),
    );
  }

  void _openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  void _navigateToPage({required Widget page}) {
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => page));
  }

  Future<void> _handleSignOut() async {
    await AuthService().signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => LoginPage(
          onNavigateToRegister: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => RegisterPageNew(
                  onNavigateToLogin: () => Navigator.pop(context),
                ),
              ),
            );
          },
        ),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: AppDrawer(
        selectedIndex: _selectedIndex,
        onSelectIndex: (index) {
          setState(() => _selectedIndex = index);
        },
        onNavigateToProfile: () => _navigateToPage(page: const ProfilePage()),
        onNavigateToIntakeHistory: () =>
            _navigateToPage(page: const IntakeHistoryPage()),
        onNavigateToOutputHistory: () =>
            _navigateToPage(page: const OutputHistoryPage()),
        onNavigateToReports: () => _navigateToPage(page: const ReportsPage()),
        onNavigateToHelp: () => _navigateToPage(page: const HelpSupportPage()),
        onNavigateToAbout: () => _navigateToPage(page: const AboutPage()),
        onSignOut: _handleSignOut,
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() => _selectedIndex = index);
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.schedule),
            label: 'Schedule',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.trending_up),
            label: 'Insights',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
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
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
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
                'Est. Output',
                '${summary.estimatedOutput.toStringAsFixed(0)} ml',
                Colors.white,
                subtitle: '${summary.estimatedOutputConfidence} confidence',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
    String label,
    String value,
    Color color, {
    String? subtitle,
  }) {
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
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: Colors.white60,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
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
                'Est O: ${shift.estimatedOutput.toStringAsFixed(0)} ml',
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
    if (summary == null || summary.intakeEntries.isEmpty) {
      return const SizedBox();
    }

    final allEntries = <(String, double, String, DateTime)>[];
    for (var e in summary.intakeEntries) {
      allEntries.add(('Intake', e.volume, e.fluidType, e.timestamp));
    }

    // Sort by timestamp (most recent first)
    allEntries.sort((a, b) => b.$4.compareTo(a.$4));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Intake',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (summary.estimationFactors.isNotEmpty)
              GestureDetector(
                onTap: () => _showEstimationDetails(context, summary),
                child: Icon(Icons.info_outline, color: Colors.blue, size: 20),
              ),
          ],
        ),
        const SizedBox(height: 12),
        ...allEntries.take(5).map((entry) {
          final type = entry.$1;
          final volume = entry.$2;
          final typeLabel = entry.$3;
          // Timestamp available as entry.$4 if needed

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
                    color: Colors.blue, // Always blue since only intake entries
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  void _showEstimationDetails(BuildContext context, DailyFluidSummary summary) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Output Estimation Details',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estimated: ${summary.estimatedOutput.toStringAsFixed(0)} ml',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Confidence: ${summary.estimatedOutputConfidence}',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Factors considered:',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ...summary.estimationFactors.map(
              (factor) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• $factor',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }
}
