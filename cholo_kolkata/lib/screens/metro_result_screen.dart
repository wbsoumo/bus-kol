import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/settings_service.dart';

class MetroResultScreen extends StatefulWidget {
  final MetroPlan plan;

  const MetroResultScreen({super.key, required this.plan});

  @override
  State<MetroResultScreen> createState() => _MetroResultScreenState();
}

class _MetroResultScreenState extends State<MetroResultScreen> {
  bool _expandLeg1 = false;
  bool _expandLeg2 = false;
  bool _expandDirect = false;

  Color _hexToColor(String? hex) {
    if (hex == null || hex.isEmpty) return const Color(0xFF00897B);
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.tryParse(hex, radix: 16) ?? 0xFF00897B);
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final isInterchange = plan.type == 'INTERCHANGE';

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Metro Route & Fare',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Colors.white),
            ),
            Text(
              '${plan.fromStation} ➔ ${plan.toStation}',
              style: TextStyle(fontSize: 12, color: SettingsService().currentTheme.lightBg),
            ),
          ],
        ),
        backgroundColor: SettingsService().currentTheme.primary,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. TOP SUMMARY CARD
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isInterchange ? const Color(0xFFFFF3E0) : const Color(0xFFE0F2F1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isInterchange ? const Color(0xFFFFB74D) : const Color(0xFF80CBC4),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isInterchange ? Icons.alt_route : Icons.straight,
                                size: 14,
                                color: isInterchange ? const Color(0xFFE65100) : const Color(0xFF00796B),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isInterchange ? '1 LINE INTERCHANGE' : 'DIRECT TRAIN (NO CHANGE)',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                  color: isInterchange ? const Color(0xFFE65100) : const Color(0xFF00796B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFA5D6A7)),
                          ),
                          child: Row(
                            children: [
                              Text(
                                plan.fareText,
                                style: const TextStyle(color: Color(0xFF1B5E20), fontWeight: FontWeight.w900, fontSize: 20),
                              ),
                              const SizedBox(width: 4),
                              const Text('FARE', style: TextStyle(color: Color(0xFF2E7D32), fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem(Icons.timer_outlined, '${plan.durationMins} mins', 'DURATION'),
                        Container(width: 1, height: 30, color: Colors.grey[200]),
                        _buildStatItem(Icons.apartment, '${plan.stationsCount} Stations', 'TOTAL STOPS'),
                        Container(width: 1, height: 30, color: Colors.grey[200]),
                        _buildStatItem(Icons.straighten, '${plan.distanceKm} km', 'DISTANCE'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 2. DETAILED ROUTE & INTERCHANGE STATIONS
            if (isInterchange) ...[
              // --- LEG 1 ---
              _buildCorridorHeader(
                corridorName: plan.leg1LineName ?? 'Line 1',
                lineColor: _hexToColor(plan.leg1LineColor ?? '#1976D2'),
                instruction: 'Board at ${plan.fromStation} towards ${plan.interchangeStation ?? "Transfer"}',
                badgeText: 'LEG 1',
              ),
              const SizedBox(height: 8),
              _buildStationsTimeline(
                stations: plan.leg1Stations.isNotEmpty ? plan.leg1Stations : plan.stations,
                lineColor: _hexToColor(plan.leg1LineColor ?? '#1976D2'),
                isExpanded: _expandLeg1,
                onToggleExpand: () => setState(() => _expandLeg1 = !_expandLeg1),
              ),
              const SizedBox(height: 14),

              // --- INTERCHANGE TRANSFER CARD (Prominent Transfer Guide) ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFFCA28), width: 1.5),
                  boxShadow: [
                    BoxShadow(color: Colors.amber.withOpacity(0.12), blurRadius: 6, offset: const Offset(0, 3)),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF8F00),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.transfer_within_a_station, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'CHANGE LINE AT ${plan.interchangeStation?.toUpperCase() ?? "ESPLANADE"}',
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFFE65100)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Alight from ${plan.leg1LineName ?? "Line 1"} and follow signs to ${plan.leg2LineName ?? "Connecting Line"} platform via concourse subway (2-3 mins transfer).',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF424242), height: 1.35),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // --- LEG 2 ---
              _buildCorridorHeader(
                corridorName: plan.leg2LineName ?? 'Line 2',
                lineColor: _hexToColor(plan.leg2LineColor ?? '#2E7D32'),
                instruction: 'Board train at ${plan.interchangeStation ?? "Transfer"} towards ${plan.toStation}',
                badgeText: 'LEG 2',
              ),
              const SizedBox(height: 8),
              _buildStationsTimeline(
                stations: plan.leg2Stations.isNotEmpty ? plan.leg2Stations : [],
                lineColor: _hexToColor(plan.leg2LineColor ?? '#2E7D32'),
                isExpanded: _expandLeg2,
                onToggleExpand: () => setState(() => _expandLeg2 = !_expandLeg2),
              ),
            ] else ...[
              // --- DIRECT SINGLE-LINE ROUTE ---
              _buildCorridorHeader(
                corridorName: plan.lineName ?? 'Direct Metro Corridor',
                lineColor: _hexToColor(plan.lineColor ?? '#00897B'),
                instruction: 'Direct train on ${plan.lineName}. No interchange needed.',
                badgeText: 'DIRECT',
              ),
              const SizedBox(height: 8),
              _buildStationsTimeline(
                stations: plan.stations,
                lineColor: _hexToColor(plan.lineColor ?? '#00897B'),
                isExpanded: _expandDirect,
                onToggleExpand: () => setState(() => _expandDirect = !_expandDirect),
              ),
            ],

            const SizedBox(height: 20),
            // Landmark and Facilities Card
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: SettingsService().currentTheme.primary),
                        const SizedBox(width: 6),
                        Text('SMART CARD & TOKEN RULES', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: SettingsService().currentTheme.primary)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• Kolkata Metro Smart Card users get 10% discount on standard token fares.\n'
                      '• QR Code tickets are available on the Official Metro App & counter.\n'
                      '• Maximum allowed journey time between entry and exit is 180 minutes.',
                      style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.5),
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

  Widget _buildStatItem(IconData icon, String val, String label) {
    return Column(
      children: [
        Icon(icon, size: 18, color: SettingsService().currentTheme.primary),
        const SizedBox(height: 4),
        Text(val, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF1E293B))),
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
      ],
    );
  }

  Widget _buildCorridorHeader({
    required String corridorName,
    required Color lineColor,
    required String instruction,
    required String badgeText,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: lineColor, width: 6)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: lineColor, borderRadius: BorderRadius.circular(4)),
                child: Text(badgeText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  corridorName,
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: lineColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(instruction, style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildStationsTimeline({
    required List<MetroStation> stations,
    required Color lineColor,
    required bool isExpanded,
    required VoidCallback onToggleExpand,
  }) {
    if (stations.isEmpty) return const SizedBox.shrink();

    final first = stations.first;
    final last = stations.last;
    final intermediate = stations.length > 2 ? stations.sublist(1, stations.length - 1) : <MetroStation>[];

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        child: Column(
          children: [
            // Boarding Station
            _buildStationRow(first, lineColor, isStart: true),

            // Intermediate Stations Dropdown/Collapsible
            if (intermediate.isNotEmpty) ...[
              InkWell(
                onTap: onToggleExpand,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 22),
                  child: Row(
                    children: [
                      Container(width: 2, height: 24, color: lineColor.withOpacity(0.4)),
                      const SizedBox(width: 14),
                      Text(
                        isExpanded ? 'Hide ${intermediate.length} intermediate stops' : '${intermediate.length} stops between (Tap to view)',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: lineColor),
                      ),
                      Icon(isExpanded ? Icons.expand_less : Icons.expand_more, size: 16, color: lineColor),
                    ],
                  ),
                ),
              ),
              if (isExpanded)
                ...intermediate.map((s) => _buildStationRow(s, lineColor, isIntermediate: true)),
            ],

            // Alight / Terminal Station
            if (stations.length > 1)
              _buildStationRow(last, lineColor, isEnd: true),
          ],
        ),
      ),
    );
  }

  Widget _buildStationRow(MetroStation s, Color lineColor, {bool isStart = false, bool isEnd = false, bool isIntermediate = false}) {
    final bn = s.stationBengali != null ? ' (${s.stationBengali})' : '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: isStart || isEnd ? lineColor : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: lineColor, width: 2.5),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${s.stationName}$bn',
                        style: TextStyle(
                          fontWeight: isStart || isEnd ? FontWeight.w900 : FontWeight.w600,
                          fontSize: isStart || isEnd ? 13 : 12,
                          color: isStart || isEnd ? const Color(0xFF0F172A) : const Color(0xFF475569),
                        ),
                      ),
                    ),
                    if (isStart)
                      _buildTag('BOARD', lineColor),
                    if (isEnd)
                      _buildTag('ALIGHT', Colors.red[700]!),
                  ],
                ),
                if (s.interchangeInfo != null && s.interchangeInfo!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      s.interchangeInfo!,
                      style: const TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 9)),
    );
  }
}

