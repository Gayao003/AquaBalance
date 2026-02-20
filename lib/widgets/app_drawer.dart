import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class AppDrawer extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelectIndex;
  final VoidCallback onNavigateToProfile;
  final VoidCallback onNavigateToIntakeHistory;
  final VoidCallback onNavigateToOutputHistory;
  final VoidCallback onNavigateToReports;
  final VoidCallback onNavigateToHelp;
  final VoidCallback onNavigateToAbout;
  final VoidCallback onSignOut;

  const AppDrawer({
    super.key,
    required this.selectedIndex,
    required this.onSelectIndex,
    required this.onNavigateToProfile,
    required this.onNavigateToIntakeHistory,
    required this.onNavigateToOutputHistory,
    required this.onNavigateToReports,
    required this.onNavigateToHelp,
    required this.onNavigateToAbout,
    required this.onSignOut,
  });

  void _handleTap(BuildContext context, VoidCallback action) {
    Navigator.pop(context);
    action();
  }

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final user = authService.currentUser;
    final displayName = user?.displayName ?? 'Hydration Champion';
    final email = user?.email ?? 'No email on file';

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                border: Border(
                  bottom: BorderSide(color: AppColors.border),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      displayName.isNotEmpty
                          ? displayName.characters.first.toUpperCase()
                          : 'U',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          email,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _buildSectionLabel('Main'),
                  _buildNavItem(
                    context,
                    icon: Icons.home_rounded,
                    label: 'Home',
                    selected: selectedIndex == 0,
                    onTap: () => onSelectIndex(0),
                  ),
                  _buildNavItem(
                    context,
                    icon: Icons.schedule,
                    label: 'Schedule',
                    selected: selectedIndex == 1,
                    onTap: () => onSelectIndex(1),
                  ),
                  _buildNavItem(
                    context,
                    icon: Icons.trending_up,
                    label: 'Insights',
                    selected: selectedIndex == 2,
                    onTap: () => onSelectIndex(2),
                  ),
                  _buildNavItem(
                    context,
                    icon: Icons.settings_rounded,
                    label: 'Settings',
                    selected: selectedIndex == 3,
                    onTap: () => onSelectIndex(3),
                  ),
                  const SizedBox(height: 12),
                  _buildSectionLabel('Track'),
                  _buildNavItem(
                    context,
                    icon: Icons.opacity,
                    label: 'Intake History',
                    onTap: onNavigateToIntakeHistory,
                  ),
                  _buildNavItem(
                    context,
                    icon: Icons.water_damage_outlined,
                    label: 'Output History',
                    onTap: onNavigateToOutputHistory,
                  ),
                  _buildNavItem(
                    context,
                    icon: Icons.insert_chart_outlined,
                    label: 'Reports',
                    onTap: onNavigateToReports,
                  ),
                  const SizedBox(height: 12),
                  _buildSectionLabel('Account'),
                  _buildNavItem(
                    context,
                    icon: Icons.person,
                    label: 'Profile',
                    onTap: onNavigateToProfile,
                  ),
                  const SizedBox(height: 12),
                  _buildSectionLabel('Support'),
                  _buildNavItem(
                    context,
                    icon: Icons.help_outline,
                    label: 'Help & Support',
                    onTap: onNavigateToHelp,
                  ),
                  _buildNavItem(
                    context,
                    icon: Icons.info_outline,
                    label: 'About',
                    onTap: onNavigateToAbout,
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  _buildNavItem(
                    context,
                    icon: Icons.logout,
                    label: 'Sign Out',
                    onTap: onSignOut,
                    color: AppColors.error,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textTertiary,
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool selected = false,
    Color? color,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color:
            color ?? (selected ? AppColors.primary : AppColors.textSecondary),
      ),
      title: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          color:
              color ?? (selected ? AppColors.primary : AppColors.textPrimary),
        ),
      ),
      selected: selected,
      selectedTileColor: AppColors.primary.withOpacity(0.08),
      onTap: () => _handleTap(context, onTap),
    );
  }
}
