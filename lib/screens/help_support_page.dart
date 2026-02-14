import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class HelpSupportPage extends StatefulWidget {
  const HelpSupportPage({super.key});

  @override
  State<HelpSupportPage> createState() => _HelpSupportPageState();
}

class _HelpSupportPageState extends State<HelpSupportPage> {
  int? _expandedIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Help & Support',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildHeroCard(),
          const SizedBox(height: 24),
          Text(
            'Quick Help',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _buildQuickActionCard(
            icon: Icons.water_drop,
            title: 'Getting Started',
            subtitle: 'Learn the basics',
            color: AppColors.primary,
            onTap: () =>
                _showDialog('Getting Started', _getGettingStartedContent()),
          ),
          const SizedBox(height: 12),
          _buildQuickActionCard(
            icon: Icons.alarm,
            title: 'Set Up Reminders',
            subtitle: 'Create your schedule',
            color: AppColors.accent,
            onTap: () =>
                _showDialog('Set Up Reminders', _getRemindersContent()),
          ),
          const SizedBox(height: 12),
          _buildQuickActionCard(
            icon: Icons.bar_chart,
            title: 'Track Your Progress',
            subtitle: 'View trends & history',
            color: AppColors.success,
            onTap: () =>
                _showDialog('Track Your Progress', _getTrackingContent()),
          ),
          const SizedBox(height: 24),
          Text(
            'Frequently Asked Questions',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ..._buildFAQs(),
          const SizedBox(height: 24),
          Text(
            'Contact Us',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _buildContactCard(
            icon: Icons.email_outlined,
            title: 'Email Support',
            subtitle: 'support@watertrackingapp.com',
            onTap: () => _launchEmail('support@watertrackingapp.com'),
          ),
          const SizedBox(height: 12),
          _buildContactCard(
            icon: Icons.feedback_outlined,
            title: 'Send Feedback',
            subtitle: 'Help us improve',
            onTap: () => _showFeedbackDialog(),
          ),
          const SizedBox(height: 12),
          _buildContactCard(
            icon: Icons.bug_report_outlined,
            title: 'Report a Bug',
            subtitle: 'Let us know what went wrong',
            onTap: () => _showBugReportDialog(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.support_agent,
              size: 40,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'We\'re Here to Help',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Find answers, tips, and support',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
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
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFAQs() {
    final faqs = [
      {
        'question': 'How is my daily hydration goal calculated?',
        'answer':
            'Your daily goal is the sum of all enabled schedules. Each schedule represents a reminder with a specific beverage type and amount. You can customize these in the Schedule page.',
      },
      {
        'question': 'What do the beverage types mean?',
        'answer':
            'Different beverages have different hydration values:\n\n• Water: Pure hydration\n• Coffee/Tea: Caffeinated beverages\n• Juice: Natural fruit beverages\n• Milk: Dairy-based drinks\n• Sports Drinks: Electrolyte beverages\n• Other: Custom beverages\n\nAll types count toward your daily intake.',
      },
      {
        'question': 'How is urinary output estimated?',
        'answer':
            'Output is estimated as 65% of your fluid intake, which is a typical average. The remaining 35% is lost through perspiration (25%) and other means (10%). This is an estimate only.',
      },
      {
        'question': 'What happens when I skip a reminder?',
        'answer':
            'Skipped reminders appear in your Intake History with a "SKIPPED" label and don\'t count toward your daily goal. Use the filter to view all skipped entries.',
      },
      {
        'question': 'Can I track multiple beverage types?',
        'answer':
            'Yes! You can create separate schedules for different beverage types. Each reminder can be customized with its own beverage type, amount, and frequency.',
      },
      {
        'question': 'How do I view my hydration trends?',
        'answer':
            'Go to the Trends page from the bottom navigation. You\'ll see daily, weekly, and monthly charts showing your intake patterns, consistency, and progress over time.',
      },
    ];

    return faqs.asMap().entries.map((entry) {
      final index = entry.key;
      final faq = entry.value;
      final isExpanded = _expandedIndex == index;

      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isExpanded ? AppColors.primary : AppColors.border,
              width: isExpanded ? 2 : 1,
            ),
            boxShadow: isExpanded
                ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _expandedIndex = isExpanded ? null : index;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              faq['question']!,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          AnimatedRotation(
                            duration: const Duration(milliseconds: 300),
                            turns: isExpanded ? 0.5 : 0,
                            child: Icon(
                              Icons.keyboard_arrow_down,
                              color: isExpanded
                                  ? AppColors.primary
                                  : AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                      AnimatedCrossFade(
                        duration: const Duration(milliseconds: 300),
                        firstChild: const SizedBox.shrink(),
                        secondChild: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            faq['answer']!,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              height: 1.5,
                            ),
                          ),
                        ),
                        crossFadeState: isExpanded
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildContactCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primaryLight, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  void _showDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          title,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        content: SingleChildScrollView(
          child: Text(
            content,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Got it!',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFeedbackDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Send Feedback',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: 'Tell us what you think...',
            hintStyle: GoogleFonts.poppins(color: AppColors.textTertiary),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Thank you for your feedback!',
                    style: GoogleFonts.poppins(),
                  ),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            child: Text('Send', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  void _showBugReportDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Report a Bug',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Describe what went wrong...',
                hintStyle: GoogleFonts.poppins(color: AppColors.textTertiary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Bug report submitted. Thank you!',
                    style: GoogleFonts.poppins(),
                  ),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            child: Text('Submit', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  Future<void> _launchEmail(String email) async {
    await Clipboard.setData(ClipboardData(text: email));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Email address copied to clipboard: $email',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  String _getGettingStartedContent() {
    return '''Welcome to Water Tracking App! Here's how to get started:

1. Set Up Your Profile
   Go to Profile and enter your preferences (volume unit, etc.)

2. Create Your Schedule
   Tap the Schedule tab and add reminders for when you want to drink

3. Log Your Intake
   Tap the + button on notifications or home page to log your drinks

4. Track Progress
   View your daily progress on the Home page and trends in the Trends tab

5. View History
   Check Intake History to see all your logged beverages and skipped reminders

That's it! The app will remind you to stay hydrated throughout the day.''';
  }

  String _getRemindersContent() {
    return '''Setting up reminders is easy:

1. Go to the Schedule page from the bottom navigation

2. Tap the + button to add a new schedule

3. Choose:
   • Time: When you want the reminder
   • Beverage Type: Water, Coffee, Tea, etc.
   • Amount: How much to drink
   • Label: Optional custom name

4. Enable/disable schedules anytime with the toggle switch

5. Edit or delete schedules by tapping on them

Tips:
• Create multiple schedules for different times of day
• Use different beverage types to track variety
• Set amounts that match your drinking habits
• Disable schedules on off days without deleting them''';
  }

  String _getTrackingContent() {
    return '''Track your hydration in multiple ways:

Home Page
• See today's progress vs your goal
• View estimated urinary output
• Quick access to log intake

Intake History
• See all logged beverages by type
• Filter by Water, Coffee, Tea, etc.
• View skipped reminders
• See time-stamped entries

Trends Page
• Daily, weekly, and monthly charts
• Consistency tracking
• Long-term progress visualization

Reports Page
• Detailed analytics
• Export your data
• View patterns over time

Pro Tips:
• Use filters to analyze specific beverage types
• Check trends regularly to stay motivated
• Adjust schedules based on your patterns''';
  }
}
