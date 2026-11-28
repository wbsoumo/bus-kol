import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/external_app_launcher.dart';
import '../services/metro_service.dart';
import '../services/search_analytics_service.dart';
import '../services/settings_service.dart';
import 'metro_result_screen.dart';
import 'drawer_pages.dart';

class MetroScreen extends StatefulWidget {
  const MetroScreen({super.key});

  @override
  State<MetroScreen> createState() => _MetroScreenState();
}

class _MetroScreenState extends State<MetroScreen> {
  final ApiService _api = ApiService();
  final SettingsService _settings = SettingsService();

  // Instant 0ms In-Memory Preload
  List<MetroStation> _stations = MetroService.defaultMetroStations;

  String? _fromStation;
  String? _toStation;

  String _alertMessage = '';

  @override
  void initState() {
    super.initState();
    _fromStation = _settings.lastFromMetroStation;
    _toStation = _settings.lastToMetroStation;
    _syncMetroData();
  }

  void _syncMetroData() async {
    try {
      final stns = await _api.getMetroStations();
      if (mounted) {
        setState(() {
          _stations = stns;
        });
      }
    } catch (_) {
      // In-memory data is already loaded and active
    }
  }

  void _swapStations() {
    setState(() {
      final temp = _fromStation;
      _fromStation = _toStation;
      _toStation = temp;
    });
    if (_fromStation != null && _toStation != null) {
      _settings.saveLastMetroSearch(_fromStation!, _toStation!);
    }
  }

  void _planJourney() {
    if (_fromStation == null || _toStation == null) {
      setState(() => _alertMessage = 'Please select both departure and destination stations.');
      return;
    }
    if (_fromStation == _toStation) {
      setState(() => _alertMessage = 'Departure and destination cannot be the same station.');
      return;
    }

    _settings.saveLastMetroSearch(_fromStation!, _toStation!);
    setState(() => _alertMessage = '');

    // Calculate instant 0ms plan and navigate to dedicated MetroResultScreen
    final plan = MetroService.planJourney(_fromStation!, _toStation!);
    SearchAnalyticsService().recordSearch(
      mode: 'metro',
      from: _fromStation!,
      to: _toStation!,
      resultsCount: plan.stationsCount,
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MetroResultScreen(plan: plan),
      ),
    );
  }

  void _selectQuickRoute(String from, String to) {
    setState(() {
      _fromStation = from;
      _toStation = to;
      _alertMessage = '';
    });
    _settings.saveLastMetroSearch(from, to);
    final plan = MetroService.planJourney(from, to);
    SearchAnalyticsService().recordSearch(
      mode: 'metro',
      from: from,
      to: to,
      resultsCount: plan.stationsCount,
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MetroResultScreen(plan: plan),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      children: [
        // 1. STATION TO STATION SEARCH CARD
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.alt_route, color: SettingsService().currentTheme.primary, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'STATION TO STATION ROUTE PLANNER',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: SettingsService().currentTheme.primary, letterSpacing: 0.5),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Departure Station Dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.trip_origin, size: 16, color: SettingsService().currentTheme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _fromStation,
                            isExpanded: true,
                            hint: const Text('Select departure station...'),
                            items: _stations.map((s) {
                              final bn = s.stationBengali != null ? ' (${s.stationBengali})' : '';
                              return DropdownMenuItem(
                                value: s.stationName,
                                child: Text('${s.stationName}$bn', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() => _fromStation = val);
                              if (val != null && _toStation != null) {
                                _settings.saveLastMetroSearch(val, _toStation!);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Swap Button Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    InkWell(
                      onTap: _swapStations,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: SettingsService().currentTheme.lightBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: SettingsService().currentTheme.badgeBg),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.swap_vert, size: 16, color: SettingsService().currentTheme.primary),
                            const SizedBox(width: 4),
                            Text('Swap Direction', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: SettingsService().currentTheme.primary)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Destination Station Dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, size: 16, color: Color(0xFFD32F2F)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _toStation,
                            isExpanded: true,
                            hint: const Text('Select arrival station...'),
                            items: _stations.map((s) {
                              final bn = s.stationBengali != null ? ' (${s.stationBengali})' : '';
                              return DropdownMenuItem(
                                value: s.stationName,
                                child: Text('${s.stationName}$bn', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() => _toStation = val);
                              if (val != null && _fromStation != null) {
                                _settings.saveLastMetroSearch(_fromStation!, val);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (_alertMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(_alertMessage, style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.subway, color: Colors.white, size: 20),
                    label: const Text(
                      'SHOW ROUTE & FARE',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5),
                    ),
                    onPressed: _planJourney,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),

        // 2. QUICK POPULAR METRO ROUTES (1-TAP DIRECT NAVIGATION)
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              Icon(Icons.bolt, size: 16, color: Colors.amber),
              SizedBox(width: 6),
              Text(
                'POPULAR METRO ROUTES',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Color(0xFF64748B), letterSpacing: 0.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),

        _buildQuickRouteCard(
          from: 'Howrah Maidan',
          to: 'Esplanade',
          line: 'Green Line (Underwater Tunnel)',
          color: const Color(0xFF2E7D32),
          fare: '₹10',
          time: '9 mins',
        ),
        _buildQuickRouteCard(
          from: 'Dakshineswar',
          to: 'Howrah Maidan',
          line: 'Blue Line ➔ Green Line (Interchange at Esplanade)',
          color: const Color(0xFFE65100),
          fare: '₹25',
          time: '28 mins',
          isInterchange: true,
        ),
        _buildQuickRouteCard(
          from: 'Dakshineswar',
          to: 'Kavi Subhash (New Garia)',
          line: 'Blue Line (North-South Corridor)',
          color: const Color(0xFF1976D2),
          fare: '₹25',
          time: '57 mins',
        ),
        _buildQuickRouteCard(
          from: 'Sealdah',
          to: 'Salt Lake Sector V',
          line: 'Green Line (IT Hub Corridor)',
          color: const Color(0xFF2E7D32),
          fare: '₹20',
          time: '18 mins',
        ),
        _buildQuickRouteCard(
          from: 'Joka',
          to: 'Majerhat',
          line: 'Purple Line (Southwest Corridor)',
          color: const Color(0xFF7B1FA2),
          fare: '₹20',
          time: '15 mins',
        ),

        const SizedBox(height: 14),

        // Official Aamar Kolkata Metro Online Ticket Booking Banner
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: SettingsService().currentTheme.lightBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: SettingsService().currentTheme.badgeBg),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset('assets/icons/aamar_kolkata_metro.png', width: 44, height: 44, fit: BoxFit.cover),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Book Metro Ticket Online',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, color: SettingsService().currentTheme.primary),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Use official Aamar Kolkata Metro app (opens Play Store if not installed).',
                      style: TextStyle(fontSize: 11, color: Color(0xFF334155)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => ExternalAppLauncher.openAamarKolkataMetro(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SettingsService().currentTheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('BOOK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11.5)),
              ),
            ],
          ),
        ),

        // 3. CORRIDOR DIRECTORY SHORTCUT (Link to Side Menu Page)
        InkWell(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const MetroDirectoryPage()));
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4)],
            ),
            child: Row(
              children: [
                Icon(Icons.menu_book, color: SettingsService().currentTheme.primary, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Metro Corridors & Timings Directory',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'View complete timings, peak headway & first/last trains',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildQuickRouteCard({
    required String from,
    required String to,
    required String line,
    required Color color,
    required String fare,
    required String time,
    bool isInterchange = false,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      color: Colors.white,
      child: InkWell(
        onTap: () => _selectQuickRoute(from, to),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 38,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('$from ➔ $to', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF0F172A))),
                        if (isInterchange) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(3)),
                            child: const Text('CHANGE', style: TextStyle(color: Color(0xFFE65100), fontWeight: FontWeight.bold, fontSize: 8)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(line, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(fare, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF1B5E20))),
                  Text(time, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
