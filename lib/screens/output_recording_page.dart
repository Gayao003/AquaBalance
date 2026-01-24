import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/hybrid_sync_service.dart';
import '../services/auth_service.dart';

class OutputRecordingPage extends StatefulWidget {
  final VoidCallback onSaved;

  const OutputRecordingPage({super.key, required this.onSaved});

  @override
  State<OutputRecordingPage> createState() => _OutputRecordingPageState();
}

class _OutputRecordingPageState extends State<OutputRecordingPage> {
  final _volumeController = TextEditingController();
  final _notesController = TextEditingController();
  final _hybridSyncService = HybridSyncService();
  final _authService = AuthService();

  String _selectedOutputType = 'Urine';
  bool _isLoading = false;
  String? _errorMessage;

  final List<String> _outputTypes = [
    'Urine',
    'Dialysate',
    'Emesis (Vomit)',
    'Stool',
    'Other',
  ];

  @override
  void dispose() {
    _volumeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleSaveOutput() async {
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
      await _hybridSyncService.addOutputEntry(
        userId: _authService.currentUser?.uid ?? '',
        volume: volume,
        outputType: _selectedOutputType,
        notes: _notesController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Output recorded: ${volume.toStringAsFixed(0)} ml',
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
          'Record Output',
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

            // Output Type
            Text(
              'Type of Output',
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
                value: _selectedOutputType,
                isExpanded: true,
                underline: const SizedBox(),
                items: _outputTypes.map((type) {
                  return DropdownMenuItem(value: type, child: Text(type));
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedOutputType = value ?? 'Urine');
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
                prefixIcon: const Icon(Icons.opacity),
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
                  _buildQuickAddButton(200),
                  const SizedBox(width: 8),
                  _buildQuickAddButton(500),
                  const SizedBox(width: 8),
                  _buildQuickAddButton(1000),
                  const SizedBox(width: 8),
                  _buildQuickAddButton(2000),
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
                onPressed: _isLoading ? null : _handleSaveOutput,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
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
                        'Save Output',
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
          color: Colors.orange.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.orange.shade300),
        ),
        child: Text(
          '${volume}ml',
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.orange.shade900,
          ),
        ),
      ),
    );
  }
}
