import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'schedule_page.dart';

class GoalsPage extends StatelessWidget {
  const GoalsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Redirect to Schedule page since goals are now managed through schedules
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => SchedulePage(onOpenDrawer: null),
        ),
      );
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Redirecting...',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      body: const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }
}
