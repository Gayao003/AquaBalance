import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/hybrid_sync_service.dart';
import '../services/auth_service.dart';

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

  final List<String> _fluidTypes = [
    'Water',
    'Juice',
    'Milk',
    'Tea/Coffee',
    'Soup',
    'Ice Cream',
    'Other',
  ];

  @override
  void dispose() {
    _volumeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleSaveIntake() async {
    if (_volumeController.text.isEmpty) {
      setState(() => _errorMessage = 'Please enter volume');
      return;
    }

    final volume = double.tryParse(_volumeController.text);
    if (volume == null || volume <= 0) {
      setState(() => _errorMessage = 'Please enter valid volume');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _hybridSyncService.addIntakeEntry(
        userId: _authService.currentUser?.uid ?? '',
        volume: volume,
        fluidType: _selectedFluidType,
        notes: _notesController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Intake recorded: ${volume.toStringAsFixed(0)} ml',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.green,
          ),
        );
        widget.onSaved();
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Record Intake',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Error message
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Text(
                  _errorMessage!,
                  style: GoogleFonts.poppins(
                    color: Colors.red.shade900,
                    fontSize: 13,
                  ),
                ),
              ),

            // Fluid Type
            Text(
              'Type of Fluid',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButton<String>(
                value: _selectedFluidType,
                isExpanded: true,
                underline: const SizedBox(),
                items: _fluidTypes.map((type) {
                  return DropdownMenuItem(value: type, child: Text(type));
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedFluidType = value ?? 'Water');
                },
              ),
            ),

            const SizedBox(height: 24),

            // Volume
            Text(
              'Volume (ml)',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _volumeController,
              decoration: InputDecoration(
                hintText: 'Enter volume in ml',
                prefixIcon: const Icon(Icons.water_drop),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 12,
                ),
              ),
              keyboardType: TextInputType.number,
            ),

            const SizedBox(height: 12),

            // Quick Add buttons
            Text(
              'Quick Add',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildQuickAddButton(250),
                  const SizedBox(width: 8),
                  _buildQuickAddButton(500),
                  const SizedBox(width: 8),
                  _buildQuickAddButton(750),
                  const SizedBox(width: 8),
                  _buildQuickAddButton(1000),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Notes
            Text(
              'Notes (Optional)',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Add any additional notes',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),

            const SizedBox(height: 32),

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleSaveIntake,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'Save Intake',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAddButton(int volume) {
    return GestureDetector(
      onTap: () {
        _volumeController.text = volume.toString();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.blue.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.blue.shade300),
        ),
        child: Text(
          '${volume}ml',
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.blue.shade900,
          ),
        ),
      ),
    );
  }
}
