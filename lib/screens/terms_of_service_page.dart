import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class TermsOfServicePage extends StatelessWidget {
  const TermsOfServicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Terms of Service',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader('Using the Water Tracking App'),
            const SizedBox(height: 16),
            _buildSection(
              title: 'Eligibility',
              body:
                  'You must be at least 13 years old to use the app. By using the app, you confirm you meet this requirement.',
            ),
            _buildSection(
              title: 'Health disclaimer',
              body:
                  'The app provides hydration guidance for informational purposes and is not a substitute for professional medical advice. Consult a clinician for medical concerns.',
            ),
            _buildSection(
              title: 'Account responsibilities',
              body:
                  'Keep your login details secure. You are responsible for activity on your account, including setting a password if you use Google sign-in.',
            ),
            _buildSection(
              title: 'Acceptable use',
              body:
                  'Do not misuse the app, attempt to access data without authorization, or disrupt the service for other users.',
            ),
            _buildSection(
              title: 'Service availability',
              body:
                  'We work to keep the app reliable, but uptime is not guaranteed. Features may change as we improve the product.',
            ),
            _buildSection(
              title: 'Termination',
              body:
                  'You may delete your account at any time. We may suspend accounts for violations of these terms.',
            ),
            _buildSection(
              title: 'Contact',
              body:
                  'Questions about these terms? Email support@watertrackingapp.app.',
            ),
            const SizedBox(height: 12),
            Text(
              'Last updated: February 3, 2026',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.article_outlined, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required String body}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: GoogleFonts.poppins(
              fontSize: 13,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
