import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/tutorial_service.dart';
import '../services/user_service.dart';
import '../services/health_profile_service.dart';
import '../models/user_profile.dart';
import '../models/health_profile.dart';
import '../theme/app_theme.dart';
import '../widgets/page_tutorial_overlay.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _authService = AuthService();
  final _tutorialService = TutorialService();
  final _userService = UserService();
  final _healthProfileService = HealthProfileService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _ageController = TextEditingController();
  final _dobController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  late Future<UserProfile?> _profileFuture;
  DateTime? _selectedDob;
  bool _initialized = false;
  bool _isSaving = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _tutorialChecked = false;

  // Health profile state variables
  HealthProfile? _activeHealthProfile;
  Set<String> _selectedConditions = {};
  String _customCondition = '';
  String _selectedTone = 'neutral';

  @override
  void initState() {
    super.initState();
    final userId = _authService.currentUser?.uid ?? '';
    _profileFuture = _userService.getUserProfile(userId);
    _loadHealthProfile();
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
        : await _tutorialService.shouldShowPageTutorial('profile');
    if (!mounted || !shouldShow) return;

    await _tutorialService.markPageTutorialSeen('profile');
    if (!mounted) return;

    await showPageTutorialOverlay(
      context: context,
      pageTitle: 'Profile',
      steps: const [
        TutorialStepItem(
          title: 'Account Details',
          description:
              'Update your name, age, date of birth, weight, and height to improve recommendations.',
          icon: Icons.person,
        ),
        TutorialStepItem(
          title: 'Health Considerations',
          description:
              'Select conditions and reminder tone to personalize hydration suggestions.',
          icon: Icons.health_and_safety,
        ),
        TutorialStepItem(
          title: 'Security',
          description:
              'Use the password fields to securely update your login credentials.',
          icon: Icons.lock,
        ),
        TutorialStepItem(
          title: 'Save Changes',
          description:
              'Always save after edits so schedules and recommendations stay in sync with your profile.',
          icon: Icons.save,
        ),
      ],
    );
  }

  Future<void> _loadHealthProfile() async {
    final userId = _authService.currentUser?.uid ?? '';
    if (userId.isEmpty) return;

    try {
      final profile = await _healthProfileService.getActiveHealthProfile(
        userId,
      );
      if (mounted) {
        setState(() {
          _activeHealthProfile = profile;
          if (profile != null) {
            _selectedConditions = Set<String>.from(profile.conditions);
            _customCondition = profile.customCondition ?? '';
            _selectedTone = profile.messageTone;
          }
        });
      }
    } catch (e) {
      print('Error loading health profile: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _ageController.dispose();
    _dobController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _initializeControllers(UserProfile? profile) {
    if (_initialized) return;

    final user = _authService.currentUser;
    _nameController.text = profile?.name ?? user?.displayName ?? '';
    _emailController.text = user?.email ?? profile?.email ?? '';
    if (profile?.age != null) {
      _ageController.text = profile!.age.toString();
    }
    if (profile?.dateOfBirth != null) {
      _selectedDob = profile!.dateOfBirth;
      _dobController.text = _formatDate(profile.dateOfBirth!);
      _ageController.text = _calculateAge(profile.dateOfBirth!).toString();
    }
    if (profile?.weightKg != null) {
      _weightController.text = profile!.weightKg!.toStringAsFixed(1);
    }
    if (profile?.heightCm != null) {
      _heightController.text = profile!.heightCm!.toStringAsFixed(1);
    }

    _initialized = true;
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  int _calculateAge(DateTime dateOfBirth) {
    final today = DateTime.now();
    int age = today.year - dateOfBirth.year;
    if (today.month < dateOfBirth.month ||
        (today.month == dateOfBirth.month && today.day < dateOfBirth.day)) {
      age -= 1;
    }
    return age;
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final initialDate = _selectedDob ?? DateTime(now.year - 25, now.month, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: now,
    );

    if (picked != null) {
      setState(() {
        _selectedDob = picked;
        _dobController.text = _formatDate(picked);
        _ageController.text = _calculateAge(picked).toString();
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final user = _authService.currentUser;
    final name = _nameController.text.trim();
    final age = _ageController.text.trim().isEmpty
        ? null
        : int.tryParse(_ageController.text.trim());
    final weight = _weightController.text.trim().isEmpty
        ? null
        : double.tryParse(_weightController.text.trim());
    final height = _heightController.text.trim().isEmpty
        ? null
        : double.tryParse(_heightController.text.trim());

    final data = <String, dynamic>{
      'name': name,
      'age': _selectedDob == null ? age : _calculateAge(_selectedDob!),
      'dateOfBirth': _selectedDob?.toIso8601String(),
      'weightKg': weight,
      'heightCm': height,
    };

    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    try {
      if (user != null && name.isNotEmpty) {
        await user.updateDisplayName(name);
      }

      if (newPassword.isNotEmpty || confirmPassword.isNotEmpty) {
        if (user != null) {
          try {
            await user.updatePassword(newPassword);
          } on FirebaseAuthException catch (e) {
            if (!mounted) return;
            final message = e.code == 'requires-recent-login'
                ? 'Please re-authenticate to update your password.'
                : 'Failed to update password. ${e.message ?? ''}'.trim();
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(message)));
          }
        }
      }

      if (user != null) {
        await _userService.updateUserProfile(user.uid, data);
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile updated')));
      }
      setState(() {
        _profileFuture = _userService.getUserProfile(user?.uid ?? '');
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _saveHealthProfile() async {
    final userId = _authService.currentUser?.uid ?? '';
    if (userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please sign in to save health profile',
            style: GoogleFonts.poppins(),
          ),
        ),
      );
      return;
    }

    try {
      // Handle "None" case - empty list means no health considerations
      final conditions = _selectedConditions.contains('None')
          ? <String>[]
          : _selectedConditions.toList();

      if (_activeHealthProfile != null) {
        // Update existing profile
        final updated = _activeHealthProfile!.copyWith(
          conditions: conditions,
          customCondition: conditions.contains('Other')
              ? _customCondition
              : null,
          messageTone: _selectedTone,
          updatedAt: DateTime.now(),
        );
        await _healthProfileService.updateHealthProfile(updated);
      } else {
        // Create new profile
        await _healthProfileService.createHealthProfile(
          userId: userId,
          conditions: conditions,
          customCondition: conditions.contains('Other')
              ? _customCondition
              : null,
          messageTone: _selectedTone,
        );
      }

      _loadHealthProfile();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Health profile saved successfully',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error saving health profile: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Edit Profile',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      body: FutureBuilder<UserProfile?>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          final profile = snapshot.data;
          _initializeControllers(profile);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(user?.displayName ?? profile?.name ?? 'User'),
                  const SizedBox(height: 24),
                  Text(
                    'Profile Details',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      label: _buildRequiredLabel('Full name'),
                      hintText: 'Enter your name',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailController,
                    readOnly: true,
                    decoration: InputDecoration(
                      label: _buildRequiredLabel('Email'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _dobController,
                    readOnly: true,
                    onTap: _pickDateOfBirth,
                    decoration: const InputDecoration(
                      labelText: 'Date of birth',
                      hintText: 'YYYY-MM-DD',
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _ageController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Age',
                      hintText: 'Enter age if not using DOB',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _weightController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Weight (kg)',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _heightController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Height (cm)',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Optional fields help personalize your hydration plan. Required fields are marked with *.',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSectionHeader('Health Considerations'),
                  const SizedBox(height: 8),
                  _buildInfoBanner(
                    'Your health conditions help us personalize hydration recommendations.',
                  ),
                  const SizedBox(height: 12),
                  _buildHealthConsiderationsSection(),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveHealthProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                      ),
                      child: Text(
                        'Save Health Profile',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  if (_activeHealthProfile != null) ...[
                    const SizedBox(height: 12),
                    _buildActiveProfileCard(),
                  ],
                  const SizedBox(height: 24),
                  _buildSectionHeader('Security'),
                  const SizedBox(height: 8),
                  _buildInfoBanner(
                    'Set a password to enable email login. Google sign-in users can add one here.',
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _newPasswordController,
                    obscureText: _obscureNewPassword,
                    decoration: InputDecoration(
                      labelText: 'New password',
                      hintText: 'At least 8 characters',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureNewPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureNewPassword = !_obscureNewPassword;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if ((value == null || value.isEmpty) &&
                          _confirmPasswordController.text.isEmpty) {
                        return null;
                      }
                      final validation = AuthService.validatePassword(
                        value ?? '',
                      );
                      return validation;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    decoration: InputDecoration(
                      labelText: 'Confirm password',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if ((_newPasswordController.text.isEmpty) &&
                          (value == null || value.isEmpty)) {
                        return null;
                      }
                      if (value != _newPasswordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveProfile,
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Save Changes'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(String name) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.primary,
            child: Text(
              name.isNotEmpty ? name.characters.first.toUpperCase() : 'U',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Unified profile for email & Google sign-in',
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

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildInfoBanner(String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
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

  Widget _buildRequiredLabel(String label) {
    return RichText(
      text: TextSpan(
        text: label,
        style: GoogleFonts.poppins(
          fontSize: 14,
          color: AppColors.textSecondary,
        ),
        children: const [
          TextSpan(
            text: ' *',
            style: TextStyle(color: AppColors.error),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthConsiderationsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Health Conditions',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          // Dropdown to select conditions
          DropdownButton<String>(
            isExpanded: true,
            underline: const SizedBox(),
            hint: Text(
              'Select a condition to add',
              style: GoogleFonts.poppins(color: AppColors.textTertiary),
            ),
            items: HealthProfile.predefinedConditions
                .where((c) => !_selectedConditions.contains(c))
                .map((condition) {
                  return DropdownMenuItem(
                    value: condition,
                    child: Text(condition, style: GoogleFonts.poppins()),
                  );
                })
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedConditions.add(value);
                  if (value != 'None') {
                    _selectedConditions.remove('None');
                  }
                });
              }
            },
          ),
          const SizedBox(height: 12),
          // Selected conditions with delete buttons
          if (_selectedConditions.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selected conditions',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _selectedConditions.map((condition) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            condition,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedConditions.remove(condition);
                                if (_selectedConditions.isEmpty) {
                                  _selectedConditions.add('None');
                                }
                              });
                            },
                            child: Icon(
                              Icons.close,
                              size: 14,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'No health conditions selected',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          const SizedBox(height: 12),
          if (_selectedConditions.contains('Other')) ...[
            const SizedBox(height: 12),
            TextField(
              onChanged: (value) => setState(() => _customCondition = value),
              decoration: InputDecoration(
                hintText: 'Specify your health condition',
                hintStyle: GoogleFonts.poppins(color: AppColors.textTertiary),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              style: GoogleFonts.poppins(color: AppColors.textPrimary),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Reminder Tone',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildToneButton('Gentle', 'gentle')),
              const SizedBox(width: 8),
              Expanded(child: _buildToneButton('Neutral', 'neutral')),
              const SizedBox(width: 8),
              Expanded(child: _buildToneButton('Frequent', 'frequent')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToneButton(String label, String value) {
    final isSelected = _selectedTone == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedTone = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveProfileCard() {
    if (_activeHealthProfile == null) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.success.withOpacity(0.2), Colors.transparent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.success),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.success.withOpacity(0.2),
            ),
            child: const Icon(
              Icons.check_circle,
              color: AppColors.success,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Active Profile',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _activeHealthProfile!.getDetailedDisplay(),
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
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
}
