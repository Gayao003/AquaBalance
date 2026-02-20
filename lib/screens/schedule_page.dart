import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/hydration_models.dart';
import '../models/health_profile.dart';
import '../services/alarm_service.dart';
import '../services/app_preferences_service.dart';
import '../services/auth_service.dart';
import '../services/schedule_service.dart';
import '../services/template_service.dart';
import '../services/tutorial_service.dart';
import '../services/user_service.dart';
import '../services/health_profile_service.dart';
import '../services/hydration_recommendation_engine.dart';
import '../theme/app_theme.dart';
import '../util/volume_utils.dart';
import '../widgets/page_tutorial_overlay.dart';

class SchedulePage extends StatefulWidget {
  final VoidCallback? onOpenDrawer;

  const SchedulePage({super.key, this.onOpenDrawer});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  final _alarmService = AlarmService();
  final _preferencesService = AppPreferencesService();
  final _scheduleService = ScheduleService();
  final _authService = AuthService();
  final _templateService = TemplateService();
  final _tutorialService = TutorialService();
  final _userService = UserService();
  final _healthProfileService = HealthProfileService();
  final Set<int> _scheduledIds = {};
  String _volumeUnit = 'ml';
  bool _tutorialChecked = false;

  @override
  void initState() {
    super.initState();
    _loadVolumeUnit();
    _checkHealthProfileAndShowPrompt();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowTutorial();
    });
  }

  Future<void> _maybeShowTutorial({bool force = false}) async {
    if (_tutorialChecked && !force) return;
    if (!force) _tutorialChecked = true;

    await Future.delayed(const Duration(milliseconds: 220));
    if (!mounted) return;

    final shouldShow = force
        ? true
        : await _tutorialService.shouldShowPageTutorial('schedule');
    if (!mounted || !shouldShow) return;

    await _tutorialService.markPageTutorialSeen('schedule');
    if (!mounted) return;

    await showPageTutorialOverlay(
      context: context,
      pageTitle: 'Schedule',
      steps: const [
        TutorialStepItem(
          title: 'Recommended Templates',
          description:
              'Choose Default, Health-based, or Custom templates to create multiple reminders quickly.',
          icon: Icons.auto_awesome,
        ),
        TutorialStepItem(
          title: 'Add Reminder',
          description:
              'Use the + button to add a custom reminder with time, amount, beverage, and date range.',
          icon: Icons.add_circle,
        ),
        TutorialStepItem(
          title: 'Smart Recommendations',
          description:
              'Inside Add Reminder, personalized suggestions adapt to your profile and health conditions.',
          icon: Icons.lightbulb,
        ),
        TutorialStepItem(
          title: 'Manage Existing Schedules',
          description:
              'Edit, delete, enable/disable, or log liquid directly from each schedule card.',
          icon: Icons.tune,
        ),
      ],
    );
  }

  Future<void> _checkHealthProfileAndShowPrompt() async {
    final userId = _authService.currentUser?.uid ?? '';
    if (userId.isEmpty) return;

    try {
      final healthProfile = await _healthProfileService.getActiveHealthProfile(
        userId,
      );

      // Check if health profile is not configured or is "None"
      if (!mounted) return;
      if (healthProfile == null || healthProfile.conditions.isEmpty) {
        _showHealthProfilePrompt();
      }
    } catch (e) {
      print('Error checking health profile: $e');
    }
  }

  void _showHealthProfilePrompt() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Personalize Your Hydration',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          'Set your health profile to get personalized hydration recommendations based on your conditions and lifestyle.',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Later',
              style: GoogleFonts.poppins(color: AppColors.textSecondary),
            ),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to Profile page
              Navigator.of(context).pushNamed('/profile');
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Go to Profile',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _loadVolumeUnit() {
    final userId = _authService.currentUser?.uid ?? '';
    if (userId.isEmpty) return;
    _userService.getUserProfile(userId).then((profile) {
      if (!mounted || profile == null) return;
      setState(() => _volumeUnit = profile.volumeUnit);
    });
  }

  Future<void> _scheduleReminder(HydrationSchedule item) async {
    if (!_preferencesService.notificationsEnabledNotifier.value) {
      return;
    }

    if (item.endDate != null && item.endDate!.isBefore(DateTime.now())) {
      return;
    }
    await _alarmService.scheduleWaterReminder(
      id: item.id,
      hour: item.hour,
      minute: item.minute,
      timezoneIdentifier: 'local',
      startDate: item.startDate,
      title: 'Time to hydrate',
      body: item.label.isEmpty
          ? 'Drink ${VolumeUtils.format(item.amountMl, _volumeUnit)} of ${item.beverageType}.'
          : '${item.label} — ${VolumeUtils.format(item.amountMl, _volumeUnit)} ${item.beverageType}.',
      payloadData: {
        'userId': item.userId,
        'scheduleId': item.id,
        'amountMl': item.amountMl,
        'beverageType': item.beverageType,
      },
    );
  }

  int _unitDecimals() {
    final normalized = VolumeUtils.normalizeUnit(_volumeUnit);
    if (normalized == 'ml') return 0;
    if (normalized == 'oz') return 1;
    return 2;
  }

  Future<void> _toggleSchedule(HydrationSchedule item, bool value) async {
    final userId = _authService.currentUser?.uid ?? '';
    if (userId.isEmpty) return;

    final updated = item.copyWith(enabled: value, updatedAt: DateTime.now());
    await _scheduleService.upsertSchedule(userId, updated);

    if (value) {
      await _scheduleReminder(updated);
    } else {
      await _alarmService.cancelReminder(item.id);
    }
  }

  Future<void> _deleteSchedule(HydrationSchedule item) async {
    final userId = _authService.currentUser?.uid ?? '';
    if (userId.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete schedule?'),
        content: Text(
          'Are you sure you want to delete "${item.label.isEmpty ? 'Hydration reminder' : item.label}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _alarmService.cancelReminder(item.id);
      await _scheduleService.deleteSchedule(userId, item.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Schedule deleted')));
      }
    }
  }

  Future<void> _deleteAllSchedules() async {
    final userId = _authService.currentUser?.uid ?? '';
    if (userId.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete all schedules?'),
        content: const Text(
          'This will permanently delete all your hydration schedules. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Cancel all alarms
      for (final id in _scheduledIds) {
        await _alarmService.cancelReminder(id);
      }
      _scheduledIds.clear();

      // Delete all schedules from Firestore
      await _scheduleService.replaceSchedules(userId, []);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('All schedules deleted')));
      }
    }
  }

  void _openScheduleSheet({HydrationSchedule? existing}) {
    final userId = _authService.currentUser?.uid ?? '';
    if (userId.isEmpty) return;

    final labelController = TextEditingController(text: existing?.label ?? '');
    final amountController = TextEditingController(
      text: VolumeUtils.fromMl(
        existing?.amountMl ?? 250,
        _volumeUnit,
      ).toStringAsFixed(_unitDecimals()),
    );
    String selectedBeverage = existing?.beverageType ?? 'Water';
    final beverages = ['Water', 'Coffee', 'Tea', 'Juice', 'Electrolytes'];
    TimeOfDay selectedTime = existing == null
        ? const TimeOfDay(hour: 9, minute: 0)
        : TimeOfDay(hour: existing.hour, minute: existing.minute);
    // Default start date to today when creating new schedule
    DateTime? startDate = existing?.startDate ?? DateTime.now();
    DateTime? endDate = existing?.endDate;
    bool enabled = existing?.enabled ?? true;
    String? selectedRecommendationLabel;

    // Fetch user profile and health profile for recommendations
    final userProfileFuture = _userService.getUserProfile(userId);
    final healthProfileFuture = _healthProfileService.getActiveHealthProfile(
      userId,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          existing == null ? 'New schedule' : 'Edit schedule',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Recommendations section
                    if (existing == null) // Only show for new schedules
                      FutureBuilder(
                        future: Future.wait([
                          userProfileFuture,
                          healthProfileFuture,
                        ]),
                        builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
                          if (snapshot.connectionState ==
                                  ConnectionState.done &&
                              snapshot.hasData) {
                            final userProfile = snapshot.data![0];
                            final healthProfile = snapshot.data![1];

                            if (userProfile != null) {
                              final recommendation =
                                  HydrationRecommendationEngine.getRecommendation(
                                    userProfile: userProfile,
                                    healthProfile: healthProfile,
                                  );

                              return Column(
                                children: [
                                  _buildRecommendationCard(
                                    recommendation,
                                    labelController,
                                    amountController,
                                    setModalState,
                                    selectedRecommendationLabel,
                                    (label) =>
                                        selectedRecommendationLabel = label,
                                  ),
                                  const SizedBox(height: 16),
                                ],
                              );
                            }
                          }
                          return const SizedBox();
                        },
                      ),
                    TextField(
                      controller: labelController,
                      decoration: const InputDecoration(
                        labelText: 'Label',
                        hintText: 'e.g. Morning routine',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Liquid type',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: beverages.map((beverage) {
                        final selected = selectedBeverage == beverage;
                        return ChoiceChip(
                          label: Text(beverage),
                          selected: selected,
                          onSelected: (_) {
                            setModalState(() => selectedBeverage = beverage);
                          },
                          selectedColor: AppColors.primary.withOpacity(0.2),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText:
                            'Amount (${VolumeUtils.normalizeUnit(_volumeUnit)})',
                        hintText: 'e.g. 250',
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildSelectorTile(
                      label: 'Time',
                      value: selectedTime.format(context),
                      icon: Icons.access_time,
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: selectedTime,
                        );
                        if (picked != null) {
                          setModalState(() => selectedTime = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildSelectorTile(
                      label: 'Start date (optional)',
                      value: startDate == null
                          ? 'Any date'
                          : _formatDate(startDate!),
                      icon: Icons.event,
                      onTap: () async {
                        final picked = await _pickDate(startDate);
                        if (picked != null) {
                          setModalState(() => startDate = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildSelectorTile(
                      label: 'End date (optional)',
                      value: endDate == null
                          ? 'No end date'
                          : _formatDate(endDate!),
                      icon: Icons.event_busy,
                      onTap: () async {
                        final picked = await _pickDate(endDate);
                        if (picked != null) {
                          setModalState(() => endDate = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      value: enabled,
                      onChanged: (value) =>
                          setModalState(() => enabled = value),
                      title: Text(
                        'Enabled',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        'Notifications will fire daily at this time.',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      activeColor: AppColors.primary,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (endDate != null &&
                              startDate != null &&
                              endDate!.isBefore(startDate!)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'End date must be after start date.',
                                ),
                              ),
                            );
                            return;
                          }

                          final amountValue =
                              double.tryParse(amountController.text.trim()) ??
                              0;
                          final amountMl = VolumeUtils.toMl(
                            amountValue,
                            _volumeUnit,
                          );

                          final now = DateTime.now();
                          final schedule =
                              (existing ??
                                      HydrationSchedule(
                                        id: DateTime.now()
                                            .millisecondsSinceEpoch,
                                        userId: userId,
                                        label: '',
                                        hour: selectedTime.hour,
                                        minute: selectedTime.minute,
                                        startDate: startDate,
                                        endDate: endDate,
                                        enabled: enabled,
                                        amountMl: amountMl,
                                        beverageType: selectedBeverage,
                                        templateId: null,
                                        createdAt: now,
                                        updatedAt: now,
                                      ))
                                  .copyWith(
                                    label: labelController.text.trim(),
                                    hour: selectedTime.hour,
                                    minute: selectedTime.minute,
                                    startDate: startDate,
                                    endDate: endDate,
                                    enabled: enabled,
                                    amountMl: amountMl,
                                    beverageType: selectedBeverage,
                                    updatedAt: now,
                                  );

                          try {
                            if (existing != null) {
                              await _alarmService.cancelReminder(existing.id);
                            }

                            await _scheduleService.upsertSchedule(
                              userId,
                              schedule,
                            );

                            if (schedule.enabled) {
                              await _scheduleReminder(schedule);
                            }
                          } finally {
                            if (mounted) Navigator.pop(context);
                          }
                        },
                        child: Text(existing == null ? 'Add schedule' : 'Save'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<DateTime?> _pickDate(DateTime? current) {
    return showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatRange(HydrationSchedule item) {
    final start = item.startDate == null
        ? 'Any time'
        : _formatDate(item.startDate!);
    final end = item.endDate == null ? 'No end' : _formatDate(item.endDate!);
    return '$start • $end';
  }

  HydrationSchedule? _nextSchedule(List<HydrationSchedule> schedules) {
    final enabledSchedules = schedules.where((e) => e.enabled).toList();
    if (enabledSchedules.isEmpty) return null;
    enabledSchedules.sort((a, b) {
      final aMinutes = a.hour * 60 + a.minute;
      final bMinutes = b.hour * 60 + b.minute;
      return aMinutes.compareTo(bMinutes);
    });
    return enabledSchedules.first;
  }

  Future<void> _syncNotifications(List<HydrationSchedule> schedules) async {
    final enabledIds = schedules
        .where((e) => e.enabled)
        .map((e) => e.id)
        .toSet();

    for (final schedule in schedules) {
      if (schedule.enabled && !_scheduledIds.contains(schedule.id)) {
        await _scheduleReminder(schedule);
        _scheduledIds.add(schedule.id);
      }
    }

    final toCancel = _scheduledIds.difference(enabledIds);
    for (final id in toCancel) {
      await _alarmService.cancelReminder(id);
      _scheduledIds.remove(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = _authService.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Schedule',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        leading: widget.onOpenDrawer == null
            ? null
            : IconButton(
                icon: const Icon(Icons.menu),
                onPressed: widget.onOpenDrawer,
              ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'delete_all') {
                await _deleteAllSchedules();
              } else if (value == 'test_notification') {
                final userId = _authService.currentUser?.uid ?? '';
                await _alarmService.showTestNotification(userId: userId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Test notification sent! Check your notification tray.',
                      ),
                    ),
                  );
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'test_notification',
                child: Row(
                  children: [
                    Icon(Icons.notifications_active, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text('Test notification'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete_all',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep, color: AppColors.error),
                    SizedBox(width: 8),
                    Text('Delete all schedules'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _openScheduleSheet(),
          ),
        ],
      ),
      body: userId.isEmpty
          ? _buildEmptyState()
          : StreamBuilder<List<HydrationSchedule>>(
              stream: _scheduleService.watchSchedules(userId),
              builder: (context, snapshot) {
                final List<HydrationSchedule> schedules =
                    (snapshot.data ?? <HydrationSchedule>[])
                        .cast<HydrationSchedule>()
                        .toList()
                      ..sort((a, b) {
                        final aMinutes = a.hour * 60 + a.minute;
                        final bMinutes = b.hour * 60 + b.minute;
                        return aMinutes.compareTo(bMinutes);
                      });
                final next = _nextSchedule(schedules);

                _syncNotifications(schedules);

                return StreamBuilder<List<HydrationTemplate>>(
                  stream: _templateService.watchTemplates(userId),
                  builder: (context, templateSnapshot) {
                    return StreamBuilder<List<HealthProfile>>(
                      stream: _healthProfileService.streamUserHealthProfiles(
                        userId,
                      ),
                      builder: (context, healthSnapshot) {
                        final activeHealthProfile = _resolveActiveHealthProfile(
                          healthSnapshot.data ?? const <HealthProfile>[],
                        );
                        final templates = _buildTemplateList(
                          userId,
                          templateSnapshot.data ?? [],
                          activeHealthProfile,
                        );

                        return ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            _buildNextCard(next),
                            const SizedBox(height: 24),
                            _buildTemplates(
                              templates,
                              schedules,
                              activeHealthProfile,
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Your schedules',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (schedules.isEmpty)
                              _buildEmptyState()
                            else
                              ...schedules.map(_buildScheduleCard),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _buildNextCard(HydrationSchedule? next) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.alarm, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  next == null ? 'No active reminders' : 'Next reminder',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  next == null
                      ? 'Add a schedule to stay hydrated.'
                      : '${next.label.isEmpty ? 'Hydration reminder' : next.label} • ${TimeOfDay(hour: next.hour, minute: next.minute).format(context)}',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplates(
    List<HydrationTemplate> templates,
    List<HydrationSchedule> currentSchedules,
    HealthProfile? healthProfile,
  ) {
    final hasPersonalizedTemplates =
        healthProfile != null &&
        healthProfile.conditions.any((condition) => condition != 'None');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recommended templates',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        if (hasPersonalizedTemplates) ...[
          const SizedBox(height: 4),
          Text(
            'Includes personalized templates based on your health profile',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: const [
            _TemplateLegendChip(
              label: 'Default',
              icon: Icons.auto_awesome,
              color: AppColors.primary,
            ),
            _TemplateLegendChip(
              label: 'Health-based',
              icon: Icons.favorite,
              color: AppColors.success,
            ),
            _TemplateLegendChip(
              label: 'Custom',
              icon: Icons.edit,
              color: AppColors.warning,
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: templates.length + 1,
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 240,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 132,
          ),
          itemBuilder: (context, index) {
            if (index == templates.length) {
              return GestureDetector(
                onTap: _openTemplateBuilder,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Create template',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Save your own schedule set',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Add template',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            final template = templates[index];
            final categoryStyle = _templateCategoryStyle(template);
            return GestureDetector(
              onTap: () => _openTemplateDetails(template, currentSchedules),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            template.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: categoryStyle.color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: categoryStyle.color.withOpacity(0.35),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                categoryStyle.icon,
                                size: 10,
                                color: categoryStyle.color,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                categoryStyle.label,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: categoryStyle.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (template.times.isNotEmpty)
                      Text(
                        _formatTemplateRange(template),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    const Spacer(),
                    Text(
                      '${template.times.length} reminders',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _applyTemplate(
    HydrationTemplate template,
    List<HydrationSchedule> currentSchedules,
  ) async {
    final userId = _authService.currentUser?.uid ?? '';
    if (userId.isEmpty) return;

    final shouldReplace = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Apply template?'),
          content: Text(
            currentSchedules.isEmpty
                ? 'This will create ${template.times.length} reminders.'
                : 'This will replace your current ${currentSchedules.length} schedules with ${template.times.length} reminders.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );

    if (shouldReplace != true) return;

    for (final schedule in currentSchedules) {
      await _alarmService.cancelReminder(schedule.id);
    }

    final now = DateTime.now();
    final baseId = DateTime.now().millisecondsSinceEpoch;
    final newSchedules = template.times
        .asMap()
        .entries
        .map(
          (entry) => HydrationSchedule(
            id: baseId + entry.key,
            userId: userId,
            label: template.title,
            hour: entry.value.hour,
            minute: entry.value.minute,
            startDate: null,
            endDate: null,
            enabled: true,
            amountMl: 250,
            beverageType: 'Water',
            templateId: template.id,
            createdAt: now,
            updatedAt: now,
          ),
        )
        .toList();

    await _scheduleService.replaceSchedules(userId, newSchedules);

    for (final schedule in newSchedules) {
      await _scheduleReminder(schedule);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${template.title} template applied.')),
      );
    }
  }

  Widget _buildScheduleCard(HydrationSchedule item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.water_drop, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label.isEmpty ? 'Hydration reminder' : item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${TimeOfDay(hour: item.hour, minute: item.minute).format(context)} • ${_formatRange(item)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.beverageType} • ${VolumeUtils.format(item.amountMl, _volumeUnit)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 30,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Switch(
                    value: item.enabled,
                    onChanged: (value) => _toggleSchedule(item, value),
                    activeColor: AppColors.primary,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  color: AppColors.textSecondary,
                ),
                onSelected: (value) {
                  if (value == 'assign') {
                    _openCheckInSheet(item);
                    return;
                  }
                  if (value == 'edit') {
                    _openScheduleSheet(existing: item);
                    return;
                  }
                  if (value == 'delete') {
                    _deleteSchedule(item);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'assign',
                    child: Row(
                      children: [
                        Icon(Icons.local_drink, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text('Assign liquid'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, color: AppColors.textSecondary),
                        SizedBox(width: 8),
                        Text('Edit schedule'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, color: AppColors.error),
                        SizedBox(width: 8),
                        Text('Delete schedule'),
                      ],
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
          const Icon(Icons.schedule, color: AppColors.primary, size: 32),
          const SizedBox(height: 8),
          Text(
            'No schedules yet',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Create a schedule or apply a template to get reminders.',
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

  List<HydrationTemplate> _buildTemplateList(
    String userId,
    List<HydrationTemplate> customTemplates,
    HealthProfile? healthProfile,
  ) {
    final builtIns = [
      HydrationTemplate(
        id: 'builtin-2h',
        userId: userId,
        title: 'Every 2 hours',
        times: const [
          HydrationTemplateTime(hour: 8, minute: 0),
          HydrationTemplateTime(hour: 10, minute: 0),
          HydrationTemplateTime(hour: 12, minute: 0),
          HydrationTemplateTime(hour: 14, minute: 0),
          HydrationTemplateTime(hour: 16, minute: 0),
          HydrationTemplateTime(hour: 18, minute: 0),
          HydrationTemplateTime(hour: 20, minute: 0),
        ],
        createdAt: DateTime.now(),
      ),
      HydrationTemplate(
        id: 'builtin-workday',
        userId: userId,
        title: 'Workday',
        times: const [
          HydrationTemplateTime(hour: 9, minute: 0),
          HydrationTemplateTime(hour: 11, minute: 0),
          HydrationTemplateTime(hour: 13, minute: 0),
          HydrationTemplateTime(hour: 15, minute: 0),
          HydrationTemplateTime(hour: 17, minute: 0),
        ],
        createdAt: DateTime.now(),
      ),
      HydrationTemplate(
        id: 'builtin-morning',
        userId: userId,
        title: 'Morning focus',
        times: const [
          HydrationTemplateTime(hour: 7, minute: 0),
          HydrationTemplateTime(hour: 8, minute: 30),
          HydrationTemplateTime(hour: 10, minute: 0),
          HydrationTemplateTime(hour: 11, minute: 30),
        ],
        createdAt: DateTime.now(),
      ),
    ];

    final healthTemplates = _buildHealthBasedTemplates(userId, healthProfile);

    return [...healthTemplates, ...builtIns, ...customTemplates];
  }

  List<HydrationTemplate> _buildHealthBasedTemplates(
    String userId,
    HealthProfile? healthProfile,
  ) {
    if (healthProfile == null) return const <HydrationTemplate>[];

    final personalizedConditions = healthProfile.conditions
        .where((condition) => condition != 'None')
        .toList();

    if (personalizedConditions.isEmpty) return const <HydrationTemplate>[];

    final now = DateTime.now();
    final templates = <HydrationTemplate>[];

    for (final condition in personalizedConditions.take(2)) {
      final interval = HealthProfile.defaultIntervals[condition] ?? 120;
      final times = _buildTimesForIntervalMinutes(interval);
      templates.add(
        HydrationTemplate(
          id: 'builtin-health-${_slugifyCondition(condition)}',
          userId: userId,
          title: '${_shortConditionLabel(condition)} plan',
          times: times,
          createdAt: now,
        ),
      );
    }

    return templates;
  }

  _TemplateCategoryStyle _templateCategoryStyle(HydrationTemplate template) {
    if (template.id.startsWith('builtin-health-')) {
      return const _TemplateCategoryStyle(
        label: 'Health',
        icon: Icons.favorite,
        color: AppColors.success,
      );
    }

    if (template.id.startsWith('builtin-')) {
      return const _TemplateCategoryStyle(
        label: 'Default',
        icon: Icons.auto_awesome,
        color: AppColors.primary,
      );
    }

    return const _TemplateCategoryStyle(
      label: 'Custom',
      icon: Icons.edit,
      color: AppColors.warning,
    );
  }

  List<HydrationTemplateTime> _buildTimesForIntervalMinutes(int interval) {
    final safeInterval = interval.clamp(30, 240);
    final slots = <HydrationTemplateTime>[];

    for (
      int totalMinutes = 7 * 60;
      totalMinutes <= 21 * 60;
      totalMinutes += safeInterval
    ) {
      slots.add(
        HydrationTemplateTime(
          hour: totalMinutes ~/ 60,
          minute: totalMinutes % 60,
        ),
      );
    }

    return slots;
  }

  String _slugifyCondition(String condition) {
    return condition
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  String _shortConditionLabel(String condition) {
    if (condition.contains('Urinary Tract Infections')) return 'UTI support';
    if (condition.contains('Athlete')) return 'Active lifestyle';
    if (condition.contains('Dry Skin')) return 'Dry skin support';
    return condition;
  }

  HealthProfile? _resolveActiveHealthProfile(List<HealthProfile> profiles) {
    for (final profile in profiles) {
      if (profile.isEnabled) return profile;
    }
    return profiles.isNotEmpty ? profiles.first : null;
  }

  String _formatTemplateRange(HydrationTemplate template) {
    if (template.times.isEmpty) return 'No times set';
    final sorted = [...template.times]
      ..sort(
        (a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute),
      );
    final start = sorted.first;
    final end = sorted.last;
    final startTime = TimeOfDay(
      hour: start.hour,
      minute: start.minute,
    ).format(context);
    final endTime = TimeOfDay(
      hour: end.hour,
      minute: end.minute,
    ).format(context);
    return '$startTime - $endTime';
  }

  void _openTemplateDetails(
    HydrationTemplate template,
    List<HydrationSchedule> currentSchedules,
  ) {
    final sorted = [...template.times]
      ..sort(
        (a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute),
      );

    final isBuiltIn = template.id.startsWith('builtin-');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      template.title,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (!isBuiltIn) ...[
                    IconButton(
                      icon: Icon(
                        Icons.edit,
                        color: AppColors.textSecondary,
                      ),
                      tooltip: 'Edit template',
                      onPressed: () {
                        Navigator.pop(context);
                        _openTemplateEditor(template);
                      },
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: AppColors.error,
                      ),
                      tooltip: 'Delete template',
                      onPressed: () async {
                        Navigator.pop(context);
                        await _deleteTemplate(template);
                      },
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: sorted
                    .map(
                      (time) => Chip(
                        label: Text(
                          TimeOfDay(
                            hour: time.hour,
                            minute: time.minute,
                          ).format(context),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _applyTemplate(template, currentSchedules);
                  },
                  child: const Text('Apply template'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openTemplateBuilder() {
    final userId = _authService.currentUser?.uid ?? '';
    if (userId.isEmpty) return;

    final titleController = TextEditingController();
    final times = <HydrationTemplateTime>[];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create template',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Template name',
                      hintText: 'e.g. Gym day',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: times
                        .map(
                          (time) => Chip(
                            label: Text(
                              TimeOfDay(
                                hour: time.hour,
                                minute: time.minute,
                              ).format(context),
                            ),
                            onDeleted: () {
                              setModalState(() => times.remove(time));
                            },
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: const TimeOfDay(hour: 9, minute: 0),
                      );
                      if (picked != null) {
                        setModalState(() {
                          times.add(
                            HydrationTemplateTime(
                              hour: picked.hour,
                              minute: picked.minute,
                            ),
                          );
                        });
                      }
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add time'),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (titleController.text.trim().isEmpty ||
                            times.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Add a name and at least one time.',
                              ),
                            ),
                          );
                          return;
                        }

                        final template = HydrationTemplate(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          userId: userId,
                          title: titleController.text.trim(),
                          times: List.from(times),
                          createdAt: DateTime.now(),
                        );

                        await _templateService.addTemplate(userId, template);
                        if (mounted) Navigator.pop(context);
                      },
                      child: const Text('Save template'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteTemplate(HydrationTemplate template) async {
    final userId = _authService.currentUser?.uid ?? '';
    if (userId.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete template'),
        content: Text('Are you sure you want to delete "${template.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _templateService.deleteTemplate(userId, template.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Template "${template.title}" deleted'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _openTemplateEditor(HydrationTemplate template) {
    final userId = _authService.currentUser?.uid ?? '';
    if (userId.isEmpty) return;

    final titleController = TextEditingController(text: template.title);
    final times = List<HydrationTemplateTime>.from(template.times);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Edit template',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Template name',
                      hintText: 'e.g. Gym day',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: times
                        .map(
                          (time) => Chip(
                            label: Text(
                              TimeOfDay(
                                hour: time.hour,
                                minute: time.minute,
                              ).format(context),
                            ),
                            onDeleted: () {
                              setModalState(() => times.remove(time));
                            },
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: const TimeOfDay(hour: 9, minute: 0),
                      );
                      if (picked != null) {
                        setModalState(() {
                          times.add(
                            HydrationTemplateTime(
                              hour: picked.hour,
                              minute: picked.minute,
                            ),
                          );
                        });
                      }
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add time'),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (titleController.text.trim().isEmpty ||
                            times.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Add a name and at least one time.',
                              ),
                            ),
                          );
                          return;
                        }

                        final updatedTemplate = HydrationTemplate(
                          id: template.id,
                          userId: userId,
                          title: titleController.text.trim(),
                          times: List.from(times),
                          createdAt: template.createdAt,
                        );

                        await _templateService.updateTemplate(
                          userId,
                          updatedTemplate,
                        );
                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Template "${updatedTemplate.title}" updated',
                              ),
                              backgroundColor: AppColors.primary,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      child: const Text('Update template'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openCheckInSheet(HydrationSchedule schedule) {
    final userId = _authService.currentUser?.uid ?? '';
    if (userId.isEmpty) return;

    final amountController = TextEditingController(
      text: VolumeUtils.fromMl(
        schedule.amountMl,
        _volumeUnit,
      ).toStringAsFixed(_unitDecimals()),
    );
    String selectedBeverage = schedule.beverageType;
    final beverages = ['Water', 'Coffee', 'Tea', 'Juice', 'Electrolytes'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Assign liquid',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: beverages.map((beverage) {
                      final selected = selectedBeverage == beverage;
                      return ChoiceChip(
                        label: Text(beverage),
                        selected: selected,
                        onSelected: (_) {
                          setModalState(() => selectedBeverage = beverage);
                        },
                        selectedColor: AppColors.primary.withOpacity(0.2),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText:
                          'Amount (${VolumeUtils.normalizeUnit(_volumeUnit)})',
                      hintText: 'e.g. 250',
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final amount =
                            double.tryParse(amountController.text.trim()) ?? 0;
                        final amountMl = VolumeUtils.toMl(amount, _volumeUnit);

                        // Update the schedule with new beverage and amount
                        final updatedSchedule = schedule.copyWith(
                          beverageType: selectedBeverage,
                          amountMl: amountMl,
                          updatedAt: DateTime.now(),
                        );

                        await _scheduleService.upsertSchedule(
                          userId,
                          updatedSchedule,
                        );

                        // Update notification if schedule is enabled
                        if (updatedSchedule.enabled) {
                          await _alarmService.cancelReminder(schedule.id);
                          await _scheduleReminder(updatedSchedule);
                        }

                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Schedule updated: ${VolumeUtils.format(amountMl, _volumeUnit)} of $selectedBeverage',
                              ),
                              backgroundColor: AppColors.primary,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      child: const Text('Update schedule'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRecommendationCard(
    HydrationRecommendation recommendation,
    TextEditingController labelController,
    TextEditingController amountController,
    StateSetter setModalState,
    String? selectedTemplateLabel,
    ValueChanged<String> onTemplateSelected,
  ) {
    final personalizedTemplates = _buildPersonalizedAmountTemplates(
      recommendation,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Health Profile Setup Prompt
        if (recommendation.healthProfile == null ||
            recommendation.healthProfile!.conditions.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.warning.withOpacity(0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppColors.warning,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Health-specific templates available',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Set your health conditions in Profile to unlock personalized templates.',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.of(context).pushNamed('/profile');
                    },
                    icon: const Icon(Icons.edit, size: 16),
                    label: Text(
                      'Go to Profile',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.warning,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        // Recommended Templates Section
        Text(
          'Recommended Templates',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        // Daily Goal Display Card
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.primary.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.track_changes, color: AppColors.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily Goal',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      VolumeUtils.format(
                        recommendation.dailyGoalMl,
                        _volumeUnit,
                      ),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${(recommendation.reminderIntervalMinutes / 60).toStringAsFixed(0)}h intervals',
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: AppColors.success,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Health-Specific Tips
        if (recommendation.healthProfile != null &&
            recommendation.healthProfile!.conditions.isNotEmpty)
          _buildHealthTipsCard(recommendation.healthProfile!),
        const SizedBox(height: 12),
        // Default Templates for All Users
        _buildTemplateGroup(
          'Universal',
          [
            ('Light', 'Small sip', 125),
            ('Normal', 'Standard glass', 250),
            ('Large', 'Full bottle', 500),
          ],
          selectedTemplateLabel,
          labelController,
          amountController,
          setModalState,
          onTemplateSelected,
        ),
        const SizedBox(height: 10),
        // Health-Specific Templates
        if (recommendation.healthProfile != null &&
            recommendation.healthProfile!.conditions.isNotEmpty)
          _buildTemplateGroup(
            'Personalized',
            personalizedTemplates,
            selectedTemplateLabel,
            labelController,
            amountController,
            setModalState,
            onTemplateSelected,
          ),
      ],
    );
  }

  List<(String label, String description, double amountMl)>
  _buildPersonalizedAmountTemplates(HydrationRecommendation recommendation) {
    final baseAmount = recommendation.amountPerReminderMl;
    final primaryCondition =
        recommendation.healthProfile?.conditions.isNotEmpty == true
        ? recommendation.healthProfile!.conditions.first
        : 'Health';

    final normalizedCondition = _shortConditionLabel(primaryCondition);

    final lowerAmount = (baseAmount * 0.85).clamp(100.0, 750.0).toDouble();
    final higherAmount = (baseAmount * 1.15).clamp(120.0, 900.0).toDouble();

    return [
      ('$normalizedCondition Focus', recommendation.message, baseAmount),
      ('Balanced', 'Steady hydration pace', lowerAmount),
      ('Boost', 'Higher intake for active windows', higherAmount),
    ];
  }

  Widget _buildTemplateGroup(
    String title,
    List<(String label, String description, double amountMl)> templates,
    String? selectedTemplateLabel,
    TextEditingController labelController,
    TextEditingController amountController,
    StateSetter setModalState,
    ValueChanged<String> onTemplateSelected,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        ...templates.map((template) {
          final (label, description, amountMl) = template;
          final isSelected = selectedTemplateLabel == label;
          return GestureDetector(
            onTap: () {
              setModalState(() {
                amountController.text = VolumeUtils.fromMl(
                  amountMl.toDouble(),
                  _volumeUnit,
                ).toStringAsFixed(_unitDecimals());

                if (labelController.text.trim().isEmpty) {
                  labelController.text = '$label hydration';
                }

                onTemplateSelected(label);
              });
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withOpacity(0.08)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          description,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withOpacity(0.2)
                          : AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      VolumeUtils.format(amountMl.toDouble(), _volumeUnit),
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  if (isSelected) ...[
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.check_circle,
                      size: 16,
                      color: AppColors.primary,
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildHealthTipsCard(HealthProfile healthProfile) {
    // Determine primary condition for tip
    String primaryCondition = healthProfile.conditions.isNotEmpty
        ? healthProfile.conditions.first
        : '';

    String tip = '';
    IconData tipIcon = Icons.info_outline;
    Color tipColor = AppColors.primary;

    if (primaryCondition.contains('Athlete')) {
      tip =
          'Stay hydrated during and after exercise. Drink water before, during, and '
          'after intense physical activity.';
      tipIcon = Icons.fitness_center;
      tipColor = const Color(0xFF6366F1);
    } else if (primaryCondition.contains('Pregnant')) {
      tip =
          'Spread your hydration intake throughout the day. Listen to your body\'s thirst signals.';
      tipIcon = Icons.favorite;
      tipColor = const Color(0xFFEC4899);
    } else if (primaryCondition.contains('Kidney')) {
      tip =
          'Maintain consistent hydration throughout the day. Avoid excessive intake at once.';
      tipIcon = Icons.local_drink;
      tipColor = const Color(0xFF8B5CF6);
    } else if (primaryCondition.contains('UTI')) {
      tip =
          'Frequent urination helps prevent UTIs. Keep a consistent hydration schedule.';
      tipIcon = Icons.schedule;
      tipColor = const Color(0xFFEF4444);
    } else if (primaryCondition.contains('Dry')) {
      tip = 'Increase hydration and use a humidifier to improve skin health.';
      tipIcon = Icons.water_drop;
      tipColor = const Color(0xFF3B82F6);
    } else {
      tip =
          'Follow the personalized recommendation to meet your hydration needs.';
      tipIcon = Icons.lightbulb_outline;
      tipColor = AppColors.primary;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tipColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tipColor.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(tipIcon, color: tipColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tip,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectorTile({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _TemplateCategoryStyle {
  final String label;
  final IconData icon;
  final Color color;

  const _TemplateCategoryStyle({
    required this.label,
    required this.icon,
    required this.color,
  });
}

class _TemplateLegendChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _TemplateLegendChip({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
