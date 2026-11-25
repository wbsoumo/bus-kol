import 'package:flutter/material.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settings = SettingsService();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _settings,
      builder: (context, _) {
        final currentTheme = _settings.currentTheme;

        return Scaffold(
          backgroundColor: const Color(0xFFF1F5F9),
          appBar: AppBar(
            backgroundColor: currentTheme.primary,
            elevation: 2,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'Settings',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // SECTION 1: APPEARANCE & THEME
              _buildSectionHeader('APPEARANCE & THEME', Icons.palette_outlined, currentTheme.primary),
              const SizedBox(height: 8),
              Card(
                elevation: 1.5,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Choose Accent Theme',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Saved permanently on your device and updates all screens instantly.',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 12),
                      ...SettingsService.themes.map((theme) {
                        final isSelected = _settings.currentThemeId == theme.id;
                        return InkWell(
                          onTap: () => _settings.setTheme(theme.id),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? theme.lightBg : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected ? theme.primary : const Color(0xFFE2E8F0),
                                width: isSelected ? 1.8 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                // Theme Color Dot
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: theme.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.15),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(theme.icon, style: const TextStyle(fontSize: 12)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            theme.name,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: isSelected ? theme.primary : const Color(0xFF1E293B),
                                            ),
                                          ),
                                          if (theme.id == 'orange') ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFFE0B2),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Text(
                                                'DEFAULT',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w900,
                                                  color: Color(0xFFBF360C),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        theme.subtitle,
                                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                      ),
                                    ],
                                  ),
                                ),
                                Radio<String>(
                                  value: theme.id,
                                  groupValue: _settings.currentThemeId,
                                  activeColor: theme.primary,
                                  onChanged: (val) {
                                    if (val != null) _settings.setTheme(val);
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // SECTION 2: TRIP NOTIFICATIONS
              _buildSectionHeader('NOTIFICATIONS & ALERTS', Icons.notifications_active_outlined, currentTheme.primary),
              const SizedBox(height: 8),
              Card(
                elevation: 1.5,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    children: [
                      SwitchListTile(
                        activeColor: currentTheme.primary,
                        title: const Text(
                          'Live Trip Notification',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        subtitle: const Text(
                          'Show Where Is My Train style tracking bar in notification shade while commuting.',
                          style: TextStyle(fontSize: 11),
                        ),
                        value: _settings.notificationsEnabled,
                        onChanged: (val) => _settings.setNotificationsEnabled(val),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        activeColor: currentTheme.primary,
                        title: const Text(
                          'Arrival Vibration Alert',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        subtitle: const Text(
                          'Vibrate phone when arriving near your alighting bus stop.',
                          style: TextStyle(fontSize: 11),
                        ),
                        value: _settings.vibrationEnabled,
                        onChanged: (val) => _settings.setVibrationEnabled(val),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // SECTION 3: SEARCH PREFERENCES & CACHE
              _buildSectionHeader('SEARCH MEMORY & CACHE', Icons.history_rounded, currentTheme.primary),
              const SizedBox(height: 8),
              Card(
                elevation: 1.5,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.save_as_rounded, size: 16, color: currentTheme.primary),
                          const SizedBox(width: 8),
                          const Text(
                            'Remember Last Search (Active)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your departure and destination stops are automatically saved so you never have to re-type them upon reopening.',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFD32F2F),
                          side: const BorderSide(color: Color(0xFFFFCDD2)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.delete_outline, size: 16),
                        label: const Text('Reset Search Memory & Cache', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: () async {
                          await _settings.clearHistory();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Search memory reset to default.'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // SECTION 4: ABOUT & APP INFO
              _buildSectionHeader('ABOUT CHOLOKOLKATA', Icons.info_outline, currentTheme.primary),
              const SizedBox(height: 8),
              Card(
                elevation: 1.5,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CholoKolkata Transit • চলো কলকাতা',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Version 2.4.0 (Build 2026) • Kolkata Bus & Metro',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.cloud_done_rounded, size: 16, color: Color(0xFF2E7D32)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '2,172 Bus Routes • 4 Metro Corridors • 718 Fleet Photos',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Colors.blueGrey[700],
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

