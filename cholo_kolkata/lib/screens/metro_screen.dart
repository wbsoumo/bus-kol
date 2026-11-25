import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class MetroScreen extends StatefulWidget {
  const MetroScreen({super.key});

  @override
  State<MetroScreen> createState() => _MetroScreenState();
}

class _MetroScreenState extends State<MetroScreen> {
  final ApiService _api = ApiService();

  bool _isLoading = true;
  List<MetroStation> _stations = [];
  List<MetroLine> _lines = [];

  String? _fromStation;
  String? _toStation;

  bool _isPlanning = false;
  MetroPlan? _plan;
  String _alertMessage = '';
  bool _areIntermediateExpanded = false; // Collapsed by default

  @override
  void initState() {
    super.initState();
    _loadMetroData();
  }

  void _loadMetroData() async {
    try {
      final stns = await _api.getMetroStations();
      final lines = await _api.getMetroLines();
      setState(() {
        _stations = stns;
        _lines = lines;
        _isLoading = false;

        // Default popular route
        if (_stations.isNotEmpty) {
          _fromStation = 'Howrah Maidan';
          _toStation = 'Esplanade';
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _alertMessage = 'Failed to load metro data';
      });
    }
  }

  void _swapStations() {
    setState(() {
      final temp = _fromStation;
      _fromStation = _toStation;
      _toStation = temp;
      _areIntermediateExpanded = false;
    });
    if (_fromStation != null && _toStation != null) {
      _planJourney();
    }
  }

  void _planJourney() async {
    if (_fromStation == null || _toStation == null) {
      setState(() => _alertMessage = 'Please select both departure and destination stations.');
      return;
    }
    if (_fromStation == _toStation) {
      setState(() => _alertMessage = 'Departure and destination cannot be the same station.');
      return;
    }

    setState(() {
      _isPlanning = true;
      _alertMessage = '';
      _areIntermediateExpanded = false; // reset to collapsed
    });

    try {
      final p = await _api.planMetroRoute(_fromStation!, _toStation!);
      setState(() {
        _plan = p;
        _isPlanning = false;
      });
    } catch (e) {
      setState(() {
        _isPlanning = false;
        _alertMessage = 'Could not calculate metro route';
      });
    }
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF00695C)));
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // Route & Fare Planner Card (Delhi Metro App Style)
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.route, color: Color(0xFF00897B), size: 18),
                    SizedBox(width: 6),
                    Text('STATION TO STATION ROUTE PLANNER', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Color(0xFF546E7A), letterSpacing: 0.5)),
                  ],
                ),
                const SizedBox(height: 12),

                // From Station Dropdown Box
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCFD8DC), width: 1.2),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.circle, color: Color(0xFF2E7D32), size: 12),
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
                            onChanged: (val) => setState(() => _fromStation = val),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Swap Row
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      InkWell(
                        onTap: _swapStations,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey[300]!),
                            boxShadow: [BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 3)],
                          ),
                          child: const Icon(Icons.swap_vert, size: 20, color: Color(0xFF00695C)),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),

                // To Station Dropdown Box
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCFD8DC), width: 1.2),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.circle, color: Color(0xFFD32F2F), size: 12),
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
                            onChanged: (val) => setState(() => _toStation = val),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                if (_alertMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(_alertMessage, style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00897B),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 2,
                    ),
                    icon: _isPlanning
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.subway, color: Colors.white),
                    label: Text(
                      _isPlanning ? 'Calculating...' : 'SHOW ROUTE & FARE',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.5),
                    ),
                    onPressed: _isPlanning ? null : _planJourney,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Journey Plan Result Card (Delhi Metro App Style with Collapsed Stations & Interchange Steps)
        if (_plan != null) ...[
          Card(
            elevation: 2.5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: Color(0xFF80CBC4), width: 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F2F1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _plan!.type == 'DIRECT' ? 'DIRECT TRAIN' : '1 INTERCHANGE ROUTE',
                              style: const TextStyle(color: Color(0xFF00796B), fontWeight: FontWeight.bold, fontSize: 10),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text('${_plan!.fromStation} ➔ ${_plan!.toStation}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFC8E6C9)),
                        ),
                        child: Column(
                          children: [
                            Text(_plan!.fareText, style: const TextStyle(color: Color(0xFF1B5E20), fontWeight: FontWeight.w900, fontSize: 17)),
                            const Text('FARE', style: TextStyle(color: Color(0xFF2E7D32), fontSize: 9, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Stats pills
                  Row(
                    children: [
                      _buildStatPill(Icons.timer_outlined, '${_plan!.durationMins} mins'),
                      const SizedBox(width: 8),
                      _buildStatPill(Icons.apartment, '${_plan!.stationsCount} Stations'),
                      const SizedBox(width: 8),
                      _buildStatPill(Icons.straighten, '${_plan!.distanceKm.toStringAsFixed(1)} km'),
                    ],
                  ),

                  // Detailed Interchange Instructions if route requires changing lines
                  if (_plan!.type == 'INTERCHANGE') ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFFCC80)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.shuffle, size: 16, color: Color(0xFFE65100)),
                              SizedBox(width: 6),
                              Text('INTERCHANGE ROUTE DETAILS', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Color(0xFFE65100))),
                            ],
                          ),
                          const SizedBox(height: 6),
                          _buildStepRow(1, 'Board train at ${_plan!.fromStation} towards ${_plan!.interchangeStation ?? "Esplanade"}.'),
                          _buildStepRow(2, 'Alight at ${_plan!.interchangeStation ?? "Esplanade"} and walk via concourse subway to connecting platform.'),
                          _buildStepRow(3, 'Board connecting train towards ${_plan!.toStation}.'),
                        ],
                      ),
                    ),
                  ],

                  // COLLAPSIBLE INTERMEDIATE STATIONS (Collapsed by default)
                  if (_plan!.stations.isNotEmpty) ...[
                    const Divider(height: 20),

                    // 1. Departure Station Node
                    _buildStationNode(
                      station: _plan!.stations.first,
                      lineColor: _hexToColor(_plan!.lineColor ?? '#2E7D32'),
                      isTerminal: true,
                      label: 'BOARDING',
                    ),

                    // 2. Collapsed Intermediate Stations Button
                    if (_plan!.stations.length > 2) ...[
                      InkWell(
                        onTap: () {
                          setState(() {
                            _areIntermediateExpanded = !_areIntermediateExpanded;
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _areIntermediateExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                    size: 18,
                                    color: const Color(0xFF00695C),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _areIntermediateExpanded
                                        ? 'Hide intermediate stations'
                                        : '${_plan!.stations.length - 2} Intermediate Stations (Tap to view)',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF00695C)),
                                  ),
                                ],
                              ),
                              const Icon(Icons.touch_app, size: 14, color: Color(0xFF00695C)),
                            ],
                          ),
                        ),
                      ),

                      // Expanded list of intermediate stations
                      if (_areIntermediateExpanded) ...[
                        ..._plan!.stations.sublist(1, _plan!.stations.length - 1).map((s) {
                          return _buildStationNode(
                            station: s,
                            lineColor: _hexToColor(_plan!.lineColor ?? '#2E7D32'),
                            isTerminal: false,
                          );
                        }),
                      ],
                    ],

                    // 3. Arrival Station Node
                    _buildStationNode(
                      station: _plan!.stations.last,
                      lineColor: _hexToColor(_plan!.lineColor ?? '#2E7D32'),
                      isTerminal: true,
                      label: 'DESTINATION',
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Active Metro Corridors & Timings
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Text('METRO CORRIDOR DIRECTORY & TIMINGS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
        ),

        ..._lines.map((l) {
          final lineColor = _hexToColor(l.lineColor);
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: lineColor.withAlpha(100), width: 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: lineColor, borderRadius: BorderRadius.circular(4)),
                        child: Text('Line ${l.lineNumber}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(l.lineName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('${l.terminalFrom} ⇄ ${l.terminalTo}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text('${l.totalStations} Stations • ${l.specialFeature}', style: TextStyle(color: Colors.grey[700], fontSize: 11)),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('First: ${l.firstTrain}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      Text('Last: ${l.lastTrain}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      Text('Peak: ${l.peakHeadway}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF00695C))),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStepRow(int num, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 8,
            backgroundColor: const Color(0xFFE65100),
            child: Text('$num', style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 11, color: Color(0xFF37474F), fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _buildStationNode({
    required MetroStation station,
    required Color lineColor,
    required bool isTerminal,
    String? label,
  }) {
    final bn = station.stationBengali != null ? ' (${station.stationBengali})' : '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Row(
        children: [
          Container(
            width: isTerminal ? 12 : 8,
            height: isTerminal ? 12 : 8,
            decoration: BoxDecoration(
              color: isTerminal ? lineColor : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: lineColor, width: 2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '${station.stationName}$bn',
                        style: TextStyle(
                          fontSize: isTerminal ? 13 : 12,
                          fontWeight: isTerminal ? FontWeight.w800 : FontWeight.w600,
                          color: isTerminal ? Colors.black87 : Colors.grey[800],
                        ),
                      ),
                    ),
                    if (label != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: label == 'BOARDING' ? const Color(0xFF2E7D32) : const Color(0xFFD32F2F),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(label, style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
                if (station.interchangeInfo != null) ...[
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDE7F6),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: const Color(0xFFD1C4E9)),
                    ),
                    child: Text(
                      station.interchangeInfo!,
                      style: const TextStyle(fontSize: 10, color: Color(0xFF4527A0), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill(IconData icon, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F6F8),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: Colors.grey[700]),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
