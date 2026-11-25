import 'package:flutter/material.dart';
import 'screens/spot_bus_screen.dart';
import 'screens/metro_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/drawer_pages.dart';
import 'services/api_service.dart';

void main() {
  runApp(const CholoKolkataApp());
}

class CholoKolkataApp extends StatelessWidget {
  const CholoKolkataApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CholoKolkata',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00695C),
          primary: const Color(0xFF00695C),
          secondary: const Color(0xFF00897B),
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFEEF1F4),
        fontFamily: 'Roboto',
        useMaterial3: true,
      ),
      home: const MainHomeScreen(),
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
  String _otaNotice = '';

  @override
  void initState() {
    super.initState();
    // Only 2 Top Tabs: BUSES and METRO (Where is My Train exact model)
    _tabController = TabController(length: 2, vsync: this);
    _checkForOtaUpdates();
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF00695C),
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
              color: const Color(0xFF00695C),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.directions_bus, color: Color(0xFF00695C), size: 30),
                  ),
                  SizedBox(height: 12),
                  Text('CholoKolkata', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
                  Text('Kolkata & Bengal Transit • চলো কলকাতা', style: TextStyle(color: Colors.white70, fontSize: 11)),
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
                    leading: const Icon(Icons.history, color: Color(0xFF00695C)),
                    title: const Text('Recent Trip History', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const TripHistoryPage()));
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.receipt_long, color: Color(0xFF00695C)),
                    title: const Text('West Bengal Bus Fare Chart', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const FareChartPage()));
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.sync, color: Color(0xFF00695C)),
                    title: const Text('Check for Route Updates (OTA)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const OtaSyncPage()));
                    },
                  ),
                  const Divider(),
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              color: const Color(0xFFE8F5E9),
              child: Row(
                children: [
                  const Icon(Icons.sync, size: 14, color: Color(0xFF2E7D32)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'OTA Sync: $_otaNotice',
                      style: const TextStyle(color: Color(0xFF1B5E20), fontSize: 11, fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 14, color: Color(0xFF2E7D32)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => setState(() => _otaNotice = ''),
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
        backgroundColor: const Color(0xFF00695C),
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
  }
}
