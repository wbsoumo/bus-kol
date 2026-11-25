import 'package:flutter/material.dart';
import 'screens/spot_bus_screen.dart';
import 'screens/metro_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/drawer_pages.dart';
import 'screens/settings_screen.dart';
import 'screens/live_track_sheet.dart';
import 'services/api_service.dart';
import 'services/notification_service.dart';
import 'services/settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().init();
  await SettingsService().init();
  runApp(const CholoKolkataApp());
}

class CholoKolkataApp extends StatelessWidget {
  const CholoKolkataApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = SettingsService();

    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        final currentTheme = settings.currentTheme;

        return MaterialApp(
          title: 'CholoKolkata',
          navigatorKey: NotificationService.navigatorKey,
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: currentTheme.primary,
              primary: currentTheme.primary,
              secondary: currentTheme.secondary,
              surface: Colors.white,
            ),
            scaffoldBackgroundColor: const Color(0xFFEEF1F4),
            fontFamily: 'Roboto',
            useMaterial3: true,
          ),
          home: const MainHomeScreen(),
        );
      },
    );
  }
}

class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({super.key});

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _api = ApiService();
  final SettingsService _settings = SettingsService();
  String _otaNotice = '';

  @override
  void initState() {
    super.initState();
    // Only 2 Top Tabs: BUSES and METRO (Where is My Train exact model)
    _tabController = TabController(length: 2, vsync: this);
    _checkForOtaUpdates();

    // Listen for notification clicks to deep-link directly to live track screen
    NotificationService().onNotificationClicked = (data) {
      _navigateToLiveTrack(data);
    };
    NotificationService().checkInitialNotification().then((data) {
      if (data != null && mounted) {
        _navigateToLiveTrack(data);
      }
    });
  }

  void _navigateToLiveTrack(Map<String, dynamic> data) {
    final routeNo = data['routeNo']?.toString() ?? '';
    final routeId = (data['routeId'] is num)
        ? (data['routeId'] as num).toInt()
        : (int.tryParse(data['routeId']?.toString() ?? '818') ?? 818);
    if (routeNo.isNotEmpty) {
      NotificationService.navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => LiveTrackScreen(
            routeId: routeId,
            routeNo: routeNo,
            busType: 'City Bus',
          ),
        ),
      );
    }
  }

  void _checkForOtaUpdates() async {
    try {
      final syncData = await _api.checkBackgroundSync('2.4.0');
      if (syncData['has_updates'] == true) {
        setState(() {
          _otaNotice = syncData['changelog'] ?? 'Kolkata bus route database synced via OTA.';
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openChatSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const AnonymousChatSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _settings,
      builder: (context, _) {
        final currentTheme = _settings.currentTheme;

        return Scaffold(
          appBar: AppBar(
            backgroundColor: currentTheme.primary,
            elevation: 0,
            leading: Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                tooltip: 'Open Menu',
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
            title: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CholoKolkata',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
                ),
                Text(
                  'Kolkata Bus & Metro • চলো কলকাতা',
                  style: TextStyle(color: Colors.white70, fontSize: 10),
                ),
              ],
            ),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(38),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.security, size: 12, color: Colors.white),
                    SizedBox(width: 4),
                    Text('SECURE OTA', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
            // Top 2 Tabs ONLY
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: const [
                Tab(icon: Icon(Icons.directions_bus, size: 20), text: 'BUSES'),
                Tab(icon: Icon(Icons.subway, size: 20), text: 'METRO'),
              ],
            ),
          ),

          // Side Navigation Drawer
          drawer: Drawer(
            child: Column(
              children: [
                // Drawer Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 48, 16, 20),
                  color: currentTheme.primary,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.directions_bus, color: currentTheme.primary, size: 30),
                      ),
                      const SizedBox(height: 12),
                      const Text('CholoKolkata', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
                      const Text('Kolkata & Bengal Transit • চলো কলকাতা', style: TextStyle(color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ),

                // Navigation Items
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.star, color: Colors.amber),
                        title: const Text('Saved & Starred Routes', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedRoutesPage()));
                        },
                      ),
                      ListTile(
                        leading: Icon(Icons.history, color: currentTheme.primary),
                        title: const Text('Recent Trip History', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const TripHistoryPage()));
                        },
                      ),
                      ListTile(
                        leading: Icon(Icons.receipt_long, color: currentTheme.primary),
                        title: const Text('West Bengal Bus Fare Chart', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const FareChartPage()));
                        },
                      ),
                      ListTile(
                        leading: Icon(Icons.subway, color: currentTheme.primary),
                        title: const Text('Metro Lines & Timings Directory', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        subtitle: const Text('Blue, Green, Purple & Orange Corridors', style: TextStyle(fontSize: 11)),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const MetroDirectoryPage()));
                        },
                      ),
                      ListTile(
                        leading: Icon(Icons.sync, color: currentTheme.primary),
                        title: const Text('Check for Route Updates (OTA)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const OtaSyncPage()));
                        },
                      ),
                      const Divider(),
                      // SETTINGS OPTION (Theme, Notifications, Alerts)
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: currentTheme.lightBg,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.settings, color: currentTheme.primary, size: 20),
                        ),
                        title: const Text('Settings & Theme', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                        subtitle: Text('Accent: ${currentTheme.name} • Notifications', style: const TextStyle(fontSize: 11)),
                        trailing: const Icon(Icons.chevron_right, size: 18),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.language, color: Colors.grey),
                        title: const Text('Language / ভাষা', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        subtitle: const Text('English / বাংলা', style: TextStyle(fontSize: 11)),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const LanguagePage()));
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.privacy_tip_outlined, color: Colors.grey),
                        title: const Text('Privacy Policy & Data Security', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        subtitle: const Text('256-bit AES-GCM Encrypted Transit', style: TextStyle(fontSize: 11)),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()));
                        },
                      ),
                    ],
                  ),
                ),

                // Drawer Bottom: "Made in Kolkata with Love of Rosogolla 🍮"
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Colors.grey[200]!)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Made in Kolkata with Love of Rosogolla',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF37474F)),
                      ),
                      SizedBox(width: 6),
                      Text('🍮', style: TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Body with TabBarView for BUSES and METRO
          body: Column(
            children: [
              if (_otaNotice.isNotEmpty)
                Container(
                  width: double.infinity,
                  color: const Color(0xFFFFF8E1),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: Color(0xFFF57F17)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _otaNotice,
                          style: const TextStyle(fontSize: 11, color: Color(0xFFE65100), fontWeight: FontWeight.bold),
                        ),
                      ),
                      InkWell(
                        onTap: () => setState(() => _otaNotice = ''),
                        child: const Icon(Icons.close, size: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: const [
                    SpotBusScreen(),
                    MetroScreen(),
                  ],
                ),
              ),
            ],
          ),

          // Floating Anonymous Commuter Chat Action Button
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: currentTheme.primary,
            elevation: 4,
            onPressed: _openChatSheet,
            icon: Stack(
              alignment: Alignment.topRight,
              children: [
                const Icon(Icons.forum, color: Colors.white),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF00E676),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            label: const Text(
              'LIVE CHAT',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5),
            ),
          ),
        );
      },
    );
  }
}
