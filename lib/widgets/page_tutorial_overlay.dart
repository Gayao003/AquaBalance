import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class TutorialStepItem {
  final String title;
  final String description;
  final IconData icon;

  const TutorialStepItem({
    required this.title,
    required this.description,
    required this.icon,
  });
}

Future<void> showPageTutorialOverlay({
  required BuildContext context,
  required String pageTitle,
  required List<TutorialStepItem> steps,
}) async {
  if (steps.isEmpty) return;

  int currentStep = 0;

  await showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Page Tutorial',
    barrierColor: Colors.black.withOpacity(0.72),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, _, __) {
      return StatefulBuilder(
        builder: (context, setState) {
          final step = steps[currentStep];
          final isFirst = currentStep == 0;
          final isLast = currentStep == steps.length - 1;
          final progress = (currentStep + 1) / steps.length;

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 520),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '$pageTitle Tutorial',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text(
                                'Skip',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor: AppColors.surfaceVariant,
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Step ${currentStep + 1} of ${steps.length}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  step.icon,
                                  color: AppColors.primary,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      step.title,
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      step.description,
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        height: 1.45,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            OutlinedButton(
                              onPressed: isFirst
                                  ? null
                                  : () {
                                      setState(() => currentStep--);
                                    },
                              child: const Text('Back'),
                            ),
                            const Spacer(),
                            ElevatedButton(
                              onPressed: () {
                                if (isLast) {
                                  Navigator.of(context).pop();
                                  return;
                                }
                                setState(() => currentStep++);
                              },
                              child: Text(isLast ? 'Done' : 'Next'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}
