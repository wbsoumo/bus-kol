import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/bus_data_service.dart';
import '../services/bus_photo_service.dart';
import '../services/multi_transit_service.dart';
import '../services/search_analytics_service.dart';
import '../services/settings_service.dart';
import '../widgets/bus_photo_viewer.dart';
import 'break_journey_detail_screen.dart';
import 'live_track_sheet.dart';

class ResultsScreen extends StatefulWidget {
  final String fromStop;
  final String toStop;

  const ResultsScreen({
    super.key,
    required this.fromStop,
    required this.toStop,
  });

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  String _error = '';
  List<BusRoute> _directRoutes = [];
  List<TransferRoute> _transferRoutes = [];
  List<BreakJourneyOption> _breakLessTime = [];
  List<BreakJourneyOption> _breakLessChanges = [];
  List<BreakJourneyOption> _breakCheapest = [];
  bool _expandLessTime = true;
  bool _expandLessChanges = false;
  bool _expandCheapest = false;
  bool _showBreakSuggestions = false;
  bool _breakSuggestionsLoaded = false;
  String _filter = 'all';

  late String _currentFrom;
  late String _currentTo;
  bool get _isBusNoSearch => _currentTo.isEmpty;

  @override
  void initState() {
    super.initState();
    _currentFrom = widget.fromStop;
    _currentTo = widget.toStop;
    _performSearch();
  }

  void _performSearch() async {
    // 1. Instant 0ms 100% Offline Search (all 2,172 routes + break journey hub engine)
    final busData = BusDataService();
    final List<BusRoute> localDirect = _isBusNoSearch
        ? busData.searchBusNumbers(_currentFrom, uniqueByRouteNo: false, limit: 80)
        : busData.searchRoutes(_currentFrom, _currentTo, limit: 80);

    final List<TransferRoute> localTransfers = !_isBusNoSearch
        ? busData.searchTransfers(_currentFrom, _currentTo, maxTransfers: 6)
        : [];

    setState(() {
      _directRoutes = localDirect;
      _transferRoutes = localTransfers;
      _breakLessTime = [];
      _breakLessChanges = [];
      _breakCheapest = [];
      _expandLessTime = true;
      _expandLessChanges = false;
      _expandCheapest = false;
      _showBreakSuggestions = false;
      _breakSuggestionsLoaded = false;
      _isLoading = false;
      _error = '';
    });

    // Record search locally and silently upload in background batch
    SearchAnalyticsService().recordSearch(
      mode: _isBusNoSearch ? 'bus_no' : 'bus_route',
      from: _isBusNoSearch ? '' : _currentFrom,
      to: _isBusNoSearch ? '' : _currentTo,
      busNo: _isBusNoSearch ? _currentFrom : '',
      resultsCount: localDirect.length + localTransfers.length,
    );

    // 2. Optional silent background sync (never blocks UI or shows offline errors)
    try {
      final res = await _api.searchRoutes(_currentFrom, _currentTo);
      final netDirect = res['direct'] as List<BusRoute>;
      final netTransfers = res['transfers'] as List<TransferRoute>;
      if (mounted && (netDirect.isNotEmpty || netTransfers.isNotEmpty)) {
        setState(() {
          if (netDirect.isNotEmpty) {
            _directRoutes = netDirect;
          }
          if (netTransfers.isNotEmpty && _transferRoutes.isEmpty) {
            _transferRoutes = netTransfers;
          }
        });
      }
    } catch (_) {
      // Offline dataset already resolved the search cleanly.
    }
  }

  void _computeBestBreakJourneys() {
    if (_isBusNoSearch) return;
    final grouped = MultiTransitService().suggestGroupedBreakJourneys(_currentFrom, _currentTo);
    setState(() {
      _breakLessTime = grouped.lessTime;
      _breakLessChanges = grouped.lessChanges;
      _breakCheapest = grouped.cheapest;
      _expandLessTime = true;
      _expandLessChanges = false;
      _expandCheapest = false;
      _breakSuggestionsLoaded = true;
      _showBreakSuggestions = true;
    });
  }

  void _swapAndRefresh() {
    if (_isBusNoSearch) {
      _performSearch();
      return;
    }
    setState(() {
      final temp = _currentFrom;
      _currentFrom = _currentTo;
      _currentTo = temp;
    });
    _performSearch();
  }

  List<BusRoute> get _filteredRoutes {
    if (_filter == 'break') return const [];
    if (_filter == 'ac') {
      return _directRoutes.where((r) => r.busType.toLowerCase().contains('ac')).toList();
    } else if (_filter == 'state') {
      return _directRoutes.where((r) =>
          r.busType.toLowerCase().contains('wbtc') ||
          r.category.contains('SBSTC') ||
          r.category.contains('NBSTC')).toList();
    } else if (_filter == 'mini') {
      return _directRoutes.where((r) => r.busType.toLowerCase().contains('mini')).toList();
    }
    return _directRoutes;
  }

  void _showBusInfo(BusRoute r) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isAc = r.busType.toLowerCase().contains('ac');
        final estKm = (r.totalStops * 1.3).toStringAsFixed(1);

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: SettingsService().currentTheme.primary, borderRadius: BorderRadius.circular(6)),
                        child: Text(r.routeNo, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                      ),
                      const SizedBox(width: 8),
                      Text(r.busType, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 10),

              // Real Bus Fleet Photo Gallery (busrepository.github.io/busrepo)
              BusPhotoGallery(
                routeNo: r.routeNo,
                isAc: isAc,
                category: r.category,
                height: 195,
              ),
              const SizedBox(height: 14),

              const Text('BUS ROUTE INFORMATION', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Color(0xFF546E7A), letterSpacing: 0.5)),
              const SizedBox(height: 8),
              _buildInfoRow('Terminal Route', '${r.origin} ➔ ${r.destination}'),
              _buildInfoRow('Via Major Stops', r.routeName),
              _buildInfoRow('Operating Hours', '05:30 AM - 10:15 PM (Daily)'),
              _buildInfoRow('Average Frequency', 'Every 8 - 12 mins'),
              _buildInfoRow('Route Distance', '~$estKm km (${r.totalStops} Stops)'),
              _buildInfoRow('Estimated Ticket Price', r.fareText),
              const SizedBox(height: 14),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SettingsService().currentTheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleText = _isBusNoSearch ? 'Bus Route: "$_currentFrom"' : '$_currentFrom ➔ $_currentTo';
    final subtitleText = _isLoading
        ? 'Scanning routes...'
        : _isBusNoSearch
            ? 'Found ${_directRoutes.length} matching routes'
            : 'Runs Daily • ${_directRoutes.length} Direct${_transferRoutes.isNotEmpty ? ' + ${_transferRoutes.length} Transfers' : ''}';

    return Scaffold(
      backgroundColor: const Color(0xFFEEF1F4),
      appBar: AppBar(
        backgroundColor: SettingsService().currentTheme.primary,
        elevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titleText,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              subtitleText,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_isBusNoSearch ? Icons.refresh : Icons.swap_vert, color: Colors.white),
            tooltip: _isBusNoSearch ? 'Refresh' : 'Swap & Refresh',
            onPressed: _swapAndRefresh,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter pills strip
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterPill('ALL', 'all'),
                  const SizedBox(width: 8),
                  _buildFilterPill('AC BUSES', 'ac'),
                  const SizedBox(width: 8),
                  _buildFilterPill('STATE (WBTC)', 'state'),
                  const SizedBox(width: 8),
                  _buildFilterPill('MINIBUS', 'mini'),
                  if (!_isBusNoSearch) ...[
                    const SizedBox(width: 8),
                    _buildFilterPill('BREAK JOURNEY', 'break'),
                  ],
                ],
              ),
            ),
          ),

          // Main list
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: SettingsService().currentTheme.primary),
                        const SizedBox(height: 12),
                        const Text('Finding Connecting Buses in Kolkata...', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )
                : _error.isNotEmpty
                    ? Center(child: Text(_error))
                    : _filteredRoutes.isEmpty && _transferRoutes.isEmpty && !_showBreakSuggestions
                        ? _buildEmptyState()
                        : ListView(
                            padding: const EdgeInsets.all(12),
                            children: [
                              // If 0 direct routes (and not user clicking BREAK JOURNEY pill) -> offer Smart Multimodal Break Journey CTA
                              if (_filteredRoutes.isEmpty && _filter != 'break' && !_isBusNoSearch)
                                _buildSuggestBestBreakCard(noDirectFound: true),

                              // Direct Bus Cards
                              ..._filteredRoutes.map((r) => _buildBusCard(r)),

                              // Suggest Best Break Journey CTA even when direct buses exist (or when BREAK filter active)
                              if (!_isBusNoSearch && (_filteredRoutes.isNotEmpty || _filter == 'break') && !_showBreakSuggestions)
                                _buildSuggestBestBreakCard(noDirectFound: false),

                              // Suggested Best Break Journeys (Collapsible: Less Time, Less Changes, Cheapest)
                              if (_showBreakSuggestions) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.bolt, size: 17, color: Color(0xFF1565C0)),
                                      const SizedBox(width: 6),
                                      const Expanded(
                                        child: Text(
                                          'SUGGESTED BREAK JOURNEYS',
                                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Color(0xFF1E293B), letterSpacing: 0.4),
                                        ),
                                      ),
                                      Text(
                                        'Tap route for details',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: SettingsService().currentTheme.primary),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_breakSuggestionsLoaded && _breakLessTime.isEmpty && _breakLessChanges.isEmpty && _breakCheapest.isEmpty)
                                  Card(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Text(
                                        'No faster Train/Auto/Bus break combination found between "$_currentFrom" and "$_currentTo". Check 1-Transfer bus routes below or refine stop names.',
                                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                      ),
                                    ),
                                  )
                                else ...[
                                  _buildBreakCategoryGroup(
                                    title: 'Less Time (Fastest ETA)',
                                    subtitle: _breakLessTime.isNotEmpty ? 'From ${_breakLessTime.first.totalEtaMins} mins' : '',
                                    icon: Icons.bolt,
                                    color: const Color(0xFF1565C0),
                                    options: _breakLessTime,
                                    isExpanded: _expandLessTime,
                                    onToggle: () => setState(() => _expandLessTime = !_expandLessTime),
                                  ),
                                  _buildBreakCategoryGroup(
                                    title: 'Less Changes (Fewest Transfers)',
                                    subtitle: _breakLessChanges.isNotEmpty
                                        ? '${_breakLessChanges.first.legs.length <= 1 ? 'Direct Rail' : '${_breakLessChanges.first.legs.length - 1} Change'}'
                                        : '',
                                    icon: Icons.swap_horiz,
                                    color: const Color(0xFF00796B),
                                    options: _breakLessChanges,
                                    isExpanded: _expandLessChanges,
                                    onToggle: () => setState(() => _expandLessChanges = !_expandLessChanges),
                                  ),
                                  _buildBreakCategoryGroup(
                                    title: 'Cheapest (Lowest Fare)',
                                    subtitle: _breakCheapest.isNotEmpty ? 'From ₹${_breakCheapest.first.totalFareInr}' : '',
                                    icon: Icons.savings_outlined,
                                    color: const Color(0xFF2E7D32),
                                    options: _breakCheapest,
                                    isExpanded: _expandCheapest,
                                    onToggle: () => setState(() => _expandCheapest = !_expandCheapest),
                                  ),
                                ],
                              ],

                              // 1-Transfer Bus Break Journey Cards
                              if (_transferRoutes.isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.shuffle, size: 16, color: Color(0xFF37474F)),
                                      SizedBox(width: 6),
                                      Text(
                                        'BUS BREAK JOURNEYS (1-TRANSFER HUBS)',
                                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF37474F), letterSpacing: 0.5),
                                      ),
                                    ],
                                  ),
                                ),
                                ..._transferRoutes.map((tr) => _buildTransferCard(tr)),
                              ],
                            ],
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPill(String title, String val) {
    final active = _filter == val;
    return InkWell(
      onTap: () => setState(() => _filter = val),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? SettingsService().currentTheme.primary : const Color(0xFFF0F4F8),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: active ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _buildBusCard(BusRoute r) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => LiveTrackScreen(
                routeId: r.id,
                routeNo: r.routeNo,
                busType: r.busType,
                initialFrom: _isBusNoSearch ? '' : _currentFrom,
                initialTo: _isBusNoSearch ? '' : _currentTo,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top line: Bus Number, Fare, (i) Details Button, Bus Type
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: SettingsService().currentTheme.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      r.routeNo,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  const Spacer(),
                  // WB Bus Fare Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFC8E6C9)),
                    ),
                    child: Text(
                      r.fareText,
                      style: const TextStyle(color: Color(0xFF1B5E20), fontWeight: FontWeight.w800, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // (i) Details Button with Real Fleet Photo
                  InkWell(
                    onTap: () => _showBusInfo(r),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: SettingsService().currentTheme.lightBg,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: SettingsService().currentTheme.badgeBg),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.info_outline, size: 14, color: SettingsService().currentTheme.primary),
                          const SizedBox(width: 3),
                          Text('INFO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: SettingsService().currentTheme.primary)),
                          if (BusPhotoService.hasKnownPhotos(r.routeNo)) ...[
                            const SizedBox(width: 3),
                            Icon(Icons.photo_camera_rounded, size: 11, color: SettingsService().currentTheme.primary),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      r.busType,
                      style: TextStyle(color: Colors.grey[800], fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Origin ➔ Destination
              Text(
                '${r.origin} ➔ ${r.destination}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 4),

              // Via Stops
              Text(
                'Via: ${r.routeName}',
                style: TextStyle(color: Colors.grey[700], fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),

              // Bottom status bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    r.stopsBetween != null ? '${r.stopsBetween} stops between' : '${r.totalStops} total stops',
                    style: TextStyle(color: Colors.grey[600], fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  Row(
                    children: [
                      Text('LIVE STATUS', style: TextStyle(color: SettingsService().currentTheme.primary, fontWeight: FontWeight.bold, fontSize: 11)),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios, size: 10, color: SettingsService().currentTheme.primary),
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

  Widget _buildTransferCard(TransferRoute tr) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFFFB74D), width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.transfer_within_a_station, size: 14, color: Color(0xFFE65100)),
                      const SizedBox(width: 4),
                      Text('Change at ${tr.hubName}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFFE65100))),
                    ],
                  ),
                  Text('~${tr.totalTimeMins} mins', style: TextStyle(color: Colors.grey[700], fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Leg 1
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LiveTrackScreen(
                      routeId: tr.leg1.id,
                      routeNo: tr.leg1.routeNo,
                      busType: tr.leg1.busType,
                      initialFrom: tr.leg1.fromStop,
                      initialTo: tr.leg1.toStop,
                    ),
                  ),
                );
              },
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFE0F2F1), borderRadius: BorderRadius.circular(3)),
                    child: Text(tr.leg1.routeNo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF00796B))),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('${tr.leg1.fromStop} ➔ ${tr.leg1.toStop}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                  Text('₹${tr.leg1.fare}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: Color(0xFF1B5E20))),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                ],
              ),
            ),
            const Divider(height: 12),

            // Leg 2
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LiveTrackScreen(
                      routeId: tr.leg2.id,
                      routeNo: tr.leg2.routeNo,
                      busType: tr.leg2.busType,
                      initialFrom: tr.leg2.fromStop,
                      initialTo: tr.leg2.toStop,
                    ),
                  ),
                );
              },
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFFFE0B2), borderRadius: BorderRadius.circular(3)),
                    child: Text(tr.leg2.routeNo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFFE65100))),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('${tr.leg2.fromStop} ➔ ${tr.leg2.toStop}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                  Text('₹${tr.leg2.fare}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: Color(0xFF1B5E20))),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                ],
              ),
            ),
            const SizedBox(height: 8),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total ${tr.totalStops} stops', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(4)),
                  child: Text('Combined: ${tr.fareText}', style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.w800, fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestBestBreakCard({required bool noDirectFound}) {
    final theme = SettingsService().currentTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: noDirectFound ? const Color(0xFFFFF8E1) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: noDirectFound ? const Color(0xFFFFCC80) : const Color(0xFFBFDBFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                noDirectFound ? Icons.alt_route : Icons.route,
                color: noDirectFound ? const Color(0xFFE65100) : theme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  noDirectFound
                      ? 'No direct bus route found between "$_currentFrom" and "$_currentTo"'
                      : 'Want a faster Break Journey route?',
                  style: TextStyle(
                    color: noDirectFound ? const Color(0xFFE65100) : const Color(0xFF1E3A8A),
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Combine Suburban Train + Bus + Share Auto (plus Ferry/Metro), ranked strictly by shortest ETA.',
            style: TextStyle(fontSize: 11.5, color: Colors.grey[800]),
          ),
          if (!_showBreakSuggestions) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _computeBestBreakJourneys,
                icon: const Icon(Icons.auto_awesome, color: Colors.white, size: 17),
                label: const Text(
                  'Suggest Best Break Journey',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: noDirectFound ? const Color(0xFFE65100) : theme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _modeBadgeColor(TransitMode mode) {
    switch (mode) {
      case TransitMode.train:
        return const Color(0xFF3949AB);
      case TransitMode.bus:
        return SettingsService().currentTheme.primary;
      case TransitMode.auto:
        return const Color(0xFF00796B);
      case TransitMode.ferry:
        return const Color(0xFF0277BD);
      case TransitMode.metro:
        return const Color(0xFF1565C0);
    }
  }

  IconData _modeBadgeIcon(TransitMode mode) {
    switch (mode) {
      case TransitMode.train:
        return Icons.train;
      case TransitMode.bus:
        return Icons.directions_bus;
      case TransitMode.auto:
        return Icons.electric_rickshaw;
      case TransitMode.ferry:
        return Icons.directions_boat;
      case TransitMode.metro:
        return Icons.subway;
    }
  }

  Widget _buildBreakCategoryGroup({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required List<BreakJourneyOption> options,
    required bool isExpanded,
    required VoidCallback onToggle,
  }) {
    if (options.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isExpanded ? color.withAlpha(110) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withAlpha(24),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Icon(icon, size: 17, color: color),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5, color: color),
                        ),
                        if (subtitle.isNotEmpty)
                          Text(
                            '$subtitle • ${options.length} route${options.length > 1 ? 's' : ''}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                          ),
                      ],
                    ),
                  ),
                  Icon(isExpanded ? Icons.expand_less : Icons.expand_more, color: color),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Column(
                children: options
                    .asMap()
                    .entries
                    .map((entry) => _buildBreakShortCard(entry.key, entry.value, title, color))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBreakShortCard(
    int idx,
    BreakJourneyOption opt,
    String categoryTitle,
    Color accentColor,
  ) {
    final changes = opt.legs.length > 1 ? opt.legs.length - 1 : 0;
    final hubsChain = <String>[
      if (opt.legs.isNotEmpty) opt.legs.first.fromStop,
      for (final l in opt.legs) l.toStop,
    ].join(' ➔ ');

    return Card(
      margin: const EdgeInsets.only(top: 6),
      elevation: 0.8,
      color: const Color(0xFFF8FAFC),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(9),
        side: BorderSide(color: idx == 0 ? accentColor.withAlpha(110) : const Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BreakJourneyDetailScreen(
                fromQuery: _currentFrom,
                toQuery: _currentTo,
                option: opt,
                categoryLabel: categoryTitle.toUpperCase(),
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Short metrics strip (ETA, Changes, KM, Fare)
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: idx == 0 ? accentColor : const Color(0xFF334155),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      '${opt.totalEtaMins} mins',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    changes == 0 ? 'Direct' : '$changes change${changes > 1 ? 's' : ''}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '• ${opt.totalDistanceKm} km',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: const Color(0xFFA5D6A7)),
                    ),
                    child: Text(
                      '₹${opt.totalFareInr}',
                      style: const TextStyle(color: Color(0xFF1B5E20), fontWeight: FontWeight.w900, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Row 2: Visual Mode Icons + Arrows
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (int i = 0; i < opt.legs.length; i++) ...[
                      if (i > 0)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(Icons.arrow_forward_rounded, size: 15, color: Color(0xFF64748B)),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: _modeBadgeColor(opt.legs[i].mode),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_modeBadgeIcon(opt.legs[i].mode), size: 12, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              opt.legs[i].badge.toUpperCase() == transitModeLabel(opt.legs[i].mode)
                                  ? transitModeLabel(opt.legs[i].mode)
                                  : '${transitModeLabel(opt.legs[i].mode)} ${opt.legs[i].badge}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 6),

              // Row 3: Short stop points + Tap prompt
              Row(
                children: [
                  Expanded(
                    child: Text(
                      hubsChain,
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('Details', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: accentColor)),
                  Icon(Icons.chevron_right, size: 15, color: accentColor),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.directions_bus_outlined, size: 58, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              _isBusNoSearch ? 'No buses matching "$_currentFrom"' : 'No direct buses found',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            const SizedBox(height: 6),
            Text(
              _isBusNoSearch
                  ? 'Try searching with route numbers like "215A", "S-12", "AC-12", or "44A".'
                  : 'No direct bus runs between "$_currentFrom" and "$_currentTo". Let CholoKolkata combine Train, Bus, and Auto sorted by shortest ETA.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            if (!_isBusNoSearch) ...[
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _computeBestBreakJourneys,
                  icon: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                  label: const Text(
                    'Suggest Best Break Journey',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SettingsService().currentTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
