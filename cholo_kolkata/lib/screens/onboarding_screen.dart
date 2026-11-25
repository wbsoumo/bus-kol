import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../main.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Defaults: Metro Blue and English
  String _selectedThemeId = 'blue';
  String _selectedLanguage = 'en';

  final List<Map<String, dynamic>> _languages = [
    {
      'code': 'en',
      'name': 'English',
      'native': 'English',
      'sub': 'Official Kolkata Transit Names',
      'enabled': true,
      'flag': '🇬🇧',
    },
    {
      'code': 'bn',
      'name': 'Bengali',
      'native': 'বাংলা',
      'sub': 'কলকাতা ও হাওড়া বাস স্টপ নাম',
      'enabled': true,
      'flag': '🇮🇳',
    },
    {
      'code': 'hi',
      'name': 'Hindi',
      'native': 'हिन्दी',
      'sub': 'कोलकाता बस और मेट्रो',
      'enabled': false,
      'flag': '🇮🇳',
    },
    {
      'code': 'as',
      'name': 'Assamese',
      'native': 'অসমীয়া',
      'sub': 'কোলকাতা বাছ সেৱা',
      'enabled': false,
      'flag': '🇮🇳',
    },
    {
      'code': 'or',
      'name': 'Odia',
      'native': 'ଓଡ଼ିଆ',
      'sub': 'କୋଲକାତା ବସ୍ ସେବା',
      'enabled': false,
      'flag': '🇮🇳',
    },
    {
      'code': 'ta',
      'name': 'Tamil',
      'native': 'தமிழ்',
      'sub': 'கொல்கத்தா பேருந்து',
      'enabled': false,
      'flag': '🇮🇳',
    },
    {
      'code': 'te',
      'name': 'Telugu',
      'native': 'తెలుగు',
      'sub': 'కోల్‌కతా బస్సు రవాణా',
      'enabled': false,
      'flag': '🇮🇳',
    },
  ];

  AppThemeOption get _activeTheme =>
      SettingsService.themes.firstWhere((t) => t.id == _selectedThemeId, orElse: () => SettingsService.themes.first);

  void _nextPage() {
    _pageController.animateToPage(
      1,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOut,
    );
  }

  void _prevPage() {
    _pageController.animateToPage(
      0,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _launchApp() async {
    await SettingsService().completeOnboarding(
      themeId: _selectedThemeId,
      language: _selectedLanguage,
    );
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainHomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = _activeTheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F8),
      body: SafeArea(
        child: Column(
          children: [
            // Top Stepper Indicator
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  // Step 1 pill
                  Expanded(
                    child: Container(
                      height: 5,
                      decoration: BoxDecoration(
                        color: theme.primary,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Step 2 pill
                  Expanded(
                    child: Container(
                      height: 5,
                      decoration: BoxDecoration(
                        color: _currentPage == 1 ? theme.primary : Colors.grey[300],
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Top Status Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _currentPage == 0 ? 'STEP 1 OF 2 • THEME' : 'STEP 2 OF 2 • LANGUAGE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: theme.primary,
                      letterSpacing: 0.8,
                    ),
                  ),
                  if (_currentPage == 1)
                    GestureDetector(
                      onTap: _prevPage,
                      child: Row(
                        children: [
                          Icon(Icons.arrow_back, size: 14, color: theme.primary),
                          const SizedBox(width: 4),
                          Text(
                            'Back',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.primary),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // PageView
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _buildThemeStep(theme),
                  _buildLanguageStep(theme),
                ],
              ),
            ),

            // Bottom Action Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(15),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 3,
                  ),
                  onPressed: _currentPage == 0 ? _nextPage : _launchApp,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _currentPage == 0 ? 'CHOOSE LANGUAGE  →' : '🚀  LAUNCH CHOLO KOLKATA',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // STEP 1: CHOOSE APP THEME (with simulated screen mockups)
  // ---------------------------------------------------------------------------
  Widget _buildThemeStep(AppThemeOption activeTheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choose App Theme',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Preview how CholoKolkata looks across bus & metro routes. Default is Metro Blue.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 16),

          // LIVE MOCKUP PREVIEW of Selected Theme
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(18),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(
                children: [
                  // Mockup Status Bar
                  Container(
                    height: 20,
                    color: activeTheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('9:41', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                        Row(
                          children: [
                            Icon(Icons.wifi, size: 10, color: Colors.white),
                            SizedBox(width: 4),
                            Icon(Icons.battery_full, size: 10, color: Colors.white),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Mockup AppBar
                  Container(
                    color: activeTheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.menu, color: Colors.white, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'CholoKolkata',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    '${activeTheme.name} Theme Active',
                                    style: const TextStyle(color: Colors.white70, fontSize: 9),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(50),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('LIVE GPS', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Top tabs mockup
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                decoration: const BoxDecoration(
                                  border: Border(bottom: BorderSide(color: Colors.white, width: 2.5)),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.directions_bus, size: 13, color: Colors.white),
                                    SizedBox(width: 4),
                                    Text('BUSES', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
                                  ],
                                ),
                              ),
                            ),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.subway, size: 13, color: Colors.white70),
                                    SizedBox(width: 4),
                                    Text('METRO', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Mockup Search & Result Cards
                  Container(
                    color: const Color(0xFFF1F5F9),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        // Search Box mockup
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.trip_origin, size: 13, color: activeTheme.primary),
                                  const SizedBox(width: 8),
                                  const Text('Howrah Station (হাওড়া)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                ],
                              ),
                              Divider(height: 12, color: Colors.grey[200]),
                              Row(
                                children: [
                                  const Icon(Icons.location_on, size: 13, color: Colors.red),
                                  const SizedBox(width: 8),
                                  const Text('Sector V (সল্টলেক)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                decoration: BoxDecoration(
                                  color: activeTheme.primary,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Center(
                                  child: Text('FIND BUSES', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Bus Result item mockup
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: activeTheme.primary,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text('215A', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Howrah ➔ Karunamoyee', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    Text('Next bus in 6 mins • AC Electric', style: TextStyle(fontSize: 9, color: Colors.grey[600])),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: activeTheme.lightBg,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text('LIVE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: activeTheme.primary)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 18),
          const Text(
            'Select App Color Scheme',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF334155)),
          ),
          const SizedBox(height: 10),

          // Theme Choice Cards
          ...SettingsService.themes.map((t) {
            final isSelected = t.id == _selectedThemeId;
            final isDefault = t.id == 'blue';

            return GestureDetector(
              onTap: () {
                setState(() => _selectedThemeId = t.id);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? t.primary : Colors.grey[200]!,
                    width: isSelected ? 2.2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [BoxShadow(color: t.primary.withAlpha(35), blurRadius: 8, offset: const Offset(0, 2))]
                      : [],
                ),
                child: Row(
                  children: [
                    // Theme Color Swatch Circle
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: t.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: t.primary.withAlpha(70),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(t.icon, style: const TextStyle(fontSize: 20)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Title and Description
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                t.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              if (isDefault) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFBBDEFB),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'DEFAULT',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF0D47A1),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            t.subtitle,
                            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    // Selection indicator
                    Radio<String>(
                      value: t.id,
                      groupValue: _selectedThemeId,
                      activeColor: t.primary,
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedThemeId = val);
                      },
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // STEP 2: CHOOSE APP LANGUAGE (English & Bengali enabled, others disabled)
  // ---------------------------------------------------------------------------
  Widget _buildLanguageStep(AppThemeOption activeTheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Language',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'ভাষা নির্বাচন করুন',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Choose your preferred language for bus stops, metro stations and route searches. English and Bengali are currently live.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 16),

          // Languages list
          ..._languages.map((lang) {
            final isEnabled = lang['enabled'] as bool;
            final isSelected = lang['code'] == _selectedLanguage;

            return Opacity(
              opacity: isEnabled ? 1.0 : 0.55,
              child: GestureDetector(
                onTap: isEnabled
                    ? () {
                        setState(() => _selectedLanguage = lang['code'] as String);
                      }
                    : null,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected && isEnabled ? activeTheme.primary : Colors.grey[200]!,
                      width: isSelected && isEnabled ? 2.2 : 1,
                    ),
                    boxShadow: isSelected && isEnabled
                        ? [BoxShadow(color: activeTheme.primary.withAlpha(30), blurRadius: 8, offset: const Offset(0, 2))]
                        : [],
                  ),
                  child: Row(
                    children: [
                      // Flag / Language Avatar
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: isEnabled ? activeTheme.lightBg : Colors.grey[100],
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            lang['flag'] as String,
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Language Names
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  lang['native'] as String,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                    color: isEnabled ? const Color(0xFF1E293B) : Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '(${lang['name']})',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              lang['sub'] as String,
                              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      ),
                      // Status / Radio Indicator
                      if (isEnabled)
                        Radio<String>(
                          value: lang['code'] as String,
                          groupValue: _selectedLanguage,
                          activeColor: activeTheme.primary,
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedLanguage = val);
                          },
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'COMING SOON',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: Colors.grey[600],
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

