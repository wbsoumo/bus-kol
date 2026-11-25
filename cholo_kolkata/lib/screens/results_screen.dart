import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/bus_photo_service.dart';
import '../widgets/bus_photo_viewer.dart';
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
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final res = await _api.searchRoutes(_currentFrom, _currentTo);
      setState(() {
        _directRoutes = res['direct'] as List<BusRoute>;
        _transferRoutes = res['transfers'] as List<TransferRoute>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not load buses. Please verify your connection.';
        _isLoading = false;
      });
    }
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
                        decoration: BoxDecoration(color: const Color(0xFF00695C), borderRadius: BorderRadius.circular(6)),
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
                    backgroundColor: const Color(0xFF00695C),
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
        backgroundColor: const Color(0xFF00695C),
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
            child: Row(
              children: [
                _buildFilterPill('ALL', 'all'),
                const SizedBox(width: 8),
                _buildFilterPill('AC BUSES', 'ac'),
                const SizedBox(width: 8),
                _buildFilterPill('STATE (WBTC)', 'state'),
                const SizedBox(width: 8),
                _buildFilterPill('MINIBUS', 'mini'),
              ],
            ),
          ),

          // Main list
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Color(0xFF00695C)),
                        SizedBox(height: 12),
                        Text('Finding Connecting Buses in Kolkata...', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )
                : _error.isNotEmpty
                    ? Center(child: Text(_error))
                    : _filteredRoutes.isEmpty && _transferRoutes.isEmpty
                        ? _buildEmptyState()
                        : ListView(
                            padding: const EdgeInsets.all(12),
                            children: [
                              // If 0 direct routes but transfers exist
                              if (_filteredRoutes.isEmpty && _transferRoutes.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF3E0),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFFFE0B2)),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.shuffle, color: Color(0xFFE65100), size: 20),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'No direct bus running. Showing recommended 1-Transfer connecting routes via major hubs:',
                                          style: TextStyle(color: Color(0xFFE65100), fontWeight: FontWeight.w700, fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              // Direct Bus Cards
                              ..._filteredRoutes.map((r) => _buildBusCard(r)),

                              // 1-Transfer Multi-Hop Cards
                              if (_transferRoutes.isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.shuffle, size: 16, color: Color(0xFF37474F)),
                                      SizedBox(width: 6),
                                      Text(
                                        '1-TRANSFER ROUTES (VIA TRANSIT HUBS)',
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
          color: active ? const Color(0xFF00695C) : const Color(0xFFF0F4F8),
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
                      color: const Color(0xFF00695C),
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
                        color: const Color(0xFFE0F2F1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFF80CBC4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.info_outline, size: 14, color: Color(0xFF00695C)),
                          const SizedBox(width: 3),
                          const Text('INFO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF00695C))),
                          if (BusPhotoService.hasKnownPhotos(r.routeNo)) ...[
                            const SizedBox(width: 3),
                            const Icon(Icons.photo_camera_rounded, size: 11, color: Color(0xFF00695C)),
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
                  const Row(
                    children: [
                      Text('LIVE STATUS', style: TextStyle(color: Color(0xFF00695C), fontWeight: FontWeight.bold, fontSize: 11)),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios, size: 10, color: Color(0xFF00695C)),
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.directions_bus_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              _isBusNoSearch ? 'No buses matching "$_currentFrom"' : 'No direct buses found',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              _isBusNoSearch
                  ? 'Try searching with route numbers like "215A", "S-12", "AC-12", or "44A".'
                  : 'No bus registered between "$_currentFrom" and "$_currentTo". Try searching via major hubs like Howrah, Esplanade, or Ultadanga.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
