import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/hydration_models.dart';
import '../services/alarm_service.dart';
import '../services/auth_service.dart';
import '../services/checkin_service.dart';
import '../services/schedule_service.dart';
import '../services/template_service.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import '../util/volume_utils.dart';

class SchedulePage extends StatefulWidget {
  final VoidCallback? onOpenDrawer;

  const SchedulePage({super.key, this.onOpenDrawer});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  final _alarmService = AlarmService();
  final _scheduleService = ScheduleService();
  final _checkInService = CheckInService();
  final _authService = AuthService();
  final _templateService = TemplateService();
  final _userService = UserService();
  final Set<int> _scheduledIds = {};
  String _volumeUnit = 'ml';

  @override
  void initState() {
    super.initState();
    _loadVolumeUnit();
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
                    onChanged: (value) => setModalState(() => enabled = value),
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
                            double.tryParse(amountController.text.trim()) ?? 0;
                        final amountMl = VolumeUtils.toMl(
                          amountValue,
                          _volumeUnit,
                        );

                        final now = DateTime.now();
                        final schedule =
                            (existing ??
                                    HydrationSchedule(
                                      id: DateTime.now().millisecondsSinceEpoch,
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
                    final templates = _buildTemplateList(
                      userId,
                      templateSnapshot.data ?? [],
                    );

                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildNextCard(next),
                        const SizedBox(height: 24),
                        _buildTemplates(templates, schedules),
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
  ) {
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
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: templates.length + 1,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.4,
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
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Save your own schedule set',
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
                    Text(
                      template.title,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (template.times.isNotEmpty)
                      Text(
                        _formatTemplateRange(template),
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
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${TimeOfDay(hour: item.hour, minute: item.minute).format(context)} • ${_formatRange(item)}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.beverageType} • ${VolumeUtils.format(item.amountMl, _volumeUnit)}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: item.enabled,
            onChanged: (value) => _toggleSchedule(item, value),
            activeColor: AppColors.primary,
          ),
          IconButton(
            icon: const Icon(Icons.local_drink, color: AppColors.primary),
            tooltip: 'Assign liquid',
            onPressed: () => _openCheckInSheet(item),
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: AppColors.textSecondary),
            onPressed: () => _openScheduleSheet(existing: item),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
            onPressed: () => _deleteSchedule(item),
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

    return [...builtIns, ...customTemplates];
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
                      icon: const Icon(
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
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
