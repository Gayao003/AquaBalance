import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/alarm_service.dart';
import '../theme/app_theme.dart';

class RemindersPage extends StatefulWidget {
  const RemindersPage({super.key});

  @override
  State<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends State<RemindersPage> {
  final _alarmService = AlarmService();
  List<String> _enabledReminders = [];
  bool _remindersEnabled = true;

  final List<String> _availableTimes = [
    '08:00 AM',
    '11:00 AM',
    '02:00 PM',
    '05:00 PM',
    '08:00 PM',
  ];

  final List<String> _timeValues = [
    '08:00',
    '11:00',
    '14:00',
    '17:00',
    '20:00',
  ];

  @override
  void initState() {
    super.initState();
    _initializeReminders();
  }

  void _initializeReminders() async {
    await _alarmService.initialize();
    setState(() {
      _enabledReminders = _timeValues.toList();
    });
  }

  void _toggleReminder(String time) {
    setState(() {
      if (_enabledReminders.contains(time)) {
        _enabledReminders.remove(time);
      } else {
        _enabledReminders.add(time);
      }
    });
    _scheduleReminders();
  }

  void _scheduleReminders() async {
    await _alarmService.cancelAllReminders();
    if (_remindersEnabled) {
      for (var i = 0; i < _enabledReminders.length; i++) {
        final time = _enabledReminders[i].split(':');
        final hour = int.parse(time[0]);
        final minute = int.parse(time[1]);

        await _alarmService.scheduleWaterReminder(
          hour: hour,
          minute: minute,
          timezoneIdentifier: 'local',
        );
      }
    }
  }

  void _toggleAllReminders() {
    setState(() {
      _remindersEnabled = !_remindersEnabled;
    });
    _scheduleReminders();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 1,
        title: Text(
          'Water Reminders',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Master Toggle
              _buildMasterToggleCard(),
              const SizedBox(height: 32),

              if (_remindersEnabled) ...[
                Text(
                  'Daily Reminders',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                ...List.generate(
                  _availableTimes.length,
                  (index) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildReminderCard(
                      _availableTimes[index],
                      _timeValues[index],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildInfoCard(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMasterToggleCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reminder Notifications',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _remindersEnabled ? 'Enabled' : 'Disabled',
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
          Switch(
            value: _remindersEnabled,
            onChanged: (_) => _toggleAllReminders(),
            activeColor: Colors.white,
            activeTrackColor: AppColors.primary.withOpacity(0.4),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderCard(String displayTime, String timeValue) {
    final isEnabled = _enabledReminders.contains(timeValue);

    return GestureDetector(
      onTap: () => _toggleReminder(timeValue),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isEnabled
              ? AppColors.primaryLight.withOpacity(0.1)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isEnabled
                ? AppColors.primary.withOpacity(0.3)
                : AppColors.border,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  color: isEnabled
                      ? AppColors.primary
                      : AppColors.textSecondary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayTime,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isEnabled
                            ? AppColors.primary
                            : AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Daily reminder',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isEnabled ? AppColors.primary : Colors.transparent,
                border: Border.all(
                  color: isEnabled ? AppColors.primary : AppColors.border,
                  width: 2,
                ),
              ),
              child: isEnabled
                  ? const Center(
                      child: Icon(Icons.check, size: 16, color: Colors.white),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.accentLight.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: AppColors.accent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Notifications will remind you to log your water intake at the selected times each day.',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
