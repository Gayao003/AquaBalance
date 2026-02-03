import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Privacy Policy',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader('Your privacy matters'),
            const SizedBox(height: 16),
            _buildSection(
              title: 'Information we collect',
              body:
                  'We collect the details you provide in your profile (name, age/date of birth, height, weight) and your hydration logs. We also store sign-in identifiers like email or Google account ID to keep your account secure.',
            ),
            _buildSection(
              title: 'How we use your data',
              body:
                  'We use your data to calculate hydration insights, personalize reminders, and sync your progress across devices. Your information is never sold.',
            ),
            _buildSection(
              title: 'Storage & security',
              body:
                  'Your data is stored securely using Firebase services with access controls. We use encryption in transit and at rest where supported by our providers.',
            ),
            _buildSection(
              title: 'Sharing',
              body:
                  'We do not share your personal data with third parties except to operate the app (e.g., cloud hosting and analytics).',
            ),
            _buildSection(
              title: 'Your choices',
              body:
                  'You can update or delete your profile at any time. You may also disable reminders or notifications from Settings.',
            ),
            _buildSection(
              title: 'Contact us',
              body:
                  'Questions about privacy? Email support@watertrackingapp.app and we will respond within 5 business days.',
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
          const Icon(Icons.shield_outlined, color: AppColors.primary),
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
