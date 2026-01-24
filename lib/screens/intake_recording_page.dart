import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/hybrid_sync_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class IntakeRecordingPage extends StatefulWidget {
  final VoidCallback onSaved;

  const IntakeRecordingPage({super.key, required this.onSaved});

  @override
  State<IntakeRecordingPage> createState() => _IntakeRecordingPageState();
}

class _IntakeRecordingPageState extends State<IntakeRecordingPage> {
  final _volumeController = TextEditingController();
  final _notesController = TextEditingController();
  final _hybridSyncService = HybridSyncService();
  final _authService = AuthService();

  String _selectedFluidType = 'Water';
  bool _isLoading = false;
  String? _errorMessage;
  double _selectedVolume = 250;

  final List<String> _fluidTypes = [
    'Water',
    'Juice',
    'Milk',
    'Tea/Coffee',
    'Soup',
    'Sports Drink',
    'Other',
  ];

  final Map<String, IconData> _fluidTypeIcons = {
    'Water': Icons.water_drop,
    'Juice': Icons.local_drink,
    'Milk': Icons.grain,
    'Tea/Coffee': Icons.local_cafe,
    'Soup': Icons.restaurant_menu,
    'Sports Drink': Icons.sports_volleyball,
    'Other': Icons.more_horiz,
  };

  @override
  void dispose() {
    _volumeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleSaveIntake() async {
    if (_volumeController.text.isEmpty && _selectedVolume == 0) {
      setState(() => _errorMessage = 'Please enter or select a volume');
      return;
    }

    final volume = _volumeController.text.isNotEmpty
        ? double.tryParse(_volumeController.text)
        : _selectedVolume;

    if (volume == null || volume <= 0) {
      setState(() => _errorMessage = 'Please enter valid volume');
      return;
    }

    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    try {
      final userId = _authService.currentUser?.uid ?? '';

      await _hybridSyncService.addIntakeEntry(
        userId: userId,
        volume: volume,
        fluidType: _selectedFluidType,
        notes: _notesController.text,
      );

      if (mounted) {
        widget.onSaved();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✓ ${volume.toStringAsFixed(0)} ml of ${_selectedFluidType} logged',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            backgroundColor: AppColors.primary,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Error saving intake: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 1,
        title: Text(
          'Log Water Intake',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildVolumeInputSection(),
              const SizedBox(height: 32),
              _buildQuickSelectButtons(),
              const SizedBox(height: 32),
              _buildFluidTypeSelector(),
              const SizedBox(height: 32),
              _buildNotesSection(),
              const SizedBox(height: 32),
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              _buildSubmitButton(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVolumeInputSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Volume (ml)',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 2),
          ),
          child: TextField(
            controller: _volumeController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              hintText: '0',
              hintStyle: GoogleFonts.poppins(
                fontSize: 28,
                color: AppColors.textTertiary,
              ),
              border: InputBorder.none,
              suffixIcon: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Text(
                    'ml',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
            onChanged: (value) {
              setState(() {});
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuickSelectButtons() {
    final amounts = [250, 500, 750, 1000];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Select',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 4,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: amounts
              .map((amount) => _buildQuickButton(amount.toDouble()))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildQuickButton(double amount) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _volumeController.text = amount.toStringAsFixed(0);
          _selectedVolume = amount;
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: _volumeController.text == amount.toStringAsFixed(0)
              ? AppColors.primary
              : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _volumeController.text == amount.toStringAsFixed(0)
                ? AppColors.primary
                : AppColors.border,
            width: 2,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${amount.toStringAsFixed(0)}',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _volumeController.text == amount.toStringAsFixed(0)
                      ? Colors.white
                      : AppColors.textPrimary,
                ),
              ),
              Text(
                'ml',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: _volumeController.text == amount.toStringAsFixed(0)
                      ? Colors.white70
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFluidTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fluid Type',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(),
          child: Row(
            children: _fluidTypes
                .map(
                  (type) => Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: _buildFluidTypeButton(type),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildFluidTypeButton(String type) {
    final isSelected = _selectedFluidType == type;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedFluidType = type);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _fluidTypeIcons[type] ?? Icons.local_drink,
              color: isSelected ? Colors.white : AppColors.primary,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              type,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Notes (Optional)',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: TextField(
            controller: _notesController,
            maxLines: 3,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'Add any notes...',
              hintStyle: GoogleFonts.poppins(
                fontSize: 13,
                color: AppColors.textTertiary,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleSaveIntake,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 4,
        ),
        child: _isLoading
            ? SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.white.withOpacity(0.8),
                  ),
                ),
              )
            : Text(
                'Log Intake',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}
