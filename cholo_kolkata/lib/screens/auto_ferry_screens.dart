import 'package:flutter/material.dart';
import '../services/external_app_launcher.dart';
import '../services/kolkata_geo.dart';
import '../services/multi_transit_service.dart';
import '../services/search_analytics_service.dart';
import '../services/settings_service.dart';
import 'transit_detail_screen.dart';

class _AutoRideBookingCard extends StatelessWidget {
  final String fromLocation;
  final String toLocation;

  const _AutoRideBookingCard({
    required this.fromLocation,
    required this.toLocation,
  });

  Future<void> _launchUber(BuildContext context) async {
    final res = await ExternalAppLauncher.openUberRide(
      fromName: fromLocation,
      toName: toLocation,
      fromCoord: KolkataGeo.lookupExactCoord(fromLocation),
      toCoord: KolkataGeo.lookupExactCoord(toLocation),
    );
    if (res == 'failed' && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Uber.')),
      );
    }
  }

  Future<void> _launchRapido(BuildContext context) async {
    final res = await ExternalAppLauncher.openRapidoRide(
      fromName: fromLocation,
      toName: toLocation,
    );
    if (context.mounted && (fromLocation.trim().isNotEmpty || toLocation.trim().isNotEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res.startsWith('opened_playstore')
                ? 'Rapido not installed — opening Play Store'
                : 'Copied route ($fromLocation ➔ $toLocation) & opening Rapido',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _launchYatriSathi(BuildContext context) async {
    final res = await ExternalAppLauncher.openYatriSathiRide(
      fromName: fromLocation,
      toName: toLocation,
    );
    if (context.mounted && (fromLocation.trim().isNotEmpty || toLocation.trim().isNotEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res.startsWith('opened_playstore')
                ? 'Yatri Sathi not installed — opening Play Store'
                : 'Copied route ($fromLocation ➔ $toLocation) & opening Yatri Sathi',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasRoute = fromLocation.trim().isNotEmpty || toLocation.trim().isNotEmpty;
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.local_taxi, size: 17, color: Color(0xFF0F172A)),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Book Private Auto / Cab Directly',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF0F172A)),
                  ),
                ),
                if (hasRoute)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2F1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'LOCATION SYNC',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF00695C)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              hasRoute
                  ? 'Tap any app to book from ${fromLocation.isEmpty ? "Current GPS" : fromLocation} to ${toLocation.isEmpty ? "your stop" : toLocation}.'
                  : 'Quick-launch Uber, Rapido, or Yatri Sathi (opens Play Store if not installed).',
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _appIconBtn(
                  assetPath: 'assets/icons/uber.png',
                  label: 'Uber Auto',
                  sub: 'Auto-prefill GPS',
                  onTap: () => _launchUber(context),
                ),
                _appIconBtn(
                  assetPath: 'assets/icons/rapido.png',
                  label: 'Rapido',
                  sub: 'Bike / Auto',
                  onTap: () => _launchRapido(context),
                ),
                _appIconBtn(
                  assetPath: 'assets/icons/yatri_sathi.png',
                  label: 'Yatri Sathi',
                  sub: 'WB Official',
                  onTap: () => _launchYatriSathi(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _appIconBtn({
    required String assetPath,
    required String label,
    required String sub,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(assetPath, width: 44, height: 44, fit: BoxFit.cover),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Color(0xFF0F172A)),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                sub,
                style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AutoScreen extends StatefulWidget {
  const AutoScreen({super.key});

  @override
  State<AutoScreen> createState() => _AutoScreenState();
}

class _AutoScreenState extends State<AutoScreen> {
  final MultiTransitService _service = MultiTransitService();
  final TextEditingController _fromCtrl = TextEditingController();
  final TextEditingController _toCtrl = TextEditingController();

  List<String> _fromSuggestions = [];
  List<String> _toSuggestions = [];
  bool _showFromSug = false;
  bool _showToSug = false;

  late List<TransitRouteItem> _browseRoutes;

  @override
  void initState() {
    super.initState();
    _browseRoutes = _service.allAutoRoutes.take(30).toList();
  }

  @override
  void dispose() {
    _fromCtrl.dispose();
    _toCtrl.dispose();
    super.dispose();
  }

  void _openSearchResultsPage() {
    FocusScope.of(context).unfocus();
    setState(() {
      _showFromSug = false;
      _showToSug = false;
    });
    final from = _fromCtrl.text.trim();
    final to = _toCtrl.text.trim();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AutoResultsScreen(fromQuery: from, toQuery: to),
      ),
    );
  }

  void _quickCorridor(String from, String to) {
    _fromCtrl.text = from;
    _toCtrl.text = to;
    _openSearchResultsPage();
  }

  @override
  Widget build(BuildContext context) {
    final theme = SettingsService().currentTheme;

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // Auto Search Card
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2F1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.electric_rickshaw, color: Color(0xFF00796B), size: 20),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Share Auto Routes (Offline)',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                          ),
                          Text(
                            '${_service.allAutoRoutes.length} West Bengal Auto Corridors • GPS + Timings',
                            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _fromCtrl,
                  onChanged: (v) {
                    setState(() {
                      _fromSuggestions = _service.searchAutoStops(v, limit: 8);
                      _showFromSug = _fromSuggestions.isNotEmpty && v.trim().isNotEmpty;
                      _showToSug = false;
                    });
                  },
                  decoration: InputDecoration(
                    labelText: 'From Auto Stand / Stop',
                    hintText: 'e.g. Phoolbagan, Ultadanga, Garia',
                    prefixIcon: const Icon(Icons.trip_origin, color: Color(0xFF00796B), size: 18),
                    suffixIcon: _fromCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () => setState(() {
                              _fromCtrl.clear();
                              _showFromSug = false;
                            }),
                          )
                        : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                  ),
                ),
                if (_showFromSug)
                  _buildSugBox(_fromSuggestions, (sel) {
                    setState(() {
                      _fromCtrl.text = sel;
                      _showFromSug = false;
                    });
                  }),
                const SizedBox(height: 10),
                TextField(
                  controller: _toCtrl,
                  onChanged: (v) {
                    setState(() {
                      _toSuggestions = _service.searchAutoStops(v, limit: 8);
                      _showToSug = _toSuggestions.isNotEmpty && v.trim().isNotEmpty;
                      _showFromSug = false;
                    });
                  },
                  decoration: InputDecoration(
                    labelText: 'To Auto Stand (Optional)',
                    hintText: 'e.g. Karunamoyee, Ruby, Esplanade',
                    prefixIcon: const Icon(Icons.place, color: Color(0xFFC62828), size: 18),
                    suffixIcon: _toCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () => setState(() {
                              _toCtrl.clear();
                              _showToSug = false;
                            }),
                          )
                        : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                  ),
                ),
                if (_showToSug)
                  _buildSugBox(_toSuggestions, (sel) {
                    setState(() {
                      _toCtrl.text = sel;
                      _showToSug = false;
                    });
                  }),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _openSearchResultsPage,
                    icon: const Icon(Icons.search, color: Colors.white, size: 18),
                    label: const Text('Find Auto Routes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _quickChip('Phoolbagan ➔ Karunamoyee', () => _quickCorridor('Phoolbagan', 'Karunamoyee')),
                    _quickChip('Ultadanga ➔ Sector V', () => _quickCorridor('Ultadanga', 'Sector V')),
                    _quickChip('Jadavpur ➔ Garia', () => _quickCorridor('Jadavpur', 'Garia')),
                    _quickChip('Ballygunge ➔ Ruby', () => _quickCorridor('Ballygunge', 'Ruby')),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),

        // 3 Booking Apps Strip (Uber, Rapido, Yatri Sathi)
        AnimatedBuilder(
          animation: Listenable.merge([_fromCtrl, _toCtrl]),
          builder: (_, _) => _AutoRideBookingCard(
            fromLocation: _fromCtrl.text.trim(),
            toLocation: _toCtrl.text.trim(),
          ),
        ),

        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Text(
            'POPULAR OFFLINE AUTO CORRIDORS (${_service.allAutoRoutes.length} TOTAL)',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569)),
          ),
        ),
        ..._browseRoutes.map((r) => _TransitRouteCard(
              route: r,
              accentColor: const Color(0xFF00796B),
              icon: Icons.electric_rickshaw,
            )),
      ],
    );
  }

  Widget _quickChip(String label, VoidCallback onTap) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      onPressed: onTap,
      backgroundColor: const Color(0xFFF1F5F9),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildSugBox(List<String> items, ValueChanged<String> onPick) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      constraints: const BoxConstraints(maxHeight: 160),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: items.length,
        itemBuilder: (_, i) => ListTile(
          dense: true,
          leading: const Icon(Icons.location_on_outlined, size: 16, color: Color(0xFF00796B)),
          title: Text(items[i], style: const TextStyle(fontSize: 13)),
          onTap: () => onPick(items[i]),
        ),
      ),
    );
  }
}

/// Dedicated Auto Search Result Page showing Stops + 3 Ride Booking App Buttons (Uber, Rapido, Yatri Sathi)
class AutoResultsScreen extends StatefulWidget {
  final String fromQuery;
  final String toQuery;

  const AutoResultsScreen({
    super.key,
    required this.fromQuery,
    required this.toQuery,
  });

  @override
  State<AutoResultsScreen> createState() => _AutoResultsScreenState();
}

class _AutoResultsScreenState extends State<AutoResultsScreen> {
  final MultiTransitService _service = MultiTransitService();
  late String _from;
  late String _to;
  late List<TransitRouteItem> _routes;

  @override
  void initState() {
    super.initState();
    _from = widget.fromQuery;
    _to = widget.toQuery;
    _search();
  }

  void _search() {
    _routes = _service.searchAutoRoutes(_from, _to, limit: 80);
    if (_from.isNotEmpty || _to.isNotEmpty) {
      SearchAnalyticsService().recordSearch(
        mode: 'auto_route',
        from: _from,
        to: _to,
        resultsCount: _routes.length,
      );
    }
  }

  void _swap() {
    setState(() {
      final tmp = _from;
      _from = _to;
      _to = tmp;
      _search();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = SettingsService().currentTheme;
    final title = (_from.isEmpty && _to.isEmpty)
        ? 'All Kolkata Auto Routes'
        : _to.isEmpty
            ? 'Auto Stands near "$_from"'
            : '$_from ➔ $_to';

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: theme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15.5),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${_routes.length} Share-Auto Route${_routes.length == 1 ? '' : 's'} Found (Offline)',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
        actions: [
          if (_from.isNotEmpty && _to.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.swap_vert, color: Colors.white),
              tooltip: 'Swap',
              onPressed: _swap,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (_routes.isEmpty)
            Card(
              elevation: 1.5,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(Icons.electric_rickshaw, size: 48, color: Color(0xFF00796B)),
                    const SizedBox(height: 10),
                    const Text(
                      'No direct share-auto corridor registered',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'You can book a direct Auto / Bike / Cab below on Uber, Rapido, or Yatri Sathi with your selected pickup and destination.',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            ..._routes.map((route) => _AutoStopRichCard(
                  route: route,
                  fromHint: _from,
                  toHint: _to,
                )),

          const SizedBox(height: 8),
          _AutoRideBookingCard(fromLocation: _from, toLocation: _to),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

/// Auto Search Result Card displaying distinct visual intermediate stop chips & timings
class _AutoStopRichCard extends StatelessWidget {
  final TransitRouteItem route;
  final String fromHint;
  final String toHint;

  const _AutoStopRichCard({
    required this.route,
    required this.fromHint,
    required this.toHint,
  });

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF00796B);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TransitDetailScreen(
                route: route,
                initialFrom: fromHint,
                initialTo: toHint,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(5)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.electric_rickshaw, size: 12, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(route.code, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${route.firstService}–${route.lastService} • Every ${route.headwayPeakMins}m',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: const Color(0xFFA5D6A7)),
                    ),
                    child: Text(route.fareText, style: const TextStyle(color: Color(0xFF1B5E20), fontWeight: FontWeight.w900, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${route.origin} ➔ ${route.destination}',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 8),

              // All Stops visual chips strip
              Wrap(
                spacing: 5,
                runSpacing: 5,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (int i = 0; i < route.stops.length; i++) ...[
                    if (i > 0)
                      const Icon(Icons.arrow_forward_rounded, size: 12, color: Color(0xFF94A3B8)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: (i == 0)
                            ? const Color(0xFFE8F5E9)
                            : (i == route.stops.length - 1)
                                ? const Color(0xFFFFEBEE)
                                : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: (i == 0)
                              ? const Color(0xFFA5D6A7)
                              : (i == route.stops.length - 1)
                                  ? const Color(0xFFEF9A9A)
                                  : const Color(0xFFCBD5E1),
                        ),
                      ),
                      child: Text(
                        route.stops[i].name,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: (i == 0 || i == route.stops.length - 1) ? FontWeight.w800 : FontWeight.w600,
                          color: (i == 0)
                              ? const Color(0xFF1B5E20)
                              : (i == route.stops.length - 1)
                                  ? const Color(0xFFB71C1C)
                                  : const Color(0xFF334155),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '~${route.durationMins} mins • ${route.distanceKm} km • ${route.stops.length} stops',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                  ),
                  const Row(
                    children: [
                      Text('MAP & TIMELINE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: accent)),
                      SizedBox(width: 3),
                      Icon(Icons.arrow_forward_ios, size: 10, color: accent),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FerryScreen extends StatefulWidget {
  const FerryScreen({super.key});

  @override
  State<FerryScreen> createState() => _FerryScreenState();
}

class _FerryScreenState extends State<FerryScreen> {
  final MultiTransitService _service = MultiTransitService();
  final TextEditingController _searchCtrl = TextEditingController();
  late List<TransitRouteItem> _routes;

  @override
  void initState() {
    super.initState();
    _routes = _service.allFerryRoutes;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _filter(String q) {
    setState(() {
      _routes = _service.searchFerryRoutes(q, '');
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE1F5FE),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.directions_boat, color: Color(0xFF0277BD), size: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Hooghly River Ferry Ghats (Offline)',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                          ),
                          Text(
                            '${_service.allFerryRoutes.length} Ferry Routes • WBSTC Timings, Fares & Ghat GPS',
                            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchCtrl,
                  onChanged: _filter,
                  decoration: InputDecoration(
                    labelText: 'Search Ghat (Howrah, Babughat, Belur, Bagbazar...)',
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF0277BD), size: 18),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              _searchCtrl.clear();
                              _filter('');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        ..._routes.map((r) => _TransitRouteCard(
              route: r,
              accentColor: const Color(0xFF0277BD),
              icon: Icons.directions_boat,
            )),
      ],
    );
  }
}

class _TransitRouteCard extends StatelessWidget {
  final TransitRouteItem route;
  final Color accentColor;
  final IconData icon;

  const _TransitRouteCard({
    required this.route,
    required this.accentColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final stopsPreview = route.stops.map((s) => s.name).take(5).join(' ➔ ');
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TransitDetailScreen(route: route),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 12, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(route.code, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${route.firstService}–${route.lastService} • Every ${route.headwayPeakMins}m',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFC8E6C9)),
                    ),
                    child: Text(
                      route.fareText,
                      style: const TextStyle(color: Color(0xFF1B5E20), fontWeight: FontWeight.w900, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${route.origin} ➔ ${route.destination}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                'Stops: $stopsPreview',
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '~${route.durationMins} mins • ${route.distanceKm} km • ${route.stops.length} stops',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                  ),
                  Row(
                    children: [
                      Text('MAP & TIMINGS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: accentColor)),
                      const SizedBox(width: 3),
                      Icon(Icons.arrow_forward_ios, size: 10, color: accentColor),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
