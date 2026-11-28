import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/bus_data_service.dart';
import '../services/kolkata_geo.dart';
import '../services/kolkata_stops.dart';
import '../services/multi_transit_service.dart';
import '../services/settings_service.dart';
import 'results_screen.dart';

// ==========================================
// 1. SAVED & STARRED ROUTES PAGE
// ==========================================
class SavedRoutesPage extends StatefulWidget {
  const SavedRoutesPage({super.key});

  @override
  State<SavedRoutesPage> createState() => _SavedRoutesPageState();
}

class _SavedRoutesPageState extends State<SavedRoutesPage> {
  final List<Map<String, dynamic>> _savedRoutes = [
    {
      'route_no': '215A',
      'from': 'Howrah Station',
      'to': 'Sector V',
      'via': 'Barabazar, MG Road, Ultadanga, Karunamoyee',
      'type': 'City Bus',
      'fare': '₹20',
      'stops_count': 21,
      'is_ac': false,
    },
    {
      'route_no': 'S-12',
      'from': 'Howrah Station',
      'to': 'New Town Eco Space',
      'via': 'Esplanade, Sealdah, Chingrighata, Sector V',
      'type': 'State Bus (WBTC)',
      'fare': '₹25',
      'stops_count': 24,
      'is_ac': false,
    },
    {
      'route_no': 'AC-12',
      'from': 'Howrah Station',
      'to': 'Salt Lake Sector V',
      'via': 'MG Road, Kankurgachi, Ultadanga',
      'type': 'AC Electric Coach',
      'fare': '₹35',
      'stops_count': 18,
      'is_ac': true,
    },
    {
      'route_no': 'Line 2 (Green)',
      'from': 'Howrah Maidan',
      'to': 'Esplanade',
      'via': 'Howrah Railway Station, BBD Bagh',
      'type': 'Kolkata Metro Rail',
      'fare': '₹10',
      'stops_count': 4,
      'is_ac': true,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: SettingsService().currentTheme.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Saved & Starred Routes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      body: _savedRoutes.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.star_border, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  const Text('No saved routes yet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey)),
                  const SizedBox(height: 6),
                  const Text('Star your frequent bus or metro routes for quick access.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _savedRoutes.length,
              itemBuilder: (ctx, i) {
                final r = _savedRoutes[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  elevation: 1.5,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: SettingsService().currentTheme.primary,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(r['route_no'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                ),
                                const SizedBox(width: 8),
                                Text(r['type'], style: TextStyle(color: Colors.grey[700], fontSize: 11, fontWeight: FontWeight.w600)),
                              ],
                            ),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(4)),
                                  child: Text(r['fare'], style: const TextStyle(color: Color(0xFF1B5E20), fontWeight: FontWeight.bold, fontSize: 11)),
                                ),
                                const SizedBox(width: 6),
                                InkWell(
                                  onTap: () {
                                    setState(() => _savedRoutes.removeAt(i));
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Route removed from saved.')));
                                  },
                                  child: const Icon(Icons.star, color: Colors.amber, size: 22),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.trip_origin, size: 14, color: Color(0xFF2E7D32)),
                            const SizedBox(width: 6),
                            Expanded(child: Text('${r['from']} ➔ ${r['to']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('Via: ${r['via']}', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                        const Divider(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${r['stops_count']} Stops • Runs Daily', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: SettingsService().currentTheme.primary,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                visualDensity: VisualDensity.compact,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              icon: const Icon(Icons.navigation, size: 12, color: Colors.white),
                              label: const Text('TRACK ROUTE', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ResultsScreen(fromStop: r['from'], toStop: r['to']),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ==========================================
// 2. RECENT TRIP HISTORY PAGE
// ==========================================
class TripHistoryPage extends StatefulWidget {
  const TripHistoryPage({super.key});

  @override
  State<TripHistoryPage> createState() => _TripHistoryPageState();
}

class _TripHistoryPageState extends State<TripHistoryPage> {
  final List<Map<String, String>> _trips = [
    {'from': 'Howrah Station', 'to': 'Sector V', 'time': 'Today, 10:05 AM', 'mode': 'BUS', 'route': '215A'},
    {'from': 'Howrah Maidan', 'to': 'Esplanade', 'time': 'Today, 09:40 AM', 'mode': 'METRO', 'route': 'Green Line'},
    {'from': 'Esplanade', 'to': 'Airport (NSCBIA)', 'time': 'Yesterday, 06:15 PM', 'mode': 'BUS', 'route': 'V-1 / AC-39'},
    {'from': 'Ultadanga', 'to': 'Ruby Hospital', 'time': 'Nov 23, 08:30 PM', 'mode': 'BUS', 'route': 'S-12 / 24A'},
    {'from': 'Sealdah Station', 'to': 'Howrah Station', 'time': 'Nov 22, 11:20 AM', 'mode': 'BUS', 'route': '24A / 71'},
    {'from': 'Dakshineswar', 'to': 'Park Street', 'time': 'Nov 20, 04:10 PM', 'mode': 'METRO', 'route': 'Blue Line'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: SettingsService().currentTheme.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Recent Trip History', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
          if (_trips.isNotEmpty)
            TextButton(
              onPressed: () {
                setState(() => _trips.clear());
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Trip history cleared.')));
              },
              child: const Text('CLEAR ALL', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: _trips.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  const Text('No trip history found', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey)),
                  const SizedBox(height: 6),
                  const Text('Your recent bus and metro searches will appear here.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _trips.length,
              itemBuilder: (ctx, i) {
                final t = _trips[i];
                final isBus = t['mode'] == 'BUS';
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isBus ? const Color(0xFFE0F2F1) : const Color(0xFFEDE7F6),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(isBus ? Icons.directions_bus : Icons.subway, color: isBus ? SettingsService().currentTheme.primary : const Color(0xFF5E35B1), size: 20),
                    ),
                    title: Text('${t['from']} ➔ ${t['to']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 2),
                        Text('${t['time']} • Preferred: ${t['route']}', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                      ],
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 13, color: Colors.grey),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ResultsScreen(fromStop: t['from']!, toStop: t['to']!),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}

// ==========================================
// 3. WEST BENGAL BUS FARE CHART PAGE
// ==========================================
class FareChartPage extends StatelessWidget {
  const FareChartPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: SettingsService().currentTheme.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('West Bengal Bus Fare Chart', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _buildNoticeCard(),
          const SizedBox(height: 14),
          _buildFareTable(
            title: '1. Ordinary City Buses (WBTC / Private)',
            subtitle: 'Standard Non-AC Stage Carriage across KMA',
            headers: ['Stage (km)', 'Distance Slab', 'Approved Fare'],
            rows: [
              ['Stage 1', '0 - 4 km', '₹10'],
              ['Stage 2', '4 - 8 km', '₹12'],
              ['Stage 3', '8 - 12 km', '₹15'],
              ['Stage 4', '12 - 16 km', '₹18'],
              ['Stage 5', '16 - 20 km', '₹20'],
              ['Stage 6', '20+ km', '₹25'],
            ],
            color: SettingsService().currentTheme.primary,
          ),
          const SizedBox(height: 14),
          _buildFareTable(
            title: '2. AC City Services (WBTC Electric & Diesel)',
            subtitle: 'Air-Conditioned Premium Services',
            headers: ['Route Range', 'Distance Slab', 'Approved Fare'],
            rows: [
              ['Base Fare', '0 - 5 km', '₹20'],
              ['Medium', '5 - 12 km', '₹25 - ₹30'],
              ['Extended', '12 - 20 km', '₹35 - ₹40'],
              ['Long Corridor', '20+ km', '₹45 - ₹50'],
            ],
            color: const Color(0xFF0277BD),
          ),
          const SizedBox(height: 14),
          _buildFareTable(
            title: '3. Minibus Services (Kolkata & Howrah)',
            subtitle: 'Private Minibus Association Fare Matrix',
            headers: ['Stage', 'Distance Slab', 'Approved Fare'],
            rows: [
              ['Stage 1', '0 - 3 km', '₹12'],
              ['Stage 2', '3 - 6 km', '₹15'],
              ['Stage 3', '6 - 10 km', '₹18'],
              ['Stage 4', '10+ km', '₹20'],
            ],
            color: const Color(0xFFE65100),
          ),
          const SizedBox(height: 14),
          _buildFareTable(
            title: '4. Kolkata Metro Rail Official Fares',
            subtitle: 'Metro Railway Kolkata (Indian Railways)',
            headers: ['Zone', 'Distance Slab', 'Token / Card Fare'],
            rows: [
              ['Zone 1', '0 - 2 km', '₹5'],
              ['Zone 2', '2 - 5 km', '₹10'],
              ['Zone 3', '5 - 10 km', '₹15'],
              ['Zone 4', '10 - 20 km', '₹20'],
              ['Zone 5', '20+ km', '₹25'],
            ],
            color: const Color(0xFF2E7D32),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildNoticeCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      color: const Color(0xFFFFF8E1),
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info, color: Color(0xFFF57F17), size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Fares shown are prescribed by the Transport Department, Government of West Bengal. Exact fares may vary slightly based on specific bus stop stage points.',
                style: TextStyle(fontSize: 11, color: Color(0xFF5D4037), height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFareTable({
    required String title,
    required String subtitle,
    required List<String> headers,
    required List<List<String>> rows,
    required Color color,
  }) {
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: color)),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            const SizedBox(height: 10),
            Table(
              border: TableBorder(horizontalInside: BorderSide(color: Colors.grey[200]!, width: 1)),
              columnWidths: const {
                0: FlexColumnWidth(1.2),
                1: FlexColumnWidth(1.5),
                2: FlexColumnWidth(1.2),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(color: color.withAlpha(25)),
                  children: headers.map((h) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6),
                    child: Text(h, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: color)),
                  )).toList(),
                ),
                ...rows.map((r) => TableRow(
                  children: [
                    Padding(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6), child: Text(r[0], style: const TextStyle(fontSize: 11))),
                    Padding(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6), child: Text(r[1], style: const TextStyle(fontSize: 11, color: Colors.black87))),
                    Padding(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6), child: Text(r[2], style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: color))),
                  ],
                )),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 4. CHECK FOR ROUTE UPDATES (OTA) PAGE
// ==========================================
class OtaSyncPage extends StatefulWidget {
  const OtaSyncPage({super.key});

  @override
  State<OtaSyncPage> createState() => _OtaSyncPageState();
}

class _OtaSyncPageState extends State<OtaSyncPage> {
  bool _isChecking = false;
  String _status = 'Offline transit directory is active and ready.';

  void _triggerCheck() async {
    setState(() {
      _isChecking = true;
      _status = 'Checking CholoKolkata OTA transit registry...';
    });
    try {
      final res = await ApiService().syncOtaInBackground(force: true);
      if (!mounted) return;
      if (res['success'] == true) {
        final updated = res['updated'] == true;
        final routesCount = res['total_routes'] ?? BusDataService().totalRoutesCount;
        final ver = res['version'] ?? BusDataService().dataVersion;
        setState(() {
          _isChecking = false;
          _status = updated
              ? 'Synced $routesCount routes to offline cache (v$ver)!'
              : 'All $routesCount routes are up to date (v$ver).';
        });
      } else {
        setState(() {
          _isChecking = false;
          _status = 'Server unreachable right now. Using ${BusDataService().totalRoutesCount} cached offline routes.';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isChecking = false;
        _status = 'Offline mode active with ${BusDataService().totalRoutesCount} cached routes.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: SettingsService().currentTheme.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Route Updates & OTA Sync', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE0F2F1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(_isChecking ? Icons.sync : Icons.cloud_done, size: 32, color: SettingsService().currentTheme.primary),
                    ),
                    const SizedBox(height: 12),
                    const Text('Over-The-Air Route Sync', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(
                      'Background route updates occur automatically without needing app updates from the store.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    const Divider(height: 24),
                    _buildSyncStat('Local Database Version', 'v${BusDataService().dataVersion} (Kolkata Core)'),
                    _buildSyncStat('Total Bus Routes', '${BusDataService().totalRoutesCount} Routes'),
                    _buildSyncStat('Total Auto Corridors', '${MultiTransitService().totalAutoRoutesCount} Routes'),
                    _buildSyncStat('Total Bus Stops', '${KolkataStops.totalStopsCount} Stops'),
                    _buildSyncStat('Geocoded GPS Stops', '${KolkataGeo.totalCoordsCount} Pins'),
                    _buildSyncStat('Metro Corridors', '5 Lines (50 Stations)'),
                    _buildSyncStat('Payload Encryption', 'AES-256-GCM Secure'),
                    _buildSyncStat('Last Synchronization', BusDataService().lastSyncTime),
                    const SizedBox(height: 16),
                    Text(_status, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: SettingsService().currentTheme.primary)),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: SettingsService().currentTheme.primary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _isChecking ? null : _triggerCheck,
                        icon: _isChecking
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.sync, color: Colors.white, size: 18),
                        label: Text(
                          _isChecking ? 'SYNCING IN BACKGROUND...' : 'CHECK FOR UPDATES NOW',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncStat(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// ==========================================
// 5. LANGUAGE / ভাষা PAGE
// ==========================================
class LanguagePage extends StatefulWidget {
  const LanguagePage({super.key});

  @override
  State<LanguagePage> createState() => _LanguagePageState();
}

class _LanguagePageState extends State<LanguagePage> {
  late String _selected;

  @override
  void initState() {
    super.initState();
    _selected = SettingsService().selectedLanguage;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: SettingsService().currentTheme.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Language / ভাষা', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Choose App Language', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF37474F))),
            const SizedBox(height: 8),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Column(
                children: [
                  RadioListTile<String>(
                    title: const Text('English (Default)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('All routes, stops and announcements in English', style: TextStyle(fontSize: 11)),
                    value: 'en',
                    groupValue: _selected,
                    activeColor: SettingsService().currentTheme.primary,
                    onChanged: (val) => setState(() => _selected = val!),
                  ),
                  const Divider(height: 1),
                  RadioListTile<String>(
                    title: const Text('বাংলা (Bengali)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('চলো কলকাতা • সমস্ত বাস ও মেট্রো রুটের বিবরণ বাংলায়', style: TextStyle(fontSize: 11)),
                    value: 'bn',
                    groupValue: _selected,
                    activeColor: SettingsService().currentTheme.primary,
                    onChanged: (val) => setState(() => _selected = val!),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: SettingsService().currentTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  SettingsService().setLanguage(_selected);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(_selected == 'bn' ? 'ভাষা বাংলা নির্বাচন করা হয়েছে' : 'Language set to English')),
                  );
                  Navigator.pop(context);
                },
                child: const Text('SAVE PREFERENCE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 6. PRIVACY POLICY & DATA SECURITY PAGE
// ==========================================
class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: SettingsService().currentTheme.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Privacy & Transit Security', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.shield, color: SettingsService().currentTheme.primary, size: 24),
                      const SizedBox(width: 8),
                      const Text('256-Bit Encrypted Architecture', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'CholoKolkata is built with zero-leakage security. All route queries, live bus schedules, and multi-hop transit paths are encrypted using AES-GCM 256-bit cryptography directly on the transport layer.',
                    style: TextStyle(fontSize: 12, height: 1.5, color: Color(0xFF37474F)),
                  ),
                  const Divider(height: 24),
                  _buildPolicyBullet('Zero Personal Identity Collection', 'We do not collect names, phone numbers, email addresses, or contacts.'),
                  _buildPolicyBullet('Anonymous Transit Search Telemetry', 'Bus & Metro route searches are queued locally and synced in aggregate batches to improve route coverage, then cleared from device storage.'),
                  _buildPolicyBullet('Community Chat Safety Metadata', 'Community posts use ephemeral Passenger IDs; approximate location and IP metadata are logged privately on the server solely for spam moderation.'),
                  _buildPolicyBullet('Offline-First Transit Cache', 'Bus stops and station directory are stored on your local device for instant access even in subway tunnels.'),
                  _buildPolicyBullet('No Third-Party Ad Trackers', 'Zero tracking SDKs or ad analytics networks monitoring commuter movements.'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            color: SettingsService().currentTheme.lightBg,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(Icons.favorite, color: SettingsService().currentTheme.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Made with love for Kolkata commuters • Dedicated to smooth daily transit across West Bengal.',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: SettingsService().currentTheme.badgeText),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyBullet(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, size: 16, color: Color(0xFF2E7D32)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 2),
                Text(desc, style: TextStyle(fontSize: 11, color: Colors.grey[700])),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 7. METRO DIRECTORY & TIMINGS PAGE
// ==========================================
class MetroDirectoryPage extends StatelessWidget {
  const MetroDirectoryPage({super.key});

  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.tryParse(hex, radix: 16) ?? 0xFF00897B);
  }

  @override
  Widget build(BuildContext context) {
    final lines = [
      {
        'num': '1',
        'name': 'Blue Line (North-South Corridor)',
        'color': '#1976D2',
        'from': 'Dakshineswar',
        'to': 'Kavi Subhash (New Garia)',
        'stations': '26 Stations',
        'first': '06:50 AM',
        'last': '09:40 PM',
        'peak': 'Every 5-6 mins',
        'offpeak': 'Every 8-10 mins',
        'feature': 'First Metro Line in India (1984) connecting North & South Kolkata',
      },
      {
        'num': '2',
        'name': 'Green Line (Underwater Ganga Section)',
        'color': '#2E7D32',
        'from': 'Howrah Maidan',
        'to': 'Esplanade',
        'stations': '4 Stations',
        'first': '07:00 AM',
        'last': '09:45 PM',
        'peak': 'Every 10-12 mins',
        'offpeak': 'Every 15 mins',
        'feature': 'India’s 1st Underwater Metro Tunnel passing 33m under the Hooghly River',
      },
      {
        'num': '2',
        'name': 'Green Line (East-West Sector V Section)',
        'color': '#2E7D32',
        'from': 'Sealdah',
        'to': 'Salt Lake Sector V',
        'stations': '8 Stations',
        'first': '06:55 AM',
        'last': '09:40 PM',
        'peak': 'Every 10-12 mins',
        'offpeak': 'Every 15-20 mins',
        'feature': 'Direct high-speed connectivity to Kolkata IT Hub & Salt Lake Stadium',
      },
      {
        'num': '3',
        'name': 'Purple Line (Southwest Corridor)',
        'color': '#7B1FA2',
        'from': 'Joka',
        'to': 'Majerhat',
        'stations': '7 Stations',
        'first': '08:30 AM',
        'last': '03:35 PM',
        'peak': 'Every 25 mins',
        'offpeak': 'Every 35 mins',
        'feature': 'Elevated Diamond Harbour Rd Corridor serving IIM Calcutta & Taratala',
      },
      {
        'num': '6',
        'name': 'Orange Line (EM Bypass Corridor)',
        'color': '#E65100',
        'from': 'Kavi Subhash (New Garia)',
        'to': 'Hemanta Mukherjee (Ruby)',
        'stations': '5 Stations',
        'first': '09:00 AM',
        'last': '04:40 PM',
        'peak': 'Every 20 mins',
        'offpeak': 'Every 24 mins',
        'feature': 'Seamless interchange with Line 1 at New Garia along EM Bypass',
      },
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: SettingsService().currentTheme.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Metro Directory & Timings',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: SettingsService().currentTheme.lightBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: SettingsService().currentTheme.badgeBg),
            ),
            child: Row(
              children: [
                Icon(Icons.subway, color: SettingsService().currentTheme.primary, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Official Kolkata Metro Rail Corporation (KMRC) Network & Timings Directory',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: SettingsService().currentTheme.badgeText),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          ...lines.map((l) {
            final lineColor = _hexToColor(l['color']!);
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 1.5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: lineColor.withOpacity(0.5), width: 1.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: lineColor, borderRadius: BorderRadius.circular(4)),
                          child: Text('Line ${l['num']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l['name']!,
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: lineColor),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('${l['from']} ⇄ ${l['to']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
                    const SizedBox(height: 3),
                    Text('${l['stations']} • ${l['feature']}', style: TextStyle(color: Colors.grey[700], fontSize: 11, height: 1.3)),
                    const Divider(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildTimingsCol('FIRST TRAIN', l['first']!),
                        _buildTimingsCol('LAST TRAIN', l['last']!),
                        _buildTimingsCol('PEAK FREQ', l['peak']!),
                        _buildTimingsCol('OFF-PEAK', l['offpeak']!),
                      ],
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

  Widget _buildTimingsCol(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF1E293B))),
      ],
    );
  }
}
